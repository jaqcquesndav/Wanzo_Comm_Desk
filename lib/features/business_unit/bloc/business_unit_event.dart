// filepath: lib/features/business_unit/bloc/business_unit_event.dart
import 'package:equatable/equatable.dart';
import '../models/business_unit.dart';

/// Événements pour le bloc BusinessUnit
abstract class BusinessUnitEvent extends Equatable {
  const BusinessUnitEvent();

  @override
  List<Object?> get props => [];
}

/// Chargement initial des business units
class LoadBusinessUnits extends BusinessUnitEvent {
  /// Filtrer par type (optionnel)
  final String? type;

  /// Filtrer par parent (optionnel)
  final String? parentId;

  /// Recherche par nom/code (optionnel)
  final String? search;

  /// Inclure les unités inactives
  final bool includeInactive;

  const LoadBusinessUnits({
    this.type,
    this.parentId,
    this.search,
    this.includeInactive = false,
  });

  @override
  List<Object?> get props => [type, parentId, search, includeInactive];
}

/// Chargement de la hiérarchie complète
class LoadBusinessUnitHierarchy extends BusinessUnitEvent {
  const LoadBusinessUnitHierarchy();
}

/// Chargement de l'unité courante de l'utilisateur
class LoadCurrentBusinessUnit extends BusinessUnitEvent {
  const LoadCurrentBusinessUnit();
}

/// Sélection d'une unité d'affaires comme unité active
class SelectBusinessUnit extends BusinessUnitEvent {
  /// L'unité sélectionnée
  final BusinessUnit unit;

  const SelectBusinessUnit(this.unit);

  @override
  List<Object?> get props => [unit];
}

/// Configuration d'une unité via son code (succursale/POS créée)
class ConfigureBusinessUnitByCode extends BusinessUnitEvent {
  /// Le code de l'unité à configurer
  final String code;

  const ConfigureBusinessUnitByCode(this.code);

  @override
  List<Object?> get props => [code];
}

/// Chargement d'une unité par son ID
class LoadBusinessUnitById extends BusinessUnitEvent {
  final String id;

  const LoadBusinessUnitById(this.id);

  @override
  List<Object?> get props => [id];
}

/// Création d'une nouvelle unité d'affaires
class CreateBusinessUnit extends BusinessUnitEvent {
  final String code;
  final String name;
  final String type;
  final String? parentId;
  final String? address;
  final String? city;
  final String? province;
  final String? country;
  final String? phone;
  final String? email;
  final String? manager;
  final String? managerId;
  final String? currency;
  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? metadata;

  const CreateBusinessUnit({
    required this.code,
    required this.name,
    required this.type,
    this.parentId,
    this.address,
    this.city,
    this.province,
    this.country,
    this.phone,
    this.email,
    this.manager,
    this.managerId,
    this.currency,
    this.settings,
    this.metadata,
  });

  @override
  List<Object?> get props => [
    code,
    name,
    type,
    parentId,
    address,
    city,
    province,
    country,
    phone,
    email,
    manager,
    managerId,
    currency,
    settings,
    metadata,
  ];
}

/// Mise à jour d'une unité d'affaires
class UpdateBusinessUnit extends BusinessUnitEvent {
  final String id;
  final String? name;
  final String? status;
  final String? address;
  final String? city;
  final String? province;
  final String? country;
  final String? phone;
  final String? email;
  final String? manager;
  final String? managerId;
  final String? currency;
  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? metadata;

  const UpdateBusinessUnit({
    required this.id,
    this.name,
    this.status,
    this.address,
    this.city,
    this.province,
    this.country,
    this.phone,
    this.email,
    this.manager,
    this.managerId,
    this.currency,
    this.settings,
    this.metadata,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    status,
    address,
    city,
    province,
    country,
    phone,
    email,
    manager,
    managerId,
    currency,
    settings,
    metadata,
  ];
}

/// Suppression d'une unité d'affaires
class DeleteBusinessUnit extends BusinessUnitEvent {
  final String id;

  const DeleteBusinessUnit(this.id);

  @override
  List<Object?> get props => [id];
}

/// Chargement des enfants d'une unité
class LoadBusinessUnitChildren extends BusinessUnitEvent {
  final String parentId;

  const LoadBusinessUnitChildren(this.parentId);

  @override
  List<Object?> get props => [parentId];
}

/// Réinitialisation à l'unité entreprise par défaut
class ResetToDefaultBusinessUnit extends BusinessUnitEvent {
  const ResetToDefaultBusinessUnit();
}

/// Synchronisation des business units avec le serveur
class SyncBusinessUnits extends BusinessUnitEvent {
  const SyncBusinessUnits();
}
