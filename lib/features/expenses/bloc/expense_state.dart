part of 'expense_bloc.dart';

abstract class ExpenseState extends Equatable {
  const ExpenseState();

  @override
  List<Object?> get props => [];
}

class ExpenseInitial extends ExpenseState {
  const ExpenseInitial();
}

class ExpenseLoading extends ExpenseState {
  const ExpenseLoading();
}

/// Dépenses chargées. [expenses] ne contient que les dépenses actives (seules
/// comptées dans les totaux) ; les annulées sont à part dans
/// [cancelledExpenses] (filtre « Annulées »).
class ExpensesLoaded extends ExpenseState {
  final List<Expense> expenses;
  final double totalExpenses;
  final List<Expense> cancelledExpenses;

  const ExpensesLoaded({
    required this.expenses,
    this.totalExpenses = 0.0,
    this.cancelledExpenses = const [],
  });

  @override
  List<Object?> get props => [expenses, totalExpenses, cancelledExpenses];
}

/// Dépense annulée ou rétablie : porte la dépense à jour pour la fiche.
class ExpenseCancellationDone extends ExpenseState {
  final Expense expense;
  final bool synced;
  final bool restored;
  final String message;

  const ExpenseCancellationDone({
    required this.expense,
    required this.synced,
    required this.message,
    this.restored = false,
  });

  @override
  List<Object?> get props => [expense, synced, restored, message];
}

class ExpenseLoaded extends ExpenseState {
  final Expense expense;

  const ExpenseLoaded({required this.expense});

  @override
  List<Object?> get props => [expense];
}

class ExpenseOperationSuccess extends ExpenseState {
  final String message;

  /// Dépense enregistrée (création) : identifiant serveur si `synced`, sinon
  /// version locale en attente d'envoi.
  final Expense? expense;

  const ExpenseOperationSuccess(this.message, {this.expense});

  @override
  List<Object?> get props => [message, expense];
}

/// Règlement enregistré sur une dette fournisseur (une tranche).
///
/// Porte la dépense à jour pour un rafraîchissement sur place, et [synced]
/// pour distinguer un décaissement confirmé d'un décaissement mis en file.
class ExpensePaymentRecorded extends ExpenseState {
  final Expense expense;
  final bool synced;
  final String message;

  const ExpensePaymentRecorded({
    required this.expense,
    required this.synced,
    required this.message,
  });

  @override
  List<Object?> get props => [expense, synced, message];
}

class ExpenseError extends ExpenseState {
  final String message;

  const ExpenseError(this.message);

  @override
  List<Object?> get props => [message];
}

// Category States
class ExpenseCategoriesLoaded extends ExpenseState {
  final List<Map<String, dynamic>> categories;

  const ExpenseCategoriesLoaded({required this.categories});

  @override
  List<Object?> get props => [categories];
}

class ExpenseCategoryOperationSuccess extends ExpenseState {
  final String message;
  final Map<String, dynamic>? category;

  const ExpenseCategoryOperationSuccess(this.message, {this.category});

  @override
  List<Object?> get props => [message, category];
}
