part of 'operations_bloc.dart';

abstract class OperationsEvent extends Equatable {
  const OperationsEvent();

  @override
  List<Object?> get props => [];
}

class LoadOperations extends OperationsEvent {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? paymentStatus; // e.g., "Payé", "Non Payé", "Partiellement Payé"
  final FinancingType? financingType; // Type de financement à filtrer

  const LoadOperations({
    this.startDate, 
    this.endDate, 
    this.paymentStatus,
    this.financingType,
  });

  @override
  List<Object?> get props => [startDate, endDate, paymentStatus, financingType];
}

// If you need to distinguish between loading sales and expenses,
// you could have separate events or use a parameter in LoadOperations.
// For now, LoadOperations can fetch both and the BLoC can filter/combine.

// Add other events as needed, e.g., for adding a new sale or expense if not handled by their own BLoCs.
