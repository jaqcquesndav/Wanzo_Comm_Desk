import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'dart:io'; // Import for File type
import '../models/user.dart';
import '../repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Bloc gérant l'état d'authentification
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthLoginWithAuth0Requested>(_onAuthLoginWithAuth0Requested);
    on<AuthLoginWithDemoAccountRequested>(_onAuthLoginWithDemoAccountRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthUserProfileUpdated>(_onAuthUserProfileUpdated);
    on<AuthJoinBusinessUnitRequested>(_onAuthJoinBusinessUnitRequested);
    on<AuthRefreshProfileRequested>(_onAuthRefreshProfileRequested);
  }

  /// Résout l'état d'authentification selon les 3 cas de /auth/me
  ///
  /// - Cas 1: Profil complet → AuthAuthenticated
  /// - Cas 2: Admin/Manager scope company → AuthAuthenticated, Non-admin sans BU → AuthBusinessUnitRequired
  /// - Cas 3: Sync Kafka en cours → AuthSyncPending
  AuthState _resolveAuthState(User user) {
    final authMeResponse = _authRepository.getLastAuthMeResponse();
    if (authMeResponse == null) {
      // Mode offline ou pas de réponse backend — accès normal
      return AuthAuthenticated(user);
    }

    // Cas 3: Synchronisation Kafka en cours
    if (authMeResponse.isSyncPending) {
      return AuthSyncPending(user, message: authMeResponse.syncStatus?.message);
    }

    // Cas 2: Utilisateur non-admin sans BU assignée
    if (authMeResponse.needsBusinessUnitJoin) {
      return AuthBusinessUnitRequired(user);
    }

    // Cas 1 ou Admin/Manager: Accès normal
    return AuthAuthenticated(user);
  }

  /// Vérifie si l'utilisateur est authentifié au démarrage
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final isLoggedIn = await _authRepository.isLoggedIn();
      if (isLoggedIn) {
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          emit(_resolveAuthState(user));
        } else {
          emit(const AuthUnauthenticated());
        }
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  /// Gère la connexion d'un utilisateur
  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.login(event.email, event.password);
      emit(_resolveAuthState(user));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  /// Gestion de la connexion via Auth0
  /// Sur desktop (Windows/Linux), utilise email/password si fournis
  /// Sur mobile/macOS, utilise le flux OAuth web
  Future<void> _onAuthLoginWithAuth0Requested(
    AuthLoginWithAuth0Requested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      // Passer email/password au repository qui décidera du flux approprié
      final user = await _authRepository.login(
        event.email ?? '',
        event.password ?? '',
      );
      emit(_resolveAuthState(user));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  /// Gère la connexion avec le compte de démonstration
  Future<void> _onAuthLoginWithDemoAccountRequested(
    AuthLoginWithDemoAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      // Ensure demo user key is set before repository call
      await _authRepository.setDemoUserActive(true);
      final user = await _authRepository.loginWithDemoAccount();
      emit(AuthAuthenticated(user));
    } catch (e) {
      // Clear demo user key on failure
      await _authRepository.setDemoUserActive(false);
      emit(AuthFailure(e.toString()));
    }
  }

  /// Gère la déconnexion d'un utilisateur
  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.logout();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  /// Handles updating the user profile information
  Future<void> _onAuthUserProfileUpdated(
    AuthUserProfileUpdated event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;
      emit(const AuthProfileUpdateInProgress()); // Emit in-progress state

      try {
        // Pass the profileImageFile to the repository method
        await _authRepository.updateUserProfile(
          // Changed: await the void call
          event.updatedUser,
          profileImage:
              event.profileImageFile, // Changed: corrected parameter name
        );
        // Fetch the potentially updated user after the update operation
        final User? fullyUpdatedUser = await _authRepository.getCurrentUser();

        if (fullyUpdatedUser != null) {
          emit(
            AuthProfileUpdateSuccess(fullyUpdatedUser),
          ); // Emit success state
          emit(
            AuthAuthenticated(fullyUpdatedUser),
          ); // Then emit authenticated with updated user
        } else {
          // Handle case where user might be null after update (e.g., if update caused logout or error)
          emit(
            AuthProfileUpdateFailure(
              'Failed to retrieve user after update.',
              originalUser: currentUser,
            ),
          );
          emit(
            AuthAuthenticated(currentUser),
          ); // Revert to original user on failure to fetch
        }
      } catch (e) {
        emit(
          AuthProfileUpdateFailure(e.toString(), originalUser: currentUser),
        ); // Emit failure state
        emit(AuthAuthenticated(currentUser));
      }
    } else {
      emit(AuthFailure('User not authenticated, cannot update profile.'));
    }
  }

  /// Gère la jonction à une unité d'affaires via code
  Future<void> _onAuthJoinBusinessUnitRequested(
    AuthJoinBusinessUnitRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Récupérer l'utilisateur actuel depuis l'état courant
    User? currentUser;
    if (state is AuthBusinessUnitRequired) {
      currentUser = (state as AuthBusinessUnitRequired).user;
    } else if (state is AuthJoinBusinessUnitFailure) {
      currentUser = (state as AuthJoinBusinessUnitFailure).user;
    } else if (state is AuthAuthenticated) {
      currentUser = (state as AuthAuthenticated).user;
    }

    emit(const AuthJoinBusinessUnitInProgress());

    try {
      await _authRepository.joinBusinessUnit(event.businessUnitCode);

      // Rafraîchir le profil pour obtenir les données mises à jour
      final refreshedUser = await _authRepository.refreshUserProfile();
      if (refreshedUser != null) {
        emit(_resolveAuthState(refreshedUser));
      } else if (currentUser != null) {
        emit(_resolveAuthState(currentUser));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(
        AuthJoinBusinessUnitFailure(
          e.toString(),
          user:
              currentUser ??
              User(
                id: '',
                name: '',
                email: '',
                phone: '',
                role: '',
                emailVerified: false,
                phoneVerified: false,
              ),
        ),
      );
    }
  }

  /// Gère le rafraîchissement du profil (retry sync ou refresh manuel)
  Future<void> _onAuthRefreshProfileRequested(
    AuthRefreshProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final refreshedUser = await _authRepository.refreshUserProfile();
      if (refreshedUser != null) {
        emit(_resolveAuthState(refreshedUser));
      }
      // Si refreshedUser est null, on garde l'état actuel
    } catch (e) {
      debugPrint('AuthBloc: Error refreshing profile: $e');
      // Ne pas changer l'état en cas d'erreur de refresh
    }
  }
}
