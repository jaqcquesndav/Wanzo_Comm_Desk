import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanzo/core/config/env_config.dart';
import 'package:wanzo/features/auth/models/user.dart';
import 'package:wanzo/features/auth/services/offline_auth_service.dart';
import 'package:wanzo/features/auth/services/jwt_offline_validator.dart';
import 'package:wanzo/features/auth/services/local_auth_server.dart';
import 'package:wanzo/core/services/business_context_service.dart';

/// Service d'authentification pour les plateformes desktop (Windows/Linux)
///
/// Ce service implémente le flux OAuth "Authorization Code" sécurisé :
/// 1. Démarre un serveur HTTP local temporaire
/// 2. Ouvre le navigateur vers Auth0 Universal Login
/// 3. Capture le callback avec le code d'autorisation
/// 4. Échange le code contre des tokens
///
/// C'est la méthode recommandée utilisée par VS Code, Slack, Spotify Desktop.
///
/// Fallback: Si le flux OAuth échoue, peut utiliser le Password Grant
/// (nécessite activation dans Auth0 Dashboard).
class DesktopAuthService {
  final String _auth0Domain = EnvConfig.auth0Domain;
  final String _auth0ClientId = EnvConfig.auth0ClientId;
  final String _auth0Audience = EnvConfig.auth0Audience;

  // Clés pour le stockage sécurisé
  static const String _accessTokenKey = 'desktop_access_token';
  static const String _refreshTokenKey = 'desktop_refresh_token';
  static const String _idTokenKey = 'desktop_id_token';
  static const String _expiresAtKey = 'desktop_expires_at';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final OfflineAuthService _offlineAuthService;
  final JwtOfflineValidator _jwtValidator = JwtOfflineValidator();
  final BusinessContextService _businessContextService =
      BusinessContextService();

  // État d'authentification
  User? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;

  // State pour la vérification CSRF
  String? _authState;

  DesktopAuthService({required OfflineAuthService offlineAuthService})
    : _offlineAuthService = offlineAuthService;

  /// Vérifie si la plateforme actuelle nécessite l'authentification desktop
  static bool get isDesktopPlatform {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux;
  }

  /// Initialise le service
  Future<void> init() async {
    await _jwtValidator.initialize();
    await _offlineAuthService.initialize();
    await _businessContextService.initialize();
    await _loadStoredCredentials();
    final osName = kIsWeb ? 'web' : Platform.operatingSystem;
    debugPrint('DesktopAuthService: Initialized for $osName');
  }

  /// Charge les credentials stockées
  Future<void> _loadStoredCredentials() async {
    try {
      _accessToken = await _secureStorage.read(key: _accessTokenKey);
      _refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      final expiresAtStr = await _secureStorage.read(key: _expiresAtKey);
      if (expiresAtStr != null) {
        _expiresAt = DateTime.fromMillisecondsSinceEpoch(
          int.parse(expiresAtStr),
        );
      }
      debugPrint('DesktopAuthService: Loaded stored credentials');
    } catch (e) {
      debugPrint('DesktopAuthService: Error loading stored credentials: $e');
    }
  }

  /// Sauvegarde les credentials
  Future<void> _saveCredentials({
    required String accessToken,
    required String idToken,
    String? refreshToken,
    required DateTime expiresAt,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _idTokenKey, value: idToken);
    if (refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    }
    await _secureStorage.write(
      key: _expiresAtKey,
      value: expiresAt.millisecondsSinceEpoch.toString(),
    );

    // Sauvegarder aussi pour l'utilisation offline
    await _offlineAuthService.cacheTokensForOffline(
      idToken: idToken,
      accessToken: accessToken,
      expiresAt: expiresAt,
    );

    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _expiresAt = expiresAt;

    debugPrint('DesktopAuthService: Credentials saved');
  }

