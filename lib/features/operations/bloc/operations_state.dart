part of 'operations_bloc.dart';

abstract class OperationsState extends Equatable {
  const OperationsState();

  @override
  List<Object?> get props => [];
}

class OperationsInitial extends OperationsState {}

class OperationsLoading extends OperationsState {}

class OperationsLoaded extends OperationsState {
  final List<Sale> sales;
  final List<Expense> expenses;

  const OperationsLoaded({required this.sales, required this.expenses});

  @override
  List<Object?> get props => [sales, expenses];
}

class OperationsError extends OperationsState {
  final String message;

  const OperationsError(this.message);

  @override
  List<Object?> get props => [message];
}
