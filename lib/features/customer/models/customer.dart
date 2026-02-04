import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';

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

  const Customer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email, // No longer required, allow null
    this.address, // No longer required, allow null
    required this.createdAt,
    this.notes, // Allow null
    this.totalPurchases = 0.0,
    this.lastPurchaseDate,
    this.category = CustomerCategory.regular,
    this.profilePicture,
    // Business Unit fields
    this.companyId,
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitType,
    this.updatedAt,
  });

  /// Crée une copie du client avec des valeurs modifiées
  Customer copyWith({
    String? id,
    String? name,
    String? phoneNumber,
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
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
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
    );
  }

  /// Crée une instance de Customer à partir d'une carte JSON
  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);

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
