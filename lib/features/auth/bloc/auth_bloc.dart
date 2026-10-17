import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'dart:io'; // Import for File type
import '../models/user.dart';
import '../models/join_request.dart';
import '../repositories/auth_repository.dart';
import '../services/join_request_service.dart' show joinRequestErrorMessage;
import '../../../core/exceptions/api_exceptions.dart';

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
    on<AuthJoinRequestCheckRequested>(_onJoinRequestCheckRequested);
    on<AuthJoinRequestCancelRequested>(_onJoinRequestCancelRequested);
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

  /// Comme [_resolveAuthState], et pour un compte sans entreprise, regarde
  /// s'il a une demande de rattachement en cours : l'écran d'attente de la
  /// demande s'affiche alors directement (au démarrage, après connexion).
  /// Un échec de cette lecture n'empêche jamais l'accès au parcours habituel.
  Future<AuthState> _resolveWithJoinRequest(User user) async {
    final resolved = _resolveAuthState(user);
    if (resolved is! AuthSyncPending) return resolved;
    try {
      final request = await _authRepository.fetchMyJoinRequest();
      if (request != null && (request.isPending || request.isRefused)) {
        return AuthJoinRequestState(user, request);
      }
    } catch (e) {
      debugPrint('AuthBloc: demande de rattachement non lue : $e');
    }
    return resolved;
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
          emit(await _resolveWithJoinRequest(user));
        } else {
          emit(const AuthUnauthenticated());
        }
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      // Dernier recours : plutôt que de renvoyer à l'écran de connexion sur une
      // panne technique, on rouvre la dernière session connue. Les écritures
      // partent dans la file hors ligne, et un vrai refus du serveur (401)
      // déconnectera proprement dès le premier échange.
      final cached = await _authRepository.getLastKnownUser();
      if (cached != null && !isClosed) {
        debugPrint('AuthBloc: reprise de la dernière session connue ($e)');
        emit(AuthAuthenticated(cached));
        return;
      }
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
      emit(await _resolveWithJoinRequest(user));
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
      emit(await _resolveWithJoinRequest(user));
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

  /// Gère la demande de rejoindre une business unit avec un code
  Future<void> _onAuthJoinBusinessUnitRequested(
    AuthJoinBusinessUnitRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Récupérer l'utilisateur courant depuis l'état actuel. Un compte sans
    // entreprise (synchro en attente ou demande refusée) saisit aussi un code.
    final previous = state;
    User? currentUser;
    if (previous is AuthBusinessUnitRequired) {
      currentUser = previous.user;
    } else if (previous is AuthJoinBusinessUnitFailure) {
      currentUser = previous.user;
    } else if (previous is AuthAuthenticated) {
      currentUser = previous.user;
    } else if (previous is AuthSyncPending) {
      currentUser = previous.user;
    } else if (previous is AuthJoinRequestState) {
      currentUser = previous.user;
    }

    if (currentUser == null) {
      emit(const AuthFailure('Utilisateur non authentifié'));
      return;
    }

    // En cas d'échec, l'écran d'origine reste affiché : l'échec est signalé
    // (message) puis l'état précédent revient. Sans cela, un code erroné
    // depuis l'écran d'attente renvoyait vers un autre écran.
    void fail(String message) {
      emit(AuthJoinBusinessUnitFailure(message, user: currentUser!));
      if (previous is AuthSyncPending ||
          previous is AuthJoinRequestState ||
          previous is AuthBusinessUnitRequired) {
        emit(
          previous is AuthJoinRequestState
              ? previous.copyWith(busy: false, clearNotice: true)
              : previous,
        );
      }
    }

    emit(const AuthJoinBusinessUnitInProgress());

    try {
      final response = await _authRepository.joinBusinessUnit(
        event.businessUnitCode,
      );

      if (response.success && response.isPending) {
        // Compte sans entreprise (202) : la demande attend l'administrateur.
        emit(
          AuthJoinRequestState(
            currentUser,
            response.toPendingRequest(),
          ),
        );
        return;
      }

      if (response.success) {
        // Rafraîchir le profil pour obtenir les données BU complètes
        User? refreshedUser;
        try {
          refreshedUser = await _authRepository.refreshUserProfile();
        } catch (e) {
          debugPrint('AuthBloc: profil non relu après jonction : $e');
        }
        if (refreshedUser != null) {
          emit(await _resolveWithJoinRequest(refreshedUser));
        } else {
          // Join a réussi mais le refresh a échoué - essayer avec l'utilisateur existant
          emit(AuthAuthenticated(currentUser));
        }
      } else {
        fail(response.message ?? "L'unité n'a pas pu être rejointe.");
      }
    } on AuthenticationException catch (_) {
      try {
        await _authRepository.logout();
      } catch (_) {}
      emit(const AuthUnauthenticated());
    } catch (e) {
      fail(joinRequestErrorMessage(e));
    }
  }

  /// Vérifie le statut de ma demande de rattachement.
  Future<void> _onJoinRequestCheckRequested(
    AuthJoinRequestCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! AuthJoinRequestState || current.busy) return;
    if (!event.silent) emit(current.copyWith(busy: true, clearNotice: true));
    await _reconcileJoinRequest(current, emit, silent: event.silent);
  }

  /// Annule ma demande en attente puis revient à l'écran du compte sans
  /// entreprise (où un autre code peut être saisi).
  Future<void> _onJoinRequestCancelRequested(
    AuthJoinRequestCancelRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! AuthJoinRequestState || current.busy) return;
    emit(current.copyWith(busy: true, clearNotice: true));
    try {
      await _authRepository.cancelMyJoinRequest();
    } on NotFoundException {
      // Plus rien en attente : la demande a peut-être été traitée entre-temps.
      await _reconcileJoinRequest(current, emit, silent: false);
      return;
    } on AuthenticationException catch (_) {
      try {
        await _authRepository.logout();
      } catch (_) {}
      emit(const AuthUnauthenticated());
      return;
    } catch (e) {
      emit(current.copyWith(busy: false, notice: joinRequestErrorMessage(e)));
      return;
    }
    emit(
      AuthSyncPending(
        current.user,
        message: 'Demande annulée. Vous pouvez saisir un autre code.',
      ),
    );
  }

  /// Relit ma demande et en tire l'état : acceptée → relecture de /auth/me et
  /// entrée dans l'application ; refusée → motif ; toujours en attente →
  /// l'écran reste. Jamais de boucle ici : un appel par demande.
  Future<void> _reconcileJoinRequest(
    AuthJoinRequestState current,
    Emitter<AuthState> emit, {
    required bool silent,
  }) async {
    try {
      final request = await _authRepository.fetchMyJoinRequest();

      if (request == null || request.isCancelled || request.isAccepted) {
        final refreshed = await _authRepository.refreshUserProfile();
        if (refreshed != null) {
          final next = await _resolveWithJoinRequest(refreshed);
          if (next is AuthJoinRequestState || next is! AuthSyncPending) {
            emit(next);
            return;
          }
          // Acceptée mais l'entreprise n'est pas encore propagée : l'écran
          // de synchronisation prend le relais (vérifications bornées).
          if (request != null && request.isAccepted) {
            emit(
              AuthSyncPending(
                refreshed,
                message:
                    "Votre demande est acceptée. Connexion à l'entreprise en cours...",
              ),
            );
            return;
          }
          emit(next);
          return;
        }
        emit(
          current.copyWith(
            request: request ?? current.request,
            busy: false,
            notice: request != null && request.isAccepted
                ? 'Votre demande est acceptée. Touchez Vérifier dans un instant pour entrer.'
                : 'Statut indisponible pour le moment. Réessayez dans un instant.',
          ),
        );
        return;
      }

      emit(
        AuthJoinRequestState(
          current.user,
          request,
          notice: !silent && request.isPending
              ? "Toujours en attente de l'accord de l'administrateur."
              : null,
        ),
      );
    } on AuthenticationException catch (_) {
      try {
        await _authRepository.logout();
      } catch (_) {}
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(
        current.copyWith(
          busy: false,
          notice: silent ? current.notice : joinRequestErrorMessage(e),
        ),
      );
    }
  }

  /// Gère le rafraîchissement du profil (retry sync ou refresh manuel)
  Future<void> _onAuthRefreshProfileRequested(
    AuthRefreshProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Une saisie de code ou une demande en cours a la priorité sur les
    // vérifications automatiques de l'écran de synchronisation.
    if (state is AuthJoinBusinessUnitInProgress ||
        state is AuthJoinRequestState) {
      return;
    }
    try {
      final refreshedUser = await _authRepository.refreshUserProfile();
      if (refreshedUser != null) {
        emit(await _resolveWithJoinRequest(refreshedUser));
      }
      // Si refreshedUser est null, on garde l'état actuel
    } catch (e) {
      debugPrint('AuthBloc: Error refreshing profile: $e');
      // Ne pas changer l'état en cas d'erreur de refresh
    }
  }
}
