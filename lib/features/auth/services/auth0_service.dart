import 'package:flutter/foundation.dart'; // For kIsWeb if needed later
import 'package:flutter/material.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';
import 'package:wanzo/core/services/business_context_service.dart';
// import '../../../core/services/auth0_management_api_service.dart'; // Unused
import '../models/user.dart';
import '../../../core/utils/connectivity_service.dart';
import '../../../core/config/env_config.dart';
import 'offline_auth_service.dart';
import 'auth_backend_service.dart';
import 'jwt_offline_validator.dart';

/// Service pour gérer l'authentification avec Auth0
class Auth0Service {
  String get _auth0Domain => EnvConfig.auth0Domain;
  String get _auth0ClientId => EnvConfig.auth0ClientId;
  String get _auth0Audience => EnvConfig.auth0Audience;
  String get _auth0Scheme => EnvConfig.auth0Scheme;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _idTokenKey = 'id_token';
  static const String _expiresAtKey = 'expires_at';
  static const String _demoUserKey = 'demo_user_active';

  late Auth0 auth0;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineAuthService offlineAuthService;
  final AuthBackendService _authBackendService = AuthBackendService();
  final JwtOfflineValidator _jwtValidator = JwtOfflineValidator();
  final BusinessContextService _businessContextService =
      BusinessContextService();

  Auth0Service({required this.offlineAuthService}) {
    auth0 = Auth0(_auth0Domain, _auth0ClientId);
  }

  Future<void> init() async {
    await _connectivityService.init();
    // Initialiser le validateur JWT pour l'authentification offline
    await _jwtValidator.initialize();
    await offlineAuthService.initialize();
    // Initialiser le BusinessContextService
    await _businessContextService.initialize();
    debugPrint(
      'Auth0Service: Initialized with offline JWT validator and BusinessContextService',
    );
  }

  Future<bool> isDemoUserActive() async {
    return await _secureStorage.read(key: _demoUserKey) == 'true';
  }

  Future<void> setDemoUserActive(bool isActive) async {
    if (isActive) {
      await _secureStorage.write(key: _demoUserKey, value: 'true');
      debugPrint("Auth0Service: Demo user mode explicitly ACTIVATED.");
    } else {
      await _secureStorage.delete(key: _demoUserKey);
      debugPrint("Auth0Service: Demo user mode explicitly DEACTIVATED.");
    }
  }

  Future<bool> isAuthenticated() async {
    // 1. Vérifier si c'est un utilisateur démo
    if (await isDemoUserActive()) {
      debugPrint(
        "Auth0Service: Demo user is active and considered authenticated.",
      );
      return true;
    }

    // 2. Vérifier la connectivité
    final isOnline = _connectivityService.isConnected;

    if (isOnline) {
      // En ligne: utiliser Auth0 SDK normalement
      try {
        final hasValid = await auth0.credentialsManager.hasValidCredentials(
          minTtl: 60,
        );
        if (hasValid) {
          debugPrint('Auth0Service: Online - valid credentials found');
          return true;
        }
      } catch (e) {
        debugPrint('Auth0Service: Error checking credentials online: $e');
        // Fallback vers offline si erreur
      }
    }

    // 3. Hors ligne ou erreur: utiliser la validation JWKS locale
    debugPrint('Auth0Service: Checking offline authentication status...');
    final offlineStatus = await offlineAuthService.checkOfflineAuthStatus();

    if (offlineStatus.canAuthenticate) {
      debugPrint(
        'Auth0Service: Offline authentication valid - ${offlineStatus.reason}',
      );
      if (offlineStatus.tokenExpired) {
        debugPrint(
          'Auth0Service: Warning - Token expired but allowing offline access',
        );
      }
      return true;
    }

    debugPrint('Auth0Service: Not authenticated - ${offlineStatus.reason}');
    return false;
  }

