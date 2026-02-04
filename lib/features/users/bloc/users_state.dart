// filepath: lib/features/users/bloc/users_state.dart
import 'package:equatable/equatable.dart';
import '../models/app_user.dart';

/// État du bloc Users
class UsersState extends Equatable {
  /// Utilisateur actuellement connecté
  final AppUser? currentUser;

  /// Liste des utilisateurs (pour les admins)
  final List<AppUser> users;

  /// Utilisateur sélectionné pour affichage détaillé
  final AppUser? selectedUser;

  /// Statut de chargement
  final UsersStatus status;

  /// Message d'erreur
  final String? errorMessage;

  /// Pagination
  final int currentPage;
  final int totalPages;
  final int totalUsers;

  /// Indique si l'unité d'affaires a été changée
  final bool businessUnitSwitched;

  /// Données du changement d'unité d'affaires
  final Map<String, dynamic>? businessUnitSwitchData;

  /// Données de l'unité courante
  final Map<String, dynamic>? currentUnitData;

  /// Liste des unités accessibles
  final List<Map<String, dynamic>> accessibleUnits;

  const UsersState({
    this.currentUser,
    this.users = const [],
    this.selectedUser,
    this.status = UsersStatus.initial,
    this.errorMessage,
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalUsers = 0,
    this.businessUnitSwitched = false,
    this.businessUnitSwitchData,
    this.currentUnitData,
    this.accessibleUnits = const [],
  });

  /// État initial
  factory UsersState.initial() => const UsersState();

  /// Crée une copie modifiée
  UsersState copyWith({
    AppUser? currentUser,
    List<AppUser>? users,
    AppUser? selectedUser,
    UsersStatus? status,
    String? errorMessage,
    int? currentPage,
    int? totalPages,
    int? totalUsers,
    bool? businessUnitSwitched,
    Map<String, dynamic>? businessUnitSwitchData,
    Map<String, dynamic>? currentUnitData,
    List<Map<String, dynamic>>? accessibleUnits,
    bool clearError = false,
    bool clearSelectedUser = false,
    bool clearBusinessUnitSwitch = false,
  }) {
    return UsersState(
      currentUser: currentUser ?? this.currentUser,
      users: users ?? this.users,
      selectedUser:
          clearSelectedUser ? null : (selectedUser ?? this.selectedUser),
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalUsers: totalUsers ?? this.totalUsers,
      businessUnitSwitched:
          clearBusinessUnitSwitch
              ? false
              : (businessUnitSwitched ?? this.businessUnitSwitched),
      businessUnitSwitchData:
          clearBusinessUnitSwitch
              ? null
              : (businessUnitSwitchData ?? this.businessUnitSwitchData),
      currentUnitData: currentUnitData ?? this.currentUnitData,
      accessibleUnits: accessibleUnits ?? this.accessibleUnits,
    );
  }

  @override
  List<Object?> get props => [
    currentUser,
    users,
    selectedUser,
    status,
    errorMessage,
    currentPage,
    totalPages,
    totalUsers,
    businessUnitSwitched,
    businessUnitSwitchData,
    currentUnitData,
    accessibleUnits,
  ];
}

/// Statuts possibles du bloc Users
enum UsersStatus {
  /// État initial
  initial,

  /// Chargement en cours
  loading,

  /// Données chargées avec succès
  loaded,

  /// Mise à jour en cours
  updating,

  /// Mise à jour réussie
  updated,

  /// Création en cours
  creating,

  /// Création réussie
  created,

  /// Changement d'unité d'affaires en cours
  switchingBusinessUnit,

  /// Changement d'unité d'affaires réussi
  businessUnitSwitched,

  /// Erreur
  error,
}
