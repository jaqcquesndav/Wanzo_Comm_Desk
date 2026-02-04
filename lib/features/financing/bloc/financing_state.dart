part of 'financing_bloc.dart';

abstract class FinancingState extends Equatable {
  const FinancingState();

  @override
  List<Object> get props => [];
}

class FinancingInitial extends FinancingState {}

class FinancingLoading extends FinancingState {}

class FinancingLoadSuccess extends FinancingState {
  final List<FinancingRequest> requests;

  const FinancingLoadSuccess(this.requests);

  @override
  List<Object> get props => [requests];
}

class FinancingOperationSuccess extends FinancingState {
  final String message;

  const FinancingOperationSuccess(this.message);

  @override
  List<Object> get props => [message];
}

class FinancingError extends FinancingState {
  final String message;

  const FinancingError(this.message);

  @override
  List<Object> get props => [message];
}
