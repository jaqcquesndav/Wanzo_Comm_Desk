import 'package:flutter_bloc/flutter_bloc.dart'; // Changed import
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
    on<AuthUserProfileUpdated>(
      _onAuthUserProfileUpdated,
    ); // Add handler for the new event
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
          emit(AuthAuthenticated(user));
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
      emit(AuthAuthenticated(user));
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
      emit(AuthAuthenticated(user));
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
}