  Future<User> loginWithDemoAccount() async {
    debugPrint('Auth0Service: Connexion avec le compte de démonstration');
    await setDemoUserActive(true);

    final demoUser = User(
      id: 'demo-user-id',
      name: 'Utilisateur Démo Wanzo',
      email: 'demo@wanzo.app',
      phone: '+243000000000',
      role: 'admin',
      token: 'mock_demo_access_token_${DateTime.now().millisecondsSinceEpoch}',
      picture: 'https://i.pravatar.cc/150?u=demo@wanzo.app',
      companyId: 'demo-company-id',
      companyName: 'Demo Company SARL',
      idCardStatus: IdStatus.VERIFIED,
      emailVerified: true, // Added for User model compatibility
      phoneVerified: true, // Added for User model compatibility
    );

    await _secureStorage.write(key: _accessTokenKey, value: demoUser.token);
    await _secureStorage.write(key: _idTokenKey, value: 'mock_demo_id_token');
    await _secureStorage.write(
      key: _expiresAtKey,
      value:
          DateTime.now()
              .add(const Duration(days: 365))
              .millisecondsSinceEpoch
              .toString(),
    );
    await _secureStorage.write(key: _demoUserKey, value: 'true');

    await offlineAuthService.saveUserForOfflineLogin(demoUser);
    await offlineAuthService.setOfflineLoginEnabled(true);
    debugPrint(
      "Auth0Service: Demo user saved for offline login and offline mode enabled.",
    );

    return demoUser;
  }

  /// Se connecte à Auth0 en utilisant les pages d'authentification d'Auth0 directement
  Future<User> login() async {
    try {
      debugPrint(
        "Auth0Service: Attempting Auth0 login with hosted login page. Clearing demo user flag.",
      );
      await setDemoUserActive(false);
      await auth0.credentialsManager.clearCredentials();

      debugPrint("Auth0Service: Using client ID: $_auth0ClientId");
      debugPrint("Auth0Service: Using domain: $_auth0Domain");
      debugPrint("Auth0Service: Using audience: $_auth0Audience");
      debugPrint("Auth0Service: Using scheme: $_auth0Scheme");

      // Utiliser directement les pages d'authentification d'Auth0 au lieu des pages intégrées
      final Credentials credentials = await auth0
          .webAuthentication(scheme: _auth0Scheme)
          .login(
            audience: _auth0Audience,
            scopes: {
              'openid',
              'profile',
              'email',
              'offline_access',
              'read:user_id_token',
            },
            // Utilisation du mode Universal Login d'Auth0
            parameters: {
              'prompt':
                  'login', // Force l'affichage de la page de login même si l'utilisateur est déjà connecté
            },
          );

      // Force la sauvegarde car c'est un nouveau login
      await _saveCredentials(credentials, force: true);
      debugPrint(
        "Auth0Service: Login successful, tokens stored. Credentials expire at: ${credentials.expiresAt}",
      );

      // getUserInfoFromSdk() fait déjà l'enrichissement avec le backend
      // Ne pas appeler _enrichUserWithBackendData une seconde fois
      final user = await getUserInfoFromSdk();
      if (user != null) {
        // L'utilisateur est déjà enrichi par getUserInfoFromSdk()
        // et déjà sauvegardé pour offline login
        return user;
      } else {
        throw Exception('Failed to get user info after login.');
      }
    } on WebAuthenticationException catch (e) {
      final String eMessage = e.message.toLowerCase();
      // Ensure details is converted to string before toLowerCase()
      final String eDetails = e.details.toString().toLowerCase();
      debugPrint(
        'WebAuthenticationException during login: ${e.message}. Details: ${e.details}.',
      );

      bool userCancelled =
          eMessage.contains('cancel') ||
          eDetails.contains('cancel') ||
          eMessage.contains('user_cancelled') ||
          eDetails.contains('user_cancelled') ||
          eMessage.contains('user closed') ||
          eDetails.contains('user closed') ||
          eMessage.contains('a0.session.user_cancelled') ||
          eDetails.contains('a0.session.user_cancelled');

      if (userCancelled) {
        debugPrint('User cancelled login flow.');
      } else {
        final offlineUser = await offlineAuthService.getLastLoggedInUser();
        if (offlineUser != null) {
          debugPrint(
            'Returning last logged in user due to online login failure (WebAuthenticationException).',
          );
          return offlineUser;
        }
      }
      rethrow;
    } on CredentialsManagerException catch (e) {
      // Specific catch block for CredentialsManagerException
      debugPrint(
        'CredentialsManagerException during login: ${e.message}. Details: ${e.details}.',
      );
      final offlineUser = await offlineAuthService.getLastLoggedInUser();
      if (offlineUser != null) {
        debugPrint(
          'Returning last logged in user due to online login failure (CredentialsManagerException).',
        );
        return offlineUser;
      }
      rethrow;
    } on ApiException catch (e) {
      debugPrint(
        'ApiException during login: Status: ${e.statusCode}. Details: ${e.toString()}',
      );
      final offlineUser = await offlineAuthService.getLastLoggedInUser();
      if (offlineUser != null) {
        debugPrint(
          'Returning last logged in user due to online login failure (ApiException).',
        );
        return offlineUser;
      }
      rethrow;
    } catch (e) {
      debugPrint('Generic error during login: $e');
      final offlineUser = await offlineAuthService.getLastLoggedInUser();
      if (offlineUser != null) {
        debugPrint(
          'Returning last logged in user due to online login failure (Generic Error).',
        );
        return offlineUser;
      }
      rethrow;
    }
  }

