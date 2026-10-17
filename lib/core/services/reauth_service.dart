import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/auth/services/auth0_service.dart';
import '../exceptions/api_exceptions.dart';

/// Service pour gérer la ré-authentification automatique
class ReauthService {
  static ReauthService? _instance;
  Auth0Service? _auth0Service;

  // Contrôleur de stream pour notifier les autres services des changements d'auth
  final StreamController<AuthStatus> _authStatusController =
      StreamController<AuthStatus>.broadcast();

  // Verrou pour éviter les tentatives multiples de ré-authentification simultanées
  bool _isReauthenticating = false;

  // Callback pour déclencher la déconnexion via le AuthBloc
  VoidCallback? _onForceLogout;

  /// Renouvellement prioritaire du jeton (ordinateur : jeton de rafraîchissement
  /// du service d'authentification desktop). `null` : SDK Auth0 seul.
  Future<String?> Function()? _tokenRefresher;

  // Callbacks pour les événements d'authentification
  final List<VoidCallback> _onAuthenticationRequired = [];
  final List<VoidCallback> _onAuthenticationSuccess = [];
  final List<VoidCallback> _onAuthenticationFailure = [];

  ReauthService._internal();

  static ReauthService get instance {
    _instance ??= ReauthService._internal();
    return _instance!;
  }

  /// Configure le service avec Auth0Service
  void configure(Auth0Service auth0Service) {
    _auth0Service = auth0Service;
  }

  /// Enregistre le callback de déconnexion forcée (à appeler après création du AuthBloc)
  void setForceLogoutCallback(VoidCallback callback) {
    _onForceLogout = callback;
  }

  /// Enregistre la source de renouvellement du jeton (ordinateur). Sans elle,
  /// un jeton expiré restait « valide » côté app : chaque requête recevait un
  /// 401 et rien ne relançait la session.
  void setTokenRefresher(Future<String?> Function() refresher) {
    _tokenRefresher = refresher;
  }

  /// Stream pour écouter les changements de statut d'authentification
  Stream<AuthStatus> get authStatusStream => _authStatusController.stream;

  /// Ajoute un callback à déclencher quand une ré-authentification est requise
  void onAuthenticationRequired(VoidCallback callback) {
    _onAuthenticationRequired.add(callback);
  }

  /// Ajoute un callback à déclencher quand la ré-authentification réussit
  void onAuthenticationSuccess(VoidCallback callback) {
    _onAuthenticationSuccess.add(callback);
  }

  /// Ajoute un callback à déclencher quand la ré-authentification échoue
  void onAuthenticationFailure(VoidCallback callback) {
    _onAuthenticationFailure.add(callback);
  }

  /// Retire un callback
  void removeCallback(VoidCallback callback) {
    _onAuthenticationRequired.remove(callback);
    _onAuthenticationSuccess.remove(callback);
    _onAuthenticationFailure.remove(callback);
  }

  /// Vérifie si le token actuel est valide
  Future<bool> isTokenValid() async {
    if (_auth0Service == null) return false;

    try {
      final token = await _auth0Service!.getAccessToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Renouvelle le jeton : d'abord la source prioritaire (ordinateur), puis
  /// le SDK Auth0. Vrai si un jeton est disponible à l'issue.
  Future<bool> _renew() async {
    if (_tokenRefresher != null) {
      try {
        final token = await _tokenRefresher!();
        if (token != null && token.isNotEmpty) return true;
      } catch (e) {
        debugPrint('ReauthService: renouvellement prioritaire impossible : $e');
      }
    }
    return _auth0Service!.renewToken();
  }

  /// Tente une ré-authentification automatique
  Future<bool> attemptReauth() async {
    if (_isReauthenticating || _auth0Service == null) {
      return false;
    }

    _isReauthenticating = true;
    _authStatusController.add(AuthStatus.reauthenticating);

    try {
      // Notifier que la ré-authentification est requise
      for (final callback in _onAuthenticationRequired) {
        callback();
      }

      // Tenter de renouveler le token
      final success = await _renew();

      if (success) {
        _authStatusController.add(AuthStatus.authenticated);

        // Notifier le succès
        for (final callback in _onAuthenticationSuccess) {
          callback();
        }

        return true;
      } else {
        throw AuthenticationException('Failed to renew token');
      }
    } catch (e) {
      _authStatusController.add(AuthStatus.authenticationFailed);

      // Notifier l'échec
      for (final callback in _onAuthenticationFailure) {
        callback();
      }

      // Si le renouvellement automatique échoue, forcer une nouvelle connexion
      await _forceLogin();
      return false;
    } finally {
      _isReauthenticating = false;
    }
  }

  /// Force une nouvelle connexion complète
  Future<void> _forceLogin() async {
    if (_auth0Service == null) return;

    try {
      _authStatusController.add(AuthStatus.loginRequired);

      // Nettoyer les tokens existants
      await _auth0Service!.logout();

      await _redirectToLogin();
    } catch (e) {
      debugPrint('Erreur lors de la redirection vers la connexion: $e');
    }
  }

  /// Redirige vers l'écran de connexion via le AuthBloc
  Future<void> _redirectToLogin() async {
    _authStatusController.add(AuthStatus.loginRequired);

    // Déclencher la déconnexion via AuthBloc → GoRouter redirigera vers /auth0_info
    if (_onForceLogout != null) {
      _onForceLogout!();
    } else {
      debugPrint(
        'ReauthService: _onForceLogout callback not configured - '
        'call setForceLogoutCallback() after AuthBloc creation',
      );
    }
  }

  /// Gère une exception d'authentification depuis l'API
  Future<void> handleAuthException(AuthenticationException exception) async {
    debugPrint(
      'Gestion de l\'exception d\'authentification: ${exception.message}',
    );

    // Vérifier si on peut tenter une ré-authentification
    if (!_isReauthenticating) {
      final success = await attemptReauth();

      if (!success) {
        // Si la ré-authentification échoue, forcer la déconnexion
        await forceLogout();
      }
    }
  }

  /// Force la déconnexion de l'utilisateur
  Future<void> forceLogout() async {
    if (_auth0Service != null) {
      await _auth0Service!.logout();
    }

    _authStatusController.add(AuthStatus.loggedOut);

    // Notifier le AuthBloc pour déclencher la navigation
    if (_onForceLogout != null) {
      _onForceLogout!();
    }
  }

  /// Nettoie les ressources
  void dispose() {
    _authStatusController.close();
    _onAuthenticationRequired.clear();
    _onAuthenticationSuccess.clear();
    _onAuthenticationFailure.clear();
  }
}

/// Énumération des statuts d'authentification
enum AuthStatus {
  authenticated,
  reauthenticating,
  authenticationFailed,
  loginRequired,
  loggedOut,
}

/// Extension pour Auth0Service pour ajouter la méthode renewToken
extension Auth0ServiceReauth on Auth0Service {
  /// Tente de renouveler le token d'accès via le SDK Auth0 (sur ordinateur,
  /// [Auth0Service.refreshAccessToken] rend le jeton en cache).
  Future<bool> renewToken() async {
    try {
      final token = await refreshAccessToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
