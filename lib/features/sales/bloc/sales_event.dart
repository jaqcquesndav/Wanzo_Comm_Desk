// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\sales\bloc\sales_event.dart
part of 'sales_bloc.dart';

/// Événements de gestion des ventes
abstract class SalesEvent extends Equatable {
  const SalesEvent();

  @override
  List<Object?> get props => [];
}

/// Événement pour charger toutes les ventes
class LoadSales extends SalesEvent {
  const LoadSales();
}

/// Événement pour charger les ventes par statut
class LoadSalesByStatus extends SalesEvent {
  final SaleStatus status;

  const LoadSalesByStatus(this.status);

  @override
  List<Object?> get props => [status];
}

/// Événement pour charger les ventes d'un client
class LoadSalesByCustomer extends SalesEvent {
  final String customerId;

  const LoadSalesByCustomer(this.customerId);

  @override
  List<Object?> get props => [customerId];
}

/// Événement pour charger les ventes par période
class LoadSalesByDateRange extends SalesEvent {
  final DateTime startDate;
  final DateTime endDate;

  const LoadSalesByDateRange({
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [startDate, endDate];
}

/// Événement pour ajouter une nouvelle vente
class AddSale extends SalesEvent {
  final Sale sale;

  const AddSale(this.sale);

  @override
  List<Object?> get props => [sale];
}

/// Événement pour mettre à jour une vente
class UpdateSale extends SalesEvent {
  final Sale sale;

  const UpdateSale(this.sale);

  @override
  List<Object?> get props => [sale];
}

/// Événement pour mettre à jour le statut d'une vente
class UpdateSaleStatus extends SalesEvent {
  final String id;
  final SaleStatus status;

  const UpdateSaleStatus(this.id, this.status);

  @override
  List<Object?> get props => [id, status];
}

/// Événement d'enregistrement d'UNE tranche de règlement sur une vente.
///
/// Le cumul et le statut sont recalculés par le serveur (endpoint
/// `sales/:id/payments`) : aucun cumul côté client.
class RecordSalePayment extends SalesEvent {
  final Sale sale;
  final PaymentDraft payment;

  const RecordSalePayment({required this.sale, required this.payment});

  @override
  List<Object?> get props => [sale.id, payment.amount, payment.paidAt];
}

/// Événement pour supprimer une vente
class DeleteSale extends SalesEvent {
  final String id;

  const DeleteSale(this.id);

  @override
  List<Object?> get props => [id];
}
