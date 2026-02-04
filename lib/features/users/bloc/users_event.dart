// filepath: lib/features/users/bloc/users_event.dart
import 'package:equatable/equatable.dart';
import '../models/app_user.dart';

/// Événements du bloc Users
abstract class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object?> get props => [];
}

/// Charge le profil de l'utilisateur courant
class LoadCurrentUser extends UsersEvent {
  const LoadCurrentUser();
}

/// Met à jour le profil de l'utilisateur courant
class UpdateCurrentUserProfile extends UsersEvent {
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? profilePictureUrl;

  const UpdateCurrentUserProfile({
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.profilePictureUrl,
  });

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    phoneNumber,
    profilePictureUrl,
  ];
}

/// Met à jour les paramètres de l'utilisateur courant
class UpdateCurrentUserSettings extends UsersEvent {
  final String? theme;
  final String? language;
  final bool? emailNotifications;
  final bool? pushNotifications;

  const UpdateCurrentUserSettings({
    this.theme,
    this.language,
    this.emailNotifications,
    this.pushNotifications,
  });

  @override
  List<Object?> get props => [
    theme,
    language,
    emailNotifications,
    pushNotifications,
  ];
}

/// Change l'unité d'affaires courante
class SwitchBusinessUnit extends UsersEvent {
  final String businessUnitCode;

  const SwitchBusinessUnit({required this.businessUnitCode});

  @override
  List<Object?> get props => [businessUnitCode];
}

/// Réinitialise vers l'Entreprise Générale (niveau company)
class ResetToCompany extends UsersEvent {
  const ResetToCompany();
}

/// Récupère l'unité d'affaires courante
class LoadCurrentUnit extends UsersEvent {
  const LoadCurrentUnit();
}

/// Récupère la liste des unités accessibles
class LoadAccessibleUnits extends UsersEvent {
  const LoadAccessibleUnits();
}

/// Charge la liste des utilisateurs (Admin)
class LoadUsers extends UsersEvent {
  final int page;
  final int limit;
  final String? role;
  final bool? isActive;
  final String? businessUnitId;
  final String? search;

  const LoadUsers({
    this.page = 1,
    this.limit = 10,
    this.role,
    this.isActive,
    this.businessUnitId,
    this.search,
  });

  @override
  List<Object?> get props => [
    page,
    limit,
    role,
    isActive,
    businessUnitId,
    search,
  ];
}

/// Crée un nouvel utilisateur (Admin)
class CreateUser extends UsersEvent {
  final String email;
  final String firstName;
  final String? lastName;
  final String? phoneNumber;
  final String role;
  final String? businessUnitCode;
  final String password;

  const CreateUser({
    required this.email,
    required this.firstName,
    this.lastName,
    this.phoneNumber,
    required this.role,
    this.businessUnitCode,
    required this.password,
  });

  @override
  List<Object?> get props => [
    email,
    firstName,
    lastName,
    phoneNumber,
    role,
    businessUnitCode,
    password,
  ];
}

/// Met à jour un utilisateur (Admin)
class UpdateUser extends UsersEvent {
  final String userId;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? role;
  final bool? isActive;
  final String? businessUnitCode;

  const UpdateUser({
    required this.userId,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.role,
    this.isActive,
    this.businessUnitCode,
  });

  @override
  List<Object?> get props => [
    userId,
    firstName,
    lastName,
    phoneNumber,
    role,
    isActive,
    businessUnitCode,
  ];
}

/// Désactive un utilisateur (Admin)
class DeactivateUser extends UsersEvent {
  final String userId;

  const DeactivateUser({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Sélectionne un utilisateur pour afficher les détails
class SelectUser extends UsersEvent {
  final AppUser? user;

  const SelectUser({this.user});

  @override
  List<Object?> get props => [user];
}

/// Efface les erreurs
class ClearUsersError extends UsersEvent {
  const ClearUsersError();
}
