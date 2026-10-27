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
///
/// [sales] ne contient que les ventes actives : tous les écrans qui en tirent
/// un total (tableau de bord, rapports) écartent ainsi les ventes annulées.
/// Les ventes annulées sont à part dans [cancelledSales] (filtre « Annulées »).
class SalesLoaded extends SalesState {
  final List<Sale> sales;
  final double totalAmountInCdf; // Renamed from totalAmount
  final List<Sale> cancelledSales;

  const SalesLoaded({
    required this.sales,
    this.totalAmountInCdf = 0.0, // Renamed from totalAmount
    this.cancelledSales = const [],
  });

  @override
  List<Object?> get props => [sales, totalAmountInCdf, cancelledSales];
}

/// État d'opération réussie
class SalesOperationSuccess extends SalesState {
  final String message;
  final String? saleId; // Added saleId

  /// Vente semblable signalée par le serveur à la création : avertissement
  /// non bloquant, avec un lien vers elle.
  final String? possibleDuplicateOf;

  const SalesOperationSuccess(
    this.message, {
    this.saleId,
    this.possibleDuplicateOf,
  });

  @override
  List<Object?> get props => [message, saleId, possibleDuplicateOf];
}

/// Vente annulée ou rétablie. Porte la vente à jour pour la fiche, et
/// [synced] pour distinguer une action confirmée d'une action en file.
class SaleCancellationDone extends SalesState {
  final Sale sale;
  final bool synced;
  final bool restored;
  final String message;

  const SaleCancellationDone({
    required this.sale,
    required this.synced,
    required this.message,
    this.restored = false,
  });

  @override
  List<Object?> get props => [sale, synced, restored, message];
}

/// Règlement enregistré sur une vente (une tranche).
///
/// Porte la vente à jour pour que l'écran de détail se rafraîchisse sans
/// recharger toute la liste, et [synced] pour distinguer un encaissement
/// confirmé par le serveur d'un encaissement mis en file hors ligne.
class SalePaymentRecorded extends SalesState {
  final Sale sale;
  final bool synced;
  final String message;

  const SalePaymentRecorded({
    required this.sale,
    required this.synced,
    required this.message,
  });

  @override
  List<Object?> get props => [sale, synced, message];
}

/// État d'erreur
class SalesError extends SalesState {
  final String message;

  const SalesError(this.message);

  @override
  List<Object?> get props => [message];
}
