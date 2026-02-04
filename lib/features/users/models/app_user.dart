// filepath: lib/features/users/models/app_user.dart
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:wanzo/core/enums/user_role.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';

part 'app_user.g.dart';

/// Modèle représentant un utilisateur de l'application
/// Conformité: Aligné avec user.entity.ts (gestion_commerciale_service)
@HiveType(typeId: 75)
@JsonSerializable(explicitToJson: true)
class AppUser extends Equatable {
  /// Identifiant unique de l'utilisateur (UUID)
  @HiveField(0)
  final String id;

  /// Adresse email (unique)
  @HiveField(1)
  final String email;

  /// Prénom de l'utilisateur
  @HiveField(2)
  final String firstName;

  /// Nom de famille (optionnel)
  @HiveField(3)
  final String? lastName;

  /// Numéro de téléphone (optionnel)
  @HiveField(4)
  final String? phoneNumber;

  /// Rôle dans le système
  @HiveField(5)
  @JsonKey(fromJson: _roleFromJson, toJson: _roleToJson)
  final UserRole role;

  /// Indique si le compte est actif
  @HiveField(6)
  final bool isActive;

  /// URL de la photo de profil (optionnel)
  @HiveField(7)
  final String? profilePictureUrl;

  /// Date de dernière connexion (optionnel)
  @HiveField(8)
  final DateTime? lastLoginAt;

  /// ID de l'entreprise associée
  @HiveField(9)
  final String? companyId;

  /// ID de l'unité commerciale assignée
  @HiveField(10)
  final String? businessUnitId;

  /// Code de l'unité (ex: POS-001)
  @HiveField(11)
  final String? businessUnitCode;

  /// Type: "company", "branch" ou "pos"
  @HiveField(12)
  @JsonKey(fromJson: _businessUnitTypeFromJson, toJson: _businessUnitTypeToJson)
  final BusinessUnitType? businessUnitType;

  /// Identifiant Auth0 (optionnel)
  @HiveField(13)
  final String? auth0Id;

  /// Configuration personnalisée (JSONB)
  @HiveField(14)
  final UserSettings? settings;

  /// Date de création
  @HiveField(15)
  final DateTime? createdAt;

  /// Date de mise à jour
  @HiveField(16)
  final DateTime? updatedAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    this.lastName,
    this.phoneNumber,
    this.role = UserRole.staff,
    this.isActive = true,
    this.profilePictureUrl,
    this.lastLoginAt,
    this.companyId,
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitType,
    this.auth0Id,
    this.settings,
    this.createdAt,
    this.updatedAt,
  });

  /// Nom complet de l'utilisateur
  String get fullName {
    if (lastName != null && lastName!.isNotEmpty) {
      return '$firstName $lastName';
    }
    return firstName;
  }

  /// Crée une instance depuis JSON
  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);

  /// Convertit en JSON
  Map<String, dynamic> toJson() => _$AppUserToJson(this);

  /// Crée une copie modifiée
  AppUser copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    UserRole? role,
    bool? isActive,
    String? profilePictureUrl,
    DateTime? lastLoginAt,
    String? companyId,
    String? businessUnitId,
    String? businessUnitCode,
    BusinessUnitType? businessUnitType,
    String? auth0Id,
    UserSettings? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      companyId: companyId ?? this.companyId,
      businessUnitId: businessUnitId ?? this.businessUnitId,
      businessUnitCode: businessUnitCode ?? this.businessUnitCode,
      businessUnitType: businessUnitType ?? this.businessUnitType,
      auth0Id: auth0Id ?? this.auth0Id,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    firstName,
    lastName,
    phoneNumber,
    role,
    isActive,
    profilePictureUrl,
    lastLoginAt,
    companyId,
    businessUnitId,
    businessUnitCode,
    businessUnitType,
    auth0Id,
    settings,
    createdAt,
    updatedAt,
  ];

  // Helpers pour la sérialisation des enums
  static UserRole _roleFromJson(String? value) =>
      value != null ? UserRoleExtension.fromApiValue(value) : UserRole.staff;

  static String _roleToJson(UserRole role) => role.apiValue;

  static BusinessUnitType? _businessUnitTypeFromJson(String? value) =>
      value != null ? BusinessUnitTypeExtension.fromApiValue(value) : null;

  static String? _businessUnitTypeToJson(BusinessUnitType? type) =>
      type?.apiValue;
}

/// Paramètres utilisateur personnalisés
@HiveType(typeId: 76)
@JsonSerializable()
class UserSettings extends Equatable {
  /// Thème de l'interface
  @HiveField(0)
  final String? theme;

  /// Langue préférée
  @HiveField(1)
  final String? language;

  /// Paramètres de notifications
  @HiveField(2)
  final NotificationSettings? notifications;

  const UserSettings({this.theme, this.language, this.notifications});

  factory UserSettings.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$UserSettingsToJson(this);

  UserSettings copyWith({
    String? theme,
    String? language,
    NotificationSettings? notifications,
  }) {
    return UserSettings(
      theme: theme ?? this.theme,
      language: language ?? this.language,
      notifications: notifications ?? this.notifications,
    );
  }

  @override
  List<Object?> get props => [theme, language, notifications];
}

/// Paramètres de notifications utilisateur
@HiveType(typeId: 77)
@JsonSerializable()
class NotificationSettings extends Equatable {
  /// Notifications par email
  @HiveField(0)
  final bool email;

  /// Notifications push
  @HiveField(1)
  final bool push;

  const NotificationSettings({this.email = true, this.push = true});

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      _$NotificationSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationSettingsToJson(this);

  NotificationSettings copyWith({bool? email, bool? push}) {
    return NotificationSettings(
      email: email ?? this.email,
      push: push ?? this.push,
    );
  }

  @override
  List<Object?> get props => [email, push];
}
