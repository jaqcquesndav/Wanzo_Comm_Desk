part of 'expense_bloc.dart';

abstract class ExpenseEvent extends Equatable {
  const ExpenseEvent();

  @override
  List<Object?> get props => [];
}

class LoadExpenses extends ExpenseEvent {
  const LoadExpenses();
}

class LoadExpensesByDateRange extends ExpenseEvent {
  final DateTime startDate;
  final DateTime endDate;

  const LoadExpensesByDateRange(this.startDate, this.endDate);

  @override
  List<Object> get props => [startDate, endDate];
}

class LoadExpensesByCategory extends ExpenseEvent {
  final ExpenseCategory category;

  const LoadExpensesByCategory(this.category);

  @override
  List<Object> get props => [category];
}

class AddExpense extends ExpenseEvent {
  final Expense expense;
  final List<File>? imageFiles; // Added imageFiles

  /// Reçoit la dépense enregistrée (identifiant serveur si elle a été
  /// acceptée, `syncStatus` « pending » si elle attend le réseau), ou l'erreur.
  final Completer<Expense>? saved;

  const AddExpense(this.expense, {this.imageFiles, this.saved});

  @override
  List<Object?> get props => [expense, imageFiles]; // Added imageFiles to props
}

class UpdateExpense extends ExpenseEvent {
  final Expense expense;

  const UpdateExpense(this.expense);

  @override
  List<Object> get props => [expense];
}

/// Enregistrement d'UNE tranche de règlement fournisseur.
///
/// Passe par `POST expenses/:id/payments` : le cumul et le statut sont
/// recalculés par le serveur, plus de cumul côté client.
class RecordExpensePayment extends ExpenseEvent {
  final Expense expense;
  final PaymentDraft payment;

  const RecordExpensePayment({required this.expense, required this.payment});

  @override
  List<Object?> get props => [expense.id, payment.amount, payment.paidAt];
}

/// Annuler une dépense (jamais la supprimer) : motif obligatoire.
class CancelExpense extends ExpenseEvent {
  final Expense expense;
  final String reason;
  final String? actorName;
  final String? actorId;

  const CancelExpense({
    required this.expense,
    required this.reason,
    this.actorName,
    this.actorId,
  });

  @override
  List<Object?> get props => [expense.id, expense.localId, reason, actorName];
}

/// Rétablir une dépense annulée (administrateur et comptable).
class RestoreExpense extends ExpenseEvent {
  final Expense expense;
  final String? reason;

  const RestoreExpense({required this.expense, this.reason});

  @override
  List<Object?> get props => [expense.id, expense.localId, reason];
}

class LoadExpenseById extends ExpenseEvent {
  final String expenseId;

  const LoadExpenseById(this.expenseId);

  @override
  List<Object> get props => [expenseId];
}

// Category Events
class LoadExpenseCategories extends ExpenseEvent {
  const LoadExpenseCategories();
}

class CreateExpenseCategory extends ExpenseEvent {
  final String name;
  final String? description;
  final String type;

  const CreateExpenseCategory({
    required this.name,
    this.description,
    required this.type,
  });

  @override
  List<Object?> get props => [name, description, type];
}

class UpdateExpenseCategory extends ExpenseEvent {
  final String id;
  final String? name;
  final String? description;
  final String? type;

  const UpdateExpenseCategory({
    required this.id,
    this.name,
    this.description,
    this.type,
  });

  @override
  List<Object?> get props => [id, name, description, type];
}

class DeleteExpenseCategory extends ExpenseEvent {
  final String categoryId;

  const DeleteExpenseCategory(this.categoryId);

  @override
  List<Object> get props => [categoryId];
}
