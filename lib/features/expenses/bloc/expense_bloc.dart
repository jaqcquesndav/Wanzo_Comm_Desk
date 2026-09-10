import 'dart:io'; // Import for File, used by ExpenseEvent

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart'; // Ajouté pour debugPrint
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../repositories/expense_repository.dart';
import '../../../core/models/operation_payment.dart';
import '../../dashboard/models/operation_journal_entry.dart';
import '../../dashboard/bloc/operation_journal_bloc.dart';

part 'expense_event.dart';
part 'expense_state.dart';

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final ExpenseRepository _expenseRepository;
  final OperationJournalBloc _operationJournalBloc;
  final _uuid = const Uuid();

  // Getter pour accéder au repository du journal directement
  OperationJournalBloc get operationJournalBloc => _operationJournalBloc;

  ExpenseBloc({
    required ExpenseRepository expenseRepository,
    required OperationJournalBloc operationJournalBloc,
  }) : _expenseRepository = expenseRepository,
       _operationJournalBloc = operationJournalBloc,
       super(const ExpenseInitial()) {
    on<LoadExpenses>(_onLoadExpenses);
    on<LoadExpensesByDateRange>(_onLoadExpensesByDateRange);
    on<LoadExpensesByCategory>(_onLoadExpensesByCategory);
    on<AddExpense>(_onAddExpense);
    on<UpdateExpense>(_onUpdateExpense);
    on<RecordExpensePayment>(_onRecordExpensePayment);
    on<DeleteExpense>(_onDeleteExpense);
    on<LoadExpenseById>(_onLoadExpenseById);
    on<LoadExpenseCategories>(_onLoadExpenseCategories);
    on<CreateExpenseCategory>(_onCreateExpenseCategory);
    on<UpdateExpenseCategory>(_onUpdateExpenseCategory);
    on<DeleteExpenseCategory>(_onDeleteExpenseCategory);
  }

  Future<void> _onLoadExpenses(
    LoadExpenses event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(const ExpenseLoading());
    try {
      final expenses = await _expenseRepository.getAllExpenses();
      final total = expenses.fold(0.0, (sum, item) => sum + item.amount);
      emit(ExpensesLoaded(expenses: expenses, totalExpenses: total));
    } catch (e) {
      emit(ExpenseError("Erreur de chargement des dépenses: ${e.toString()}"));
    }
  }

  Future<void> _onLoadExpensesByDateRange(
    LoadExpensesByDateRange event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(const ExpenseLoading());
    try {
      final expenses = await _expenseRepository.getExpensesByDateRange(
        event.startDate,
        event.endDate,
      );
      final total = expenses.fold(0.0, (sum, item) => sum + item.amount);
      emit(ExpensesLoaded(expenses: expenses, totalExpenses: total));
    } catch (e) {
      emit(
        ExpenseError(
          "Erreur de chargement des dépenses par période: ${e.toString()}",
        ),
      );
    }
  }

  Future<void> _onLoadExpensesByCategory(
    LoadExpensesByCategory event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(const ExpenseLoading());
    try {
      final expenses = await _expenseRepository.getExpensesByCategory(
        event.category,
      );
      final total = expenses.fold(0.0, (sum, item) => sum + item.amount);
      emit(ExpensesLoaded(expenses: expenses, totalExpenses: total));
    } catch (e) {
      emit(
        ExpenseError(
          "Erreur de chargement des dépenses par catégorie: ${e.toString()}",
        ),
      );
    }
  }

  Future<void> _onAddExpense(
    AddExpense event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(const ExpenseLoading());
    try {
      debugPrint(
        "🔄 Traitement de l'ajout d'une dépense et création de l'entrée journal...",
      );

      // The repository now handles image uploads via the API service.
      // We pass the expense object and the imageFiles directly.
      final newExpense = await _expenseRepository.addExpense(
        event.expense,
        imageFiles: event.imageFiles,
      );

      debugPrint(
        "✅ Dépense ajoutée avec succès: ${newExpense.id}, ${newExpense.motif}, ${newExpense.amount} ${newExpense.effectiveCurrencyCode}",
      );

      // Journal entry creation with detailed logging
      final journalEntry = OperationJournalEntry(
        id: _uuid.v4(),
        date: newExpense.date,
        type: OperationType.cashOut,
        description: "Dépense: ${newExpense.motif}",
        amount: -newExpense.amount.abs(), // Amount négatif pour cashOut
        paymentMethod: newExpense.paymentMethod,
        relatedDocumentId: newExpense.id,
        currencyCode: newExpense.effectiveCurrencyCode,
        isDebit: true,
        isCredit: false,
        balanceAfter: 0.0, // Placeholder, will be calculated
      );

      debugPrint(
        "📝 Entrée journal créée: ${journalEntry.id}, ${journalEntry.description}, ${journalEntry.amount} ${journalEntry.currencyCode}",
      );

      // Utiliser une approche plus fiable pour l'ajout au journal (comme pour les ventes)
      try {
        debugPrint("🔄 Ajout de l'entrée au journal via repository...");
        // Accéder au repository du journal via le bloc
        await _operationJournalBloc.repository.addOperation(journalEntry);
        debugPrint("✅ Entrée ajoutée avec succès au journal via repository");

        // Rafraîchir le bloc du journal pour mettre à jour l'affichage
        _operationJournalBloc.add(const RefreshJournal());
        debugPrint("🔄 Journal rafraîchi");

        emit(
          const ExpenseOperationSuccess(
            'Dépense ajoutée avec succès et enregistrée au journal des opérations.',
          ),
        );
      } catch (journalError) {
        debugPrint(
          "⚠️ Erreur lors de l'ajout au journal via repository: $journalError",
        );

        // Méthode alternative via l'événement du bloc
        debugPrint("🔄 Tentative d'ajout via événement du bloc...");
        _operationJournalBloc.add(AddOperationJournalEntry(journalEntry));
        debugPrint("✅ Événement d'ajout envoyé au bloc du journal");

        emit(
          const ExpenseOperationSuccess(
            'Dépense ajoutée avec succès. Enregistrement au journal en cours...',
          ),
        );
      }

      add(const LoadExpenses());
    } catch (e) {
      debugPrint("❌ ERREUR lors de l'ajout de la dépense: $e");
      emit(
        ExpenseError("Erreur lors de l'ajout de la dépense: ${e.toString()}"),
      );
    }
  }

  Future<void> _onUpdateExpense(
    UpdateExpense event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(const ExpenseLoading());
    try {
      debugPrint(
        "🔄 Mise à jour d'une dépense et des entrées journal associées...",
      );

      // Fetch the original expense to compare changes
      final originalExpense = await _expenseRepository.getExpenseById(
        event.expense.id,
      );

      if (originalExpense == null) {
        debugPrint(
          "❌ Dépense originale non trouvée pour ID: ${event.expense.id}",
        );
        emit(
          ExpenseError(
            "Dépense originale non trouvée pour la mise à jour du journal.",
          ),
        );
        add(const LoadExpenses()); // Reload to reflect current state
        return;
      }

      await _expenseRepository.updateExpense(event.expense);
      final updatedExpense = event.expense; // Alias for clarity

      debugPrint(
        "✅ Dépense mise à jour: ${updatedExpense.id}, ${updatedExpense.motif}, ${updatedExpense.amount} ${updatedExpense.effectiveCurrencyCode}",
      );

      // 1. Create a reversing journal entry for the original expense
      final reversalJournalEntry = OperationJournalEntry(
        id: _uuid.v4(),
        date:
            DateTime.now(), // Or originalExpense.date - using now for reversal event time
        type: OperationType.cashIn, // Reversing a cashOut
        description:
            "Annulation (MàJ) Dépense: ${originalExpense.motif}", // Changed from description to motif
        amount: originalExpense.amount.abs(), // Positive amount for cashIn
        paymentMethod: originalExpense.paymentMethod,
        relatedDocumentId: originalExpense.id,
        currencyCode: originalExpense.effectiveCurrencyCode,
        isDebit: false, // Reversal of an expense is a credit
        isCredit: true,
        balanceAfter: 0.0, // Placeholder, to be calculated by journal logic
      );

      // 2. Create a new journal entry for the updated expense
      final newJournalEntry = OperationJournalEntry(
        id: _uuid.v4(),
        date: updatedExpense.date,
        type: OperationType.cashOut,
        description:
            "Dépense (MàJ): ${updatedExpense.motif}", // Changed from description to motif
        amount: -updatedExpense.amount.abs(), // Negative amount for cashOut
        paymentMethod: updatedExpense.paymentMethod,
        relatedDocumentId: updatedExpense.id,
        currencyCode: updatedExpense.effectiveCurrencyCode,
        isDebit: true, // Updated expense is a debit
        isCredit: false,
        balanceAfter: 0.0, // Placeholder, to be calculated by journal logic
      );

      // Tenter d'ajouter les entrées directement au repository du journal
      try {
        debugPrint("🔄 Ajout des entrées au journal via repository...");
        await _operationJournalBloc.repository.addOperationEntries([
          reversalJournalEntry,
          newJournalEntry,
        ]);
        debugPrint("✅ Entrées ajoutées avec succès au journal via repository");

        // Rafraîchir le bloc du journal
        _operationJournalBloc.add(const RefreshJournal());
      } catch (journalError) {
        debugPrint(
          "⚠️ Erreur lors de l'ajout au journal via repository: $journalError",
        );

        // Méthode alternative via l'événement du bloc
        debugPrint("🔄 Tentative d'ajout via événements du bloc...");
        _operationJournalBloc.add(
          AddOperationJournalEntry(reversalJournalEntry),
        );
        _operationJournalBloc.add(AddOperationJournalEntry(newJournalEntry));
      }

      emit(
        const ExpenseOperationSuccess(
          'Dépense mise à jour et journal ajusté avec succès.',
        ),
      );
      add(const LoadExpenses());
    } catch (e) {
      debugPrint("❌ ERREUR lors de la mise à jour de la dépense: $e");
      emit(
        ExpenseError(
          "Erreur lors de la mise à jour de la dépense: ${e.toString()}",
        ),
      );
    }
  }

  /// Enregistrer une tranche de règlement sur une dette fournisseur.
  Future<void> _onRecordExpensePayment(
    RecordExpensePayment event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(const ExpenseLoading());
    try {
      final outcome = await _expenseRepository.recordPayment(
        event.expense,
        event.payment,
      );

      // Décaissement au journal : seule la tranche réellement payée impacte la
      // trésorerie (la charge a déjà été enregistrée à la création).
      try {
        await _operationJournalBloc.repository.addOperation(
          OperationJournalEntry(
            id: _uuid.v4(),
            date: event.payment.paidAt,
            type: OperationType.cashOut,
            description: 'Règlement fournisseur: ${event.expense.motif}',
            amount: -event.payment.amountInCdf.abs(),
            paymentMethod: event.payment.method,
            relatedDocumentId: event.expense.id,
            currencyCode: event.payment.currencyCode,
            isDebit: true,
            isCredit: false,
            balanceAfter: 0.0,
          ),
        );
        _operationJournalBloc.add(const RefreshJournal());
      } catch (journalError) {
        debugPrint("⚠️ Erreur journal (règlement fournisseur): $journalError");
      }

      emit(
        ExpensePaymentRecorded(
          expense: outcome.expense,
          synced: outcome.synced,
          message: outcome.message,
        ),
      );
    } catch (e) {
      emit(
        ExpenseError(
          "Le paiement n'a pas pu être enregistré: "
          "${e is StateError ? e.message : e.toString()}",
        ),
      );
    }
  }

  Future<void> _onDeleteExpense(
    DeleteExpense event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(const ExpenseLoading());
    try {
      debugPrint(
        "🔄 Suppression d'une dépense et création d'une entrée d'annulation au journal...",
      );

      // Fetch the expense before deleting to get its details for the journal entry
      final expenseToDelete = await _expenseRepository.getExpenseById(
        event.expenseId,
      );

      if (expenseToDelete == null) {
        debugPrint("❌ Dépense non trouvée pour ID: ${event.expenseId}");
        emit(
          const ExpenseError(
            "Dépense non trouvée pour l'annulation du journal.",
          ),
        );
        return;
      }

      await _expenseRepository.deleteExpense(event.expenseId);
      debugPrint("✅ Dépense supprimée: ${event.expenseId}");

      // Create a reversing journal entry
      final journalEntry = OperationJournalEntry(
        id: _uuid.v4(),
        date:
            DateTime.now(), // Or expenseToDelete.date - decide on consistent date for reversal
        type: OperationType.cashIn, // Reversing a cashOut
        description:
            "Annulation Dépense: ${expenseToDelete.motif}", // Changed from description to motif
        amount: expenseToDelete.amount.abs(), // Positive amount for cashIn
        paymentMethod: expenseToDelete.paymentMethod,
        relatedDocumentId: expenseToDelete.id,
        currencyCode: expenseToDelete.effectiveCurrencyCode,
        isDebit: false, // Reversal of an expense is a credit
        isCredit: true,
        balanceAfter: 0.0, // Placeholder, to be calculated by journal logic
      );

      try {
        debugPrint(
          "🔄 Ajout de l'entrée d'annulation au journal via repository...",
        );
        await _operationJournalBloc.repository.addOperation(journalEntry);
        debugPrint(
          "✅ Entrée d'annulation ajoutée avec succès au journal via repository",
        );

        // Rafraîchir le bloc du journal
        _operationJournalBloc.add(const RefreshJournal());
      } catch (journalError) {
        debugPrint(
          "⚠️ Erreur lors de l'ajout de l'annulation au journal via repository: $journalError",
        );

        // Méthode alternative via l'événement du bloc
        _operationJournalBloc.add(AddOperationJournalEntry(journalEntry));
      }

      emit(
        const ExpenseOperationSuccess(
          'Dépense supprimée et annulation enregistrée au journal.',
        ),
      );
      add(const LoadExpenses());
    } catch (e) {
      debugPrint("❌ ERREUR lors de la suppression de la dépense: $e");
      emit(
        ExpenseError(
          "Erreur lors de la suppression de la dépense: ${e.toString()}",
        ),
      );
    }
  }

  Future<void> _onLoadExpenseById(
    LoadExpenseById event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(const ExpenseLoading());
    try {
      final expense = await _expenseRepository.getExpenseById(event.expenseId);
      if (expense != null) {
        emit(ExpenseLoaded(expense: expense));
      } else {
        emit(const ExpenseError("Dépense non trouvée."));
      }
    } catch (e) {
      emit(ExpenseError("Erreur de chargement de la dépense: ${e.toString()}"));
    }
  }

  // Category event handlers
  Future<void> _onLoadExpenseCategories(
    LoadExpenseCategories event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(const ExpenseLoading());
    try {
      final categories = await _expenseRepository.getExpenseCategories();
      emit(ExpenseCategoriesLoaded(categories: categories));
    } catch (e) {
      emit(
        ExpenseError("Erreur de chargement des catégories: ${e.toString()}"),
      );
    }
  }

  Future<void> _onCreateExpenseCategory(
    CreateExpenseCategory event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(const ExpenseLoading());
    try {
      final category = await _expenseRepository.createExpenseCategory(
        name: event.name,
        description: event.description,
        type: event.type,
      );
      if (category != null) {
        emit(
          ExpenseCategoryOperationSuccess(
            "Catégorie créée avec succès",
            category: category,
          ),
        );
      } else {
        emit(const ExpenseError("Échec de la création de la catégorie"));
      }
    } catch (e) {
      emit(ExpenseError("Erreur lors de la création: ${e.toString()}"));
    }
  }

  Future<void> _onUpdateExpenseCategory(
    UpdateExpenseCategory event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(const ExpenseLoading());
    try {
      final category = await _expenseRepository.updateExpenseCategory(
        id: event.id,
        name: event.name,
        description: event.description,
        type: event.type,
      );
      if (category != null) {
        emit(
          ExpenseCategoryOperationSuccess(
            "Catégorie mise à jour avec succès",
            category: category,
          ),
        );
      } else {
        emit(const ExpenseError("Échec de la mise à jour de la catégorie"));
      }
    } catch (e) {
      emit(ExpenseError("Erreur lors de la mise à jour: ${e.toString()}"));
    }
  }

  Future<void> _onDeleteExpenseCategory(
    DeleteExpenseCategory event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(const ExpenseLoading());
    try {
      final success = await _expenseRepository.deleteExpenseCategory(
        event.categoryId,
      );
      if (success) {
        emit(
          const ExpenseCategoryOperationSuccess(
            "Catégorie supprimée avec succès",
          ),
        );
      } else {
        emit(const ExpenseError("Échec de la suppression de la catégorie"));
      }
    } catch (e) {
      emit(ExpenseError("Erreur lors de la suppression: ${e.toString()}"));
    }
  }
}
