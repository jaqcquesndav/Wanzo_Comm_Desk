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
  final List<FinancingRequest> financingRequests;
  // You might want to add a combined list or handle that in the UI.

  const OperationsLoaded({
    required this.sales, 
    required this.expenses,
    this.financingRequests = const [],
  });

  @override
  List<Object?> get props => [sales, expenses, financingRequests];
}

class OperationsError extends OperationsState {
  final String message;

  const OperationsError(this.message);

  @override
  List<Object?> get props => [message];
}
