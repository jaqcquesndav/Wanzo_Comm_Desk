// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\sales\bloc\sales_state.dart
part of 'sales_bloc.dart';

/// États de gestion des ventes
abstract class SalesState extends Equatable {
  const SalesState();
  
  @override
  List<Object?> get props => [];
}

/// État initial
class SalesInitial extends SalesState {
  const SalesInitial();
}

/// État de chargement
class SalesLoading extends SalesState {
  const SalesLoading();
}

/// État avec la liste des ventes chargées
class SalesLoaded extends SalesState {
  final List<Sale> sales;
  final double totalAmountInCdf; // Renamed from totalAmount
  
  const SalesLoaded({
    required this.sales,
    this.totalAmountInCdf = 0.0, // Renamed from totalAmount
  });
  
  @override
  List<Object?> get props => [sales, totalAmountInCdf]; // Renamed from totalAmount
}

/// État d'opération réussie
class SalesOperationSuccess extends SalesState {
  final String message;
  final String? saleId; // Added saleId

  const SalesOperationSuccess(this.message, {this.saleId}); // Updated constructor

  @override
  List<Object?> get props => [message, saleId]; // Updated props
}

/// État d'erreur
class SalesError extends SalesState {
  final String message;
  
  const SalesError(this.message);
  
  @override
  List<Object?> get props => [message];
}
