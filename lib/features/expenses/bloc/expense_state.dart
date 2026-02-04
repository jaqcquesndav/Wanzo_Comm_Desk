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

class ExpensesLoaded extends ExpenseState {
  final List<Expense> expenses;
  final double totalExpenses;

  const ExpensesLoaded({required this.expenses, this.totalExpenses = 0.0});

  @override
  List<Object?> get props => [expenses, totalExpenses];
}

class ExpenseLoaded extends ExpenseState {
  final Expense expense;

  const ExpenseLoaded({required this.expense});

  @override
  List<Object?> get props => [expense];
}

class ExpenseOperationSuccess extends ExpenseState {
  final String message;
  const ExpenseOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
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
