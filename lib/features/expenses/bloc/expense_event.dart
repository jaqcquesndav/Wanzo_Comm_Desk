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

  const AddExpense(this.expense, {this.imageFiles}); // Added imageFiles

  @override
  List<Object?> get props => [expense, imageFiles]; // Added imageFiles to props
}

class UpdateExpense extends ExpenseEvent {
  final Expense expense;

  const UpdateExpense(this.expense);

  @override
  List<Object> get props => [expense];
}

class DeleteExpense extends ExpenseEvent {
  final String expenseId;

  const DeleteExpense(this.expenseId);

  @override
  List<Object> get props => [expenseId];
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
