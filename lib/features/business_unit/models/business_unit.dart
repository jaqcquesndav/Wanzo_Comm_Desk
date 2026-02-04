// filepath: lib/features/business_unit/models/business_unit.dart
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';

part 'business_unit.g.dart';

/// Modèle représentant une unité d'affaires
///
/// Hiérarchie supportée:
/// - COMPANY (niveau 0) - Entreprise principale
/// - BRANCH (niveau 1) - Succursale/Agence
/// - POS (niveau 2) - Point de Vente
@HiveType(typeId: 73)
@JsonSerializable(explicitToJson: true)
class BusinessUnit extends Equatable {
  /// Identifiant unique (UUID)
  @HiveField(0)
  final String id;

  /// Code unique par entreprise (ex: BRN-001, POS-002)
  @HiveField(1)
  final String code;

  /// Nom de l'unité
  @HiveField(2)
  final String name;

  /// Type: company, branch, pos
  @HiveField(3)
  final BusinessUnitType type;

  /// Statut: active, inactive, suspended, closed
  @HiveField(4)
  final BusinessUnitStatus status;

  /// ID de l'entreprise principale
  @HiveField(5)
  final String companyId;

  /// ID de l'unité parente (null si company)
  @HiveField(6)
  final String? parentId;

  /// Niveau dans la hiérarchie (0, 1 ou 2)
  @HiveField(7)
  final int hierarchyLevel;

  /// Chemin complet dans la hiérarchie
  @HiveField(8)
  final String? hierarchyPath;

  /// Adresse (optionnel)
  @HiveField(9)
  final String? address;

  /// Ville (optionnel)
  @HiveField(10)
  final String? city;

  /// Province (optionnel)
  @HiveField(11)
  final String? province;

  /// Pays (défaut: RDC)
  @HiveField(12)
  final String country;

  /// Téléphone (optionnel)
  @HiveField(13)
  final String? phone;

  /// Email (optionnel)
  @HiveField(14)
  final String? email;

  /// Nom du responsable (optionnel)
  @HiveField(15)
  final String? manager;

  /// ID utilisateur du responsable (optionnel)
  @HiveField(16)
  final String? managerId;

  /// Devise principale (défaut: CDF)
  @HiveField(17)
  final String currency;

  /// Fuseau horaire (défaut: Africa/Kinshasa)
  @HiveField(18)
  final String timezone;

  /// Paramètres personnalisés (JSON)
  @HiveField(19)
  final Map<String, dynamic>? settings;

  /// Métadonnées additionnelles (JSON)
  @HiveField(20)
  final Map<String, dynamic>? metadata;

  /// ID correspondant dans accounting-service (sync)
  @HiveField(21)
  final String? accountingServiceId;

  /// Date de création
  @HiveField(22)
  final DateTime createdAt;

  /// Date de dernière modification
  @HiveField(23)
  final DateTime updatedAt;

  /// Utilisateur créateur
  @HiveField(24)
  final String? createdBy;

  /// Dernier modificateur
  @HiveField(25)
  final String? updatedBy;

  /// Nom du responsable (pour affichage, séparé de managerId)
  @HiveField(26)
  final String? managerName;

  /// Scope d'accès: "company" (accès entreprise) ou "unit" (limité à l'unité)
  /// - "company": Utilisateur sans businessUnitId, accès niveau entreprise (admin/super_admin)
  /// - "unit": Utilisateur assigné à une unité spécifique, données filtrées par unité
  @HiveField(27)
  final String? scope;

  const BusinessUnit({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.status = BusinessUnitStatus.active,
    required this.companyId,
    this.parentId,
    required this.hierarchyLevel,
    this.hierarchyPath,
    this.address,
    this.city,
    this.province,
    this.country = 'RDC',
    this.phone,
    this.email,
    this.manager,
    this.managerId,
    this.currency = 'CDF',
    this.timezone = 'Africa/Kinshasa',
    this.settings,
    this.metadata,
    this.accountingServiceId,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.managerName,
    this.scope,
  });

