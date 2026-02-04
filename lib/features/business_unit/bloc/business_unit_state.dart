// filepath: lib/features/business_unit/bloc/business_unit_state.dart
import 'package:equatable/equatable.dart';
import '../models/business_unit.dart';

/// États pour le bloc BusinessUnit
abstract class BusinessUnitState extends Equatable {
  const BusinessUnitState();

  @override
  List<Object?> get props => [];
}

/// État initial
class BusinessUnitInitial extends BusinessUnitState {
  const BusinessUnitInitial();
}

/// Chargement en cours
class BusinessUnitLoading extends BusinessUnitState {
  const BusinessUnitLoading();
}

/// Unités d'affaires chargées avec succès
class BusinessUnitsLoaded extends BusinessUnitState {
  /// Liste des unités d'affaires
  final List<BusinessUnit> units;

  /// Unité courante sélectionnée (peut être null si niveau entreprise par défaut)
  final BusinessUnit? currentUnit;

  const BusinessUnitsLoaded({required this.units, this.currentUnit});

  @override
  List<Object?> get props => [units, currentUnit];
}

/// Hiérarchie des unités chargée
class BusinessUnitHierarchyLoaded extends BusinessUnitState {
  /// Hiérarchie complète
  final BusinessUnitHierarchy hierarchy;

  /// Unité courante sélectionnée
  final BusinessUnit? currentUnit;

  const BusinessUnitHierarchyLoaded({
    required this.hierarchy,
    this.currentUnit,
  });

  @override
  List<Object?> get props => [hierarchy, currentUnit];
}

/// Unité courante chargée/sélectionnée
class CurrentBusinessUnitLoaded extends BusinessUnitState {
  /// L'unité courante
  final BusinessUnit currentUnit;

  /// Indique si c'est l'unité par défaut (entreprise)
  final bool isDefault;

  const CurrentBusinessUnitLoaded({
    required this.currentUnit,
    this.isDefault = false,
  });

  @override
  List<Object?> get props => [currentUnit, isDefault];
}

/// Unité d'affaires créée avec succès
class BusinessUnitCreated extends BusinessUnitState {
  final BusinessUnit unit;
  final String message;

  const BusinessUnitCreated({
    required this.unit,
    this.message = 'Unité créée avec succès',
  });

  @override
  List<Object?> get props => [unit, message];
}

/// Unité d'affaires mise à jour avec succès
class BusinessUnitUpdated extends BusinessUnitState {
  final BusinessUnit unit;
  final String message;

  const BusinessUnitUpdated({
    required this.unit,
    this.message = 'Unité mise à jour avec succès',
  });

  @override
  List<Object?> get props => [unit, message];
}

/// Unité d'affaires supprimée avec succès
class BusinessUnitDeleted extends BusinessUnitState {
  final String unitId;
  final String message;

  const BusinessUnitDeleted({
    required this.unitId,
    this.message = 'Unité supprimée avec succès',
  });

  @override
  List<Object?> get props => [unitId, message];
}

/// Unité d'affaires sélectionnée
class BusinessUnitSelected extends BusinessUnitState {
  final BusinessUnit unit;
  final String message;

  const BusinessUnitSelected({
    required this.unit,
    this.message = 'Unité sélectionnée',
  });

  @override
  List<Object?> get props => [unit, message];
}

/// Enfants d'une unité chargés
class BusinessUnitChildrenLoaded extends BusinessUnitState {
  final String parentId;
  final List<BusinessUnit> children;

  const BusinessUnitChildrenLoaded({
    required this.parentId,
    required this.children,
  });

  @override
  List<Object?> get props => [parentId, children];
}

/// Configuration par code réussie
class BusinessUnitConfiguredByCode extends BusinessUnitState {
  final BusinessUnit unit;
  final String message;

  const BusinessUnitConfiguredByCode({
    required this.unit,
    this.message = 'Unité configurée avec succès',
  });

  @override
  List<Object?> get props => [unit, message];
}

/// Erreur lors d'une opération
class BusinessUnitError extends BusinessUnitState {
  final String message;
  final String? errorCode;

  const BusinessUnitError({required this.message, this.errorCode});

  @override
  List<Object?> get props => [message, errorCode];
}

/// Synchronisation en cours
class BusinessUnitSyncing extends BusinessUnitState {
  const BusinessUnitSyncing();
}

/// Synchronisation terminée
class BusinessUnitSynced extends BusinessUnitState {
  final int syncedCount;
  final String message;

  const BusinessUnitSynced({
    required this.syncedCount,
    this.message = 'Synchronisation terminée',
  });

  @override
  List<Object?> get props => [syncedCount, message];
}
