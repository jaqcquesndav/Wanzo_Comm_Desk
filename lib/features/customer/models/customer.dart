import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';

import 'customer_contact.dart';
import 'customer_type.dart';

// Les consommateurs de Customer voient aussi le type et les contacts (extensions).
export 'customer_contact.dart';
export 'customer_type.dart';

part 'customer.g.dart';

/// Modèle de données pour un client
@HiveType(typeId: 35)
@JsonSerializable(explicitToJson: true)
class Customer extends Equatable {
  /// Identifiant unique du client
  @HiveField(0)
  final String id;

  /// Nom du client
  @HiveField(1)
  @JsonKey(name: 'fullName') // Pour compatibilité avec l'API
  final String name;

  /// Numéro de téléphone du client
  @HiveField(2)
  final String phoneNumber;

  /// Matricule / code client renvoye par le backend (affichage). Injecte
  /// manuellement dans fromJson pour eviter de regenerer customer.g.dart.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? customerCode;

  /// Adresse email du client
  @HiveField(3)
  final String? email; // Changed to nullable

  /// Adresse physique du client
  @HiveField(4)
  final String? address; // Changed to nullable

  /// Date de création du client dans le système
  @HiveField(5)
  final DateTime createdAt;

  /// Notes ou informations supplémentaires sur le client
  @HiveField(6)
  final String? notes; // Changed to nullable

  /// Historique d'achat total du client (en francs congolais - FC)
  @HiveField(7)
  final double totalPurchases;

  /// Date de dernier achat
  @HiveField(8)
  final DateTime? lastPurchaseDate;

  /// Catégorie du client (VIP, Régulier, etc.)
  @HiveField(9)
  final CustomerCategory category;

  /// URL de la photo de profil du client
  @HiveField(10)
  final String? profilePicture;

  // ============= BUSINESS UNIT FIELDS =============

  /// ID de l'entreprise associée
  @HiveField(11)
  final String? companyId;

  /// ID de l'unité commerciale
  @HiveField(12)
  final String? businessUnitId;

  /// Code de l'unité (ex: POS-001)
  @HiveField(13)
  final String? businessUnitCode;

  /// Type d'unité: company, branch ou pos
  @HiveField(14)
  @JsonKey(fromJson: _businessUnitTypeFromJson, toJson: _businessUnitTypeToJson)
  final BusinessUnitType? businessUnitType;

  /// Date de mise à jour
  @HiveField(15)
  final DateTime? updatedAt;

  /// Statut de synchronisation (pending, synced, pending_update)
  @HiveField(16)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String syncStatus;

  /// ID local pour réconciliation après sync
  @HiveField(17)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? localId;

  // ============= PERSONNE PHYSIQUE / MORALE =============

  /// Nature du client (valeur API : individual, company, ngo, cooperative,
  /// public_institution, association, other). Voir [type].
  @HiveField(18, defaultValue: 'individual')
  @JsonKey(defaultValue: 'individual')
  final String customerType;

  /// NIF / RCCM d'une personne morale.
  @HiveField(19)
  final String? taxId;

  /// Personnes de contact d'une personne morale.
  @HiveField(20, defaultValue: [])
  @JsonKey(defaultValue: [])
  final List<CustomerContact> contacts;

  CustomerType get type => CustomerTypeX.fromApiValue(customerType);

  const Customer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.customerCode,
    this.email,
    this.address,
    required this.createdAt,
    this.notes,
    this.totalPurchases = 0.0,
    this.lastPurchaseDate,
    this.category = CustomerCategory.regular,
    this.profilePicture,
    this.companyId,
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitType,
    this.updatedAt,
    this.syncStatus = 'synced',
    this.localId,
    this.customerType = 'individual',
    this.taxId,
    this.contacts = const [],
  });

  /// Crée une copie du client avec des valeurs modifiées
  Customer copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? customerCode,
    String? email,
    String? address,
    DateTime? createdAt,
    String? notes,
    double? totalPurchases,
    DateTime? lastPurchaseDate,
    CustomerCategory? category,
    String? profilePicture,
    String? companyId,
    String? businessUnitId,
    String? businessUnitCode,
    BusinessUnitType? businessUnitType,
    DateTime? updatedAt,
    String? syncStatus,
    String? localId,
    String? customerType,
    String? taxId,
    List<CustomerContact>? contacts,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      customerCode: customerCode ?? this.customerCode,
      email: email ?? this.email,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      category: category ?? this.category,
      profilePicture: profilePicture ?? this.profilePicture,
      companyId: companyId ?? this.companyId,
      businessUnitId: businessUnitId ?? this.businessUnitId,
      businessUnitCode: businessUnitCode ?? this.businessUnitCode,
      businessUnitType: businessUnitType ?? this.businessUnitType,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      localId: localId ?? this.localId,
      customerType: customerType ?? this.customerType,
      taxId: taxId ?? this.taxId,
      contacts: contacts ?? this.contacts,
    );
  }

  /// Crée une instance de Customer à partir d'une carte JSON
  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json).copyWith(customerCode: json['customerCode'] as String?);

  /// Convertit une instance de Customer en carte JSON
  Map<String, dynamic> toJson() => _$CustomerToJson(this);

  // Helpers pour la sérialisation des enums
  static BusinessUnitType? _businessUnitTypeFromJson(String? value) =>
      value != null ? BusinessUnitTypeExtension.fromApiValue(value) : null;

  static String? _businessUnitTypeToJson(BusinessUnitType? type) =>
      type?.apiValue;

  @override
  List<Object?> get props => [
    id,
    name,
    phoneNumber,
    customerCode,
    email,
    address,
    createdAt,
    notes,
    totalPurchases,
    lastPurchaseDate,
    category,
    profilePicture,
    companyId,
    businessUnitId,
    businessUnitCode,
    businessUnitType,
    updatedAt,
    syncStatus,
    localId,
    customerType,
    taxId,
    contacts,
  ];
}

/// Catégories de clients
@HiveType(typeId: 36)
enum CustomerCategory {
  /// Client VIP ou premium
  @HiveField(0)
  vip,

  /// Client régulier
  @HiveField(1)
  regular,

  /// Nouveau client
  @HiveField(2)
  new_customer,

  /// Client occasionnel
  @HiveField(3)
  occasional,

  /// Client B2B (Business to Business)
  @HiveField(4)
  business,
}
