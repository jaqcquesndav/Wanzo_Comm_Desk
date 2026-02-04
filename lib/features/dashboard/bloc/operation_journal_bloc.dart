import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../models/operation_journal_entry.dart';
import '../models/journal_filter.dart';
import '../repositories/operation_journal_repository.dart';
import 'package:collection/collection.dart'; // For sortBy and groupBy
import '../../../core/utils/connectivity_service.dart';

part 'operation_journal_event.dart';
part 'operation_journal_state.dart';

class OperationJournalBloc
    extends Bloc<OperationJournalEvent, OperationJournalState> {
  final OperationJournalRepository _repository;
  final ConnectivityService _connectivityService;
  StreamSubscription? _connectivitySubscription;

  // Getter public pour accéder au repository depuis l'extérieur
  OperationJournalRepository get repository => _repository;

  OperationJournalBloc({
    required OperationJournalRepository repository,
    ConnectivityService? connectivityService,
  }) : _repository = repository,
       _connectivityService = connectivityService ?? ConnectivityService(),
       super(const OperationJournalInitial()) {
    on<LoadOperations>(_onLoadOperations);
    on<LoadOperationsWithFilter>(_onLoadOperationsWithFilter);
    on<FilterPeriodChanged>(_onFilterPeriodChanged);
    on<RefreshJournal>(_onRefreshJournal);
    on<AddOperationJournalEntry>(_onAddOperationJournalEntry);
    on<AddMultipleOperationJournalEntries>(
      _onAddMultipleOperationJournalEntries,
    );

    // Écouter les changements de connectivité pour synchroniser automatiquement
    _setupConnectivityListener();

    if (kDebugMode) {
      print('✅ OperationJournalBloc initialized and ready');
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Stream.periodic(
      const Duration(milliseconds: 500),
      (_) => _connectivityService.isConnected,
    ).distinct().listen((isConnected) {
      if (isConnected) {
        if (kDebugMode) {
          print(
            '🌐 Connexion rétablie - Synchronisation automatique du journal...',
          );
        }
        // Rafraîchir les données dès que la connexion est rétablie
        add(const RefreshJournal());
      }
    });
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadOperations(
    LoadOperations event,
    Emitter<OperationJournalState> emit,
  ) async {
    emit(const OperationJournalLoading());
    try {
      if (kDebugMode) {
        print(
          "📥 OperationJournalBloc: Loading operations from ${event.startDate} to ${event.endDate}",
        );
      }

      // 1. Fetch raw operations and opening balances
      final rawOperations = await _repository.getOperations(
        event.startDate,
        event.endDate,
      );

      if (kDebugMode) {
        print(
          "✅ OperationJournalBloc: Fetched ${rawOperations.length} operations",
        );
        if (rawOperations.isEmpty) {
          print(
            "⚠️ No operations found for the specified date range. This could be normal if:",
          );
          print("   - No transactions have been created yet");
          print("   - The date range doesn't contain any operations");
          print("   - Data was cleared/reset");
        }
      }
      // Récupérer les soldes d'ouverture PAR TYPE
      final openingBalancesByType = await _repository.getOpeningBalancesByType(
        event.startDate,
      );

      final openingCashBalances = openingBalancesByType['cash']!;
      final openingSalesBalances = openingBalancesByType['sales']!;
      final openingStockValues = openingBalancesByType['stock']!;

      // Pour rétrocompatibilité
      final openingBalancesByCurrency = openingCashBalances;
      final openingBalance = openingBalancesByCurrency.values.fold(
        0.0,
        (prev, curr) => prev + curr,
      );

      // 2. Sort operations by date
      final sortedOperations = List<OperationJournalEntry>.from(rawOperations);
      sortedOperations.sort((a, b) => a.date.compareTo(b.date));

      // 3. Calculate isDebit, isCredit, and running balances by TYPE
      final processedOperations = <OperationJournalEntry>[];

      // Maintenir les 3 types de soldes séparément
      Map<String, double> currentCashBalances = Map<String, double>.from(
        openingCashBalances,
      );
      Map<String, double> currentSalesBalances = Map<String, double>.from(
        openingSalesBalances,
      );
      Map<String, double> currentStockValues = Map<String, double>.from(
        openingStockValues,
      );

      double currentBalance = openingBalance; // DEPRECATED

      for (final op in sortedOperations) {
        final bool calculatedIsDebit = op.amount < 0;
        final bool calculatedIsCredit = op.amount > 0;
        final currencyCode = op.currencyCode ?? 'CDF';

        double? cashBalance;
        double? salesBalance;
        double? stockValue;

        // Traiter selon le type d'opération
        if (op.type.impactsCash) {
          // Opération de trésorerie
          final current = currentCashBalances[currencyCode] ?? 0.0;
          currentCashBalances[currencyCode] = current + op.amount;
          cashBalance = currentCashBalances[currencyCode];
          currentBalance += op.amount; // DEPRECATED
        } else if (op.type.isSalesOperation) {
          // Opération de vente
          // NOTE: On n'utilise PAS abs() car une correction de vente doit être soustraite
          // Les ventes sont toujours positives, les corrections/annulations sont négatives
          final current = currentSalesBalances[currencyCode] ?? 0.0;
          currentSalesBalances[currencyCode] = current + op.amount;
          salesBalance = currentSalesBalances[currencyCode];
          // NE PAS impacter currentBalance (c'est pas de la trésorerie!)
        } else if (op.type.impactsStock) {
          // Opération de stock
          final current = currentStockValues[currencyCode] ?? 0.0;
          currentStockValues[currencyCode] = current + op.amount;
          stockValue = currentStockValues[currencyCode];
          // NE PAS impacter currentBalance
        } else if (op.type.isFinancingOperation) {
          // Opération de financement - pas d'impact
        }

        // Vérifier que les devises principales sont présentes
        if (!currentCashBalances.containsKey('USD')) {
          currentCashBalances['USD'] = 0.0;
        }
        if (!currentCashBalances.containsKey('CDF')) {
          currentCashBalances['CDF'] = 0.0;
        }

        processedOperations.add(
          op.copyWith(
            isDebit: calculatedIsDebit,
            isCredit: calculatedIsCredit,
            balanceAfter: currentBalance, // DEPRECATED
            balancesByCurrency: Map<String, double>.from(
              currentCashBalances,
            ), // DEPRECATED
            cashBalance: cashBalance,
            salesBalance: salesBalance,
            stockValue: stockValue,
            cashBalancesByCurrency: Map<String, double>.from(
              currentCashBalances,
            ),
            salesBalancesByCurrency: Map<String, double>.from(
              currentSalesBalances,
            ),
            stockValuesByCurrency: Map<String, double>.from(currentStockValues),
          ),
        );
      }

      // 4. Group processed operations by day
      final grouped = _groupOperationsByDay(processedOperations);

      // 5. Emit the loaded state with processed data
      emit(
        OperationJournalLoaded(
          operations: processedOperations,
          filteredOperations:
              processedOperations, // Par défaut, toutes les opérations
          startDate: event.startDate,
          endDate: event.endDate,
          groupedOperations: grouped,
          openingBalance: openingBalance, // DEPRECATED
          openingBalancesByCurrency: openingBalancesByCurrency, // DEPRECATED
          openingCashBalances: openingCashBalances,
          openingSalesBalances: openingSalesBalances,
          openingStockValues: openingStockValues,
        ),
      );
    } catch (e) {
      emit(
        OperationJournalError(
          'Erreur de chargement des opérations: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _onLoadOperationsWithFilter(
    LoadOperationsWithFilter event,
    Emitter<OperationJournalState> emit,
  ) async {
    emit(const OperationJournalLoading());
    try {
      // 1. Charger toutes les opérations pour la période
      final rawOperations = await _repository.getOperations(
        event.filter.startDate ??
            DateTime.now().subtract(const Duration(days: 30)),
        event.filter.endDate ?? DateTime.now(),
      );

      // 2. Appliquer les filtres
      final filteredOperations =
          rawOperations.where((op) => event.filter.matches(op)).toList();

      // 3. Trier selon les critères de date en premier pour garantir un calcul correct des soldes
      filteredOperations.sort((a, b) => a.date.compareTo(b.date));

      // 4. Calculer les soldes d'ouverture à la date de début du filtre
      final startDate =
          event.filter.startDate ??
          DateTime.now().subtract(const Duration(days: 30));

      final openingBalancesByType = await _repository.getOpeningBalancesByType(
        startDate,
      );
      final openingCashBalances = openingBalancesByType['cash']!;
      final openingSalesBalances = openingBalancesByType['sales']!;
      final openingStockValues = openingBalancesByType['stock']!;

      // Pour rétrocompatibilité
      final openingBalancesByCurrency = openingCashBalances;
      final openingBalance = openingBalancesByCurrency.values.fold(
        0.0,
        (prev, curr) => prev + curr,
      );

      // 5. Recalculer les soldes pour les opérations filtrées
      final processedOperations = _processOperationsWithBalance(
        filteredOperations,
        openingCashBalances,
        openingSalesBalances,
        openingStockValues,
      );

      // 6. Appliquer le tri final selon les critères de l'utilisateur
      _sortOperations(
        processedOperations,
        event.filter.sortBy,
        event.filter.sortAscending,
      );

      // 7. Grouper par jour
      final grouped = _groupOperationsByDay(processedOperations);

      emit(
        OperationJournalLoaded(
          operations:
              rawOperations, // Garder toutes les opérations pour référence
          filteredOperations: processedOperations,
          startDate:
              event.filter.startDate ??
              DateTime.now().subtract(const Duration(days: 30)),
          endDate: event.filter.endDate ?? DateTime.now(),
          groupedOperations: grouped,
          openingBalance: openingBalance, // DEPRECATED
          openingBalancesByCurrency: openingBalancesByCurrency, // DEPRECATED
          openingCashBalances: openingCashBalances,
          openingSalesBalances: openingSalesBalances,
          openingStockValues: openingStockValues,
          activeFilter: event.filter,
        ),
      );
    } catch (e) {
      emit(
        OperationJournalError(
          'Erreur de chargement des opérations: ${e.toString()}',
        ),
      );
    }
  }

  void _onFilterPeriodChanged(
    FilterPeriodChanged event,
    Emitter<OperationJournalState> emit,
  ) {
    if (state is OperationJournalLoaded) {
      final currentState = state as OperationJournalLoaded;
      final newStartDate = event.newStartDate ?? currentState.startDate;
      final newEndDate = event.newEndDate ?? currentState.endDate;
      add(LoadOperations(startDate: newStartDate, endDate: newEndDate));
    }
  }

  Future<void> _onRefreshJournal(
    RefreshJournal event,
    Emitter<OperationJournalState> emit,
  ) async {
    // Ajouter un court délai pour permettre aux autres opérations de se terminer
    if (kDebugMode) {
      print("🔄 Rafraîchissement du journal des opérations...");
    }

    emit(const OperationJournalLoading()); // Force UI to show loading state

    try {
      // Attendre un court délai pour s'assurer que toutes les opérations précédentes sont terminées
      await Future.delayed(const Duration(milliseconds: 300));

      if (state is OperationJournalLoaded) {
        final currentState = state as OperationJournalLoaded;
        if (kDebugMode) {
          print(
            "📅 Rechargement du journal du ${currentState.startDate} au ${currentState.endDate}",
          );
        }
        add(
          LoadOperations(
            startDate: currentState.startDate,
            endDate: currentState.endDate,
          ),
        );
      } else {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        if (kDebugMode) {
          print("📅 Chargement initial du journal du $startOfMonth au $now");
        }
        add(LoadOperations(startDate: startOfMonth, endDate: now));
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ ERREUR lors du rafraîchissement du journal: $e");
      }
      emit(
        OperationJournalError(
          "Erreur lors du rafraîchissement du journal: ${e.toString()}",
        ),
      );
    }
  }

  // Handler for adding a new journal entry
  Future<void> _onAddOperationJournalEntry(
    AddOperationJournalEntry event,
    Emitter<OperationJournalState> emit,
  ) async {
    try {
      await _repository.addOperation(event.entry);
      // After adding, refresh the journal to show the new entry
      // We need to ensure the current state has date range, or use a default
      if (state is OperationJournalLoaded) {
        final currentState = state as OperationJournalLoaded;
        add(
          LoadOperations(
            startDate: currentState.startDate,
            endDate: currentState.endDate,
          ),
        );
      } else {
        // If journal wasn't loaded, load it with a default range
        final now = DateTime.now();
        add(
          LoadOperations(
            startDate: DateTime(now.year, now.month, 1),
            endDate: now,
          ),
        );
      }
    } catch (e) {
      // Optionally, emit an error state or log the error
      // For now, we'll just print it, as journal update is a background task
      if (kDebugMode) {
        print('Erreur lors de l\'ajout à l\'operation journal: $e');
      }
      // To prevent UI freeze if this bloc is listened to for errors,
      // ensure we emit a state if an error occurs during add.
      // However, typically adding to journal might not need specific UI error feedback
      // unless it's critical for the user flow.
      // If the current state is an error, we might want to preserve it or update it.
      // if (state is! OperationJournalError) { // Avoid overwriting existing error if not relevant
      //    emit(OperationJournalError('Erreur lors de l\'ajout de l\'entrée: ${e.toString()}'));
      // }
      emit(
        OperationJournalError(
          'Erreur lors de l\'ajout de l\'entrée au journal: ${e.toString()}',
        ),
      );
    }
  }

  // Handler for adding multiple journal entries
  Future<void> _onAddMultipleOperationJournalEntries(
    AddMultipleOperationJournalEntries event,
    Emitter<OperationJournalState> emit,
  ) async {
    if (event.entries.isEmpty) {
      // If there are no entries, no need to do anything or refresh.
      // Optionally, log this situation if it's unexpected.
      if (kDebugMode) {
        print("No entries provided to _onAddMultipleOperationJournalEntries.");
      }
      return;
    }

    if (kDebugMode) {
      print(
        "🔄 Ajout de ${event.entries.length} entrées au journal des opérations...",
      );

      // Log summary of entry types being added
      final entryTypes = event.entries.map((e) => e.type.name).toList();
      final typeCounts = <String, int>{};
      for (var type in entryTypes) {
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
      print("📊 Types d'entrées à ajouter: $typeCounts");
    }

    try {
      // Ajouter les entrées dans le repository
      await _repository.addOperationEntries(event.entries);

      if (kDebugMode) {
        print("✅ Entrées ajoutées avec succès au journal des opérations!");
      }

      // After adding, refresh the journal to show the new entries
      if (state is OperationJournalLoaded) {
        final currentState = state as OperationJournalLoaded;
        // Force a refresh with current dates
        if (kDebugMode) {
          print(
            "🔄 Rafraîchissement du journal pour afficher les nouvelles entrées...",
          );
        }
        add(
          LoadOperations(
            startDate: currentState.startDate,
            endDate: currentState.endDate,
          ),
        );
      } else {
        // Si le journal n'était pas chargé, le charger avec une plage de dates par défaut
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        if (kDebugMode) {
          print("🔄 Chargement initial du journal du $startOfMonth au $now");
        }
        add(LoadOperations(startDate: startOfMonth, endDate: now));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ERREUR lors de l\'ajout de plusieurs entrées au journal: $e');
      }
      // Émettre un état d'erreur mais continuer à fonctionner
      emit(
        OperationJournalError(
          'Erreur lors de l\'ajout des entrées au journal: ${e.toString()}',
        ),
      );

      // Essayer de récupérer en rafraîchissant après l'erreur
      Future.delayed(const Duration(seconds: 2), () {
        add(const RefreshJournal());
      });
    }
  }

  Map<DateTime, List<OperationJournalEntry>> _groupOperationsByDay(
    List<OperationJournalEntry> operations,
  ) {
    // Group by the date part only (year, month, day)
    return groupBy(operations, (OperationJournalEntry op) {
      return DateTime(op.date.year, op.date.month, op.date.day);
    });
  }

  /// Trie la liste d'opérations selon les critères spécifiés
  void _sortOperations(
    List<OperationJournalEntry> operations,
    JournalSortOption sortBy,
    bool ascending,
  ) {
    operations.sort((a, b) {
      int comparison;
      switch (sortBy) {
        case JournalSortOption.date:
          comparison = a.date.compareTo(b.date);
          break;
        case JournalSortOption.amount:
          comparison = a.amount.abs().compareTo(b.amount.abs());
          break;
        case JournalSortOption.type:
          comparison = a.type.displayName.compareTo(b.type.displayName);
          break;
        case JournalSortOption.description:
          comparison = a.description.compareTo(b.description);
          break;
      }
      return ascending ? comparison : -comparison;
    });
  }

  /// Traite les opérations pour calculer les soldes et les flags débit/crédit
  List<OperationJournalEntry> _processOperationsWithBalance(
    List<OperationJournalEntry> operations,
    Map<String, double> openingCashBalances,
    Map<String, double> openingSalesBalances,
    Map<String, double> openingStockValues,
  ) {
    final processedOperations = <OperationJournalEntry>[];

    // Maintenir les 3 types de soldes
    Map<String, double> currentCashBalances = Map<String, double>.from(
      openingCashBalances,
    );
    Map<String, double> currentSalesBalances = Map<String, double>.from(
      openingSalesBalances,
    );
    Map<String, double> currentStockValues = Map<String, double>.from(
      openingStockValues,
    );

    double currentBalance = openingCashBalances.values.fold(
      0.0,
      (a, b) => a + b,
    ); // DEPRECATED

    // Vérifier que les devises principales sont présentes
    if (!currentCashBalances.containsKey('CDF')) {
      currentCashBalances['CDF'] = 0.0;
    }
    if (!currentCashBalances.containsKey('USD')) {
      currentCashBalances['USD'] = 0.0;
    }

    // Trier les opérations par date pour garantir un calcul correct
    final sortedOperations = List<OperationJournalEntry>.from(operations)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final op in sortedOperations) {
      final bool calculatedIsDebit = op.amount < 0;
      final bool calculatedIsCredit = op.amount > 0;
      final currencyCode = op.currencyCode ?? 'CDF';

      double? cashBalance;
      double? salesBalance;
      double? stockValue;

      // Traiter selon le type d'opération
      if (op.type.impactsCash) {
        final current = currentCashBalances[currencyCode] ?? 0.0;
        currentCashBalances[currencyCode] = current + op.amount;
        cashBalance = currentCashBalances[currencyCode];
        currentBalance += op.amount; // DEPRECATED
      } else if (op.type.isSalesOperation) {
        final current = currentSalesBalances[currencyCode] ?? 0.0;
        // NOTE: On n'utilise PAS abs() car une correction de vente doit être soustraite
        currentSalesBalances[currencyCode] = current + op.amount;
        salesBalance = currentSalesBalances[currencyCode];
      } else if (op.type.impactsStock) {
        final current = currentStockValues[currencyCode] ?? 0.0;
        currentStockValues[currencyCode] = current + op.amount;
        stockValue = currentStockValues[currencyCode];
      }

      // Créer une nouvelle entrée avec les valeurs calculées
      final processedOp = op.copyWith(
        isDebit: calculatedIsDebit,
        isCredit: calculatedIsCredit,
        balanceAfter: currentBalance, // DEPRECATED
        balancesByCurrency: Map<String, double>.from(
          currentCashBalances,
        ), // DEPRECATED
        cashBalance: cashBalance,
        salesBalance: salesBalance,
        stockValue: stockValue,
        cashBalancesByCurrency: Map<String, double>.from(currentCashBalances),
        salesBalancesByCurrency: Map<String, double>.from(currentSalesBalances),
        stockValuesByCurrency: Map<String, double>.from(currentStockValues),
      );

      processedOperations.add(processedOp);
    }

    return processedOperations;
  }
}
