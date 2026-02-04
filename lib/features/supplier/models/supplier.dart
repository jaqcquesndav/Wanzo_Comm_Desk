import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';

part 'supplier.g.dart';

/// Modèle de données pour un fournisseur
@HiveType(typeId: 38)
@JsonSerializable(explicitToJson: true)
class Supplier extends Equatable {
  /// Identifiant unique du fournisseur
  @HiveField(0)
  final String id;

  /// Nom du fournisseur
  @HiveField(1)
  final String name;

  /// Numéro de téléphone du fournisseur
  @HiveField(2)
  final String phoneNumber;

  /// Adresse email du fournisseur
  @HiveField(3)
  final String email;

  /// Adresse physique du fournisseur
  @HiveField(4)
  final String address;

  /// Personne à contacter chez le fournisseur
  @HiveField(5)
  final String contactPerson;

  /// Date de création du fournisseur dans le système
  @HiveField(6)
  final DateTime createdAt;

  /// Notes ou informations supplémentaires sur le fournisseur
  @HiveField(7)
  final String notes;

  /// Total des achats effectués auprès de ce fournisseur (en francs congolais - FC)
  @HiveField(8)
  final double totalPurchases;

  /// Date du dernier achat auprès de ce fournisseur
  @HiveField(9)
  final DateTime? lastPurchaseDate;

  /// Catégorie du fournisseur
  @HiveField(10)
  final SupplierCategory category;

  /// Délai de livraison moyen (en jours)
  @HiveField(11)
  final int deliveryTimeInDays;

  /// Termes de paiement avec ce fournisseur (ex: "Net 30")
  @HiveField(12)
  final String paymentTerms;

  // ============= BUSINESS UNIT FIELDS =============

  /// ID de l'entreprise associée
  @HiveField(13)
  final String? companyId;

  /// ID de l'unité commerciale
  @HiveField(14)
  final String? businessUnitId;

  /// Code de l'unité (ex: POS-001)
  @HiveField(15)
  final String? businessUnitCode;

  /// Type d'unité: company, branch ou pos
  @HiveField(16)
  @JsonKey(fromJson: _businessUnitTypeFromJson, toJson: _businessUnitTypeToJson)
  final BusinessUnitType? businessUnitType;

  /// Date de mise à jour
  @HiveField(17)
  final DateTime? updatedAt;

  /// IDs des produits fournis (relation ManyToMany)
  @HiveField(18)
  final List<String>? productIds;

  const Supplier({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email = '',
    this.address = '',
    this.contactPerson = '',
    required this.createdAt,
    this.notes = '',
    this.totalPurchases = 0.0,
    this.lastPurchaseDate,
    this.category = SupplierCategory.regular,
    this.deliveryTimeInDays = 0,
    this.paymentTerms = '',
    // Business Unit fields
    this.companyId,
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitType,
    this.updatedAt,
    this.productIds,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) =>
      _$SupplierFromJson(json);
  Map<String, dynamic> toJson() => _$SupplierToJson(this);

  // Helpers pour la sérialisation des enums
  static BusinessUnitType? _businessUnitTypeFromJson(String? value) =>
      value != null ? BusinessUnitTypeExtension.fromApiValue(value) : null;

  static String? _businessUnitTypeToJson(BusinessUnitType? type) =>
      type?.apiValue;

  /// Crée une copie du fournisseur avec des valeurs modifiées
  Supplier copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    String? address,
    String? contactPerson,
    DateTime? createdAt,
    String? notes,
    double? totalPurchases,
    DateTime? lastPurchaseDate,
    SupplierCategory? category,
    int? deliveryTimeInDays,
    String? paymentTerms,
    String? companyId,
    String? businessUnitId,
    String? businessUnitCode,
    BusinessUnitType? businessUnitType,
    DateTime? updatedAt,
    List<String>? productIds,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      category: category ?? this.category,
      deliveryTimeInDays: deliveryTimeInDays ?? this.deliveryTimeInDays,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      companyId: companyId ?? this.companyId,
      businessUnitId: businessUnitId ?? this.businessUnitId,
      businessUnitCode: businessUnitCode ?? this.businessUnitCode,
      businessUnitType: businessUnitType ?? this.businessUnitType,
      updatedAt: updatedAt ?? this.updatedAt,
      productIds: productIds ?? this.productIds,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    phoneNumber,
    email,
    address,
    contactPerson,
    createdAt,
    notes,
    totalPurchases,
    lastPurchaseDate,
    category,
    deliveryTimeInDays,
    paymentTerms,
    companyId,
    businessUnitId,
    businessUnitCode,
    businessUnitType,
    updatedAt,
    productIds,
  ];
}

/// Catégories de fournisseurs
@HiveType(typeId: 39)
@JsonEnum()
enum SupplierCategory {
  /// Fournisseur principal ou stratégique
  @HiveField(0)
  strategic,

  /// Fournisseur régulier
  @HiveField(1)
  regular,

  /// Nouveau fournisseur
  @HiveField(2)
  newSupplier,

  /// Fournisseur occasionnel
  @HiveField(3)
  occasional,

  /// Fournisseur local
  @HiveField(4)
  local,

  /// Fournisseur international
  @HiveField(5)
  international,

  /// Fournisseur en ligne
  @HiveField(6)
  online,
}
