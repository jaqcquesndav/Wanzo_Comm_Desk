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

/// Événement pour se connecter
class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

/// Événement pour se connecter avec Auth0
class AuthLoginWithAuth0Requested extends AuthEvent {
  const AuthLoginWithAuth0Requested();
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

  const AuthUserProfileUpdated(this.updatedUser, {this.profileImageFile}); // Updated constructor

  @override
  List<Object?> get props => [updatedUser, profileImageFile]; // Updated props
}