  // Cache pour éviter les sauvegardes répétées des mêmes credentials
  String? _lastSavedAccessToken;
  DateTime? _lastCredentialsSaveTime;
  static const Duration _credentialsSaveDebounce = Duration(seconds: 30);

  Future<void> _saveCredentials(
    Credentials credentials, {
    bool force = false,
  }) async {
    // Éviter les sauvegardes répétées des mêmes credentials
    if (!force &&
        _lastSavedAccessToken == credentials.accessToken &&
        _lastCredentialsSaveTime != null &&
        DateTime.now().difference(_lastCredentialsSaveTime!) <
            _credentialsSaveDebounce) {
      // Credentials identiques sauvegardées récemment, ignorer
      return;
    }

    await _secureStorage.write(
      key: _accessTokenKey,
      value: credentials.accessToken,
    );
    await _secureStorage.write(key: _idTokenKey, value: credentials.idToken);
    if (credentials.refreshToken != null) {
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: credentials.refreshToken!,
      );
    }
    await _secureStorage.write(
      key: _expiresAtKey,
      value: credentials.expiresAt.millisecondsSinceEpoch.toString(),
    );

    // Cacher les tokens pour l'utilisation offline avec validation JWKS
    await offlineAuthService.cacheTokensForOffline(
      idToken: credentials.idToken,
      accessToken: credentials.accessToken,
      expiresAt: credentials.expiresAt,
    );

    // Mettre à jour le cache de debounce
    _lastSavedAccessToken = credentials.accessToken;
    _lastCredentialsSaveTime = DateTime.now();

