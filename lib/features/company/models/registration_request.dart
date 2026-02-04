import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'business_sector.dart';

part 'registration_request.g.dart';

/// Modèle pour la demande d'inscription
@JsonSerializable(explicitToJson: true)
class RegistrationRequest extends Equatable {
  /// Nom de l'utilisateur
  final String ownerName;
  
  /// Email de l'utilisateur
  final String email;
  
  /// Mot de passe
  final String password;
  
  /// Numéro de téléphone
  final String phoneNumber;
  
  /// Nom de l'entreprise
  final String companyName;
  
  /// Numéro RCCM (Registre du Commerce et du Crédit Mobilier)
  final String rccmNumber;
  
  /// Lieu/Adresse de l'entreprise
  final String location;
  
  /// Secteur d'activité
  final BusinessSector sector;
  
  /// Constructeur
  const RegistrationRequest({
    required this.ownerName,
    required this.email,
    required this.password,
    required this.phoneNumber,
    required this.companyName,
    required this.rccmNumber,
    required this.location,
    required this.sector,
  });
  
  /// Creates a RegistrationRequest from a JSON object.
  factory RegistrationRequest.fromJson(Map<String, dynamic> json) => _$RegistrationRequestFromJson(json);

  /// Converts this RegistrationRequest instance to a JSON object.
  Map<String, dynamic> toJson() => _$RegistrationRequestToJson(this);

  /// Crée une copie avec des valeurs modifiées
  RegistrationRequest copyWith({
    String? ownerName,
    String? email,
    String? password,
    String? phoneNumber,
    String? companyName,
    String? rccmNumber,
    String? location,
    BusinessSector? sector,
  }) {
    return RegistrationRequest(
      ownerName: ownerName ?? this.ownerName,
      email: email ?? this.email,
      password: password ?? this.password,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      companyName: companyName ?? this.companyName,
      rccmNumber: rccmNumber ?? this.rccmNumber,
      location: location ?? this.location,
      sector: sector ?? this.sector,
    );
  }
  
  @override
  List<Object?> get props => [
    ownerName,
    email,
    password,
    phoneNumber,
    companyName,
    rccmNumber,
    location,
    sector,
  ];
}