  /// Efface les credentials
  Future<void> _clearCredentials() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _idTokenKey);
    await _secureStorage.delete(key: _expiresAtKey);

    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _currentUser = null;

    debugPrint('DesktopAuthService: Credentials cleared');
  }

  /// Vérifie si l'utilisateur est authentifié
  Future<bool> isAuthenticated() async {
    // Vérifier le token en cache
    if (_accessToken != null && _expiresAt != null) {
      if (_expiresAt!.isAfter(DateTime.now())) {
        return true;
      }
      // Token expiré, essayer de rafraîchir
      if (_refreshToken != null) {
        try {
          await refreshAccessToken();
          return true;
        } catch (e) {
          debugPrint('DesktopAuthService: Failed to refresh token: $e');
        }
      }
    }

    // Vérifier l'authentification offline
    final offlineStatus = await _offlineAuthService.checkOfflineAuthStatus();
    return offlineStatus.canAuthenticate;
  }

  /// Génère un state aléatoire pour la protection CSRF
  String _generateState() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  /// Authentifie l'utilisateur via le flux OAuth Authorization Code (RECOMMANDÉ)
  ///
  /// Cette méthode :
  /// 1. Démarre un serveur HTTP local sur un port disponible
  /// 2. Ouvre le navigateur vers Auth0 Universal Login
  /// 3. Attend le callback avec le code d'autorisation
  /// 4. Échange le code contre des tokens
  ///
  /// Si [email] et [password] sont fournis, utilise le Password Grant en fallback.
  Future<User> login(String email, String password) async {
    debugPrint('DesktopAuthService: Starting OAuth login flow');

    // Si email/password fournis et non vides, essayer d'abord le Password Grant
    // (utile pour les tests ou si configuré dans Auth0)
    if (email.isNotEmpty && password.isNotEmpty) {
      try {
        return await _loginWithPassword(email, password);
      } on DesktopAuthException catch (e) {
        if (e.isPasswordGrantDisabled) {
          debugPrint(
            'DesktopAuthService: Password Grant disabled, using OAuth flow',
          );
          // Continuer avec le flux OAuth
        } else {
          rethrow;
        }
      }
    }

    // Flux OAuth Authorization Code (méthode principale)
    return await _loginWithOAuth();
  }

  /// Login via OAuth Authorization Code avec serveur local
  Future<User> _loginWithOAuth() async {
    LocalAuthServer? server;

    try {
      // 1. Démarrer le serveur local
      server = LocalAuthServer(timeout: const Duration(minutes: 5));
      final serverFuture = server.startAndWaitForCallback();

      // Attendre que le serveur soit prêt
      await Future.delayed(const Duration(milliseconds: 100));

      // 2. Générer le state pour la protection CSRF
      _authState = _generateState();

      // 3. Construire l'URL d'autorisation Auth0
      final authUrl = Uri.https(_auth0Domain, '/authorize', {
        'response_type': 'code',
        'client_id': _auth0ClientId,
        'redirect_uri': server.callbackUrl,
        'scope': 'openid profile email offline_access read:user_id_token',
        'audience': _auth0Audience,
        'state': _authState,
      });

      debugPrint('DesktopAuthService: Opening browser for Auth0 login');
      debugPrint('DesktopAuthService: Callback URL: ${server.callbackUrl}');

      // 4. Ouvrir le navigateur
      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw DesktopAuthException(
          'Could not open browser for authentication',
          code: 'browser_error',
        );
      }

      // 5. Attendre le callback
      debugPrint('DesktopAuthService: Waiting for OAuth callback...');
      final response = await serverFuture;

      // 6. Vérifier le résultat
      if (!response.isSuccess) {
        if (response.isCancelled) {
          throw DesktopAuthException(
            'Authentication cancelled by user',
            code: 'user_cancelled',
          );
        }
        throw DesktopAuthException(
          response.errorDescription ?? 'Authentication failed',
          code: response.error ?? 'auth_error',
        );
      }

      // 7. Vérifier le state (protection CSRF)
      if (response.state != null && response.state != _authState) {
        throw DesktopAuthException(
          'State mismatch - possible CSRF attack',
          code: 'state_mismatch',
        );
      }

      // 8. Échanger le code contre des tokens
      debugPrint(
        'DesktopAuthService: Exchanging authorization code for tokens',
      );
      final user = await _exchangeCodeForTokens(
        response.code!,
        server.callbackUrl,
      );

      debugPrint(
        'DesktopAuthService: OAuth login successful for ${user.email}',
      );
      return user;
    } catch (e) {
      debugPrint('DesktopAuthService: OAuth login error: $e');

      // Note: Ne PAS faire de fallback vers l'utilisateur offline lors d'un login
      // Le fallback offline ne doit être utilisé que pour la vérification d'authentification
      // existante, pas pour un nouveau login

      if (e is DesktopAuthException) rethrow;
      throw DesktopAuthException(
        'Authentication failed: $e',
        code: 'auth_error',
      );
    } finally {
      // Arrêter le serveur
      await server?.stop();
      _authState = null;
    }
  }

  /// Échange le code d'autorisation contre des tokens
  Future<User> _exchangeCodeForTokens(String code, String redirectUri) async {
    final response = await http.post(
      Uri.parse('https://$_auth0Domain/oauth/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'grant_type': 'authorization_code',
        'client_id': _auth0ClientId,
        'code': code,
        'redirect_uri': redirectUri,
      }),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw DesktopAuthException(
        errorData['error_description'] ?? 'Token exchange failed',
        code: errorData['error'] ?? 'token_error',
      );
    }

    final data = jsonDecode(response.body);

    final accessToken = data['access_token'] as String;
    final idToken = data['id_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    final expiresIn = data['expires_in'] as int? ?? 86400;
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    // Sauvegarder les credentials
    await _saveCredentials(
      accessToken: accessToken,
      idToken: idToken ?? '',
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );

    // Récupérer les informations utilisateur
    final user = await _getUserInfo(accessToken);
    if (user != null) {
      _currentUser = user;
      await _offlineAuthService.saveUserForOfflineLogin(user);
      return user;
    }

    throw DesktopAuthException(
      'Failed to get user info after authentication',
      code: 'user_info_error',
    );
  }

  /// Login via Password Grant (fallback, nécessite activation dans Auth0)
  Future<User> _loginWithPassword(String email, String password) async {
    debugPrint(
      'DesktopAuthService: Attempting Password Grant login for $email',
    );

    final response = await http.post(
      Uri.parse('https://$_auth0Domain/oauth/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'grant_type': 'password',
        'username': email,
        'password': password,
        'client_id': _auth0ClientId,
        'audience': _auth0Audience,
        'scope': 'openid profile email offline_access read:user_id_token',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final accessToken = data['access_token'] as String;
      final idToken = data['id_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      final expiresIn = data['expires_in'] as int? ?? 86400;
      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

      await _saveCredentials(
        accessToken: accessToken,
        idToken: idToken ?? '',
        refreshToken: refreshToken,
        expiresAt: expiresAt,
      );

      final user = await _getUserInfo(accessToken);
      if (user != null) {
        _currentUser = user;
        await _offlineAuthService.saveUserForOfflineLogin(user);
        debugPrint('DesktopAuthService: Password Grant login successful');
        return user;
      }
      throw DesktopAuthException(
        'Failed to get user info',
        code: 'user_info_error',
      );
    } else if (response.statusCode == 403) {
      throw DesktopAuthException(
        'Password grant is disabled. Using OAuth flow instead.',
        code: 'password_grant_disabled',
      );
    } else {
      final errorData = jsonDecode(response.body);
      throw DesktopAuthException(
        errorData['error_description'] ?? 'Login failed',
        code: errorData['error'] ?? 'auth_error',
      );
    }
  }

  /// Récupère les informations utilisateur depuis Auth0
  Future<User?> _getUserInfo(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://$_auth0Domain/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final User user = User(
          id: data['sub'] as String,
          name: data['name'] ?? data['nickname'] ?? 'N/A',
          email: data['email'] ?? 'N/A',
          emailVerified: data['email_verified'] ?? false,
          picture: data['picture'],
          phone:
              data['https://wanzo.app/phone_number'] ??
              data['phone_number'] ??
              '',
          phoneVerified: data['phone_number_verified'] ?? false,
          role: _extractRole(data['https://wanzo.app/roles']) ?? 'user',
          companyId: data['https://wanzo.app/company_id'],
          companyName: data['https://wanzo.app/company_name'],
          idCardStatus: _parseIdStatus(
            data['https://wanzo.app/id_card_status'],
          ),
          token: accessToken,
        );

        return user;
      } else {
        debugPrint(
          'DesktopAuthService: Failed to get user info: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('DesktopAuthService: Error getting user info: $e');
      return null;
    }
  }

  /// Rafraîchit le token d'accès
  Future<String?> refreshAccessToken() async {
    if (_refreshToken == null) {
      debugPrint('DesktopAuthService: No refresh token available');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('https://$_auth0Domain/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'grant_type': 'refresh_token',
          'client_id': _auth0ClientId,
          'refresh_token': _refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final accessToken = data['access_token'] as String;
        final idToken = data['id_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;
        final expiresIn = data['expires_in'] as int? ?? 86400;
        final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

        await _saveCredentials(
          accessToken: accessToken,
          idToken: idToken ?? '',
          refreshToken: newRefreshToken ?? _refreshToken,
          expiresAt: expiresAt,
        );

        debugPrint('DesktopAuthService: Token refreshed successfully');
        return accessToken;
      } else {
        debugPrint(
          'DesktopAuthService: Failed to refresh token: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('DesktopAuthService: Error refreshing token: $e');
      return null;
    }
  }

  /// Déconnecte l'utilisateur
  Future<void> logout() async {
    debugPrint('DesktopAuthService: Logging out');

    await _clearCredentials();
    await _businessContextService.clear();

    // Optionnel: révoquer le token côté Auth0
    if (_accessToken != null) {
      try {
        await http.post(
          Uri.parse('https://$_auth0Domain/oauth/revoke'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'client_id': _auth0ClientId,
            'token': _refreshToken ?? _accessToken,
          }),
        );
      } catch (e) {
        debugPrint('DesktopAuthService: Error revoking token: $e');
      }
    }

    debugPrint('DesktopAuthService: Logout complete');
  }

  /// Récupère le token d'accès actuel
  Future<String?> getAccessToken() async {
    // Vérifier si le token est encore valide
    if (_accessToken != null && _expiresAt != null) {
      if (_expiresAt!.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
        return _accessToken;
      }
      // Token proche de l'expiration, essayer de rafraîchir
      if (_refreshToken != null) {
        final newToken = await refreshAccessToken();
        if (newToken != null) return newToken;
      }
    }

    // Fallback: token stocké
    return await _secureStorage.read(key: _accessTokenKey);
  }

  /// Récupère l'utilisateur actuel
  Future<User?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    // Essayer de récupérer depuis le cache offline
    final offlineUser = await _offlineAuthService.getLastLoggedInUser();
    if (offlineUser != null) {
      _currentUser = offlineUser;
      return offlineUser;
    }

    // Si on a un token valide, récupérer les infos utilisateur
    final token = await getAccessToken();
    if (token != null) {
      final user = await _getUserInfo(token);
      if (user != null) {
        _currentUser = user;
        await _offlineAuthService.saveUserForOfflineLogin(user);
        return user;
      }
    }

    return null;
  }

  // Helpers pour parser les données utilisateur

  String? _extractRole(dynamic rolesData) {
    if (rolesData == null) return null;
    if (rolesData is String) return rolesData;
    if (rolesData is List && rolesData.isNotEmpty) {
      return rolesData.first.toString();
    }
    return null;
  }

  IdStatus _parseIdStatus(String? status) {
    if (status == null) return IdStatus.UNKNOWN;
    switch (status.toLowerCase()) {
      case 'pending':
        return IdStatus.PENDING;
      case 'verified':
        return IdStatus.VERIFIED;
      case 'rejected':
        return IdStatus.REJECTED;
      default:
        return IdStatus.UNKNOWN;
    }
  }
}

/// Exception personnalisée pour les erreurs d'authentification desktop
class DesktopAuthException implements Exception {
  final String message;
  final String code;

  DesktopAuthException(this.message, {this.code = 'unknown'});

  @override
  String toString() => 'DesktopAuthException($code): $message';

  /// Vérifie si l'erreur est due à des identifiants invalides
  bool get isInvalidCredentials =>
      code == 'invalid_grant' ||
      code == 'invalid_user_password' ||
      code == 'access_denied';

  /// Vérifie si l'erreur est due à un problème réseau
  bool get isNetworkError => code == 'network_error';

  /// Vérifie si le Password Grant est désactivé
  bool get isPasswordGrantDisabled => code == 'password_grant_disabled';
}
