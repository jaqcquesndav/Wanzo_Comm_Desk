import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'customer.g.dart';

/// Modèle représentant un client
@HiveType(typeId: 42)
@JsonSerializable(explicitToJson: true)
class Customer extends Equatable {
  /// Identifiant unique du client
  @HiveField(0)
  final String id;
  
  /// Nom complet du client
  @HiveField(1)
  final String fullName;
  
  /// Numéro de téléphone
  @HiveField(2)
  final String phoneNumber;
  
  /// Adresse email
  @HiveField(3)
  final String? email;
  
  /// Adresse physique
  @HiveField(4)
  final String? address;
  
  /// Date d'ajout du client
  @HiveField(5)
  final DateTime createdAt;
  
  /// Notes sur le client
  @HiveField(6)
  final String? notes;
  
  /// Montant total des achats (historique)
  @HiveField(7)
  final double? totalPurchases;
  
  /// URL de l'image de profil du client
  @HiveField(8)
  final String? profilePicture;
  
  /// Constructeur
  const Customer({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    this.email,
    this.address,
    required this.createdAt,
    this.notes,
    this.totalPurchases,
    this.profilePicture,
  });

  /// Crée une instance de Customer à partir d'une carte JSON
  factory Customer.fromJson(Map<String, dynamic> json) => _$CustomerFromJson(json);

  /// Convertit une instance de Customer en carte JSON
  Map<String, dynamic> toJson() => _$CustomerToJson(this);
  
  /// Crée une copie de ce client avec les champs donnés remplacés par les nouvelles valeurs
  Customer copyWith({
    String? id,
    String? fullName,
    String? phoneNumber,
    String? email,
    String? address,
    DateTime? createdAt,
    String? notes,
    double? totalPurchases,
    String? profilePicture,
  }) {
    return Customer(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      profilePicture: profilePicture ?? this.profilePicture,
    );
  }
  
  @override
  List<Object?> get props => [
    id,
    fullName,
    phoneNumber,
    email,
    address,
    createdAt,
    notes,
    totalPurchases,
    profilePicture,
  ];
}