  /// Crée une BusinessUnit vide par défaut (niveau entreprise)
  factory BusinessUnit.defaultCompany({
    required String id,
    required String name,
  }) {
    final now = DateTime.now();
    return BusinessUnit(
      id: id,
      code: 'COMPANY',
      name: name,
      type: BusinessUnitType.company,
      status: BusinessUnitStatus.active,
      companyId: id,
      hierarchyLevel: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory BusinessUnit.fromJson(Map<String, dynamic> json) =>
      _$BusinessUnitFromJson(json);

  Map<String, dynamic> toJson() => _$BusinessUnitToJson(this);

  /// Vérifie si c'est l'entreprise principale (niveau 0)
  bool get isCompany => type == BusinessUnitType.company;

  /// Vérifie si c'est une succursale (niveau 1)
  bool get isBranch => type == BusinessUnitType.branch;

  /// Vérifie si c'est un point de vente (niveau 2)
  bool get isPOS => type == BusinessUnitType.pos;

  /// Vérifie si l'unité est active
  bool get isActive => status == BusinessUnitStatus.active;

  /// Vérifie si l'unité peut avoir des enfants
  bool get canHaveChildren => type != BusinessUnitType.pos;

  /// Vérifie si l'unité a besoin d'un parent
  bool get requiresParent => type != BusinessUnitType.company;

  BusinessUnit copyWith({
    String? id,
    String? code,
    String? name,
    BusinessUnitType? type,
    BusinessUnitStatus? status,
    String? companyId,
    String? parentId,
    int? hierarchyLevel,
    String? hierarchyPath,
    String? address,
    String? city,
    String? province,
    String? country,
    String? phone,
    String? email,
    String? manager,
    String? managerId,
    String? currency,
    String? timezone,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? metadata,
    String? accountingServiceId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    String? managerName,
    String? scope,
  }) {
    return BusinessUnit(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      companyId: companyId ?? this.companyId,
      parentId: parentId ?? this.parentId,
      hierarchyLevel: hierarchyLevel ?? this.hierarchyLevel,
      hierarchyPath: hierarchyPath ?? this.hierarchyPath,
      address: address ?? this.address,
      city: city ?? this.city,
      province: province ?? this.province,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      manager: manager ?? this.manager,
      managerId: managerId ?? this.managerId,
      currency: currency ?? this.currency,
      timezone: timezone ?? this.timezone,
      settings: settings ?? this.settings,
      metadata: metadata ?? this.metadata,
      accountingServiceId: accountingServiceId ?? this.accountingServiceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      managerName: managerName ?? this.managerName,
      scope: scope ?? this.scope,
    );
  }

  @override
  List<Object?> get props => [
    id,
    code,
    name,
    type,
    status,
    companyId,
    parentId,
    hierarchyLevel,
    hierarchyPath,
    address,
    city,
    province,
    country,
    phone,
    email,
    manager,
    managerId,
    currency,
    timezone,
    settings,
    metadata,
    accountingServiceId,
    createdAt,
    updatedAt,
    createdBy,
    updatedBy,
    managerName,
    scope,
  ];

  /// Vérifie si l'utilisateur a un accès niveau entreprise
  bool get hasCompanyScope => scope == 'company';

  /// Vérifie si l'utilisateur est limité à cette unité
  bool get hasUnitScope => scope == 'unit' || scope == null;
}

/// Modèle pour la hiérarchie des business units avec enfants
@JsonSerializable(explicitToJson: true)
class BusinessUnitHierarchy extends Equatable {
  final BusinessUnit unit;
  final List<BusinessUnitHierarchy> children;

  const BusinessUnitHierarchy({required this.unit, this.children = const []});

  factory BusinessUnitHierarchy.fromJson(Map<String, dynamic> json) =>
      _$BusinessUnitHierarchyFromJson(json);

  Map<String, dynamic> toJson() => _$BusinessUnitHierarchyToJson(this);

  @override
  List<Object?> get props => [unit, children];
}

/// Paramètres de configuration spécifiques à une unité d'affaires
@JsonSerializable()
class BusinessUnitSettings extends Equatable {
  /// Liste de prix par défaut
  final String? defaultPriceList;

  /// Autoriser les remises
  final bool allowDiscounts;

  /// Remise maximale autorisée (%)
  final double maxDiscountPercent;

  /// Montant max par transaction
  final double? maxTransactionAmount;

  /// Limite journalière
  final double? dailyTransactionLimit;

  /// Taux de taxe par défaut (%)
  final double defaultTaxRate;

  /// Numéro de TVA
  final String? vatNumber;

  const BusinessUnitSettings({
    this.defaultPriceList,
    this.allowDiscounts = true,
    this.maxDiscountPercent = 15.0,
    this.maxTransactionAmount,
    this.dailyTransactionLimit,
    this.defaultTaxRate = 16.0,
    this.vatNumber,
  });

  factory BusinessUnitSettings.fromJson(Map<String, dynamic> json) =>
      _$BusinessUnitSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$BusinessUnitSettingsToJson(this);

  @override
  List<Object?> get props => [
    defaultPriceList,
    allowDiscounts,
    maxDiscountPercent,
    maxTransactionAmount,
    dailyTransactionLimit,
    defaultTaxRate,
    vatNumber,
  ];
}
