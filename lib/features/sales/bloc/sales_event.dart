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

  /// Moyen de paiement de l'ACOMPTE d'une vente à crédit (espèces, Mobile
  /// Money...). La vente garde « crédit » comme moyen ; l'acompte, lui, est
  /// compté en caisse et au journal avec ce moyen. Null : espèces.
  final String? downPaymentMethod;

  const AddSale(this.sale, {this.downPaymentMethod});

  @override
  List<Object?> get props => [sale, downPaymentMethod];
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

/// Annuler une vente (jamais la supprimer) : motif obligatoire. Le stock et
/// les règlements sont rétablis, la caisse et le journal contre-passés, la
/// comptabilité informée par le serveur.
class CancelSale extends SalesEvent {
  final Sale sale;
  final String reason;

  /// Auteur affiché sur la fiche tant que le serveur n'a pas répondu.
  final String? actorName;
  final String? actorId;

  const CancelSale({
    required this.sale,
    required this.reason,
    this.actorName,
    this.actorId,
  });

  @override
  List<Object?> get props => [sale.id, reason, actorName, actorId];
}

/// Rétablir une vente annulée (administrateur et comptable).
class RestoreSale extends SalesEvent {
  final Sale sale;
  final String? reason;

  const RestoreSale({required this.sale, this.reason});

  @override
  List<Object?> get props => [sale.id, reason];
}
