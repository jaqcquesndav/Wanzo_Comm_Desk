import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'dart:io'; // Import for File type
import '../models/user.dart';
import '../models/join_request.dart';
import '../repositories/auth_repository.dart';
import '../services/join_request_service.dart' show joinRequestErrorMessage;
import '../../../core/exceptions/api_exceptions.dart';
import '../../../core/services/company_scope_guard.dart';
import '../../../core/utils/connectivity_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Message d'un compte sans entreprise (aucun texte du serveur).
const String kNoCompanyMessage =
    "Ce compte n'est rattaché à aucune entreprise pour le moment.";

/// Bloc gérant l'état d'authentification
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  /// Réseau disponible ? (injectable pour les tests)
  final bool Function() _isOnline;

  /// Dernière entreprise confirmée par le serveur (purge, hors ligne).
  /// L'application passe [CompanyScopeGuard.instance] ; absent (tests), rien
  /// n'est noté ni relu.
  final CompanyScopeGuard? _scopeGuard;

  AuthBloc({
    required AuthRepository authRepository,
    bool Function()? isOnline,
    CompanyScopeGuard? scopeGuard,
  }) : _authRepository = authRepository,
      _scopeGuard = scopeGuard,
      _isOnline = isOnline ?? (() => ConnectivityService().isConnected),
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
  AuthState _resolveAuthState(User user, {CompanyScopeSnapshot? lastKnown}) {
    final authMeResponse = _authRepository.getLastAuthMeResponse();

    if (authMeResponse == null) {
      // Hors ligne : si la dernière réponse du serveur disait « sans
      // entreprise » pour ce compte (retiré, ou jamais rattaché), l'ancienne
      // session ne se rouvre pas.
      if (lastKnown != null &&
          lastKnown.userId == user.id &&
          !lastKnown.hasCompany) {
        return AuthSyncPending(
          user,
          message: kNoCompanyMessage,
          revoked: lastKnown.wasRevoked,
        );
      }
      // Pas de réponse backend (offline?) -> authentifié avec données locales
      return AuthAuthenticated(user);
    }

    // Compte sans entreprise (retiré, ou jamais rattaché) : jamais le
    // tableau de bord, l'écran pour rejoindre une entreprise.
    if (authMeResponse.hasNoCompany) {
      return AuthSyncPending(
        user,
        message: authMeResponse.syncStatus?.message ?? kNoCompanyMessage,
        revoked: authMeResponse.wasRevoked,
      );
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

  /// Note la réponse du serveur (purge des données d'une entreprise quittée)
  /// ou, sans réponse, rend ce qu'il a dit en dernier. Jamais bloquant.
  Future<CompanyScopeSnapshot?> _recordCompanyScope(User user) async {
    final guard = _scopeGuard;
    if (guard == null) return null;
    final me = _authRepository.getLastAuthMeResponse();
    try {
      if (me == null) return await guard.lastKnown();
      // Entreprise en cours de synchronisation : rien de sûr à noter.
      if (me.isSyncPending && !me.hasNoCompany) return null;
      await guard.recordServerAnswer(
        userId: user.id,
        companyId: me.companyIdOrNull,
        revokedFromCompanyId: me.revokedFromCompanyId,
      );
    } catch (e) {
      debugPrint('AuthBloc: entreprise du compte non notée : $e');
    }
    return null;
  }

  /// Relit /auth/me : si le compte a désormais une entreprise (ajouté
  /// directement par l'administrateur, demande acceptée), l'état d'entrée ;
  /// sinon `null`. Une session refusée (401) remonte.
  Future<AuthState?> _stateIfNowMember() async {
    User? refreshed;
    try {
      refreshed = await _authRepository.refreshUserProfile();
    } on AuthenticationException {
      rethrow;
    } catch (e) {
      debugPrint('AuthBloc: /auth/me non relu : $e');
      return null;
    }
    final me = _authRepository.getLastAuthMeResponse();
    if (refreshed == null || me == null || me.hasNoCompany) return null;
    final next = await _resolveWithJoinRequest(refreshed);
    return next is AuthSyncPending ? null : next;
  }

  /// Comme [_resolveAuthState], et pour un compte sans entreprise, regarde
  /// s'il a une demande de rattachement en cours : l'écran d'attente de la
  /// demande s'affiche alors directement (au démarrage, après connexion).
  /// Un échec de cette lecture n'empêche jamais l'accès au parcours habituel.
  Future<AuthState> _resolveWithJoinRequest(User user) async {
    final lastKnown = await _recordCompanyScope(user);
    final resolved = _resolveAuthState(user, lastKnown: lastKnown);
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
    // Éviter d'émettre AuthLoading si l'utilisateur est déjà authentifié :
    // cela évite le flash de chargement lors des rares appels post-connexion.
    if (state is! AuthAuthenticated) {
      emit(const AuthLoading());
    }
    try {
      final isLoggedIn = await _authRepository.isLoggedIn();
      if (isLoggedIn) {
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          // Émettre immédiatement avec les données disponibles (cache)
          emit(await _resolveWithJoinRequest(user));

          // Sur le poste, la reprise de session lit l'utilisateur en cache
          // sans appeler /auth/me : sans cette relecture, un compte en
          // attente de synchronisation ou de rattachement entrait dans l'app
          // comme un compte complet, et le contexte entreprise/unité restait
          // celui de la dernière session.
          if (_authRepository.getLastAuthMeResponse() == null) {
            // Ce rafraîchissement est un CONFORT, pas une condition d'accès :
            // hors ligne, on garde l'état déjà émis.
            try {
              final refreshedUser = await _authRepository.refreshUserProfile();
              if (refreshedUser != null && !isClosed) {
                emit(await _resolveWithJoinRequest(refreshedUser));
              }
            } on AuthenticationException {
              // Le serveur a répondu et refuse la session : seule cette
              // réponse ferme l'accès, et uniquement si le réseau est là.
              if (_isOnline()) rethrow;
            } catch (e) {
              debugPrint(
                'AuthBloc: profil non rafraîchi (hors ligne), session conservée : $e',
              );
            }
          }
        } else {
          emit(const AuthUnauthenticated());
        }
      } else {
        emit(const AuthUnauthenticated());
      }
    } on AuthenticationException catch (_) {
      // Jeton refusé (401 sur /auth/me) → déconnexion et retour à la connexion
      debugPrint(
        'AuthBloc: Token invalide (401) lors de la vérification - forçage de la déconnexion',
      );
      try {
        await _authRepository.logout();
      } catch (_) {}
      emit(const AuthUnauthenticated());
    } catch (e) {
      // Dernier recours : plutôt que de renvoyer à l'écran de connexion sur une
      // panne technique, on rouvre la dernière session connue. Les écritures
      // partent dans la file hors ligne, et un vrai refus du serveur (401)
      // déconnectera proprement dès le premier échange.
      final cached = await _authRepository.getLastKnownUser();
      if (cached != null && !isClosed) {
        debugPrint('AuthBloc: reprise de la dernière session connue ($e)');
        // Même règle que d'habitude : un compte que le serveur a dit « sans
        // entreprise » ne rouvre pas l'ancienne session.
        final lastKnown = await _recordCompanyScope(cached);
        if (isClosed) return;
        emit(_resolveAuthState(cached, lastKnown: lastKnown));
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
        } on AuthenticationException {
          rethrow; // session refusée : déconnexion (ci-dessous)
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

      // Demande encore en attente (ou refusée), mais le compte a pu être
      // ajouté directement par l'administrateur : /auth/me tranche. Une
      // entreprise présente fait entrer, quelle que soit la demande.
      final member = await _stateIfNowMember();
      if (member != null) {
        emit(member);
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
      } else if (state is AuthSyncPending) {
        // Garder l'écran de synchronisation, avec un message à jour
        emit(
          AuthSyncPending(
            (state as AuthSyncPending).user,
            message: 'Synchronisation toujours en cours...',
          ),
        );
      }
    } on AuthenticationException catch (_) {
      // Jeton refusé (401 sur /auth/me) → déconnexion
      debugPrint(
        'AuthBloc: Token invalide (401) lors du refresh profil - forçage de la déconnexion',
      );
      try {
        await _authRepository.logout();
      } catch (_) {}
      emit(const AuthUnauthenticated());
    } catch (e) {
      debugPrint('AuthBloc: Error refreshing profile: $e');
      // Ne pas changer l'état en cas d'erreur de refresh
    }
  }
}