    debugPrint('Auth0Service: Credentials saved and cached for offline use');
  }

  Future<void> logout() async {
    try {
      final bool wasDemoUser = await isDemoUserActive();
      debugPrint("Auth0Service: Logging out. Was demo user: $wasDemoUser");

      if (!wasDemoUser) {
        try {
          await auth0.webAuthentication(scheme: _auth0Scheme).logout();
          debugPrint("Auth0Service: Auth0 SDK web logout initiated.");
        } on WebAuthenticationException catch (e) {
          debugPrint(
            "Auth0Service: WebAuthenticationException during web logout: ${e.message}. Details: ${e.details}. Proceeding with local cleanup.",
          );
        } catch (e) {
          debugPrint(
            "Auth0Service: Generic error during web logout: $e. Proceeding with local cleanup.",
          );
        }
      }

      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _idTokenKey);
      await _secureStorage.delete(key: _expiresAtKey);
      await _secureStorage.delete(key: _demoUserKey);
      debugPrint("Auth0Service: All local tokens and demo key deleted.");

      if (!wasDemoUser) {
        try {
          await auth0.credentialsManager.clearCredentials();
          debugPrint(
            "Auth0Service: Cleared credentials from CredentialsManager.",
          );
        } on CredentialsManagerException catch (e) {
          debugPrint(
            "Auth0Service: CredentialsManagerException during clearCredentials: ${e.message}. Details: ${e.details}.",
          );
        } catch (e) {
          debugPrint(
            "Auth0Service: Generic error during clearCredentials: $e.",
          );
        }
      }

      if (!wasDemoUser) {
        final keepOfflineData =
            await offlineAuthService.isOfflineLoginEnabled();
        if (!keepOfflineData) {
          await offlineAuthService.clearOfflineData(); // Corrected method name
          debugPrint(
            'Auth0Service: Offline user data cleared for non-demo user.',
          );
        }
      } else {
        debugPrint(
          'Auth0Service: Demo user logout. Offline data retained by default.',
        );
      }

      // Effacer le contexte business
      await _businessContextService.clear();
      debugPrint("Auth0Service: BusinessContextService cleared on logout");
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  Future<String?> getAccessToken() async {
    if (await isDemoUserActive()) {
      debugPrint(
        "Auth0Service: Demo user active. Returning demo access token.",
      );
      return await _secureStorage.read(key: _accessTokenKey);
    }

    // Vérifier la connectivité
    final isOnline = _connectivityService.isConnected;

    if (isOnline) {
      // En ligne: utiliser Auth0 SDK
      try {
        final credentials = await auth0.credentialsManager.credentials(
          minTtl: 60,
        );
        await _saveCredentials(credentials);
        return credentials.accessToken;
      } on CredentialsManagerException catch (e) {
        debugPrint(
          'Auth0Service: CredentialsManagerException getting access token: ${e.message}. Trying offline...',
        );
      } catch (e) {
        debugPrint(
          'Auth0Service: Error getting access token online: $e. Trying offline...',
        );
      }
    }

    // Hors ligne ou erreur: utiliser le token en cache
    debugPrint(
      'Auth0Service: Attempting to get cached access token for offline use',
    );
    final cachedToken = await offlineAuthService.getCachedAccessToken();

    if (cachedToken != null) {
      // Valider le token localement
      final validationResult = await _jwtValidator.validateToken(cachedToken);
      if (validationResult.isValid) {
        debugPrint('Auth0Service: Using valid cached access token');
        return cachedToken;
      } else if (!_jwtValidator.isTokenExpired(cachedToken)) {
        // Token pas expiré mais validation échouée (probablement signature)
        // On peut quand même l'utiliser en mode offline dégradé
        debugPrint('Auth0Service: Using cached token (offline degraded mode)');
        return cachedToken;
      }
    }

    // Dernier recours: token stocké dans secure storage
    final storedToken = await _secureStorage.read(key: _accessTokenKey);
    if (storedToken != null) {
      debugPrint('Auth0Service: Using stored access token as fallback');
      return storedToken;
    }

    debugPrint('Auth0Service: No access token available');
    return null;
  }

  Future<String?> refreshAccessToken() async {
    if (await isDemoUserActive()) {
      debugPrint(
        "Auth0Service: Demo user active, no refresh needed for demo token.",
      );
      return await _secureStorage.read(key: _accessTokenKey);
    }

    // Vérifier la connectivité
    final isOnline = _connectivityService.isConnected;

    if (isOnline) {
      try {
        debugPrint(
          "Auth0Service: Attempting to renew credentials via SDK (online).",
        );
        final Credentials credentials = await auth0.credentialsManager
            .credentials(minTtl: 60);

        await _saveCredentials(credentials);
        debugPrint("Auth0Service: Credentials renewed successfully.");
        return credentials.accessToken;
      } on CredentialsManagerException catch (e) {
        debugPrint(
          'Auth0Service: CredentialsManagerException during token refresh: ${e.message}. Falling back to offline...',
        );
      } catch (e) {
        debugPrint(
          'Auth0Service: Error during token refresh: $e. Falling back to offline...',
        );
      }
    }

    // Hors ligne: retourner le token en cache s'il est encore utilisable
    debugPrint(
      'Auth0Service: Cannot refresh token offline, using cached token',
    );
    final cachedToken = await offlineAuthService.getCachedAccessToken();

    if (cachedToken != null) {
      // En mode offline, on accepte même un token expiré si l'utilisateur a une session valide
      final offlineStatus = await offlineAuthService.checkOfflineAuthStatus();
      if (offlineStatus.canAuthenticate) {
        debugPrint('Auth0Service: Returning cached token for offline use');
        return cachedToken;
      }
    }

    debugPrint('Auth0Service: No valid token available for offline use');
    return null;
  }

  Future<User?> getUserInfoFromSdk() async {
    if (await isDemoUserActive()) {
      final demoToken = await _secureStorage.read(key: _accessTokenKey);
      final demoUser = await offlineAuthService.getLastLoggedInUser();
      if (demoUser != null && demoUser.token == demoToken) {
        debugPrint(
          "Auth0Service: Demo user active. Returning stored demo user from offline service.",
        );
        return demoUser;
      }
      debugPrint(
        "Auth0Service: Demo user active but no matching user found in offline store. This shouldn't happen.",
      );
      return null;
    }

    // Vérifier la connectivité
    final isOnline = _connectivityService.isConnected;

    if (!isOnline) {
      // Mode offline: retourner l'utilisateur en cache
      debugPrint('Auth0Service: Offline - returning cached user');
      final cachedUser = await offlineAuthService.getLastLoggedInUser();
      if (cachedUser != null) {
        return cachedUser;
      }
      debugPrint('Auth0Service: No cached user available for offline');
      return null;
    }

    debugPrint(
      "Auth0Service: Fetching user info using auth0.api.userProfile().",
    );
    try {
      String? accessToken;
      if (await auth0.credentialsManager.hasValidCredentials(minTtl: 5)) {
        final creds = await auth0.credentialsManager.credentials();
        accessToken = creds.accessToken;
      } else {
        debugPrint(
          "Auth0Service: No valid credentials to fetch user info. Attempting refresh.",
        );
        accessToken = await refreshAccessToken();
        if (accessToken == null) {
          debugPrint("Auth0Service: Refresh failed. Trying cached user.");
          return await offlineAuthService.getLastLoggedInUser();
        }
      }

      final UserProfile userProfile = await auth0.api.userProfile(
        accessToken: accessToken,
      );
      final Credentials currentCredentials =
          await auth0.credentialsManager.credentials();

      final auth0User = User(
        id: userProfile.sub, // sub is non-nullable in UserProfile
        name: userProfile.name ?? userProfile.nickname ?? 'N/A',
        email: userProfile.email ?? 'N/A',
        emailVerified: userProfile.isEmailVerified ?? false,
        picture: userProfile.pictureUrl?.toString(),
        phone:
            userProfile.customClaims?['https://wanzo.app/phone_number']
                as String? ??
            userProfile.phoneNumber ??
            '',
        phoneVerified: userProfile.isPhoneNumberVerified ?? false,
        role: _extractRole(
          userProfile.customClaims?['https://wanzo.app/roles'],
        ),
        companyId:
            userProfile.customClaims?['https://wanzo.app/company_id']
                as String?,
        companyName:
            userProfile.customClaims?['https://wanzo.app/company_name']
                as String?,
        idCardStatus: _parseIdStatus(
          userProfile.customClaims?['https://wanzo.app/id_card_status']
              as String?,
        ),
        token: currentCredentials.accessToken,
      );
      final enrichedUser = await _enrichUserWithBackendData(auth0User);
      await offlineAuthService.saveUserForOfflineLogin(enrichedUser);
      return enrichedUser;
    } on ApiException catch (e) {
      debugPrint(
        'Auth0Service: ApiException fetching user info: Status: ${e.statusCode}. Falling back to cached user.',
      );
      return await offlineAuthService.getLastLoggedInUser();
    } catch (e) {
      debugPrint(
        'Auth0Service: Error fetching user info: $e. Falling back to cached user.',
      );
      return await offlineAuthService.getLastLoggedInUser();
    }
  }

  // Add compatibility method for old code still using getUserInfo
  Future<User?> getUserInfo(String accessToken) async {
    // Simply delegate to getUserInfoFromSdk
    return await getUserInfoFromSdk();
  }

  String _extractRole(dynamic rolesClaim) {
    if (rolesClaim is List && rolesClaim.isNotEmpty) {
      return rolesClaim.first as String? ?? 'user';
    } else if (rolesClaim is String) {
      return rolesClaim;
    }
    return 'user';
  }

  IdStatus _parseIdStatus(String? statusString) {
    if (statusString == null) return IdStatus.UNKNOWN;
    switch (statusString.toLowerCase()) {
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

  /// Enrichit l'utilisateur Auth0 avec les données du backend
  ///
  /// Récupère le profil complet depuis /users/me incluant:
  /// - user: données utilisateur avec companyId (UUID), businessUnitId, etc.
  /// - company: informations de l'entreprise
  /// - businessUnit: informations de l'unité commerciale avec scope
  ///
  /// Met également à jour le BusinessContextService avec le contexte de l'utilisateur.
  /// En cas d'échec réseau, retourne l'utilisateur Auth0 tel quel.
  Future<User> _enrichUserWithBackendData(User auth0User) async {
    try {
      debugPrint(
        "Auth0Service: Enriching user with backend data from /users/me...",
      );

      // Utiliser la nouvelle méthode qui parse la réponse complète
      final authMeResponse = await _authBackendService.fetchAuthMe();

      if (authMeResponse != null) {
        final backendProfile = authMeResponse.user;
        final businessUnit = authMeResponse.businessUnit;
        final company = authMeResponse.company;

        debugPrint(
          "Auth0Service: Backend profile fetched. CompanyId: ${backendProfile.companyId}",
        );
        debugPrint(
          "Auth0Service: Company from /users/me: name=${company?.name}, id=${company?.id}",
        );
        debugPrint(
          "Auth0Service: BusinessUnitId: ${backendProfile.businessUnitId ?? businessUnit?.id}",
        );
        debugPrint(
          "Auth0Service: BusinessUnit scope: ${businessUnit?.scope ?? 'N/A'}",
        );

        // Mettre à jour le BusinessContextService avec les données de /users/me
        await _businessContextService.updateFromAuthMeResponse(authMeResponse);
        debugPrint(
          "Auth0Service: BusinessContextService updated from /users/me",
        );

        // Fusionner les données Auth0 avec les données backend complètes
        // Les données backend ont priorité pour companyId et autres champs business
        // Note: company.name vient de l'objet company séparé, pas de user
        final companyName =
            authMeResponse.company?.name ?? backendProfile.companyName;
        return auth0User.copyWith(
          companyId: backendProfile.companyId,
          companyName: companyName ?? auth0User.companyName,
          rccmNumber: backendProfile.rccmNumber ?? auth0User.rccmNumber,
          companyLocation:
              backendProfile.companyLocation ?? auth0User.companyLocation,
          businessSector:
              backendProfile.businessSector ?? auth0User.businessSector,
          businessSectorId:
              backendProfile.businessSectorId ?? auth0User.businessSectorId,
          businessAddress:
              backendProfile.businessAddress ?? auth0User.businessAddress,
          businessLogoUrl:
              backendProfile.businessLogoUrl ?? auth0User.businessLogoUrl,
          jobTitle: backendProfile.jobTitle ?? auth0User.jobTitle,
          physicalAddress:
              backendProfile.physicalAddress ?? auth0User.physicalAddress,
          idCard: backendProfile.idCard ?? auth0User.idCard,
          idCardStatus:
              backendProfile.idCardStatus != null
                  ? _parseIdStatus(backendProfile.idCardStatus)
                  : auth0User.idCardStatus,
          idCardStatusReason:
              backendProfile.idCardStatusReason ?? auth0User.idCardStatusReason,
          // Business Unit fields from /users/me response
          businessUnitId: backendProfile.businessUnitId ?? businessUnit?.id,
          businessUnitCode: businessUnit?.code,
          businessUnitType:
              backendProfile.businessUnitType != null
                  ? _parseBusinessUnitType(backendProfile.businessUnitType)
                  : businessUnit?.type != null
                  ? _parseBusinessUnitType(businessUnit!.type)
                  : null,
          isActive: backendProfile.isActive,
        );
      } else {
        debugPrint(
          "Auth0Service: Backend profile not available, using Auth0 user as-is",
        );
        // Mettre à jour le contexte avec les données Auth0 minimales
        await _businessContextService.updateFromUser(auth0User);
        return auth0User;
      }
    } catch (e) {
      debugPrint("Auth0Service: Error enriching user with backend data: $e");
      // En cas d'erreur, retourner l'utilisateur Auth0 sans les données backend
      return auth0User;
    }
  }

  /// Parse le type de business unit depuis une chaîne
  BusinessUnitType? _parseBusinessUnitType(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'company':
        return BusinessUnitType.company;
      case 'branch':
        return BusinessUnitType.branch;
      case 'pos':
        return BusinessUnitType.pos;
      default:
        return null;
    }
  }

  /// Récupère le profil utilisateur depuis le backend
  ///
  /// Utile pour rafraîchir les données business (companyId, businessUnitId, etc.)
  /// sans refaire une authentification complète.
  /// Met également à jour le BusinessContextService.
  Future<User?> refreshUserFromBackend() async {
    try {
      final currentUser = await offlineAuthService.getLastLoggedInUser();
      if (currentUser == null) {
        debugPrint("Auth0Service: No current user to refresh");
        return null;
      }

      final authMeResponse = await _authBackendService.fetchAuthMe();
      if (authMeResponse != null) {
        final backendProfile = authMeResponse.user;
        final businessUnit = authMeResponse.businessUnit;

        // Mettre à jour le BusinessContextService
        await _businessContextService.updateFromAuthMeResponse(authMeResponse);
        debugPrint(
          "Auth0Service: BusinessContextService updated during refresh",
        );

        // Note: company.name vient de l'objet company séparé, pas de user
        final companyName =
            authMeResponse.company?.name ?? backendProfile.companyName;
        final enrichedUser = currentUser.copyWith(
          companyId: backendProfile.companyId,
          companyName: companyName,
          rccmNumber: backendProfile.rccmNumber,
          companyLocation: backendProfile.companyLocation,
          businessSector: backendProfile.businessSector,
          businessSectorId: backendProfile.businessSectorId,
          businessAddress: backendProfile.businessAddress,
          businessLogoUrl: backendProfile.businessLogoUrl,
          // Business Unit fields
          businessUnitId: backendProfile.businessUnitId ?? businessUnit?.id,
          businessUnitCode: businessUnit?.code,
          businessUnitType:
              backendProfile.businessUnitType != null
                  ? _parseBusinessUnitType(backendProfile.businessUnitType)
                  : businessUnit?.type != null
                  ? _parseBusinessUnitType(businessUnit!.type)
                  : null,
          isActive: backendProfile.isActive,
        );

        await offlineAuthService.saveUserForOfflineLogin(enrichedUser);
        debugPrint(
          "Auth0Service: User refreshed from backend. CompanyId: ${enrichedUser.companyId}, BusinessUnitId: ${enrichedUser.businessUnitId}",
        );
        return enrichedUser;
      }

      return currentUser;
    } catch (e) {
      debugPrint("Auth0Service: Error refreshing user from backend: $e");
      return await offlineAuthService.getLastLoggedInUser();
    }
  }

  Future<String?> getIdToken() async {
    if (await isDemoUserActive()) {
      return await _secureStorage.read(key: _idTokenKey);
    }
    try {
      if (await auth0.credentialsManager.hasValidCredentials()) {
        final credentials = await auth0.credentialsManager.credentials();
        return credentials.idToken;
      }
    } on CredentialsManagerException catch (e) {
      debugPrint(
        'CredentialsManagerException getting id token: ${e.message}. Details: ${e.details}.',
      );
    }
    return null;
  }

  /// Sends a password reset email using Auth0's API
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('Auth0Service: Sending password reset email to $email');
      await auth0.api.resetPassword(
        email: email,
        connection:
            'Username-Password-Authentication', // This is typically the default connection
      );
      debugPrint('Auth0Service: Password reset email sent successfully');
    } on ApiException catch (e) {
      debugPrint(
        'ApiException during password reset: Status: ${e.statusCode}. Details: ${e.toString()}',
      );
      rethrow;
    } catch (e) {
      debugPrint('Generic error during password reset: $e');
      rethrow;
    }
  }
}

// Assuming IdStatus enum exists, e.g.:
// enum IdStatus { NOT_UPLOADED, PENDING, VERIFIED, REJECTED }
// User model needs to be compatible with UserProfile fields (e.g. emailVerified, phoneVerified)
