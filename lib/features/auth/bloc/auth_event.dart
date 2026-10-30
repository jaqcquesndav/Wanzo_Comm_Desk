part of 'auth_bloc.dart';

/// Classe de base pour les événements d'authentification
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Événement déclenché au démarrage de l'application pour vérifier l'état d'authentification
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Événement pour se connecter avec email/password
/// Utilisé sur desktop (Windows/Linux) avec l'authentification directe
class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

/// Événement pour se connecter avec Auth0 (OAuth web)
/// Utilisé sur mobile/macOS avec le flux de redirection navigateur
class AuthLoginWithAuth0Requested extends AuthEvent {
  /// Email et password optionnels pour desktop
  /// Si fournis sur desktop, utilise l'authentification directe
  final String? email;
  final String? password;

  const AuthLoginWithAuth0Requested({this.email, this.password});

  @override
  List<Object?> get props => [email, password];
}

/// Événement pour se connecter avec le compte de démonstration
class AuthLoginWithDemoAccountRequested extends AuthEvent {
  const AuthLoginWithDemoAccountRequested();
}

/// Événement pour se déconnecter
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Event to update the user profile
class AuthUserProfileUpdated extends AuthEvent {
  final User updatedUser;
  final File? profileImageFile; // Added to carry the actual image file

  const AuthUserProfileUpdated(
    this.updatedUser, {
    this.profileImageFile,
  }); // Updated constructor

  @override
  List<Object?> get props => [updatedUser, profileImageFile]; // Updated props
}

/// Événement pour rejoindre une unité d'affaires via son code
class AuthJoinBusinessUnitRequested extends AuthEvent {
  final String businessUnitCode;

  const AuthJoinBusinessUnitRequested({required this.businessUnitCode});

  @override
  List<Object?> get props => [businessUnitCode];
}

/// Événement pour rafraîchir le profil depuis /auth/me
/// Utilisé pour le retry de sync pending ou après join BU
class AuthRefreshProfileRequested extends AuthEvent {
  const AuthRefreshProfileRequested();
}

/// Vérifie le statut de ma demande de rattachement (bouton « Vérifier »,
/// retour au premier plan, vérifications espacées). `silent` : sans
/// indicateur ni message « toujours en attente ».
class AuthJoinRequestCheckRequested extends AuthEvent {
  final bool silent;

  const AuthJoinRequestCheckRequested({this.silent = false});

  @override
  List<Object?> get props => [silent];
}

/// Annule ma demande de rattachement en attente.
class AuthJoinRequestCancelRequested extends AuthEvent {
  const AuthJoinRequestCancelRequested();
}

/// Relecture du rôle depuis /auth/me sans redémarrage (premier plan, refus
/// 403 de droits, droits encore inconnus). [done] est complété à la fin.
class AuthRoleRefreshRequested extends AuthEvent {
  final String reason;
  final Completer<void>? done;

  const AuthRoleRefreshRequested({this.reason = '', this.done});

  @override
  List<Object?> get props => [reason, done];
}
