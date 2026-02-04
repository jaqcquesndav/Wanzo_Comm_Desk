import 'package:equatable/equatable.dart';
import '../models/supplier.dart';

/// États pour le bloc Supplier
abstract class SupplierState extends Equatable {
  const SupplierState();

  @override
  List<Object?> get props => [];
}

/// État initial du bloc Supplier
class SupplierInitial extends SupplierState {
  const SupplierInitial();
}

/// Chargement en cours
class SupplierLoading extends SupplierState {
  const SupplierLoading();
}

/// Chargement des fournisseurs réussi
class SuppliersLoaded extends SupplierState {
  /// Liste des fournisseurs chargés
  final List<Supplier> suppliers;

  const SuppliersLoaded(this.suppliers);

  @override
  List<Object?> get props => [suppliers];
}

/// Chargement d'un fournisseur spécifique réussi
class SupplierLoaded extends SupplierState {
  /// Fournisseur chargé
  final Supplier supplier;

  const SupplierLoaded(this.supplier);

  @override
  List<Object?> get props => [supplier];
}

/// Opération sur un fournisseur réussie (création, mise à jour, suppression)
class SupplierOperationSuccess extends SupplierState {
  /// Message de succès
  final String message;

  /// Fournisseur concerné par l'opération (peut être null pour une suppression)
  final Supplier? supplier;

  const SupplierOperationSuccess({required this.message, this.supplier});

  @override
  List<Object?> get props => [message, supplier];
}

/// Erreur lors d'une opération sur un fournisseur
class SupplierError extends SupplierState {
  /// Message d'erreur
  final String message;

  const SupplierError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Résultats de recherche de fournisseurs
class SupplierSearchResults extends SupplierState {
  /// Liste des fournisseurs correspondant à la recherche
  final List<Supplier> suppliers;

  /// Terme de recherche utilisé
  final String searchTerm;

  const SupplierSearchResults({
    required this.suppliers,
    required this.searchTerm,
  });

  @override
  List<Object?> get props => [suppliers, searchTerm];
}

/// Chargement des principaux fournisseurs réussi
class TopSuppliersLoaded extends SupplierState {
  /// Liste des principaux fournisseurs
  final List<Supplier> suppliers;

  const TopSuppliersLoaded(this.suppliers);

  @override
  List<Object?> get props => [suppliers];
}

/// Chargement des fournisseurs récents réussi
class RecentSuppliersLoaded extends SupplierState {
  /// Liste des fournisseurs récents
  final List<Supplier> suppliers;

  const RecentSuppliersLoaded(this.suppliers);

  @override
  List<Object?> get props => [suppliers];
}

/// Chargement de l'historique des achats d'un fournisseur réussi
class SupplierPurchasesLoaded extends SupplierState {
  /// ID du fournisseur
  final String supplierId;

  /// Liste des achats
  final List<Map<String, dynamic>> purchases;

  const SupplierPurchasesLoaded({
    required this.supplierId,
    required this.purchases,
  });

  @override
  List<Object?> get props => [supplierId, purchases];
}

/// Fournisseurs filtrés par catégorie
class SupplierFilteredByCategory extends SupplierState {
  /// Liste des fournisseurs filtrés
  final List<Supplier> suppliers;

  /// Catégorie utilisée pour le filtrage
  final SupplierCategory category;

  const SupplierFilteredByCategory({
    required this.suppliers,
    required this.category,
  });

  @override
  List<Object?> get props => [suppliers, category];
}
