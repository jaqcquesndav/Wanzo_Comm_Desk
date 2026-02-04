import 'package:equatable/equatable.dart';
import 'business_sector.dart';

/// Modèle représentant une demande d'inscription
class RegistrationRequest extends Equatable {
  /// Nom du propriétaire de l'entreprise
  final String ownerName;
  
  /// Adresse email du compte
  final String email;
  
  /// Mot de passe du compte
  final String password;
  
  /// Numéro de téléphone
  final String phoneNumber;
  
  /// Nom de l'entreprise
  final String companyName;
  
  /// Numéro RCCM (Registre du Commerce et du Crédit Mobilier)
  final String rccmNumber;
  
  /// Localisation de l'entreprise
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
  
  /// Convertit l'objet en Map pour l'API
  Map<String, dynamic> toJson() {
    return {
      'ownerName': ownerName,
      'email': email,
      'password': password,
      'phoneNumber': phoneNumber,
      'companyName': companyName,
      'rccmNumber': rccmNumber,
      'location': location,
      'sector': sector.id,
    };
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
