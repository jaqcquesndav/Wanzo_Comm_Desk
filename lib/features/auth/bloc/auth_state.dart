part of 'auth_bloc.dart';

/// Classe de base pour les états d'authentification
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// État initial de l'authentification (en cours de vérification)
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// État indiquant que l'authentification est en cours
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// État indiquant que l'utilisateur est authentifié
class AuthAuthenticated extends AuthState {
  final User user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// État indiquant que l'utilisateur n'est pas authentifié
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// État indiquant qu'une erreur s'est produite lors de l'authentification
class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}

/// State indicating that a profile update is in progress
class AuthProfileUpdateInProgress extends AuthState {
  const AuthProfileUpdateInProgress();
}

/// State indicating that a profile update has succeeded
/// It might carry the updated user if needed, but AuthAuthenticated already does.
class AuthProfileUpdateSuccess extends AuthState {
  final User
  user; // Optionally include the user if specific UI changes depend on it here
  const AuthProfileUpdateSuccess(this.user);

  @override
  List<Object?> get props => [user];
}

/// State indicating that a profile update has failed
class AuthProfileUpdateFailure extends AuthState {
  final String error;
  final User?
  originalUser; // Optionally carry the original user to allow reverting or retrying

  const AuthProfileUpdateFailure(this.error, {this.originalUser});

  @override
  List<Object?> get props => [error, originalUser];
}

/// État indiquant que la synchronisation Kafka est en cours (cas 3 de /auth/me)
/// L'utilisateur vient de s'inscrire et ses données entreprise ne sont pas encore disponibles
class AuthSyncPending extends AuthState {
  final User user;
  final String? message;

  const AuthSyncPending(this.user, {this.message});

  @override
  List<Object?> get props => [user, message];
}

/// État indiquant que l'utilisateur non-admin doit confirmer son unité d'affaires
/// Il doit saisir le code BU communiqué par son administrateur
class AuthBusinessUnitRequired extends AuthState {
  final User user;

  const AuthBusinessUnitRequired(this.user);

  @override
  List<Object?> get props => [user];
}

/// État indiquant que la jonction à une BU est en cours
class AuthJoinBusinessUnitInProgress extends AuthState {
  const AuthJoinBusinessUnitInProgress();
}

/// État indiquant que la jonction à une BU a échoué
class AuthJoinBusinessUnitFailure extends AuthState {
  final String error;
  final User user;

  const AuthJoinBusinessUnitFailure(this.error, {required this.user});

  @override
  List<Object?> get props => [error, user];
}
