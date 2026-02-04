import 'package:equatable/equatable.dart';
import '../models/supplier.dart';

/// Événements pour le bloc Supplier
abstract class SupplierEvent extends Equatable {
  const SupplierEvent();

  @override
  List<Object?> get props => [];
}

/// Chargement de tous les fournisseurs
class LoadSuppliers extends SupplierEvent {
  const LoadSuppliers();
}

/// Chargement d'un fournisseur spécifique
class LoadSupplier extends SupplierEvent {
  /// ID du fournisseur à charger
  final String supplierId;

  const LoadSupplier(this.supplierId);

  @override
  List<Object?> get props => [supplierId];
}

/// Ajout d'un nouveau fournisseur
class AddSupplier extends SupplierEvent {
  /// Fournisseur à ajouter
  final Supplier supplier;

  const AddSupplier(this.supplier);

  @override
  List<Object?> get props => [supplier];
}

/// Mise à jour d'un fournisseur existant
class UpdateSupplier extends SupplierEvent {
  /// Fournisseur mis à jour
  final Supplier supplier;

  const UpdateSupplier(this.supplier);

  @override
  List<Object?> get props => [supplier];
}

/// Suppression d'un fournisseur
class DeleteSupplier extends SupplierEvent {
  /// ID du fournisseur à supprimer
  final String supplierId;

  const DeleteSupplier(this.supplierId);

  @override
  List<Object?> get props => [supplierId];
}

/// Recherche de fournisseurs
class SearchSuppliers extends SupplierEvent {
  /// Terme de recherche
  final String searchTerm;

  const SearchSuppliers(this.searchTerm);

  @override
  List<Object?> get props => [searchTerm];
}

/// Chargement des principaux fournisseurs
class LoadTopSuppliers extends SupplierEvent {
  /// Nombre de fournisseurs à charger
  final int limit;

  const LoadTopSuppliers({this.limit = 5});

  @override
  List<Object?> get props => [limit];
}

/// Chargement des fournisseurs récents
class LoadRecentSuppliers extends SupplierEvent {
  /// Nombre de fournisseurs à charger
  final int limit;

  const LoadRecentSuppliers({this.limit = 5});

  @override
  List<Object?> get props => [limit];
}

/// Mise à jour du total des achats auprès d'un fournisseur
class UpdateSupplierPurchaseTotal extends SupplierEvent {
  /// ID du fournisseur
  final String supplierId;

  /// Montant à ajouter au total
  final double amount;

  const UpdateSupplierPurchaseTotal(this.supplierId, this.amount);

  @override
  List<Object?> get props => [supplierId, amount];
}

/// Event to filter suppliers by category
class FilterSuppliersByCategoryEvent extends SupplierEvent {
  final SupplierCategory category;

  const FilterSuppliersByCategoryEvent(this.category);

  @override
  List<Object?> get props => [category];
}

/// Chargement de l'historique des achats d'un fournisseur
class LoadSupplierPurchases extends SupplierEvent {
  /// ID du fournisseur
  final String supplierId;

  const LoadSupplierPurchases(this.supplierId);

  @override
  List<Object?> get props => [supplierId];
}
