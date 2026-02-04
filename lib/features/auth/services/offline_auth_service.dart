// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\auth\services\offline_auth_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/connectivity_service.dart';
import 'jwt_offline_validator.dart';

/// Service pour gérer l'authentification en mode hors ligne
class OfflineAuthService {
  static const String _lastUserKey = 'lastLoggedInUser';
  static const String _offlineLoginEnabledKey = 'offlineLoginEnabled';
  static const String _cachedIdTokenKey = 'cached_id_token';
  static const String _cachedAccessTokenKey = 'cached_access_token';
  static const String _tokenExpiryKey = 'token_expiry_timestamp';

  final FlutterSecureStorage _secureStorage;
  final DatabaseService _databaseService;
  final JwtOfflineValidator _jwtValidator = JwtOfflineValidator();

  /// Constructeur
  OfflineAuthService({
    required FlutterSecureStorage secureStorage,
    required DatabaseService databaseService,
    required ConnectivityService connectivityService,
  }) : _secureStorage = secureStorage,
       _databaseService = databaseService;

  /// Initialise le validateur JWT pour la validation offline
  Future<void> initialize() async {
    try {
      await _jwtValidator.initialize();
      debugPrint('OfflineAuthService: JWT validator initialized');
    } catch (e) {
      debugPrint('OfflineAuthService: Failed to initialize JWT validator: $e');
    }
  }

  /// Vérifie si l'authentification hors ligne est activée
  Future<bool> isOfflineLoginEnabled() async {
    final value = await _secureStorage.read(key: _offlineLoginEnabledKey);
    return value == 'true';
  }

  /// Active ou désactive l'authentification hors ligne
  Future<void> setOfflineLoginEnabled(bool enabled) async {
    await _secureStorage.write(
      key: _offlineLoginEnabledKey,
      value: enabled.toString(),
    );
  }

  /// Sauvegarde les tokens pour utilisation offline
  Future<void> cacheTokensForOffline({
    required String? idToken,
    required String? accessToken,
    DateTime? expiresAt,
  }) async {
    try {
      if (idToken != null) {
        await _secureStorage.write(key: _cachedIdTokenKey, value: idToken);
      }
      if (accessToken != null) {
        await _secureStorage.write(
          key: _cachedAccessTokenKey,
          value: accessToken,
        );
      }
      if (expiresAt != null) {
        await _secureStorage.write(
          key: _tokenExpiryKey,
          value: expiresAt.millisecondsSinceEpoch.toString(),
        );
      }
      debugPrint('OfflineAuthService: Tokens cached for offline use');
    } catch (e) {
      debugPrint('OfflineAuthService: Error caching tokens: $e');
    }
  }

  /// Récupère le token ID mis en cache
  Future<String?> getCachedIdToken() async {
    return await _secureStorage.read(key: _cachedIdTokenKey);
  }

  /// Récupère le token d'accès mis en cache
  Future<String?> getCachedAccessToken() async {
    return await _secureStorage.read(key: _cachedAccessTokenKey);
  }

  /// Vérifie si les tokens en cache sont encore valides
  Future<bool> hasValidCachedTokens() async {
    final idToken = await getCachedIdToken();
    if (idToken == null) return false;

    // Valider le token avec JWKS local
    final validationResult = await _jwtValidator.validateToken(idToken);

    if (validationResult.isValid) {
      debugPrint(
        'OfflineAuthService: Cached tokens are valid (offline validation)',
      );
      return true;
    }

    debugPrint(
      'OfflineAuthService: Cached tokens validation failed: ${validationResult.error}',
    );
    return false;
  }

  /// Vérifie si on peut utiliser l'authentification offline
  /// Conditions:
  /// 1. Offline login activé
  /// 2. Utilisateur sauvegardé
  /// 3. Tokens valides (validés localement avec JWKS)
  Future<OfflineAuthStatus> checkOfflineAuthStatus() async {
    final isEnabled = await isOfflineLoginEnabled();
    if (!isEnabled) {
      return OfflineAuthStatus(
        canAuthenticate: false,
        reason: 'Offline login not enabled',
      );
    }

    final user = await getLastLoggedInUser();
    if (user == null) {
      return OfflineAuthStatus(
        canAuthenticate: false,
        reason: 'No user data cached',
      );
    }

    // Vérifier les tokens avec validation JWKS locale
    final hasValidTokens = await hasValidCachedTokens();
    if (!hasValidTokens) {
      // Token expiré ou invalide, mais on peut quand même permettre
      // l'accès offline avec les données utilisateur en cache
      // L'utilisateur devra se reconnecter quand internet sera disponible
      final idToken = await getCachedIdToken();
      if (idToken != null) {
        final expiry = _jwtValidator.getTokenExpiration(idToken);
        return OfflineAuthStatus(
          canAuthenticate: true,
          user: user,
          tokenExpired: true,
          tokenExpiry: expiry,
          reason:
              'Token expired but offline access granted with cached user data',
        );
      }

      return OfflineAuthStatus(
        canAuthenticate: false,
        reason: 'No valid tokens available',
      );
    }

    return OfflineAuthStatus(
      canAuthenticate: true,
      user: user,
      tokenExpired: false,
      reason: 'Valid offline authentication',
    );
  }

  /// Sauvegarde les informations de l'utilisateur pour l'authentification hors ligne
  Future<void> saveUserForOfflineLogin(User user) async {
    try {
      // Enregistrer l'utilisateur dans le stockage sécurisé
      await _secureStorage.write(
        key: _lastUserKey,
        value: jsonEncode(user.toJson()),
      );

      // Activer automatiquement l'authentification offline
      await setOfflineLoginEnabled(true);

      debugPrint(
        'OfflineAuthService: User saved for offline login: ${user.email}',
      );
    } catch (e) {
      debugPrint('OfflineAuthService: Error saving user for offline login: $e');
    }
  }

  /// Récupère l'utilisateur sauvegardé pour l'authentification hors ligne
  Future<User?> getLastLoggedInUser() async {
    try {
      final userData = await _secureStorage.read(key: _lastUserKey);

      if (userData != null) {
        final userJson = jsonDecode(userData) as Map<String, dynamic>;
        return User.fromJson(userJson);
      }
    } catch (e) {
      debugPrint('OfflineAuthService: Error getting offline user: $e');
    }

    return null;
  }

  /// Supprime les informations de l'utilisateur pour l'authentification hors ligne
  Future<void> clearOfflineData() async {
    await _secureStorage.delete(key: _lastUserKey);
    await _secureStorage.delete(key: _cachedIdTokenKey);
    await _secureStorage.delete(key: _cachedAccessTokenKey);
    await _secureStorage.delete(key: _tokenExpiryKey);
    debugPrint("OfflineAuthService: Cleared all offline data");
  }

  /// Vérifie si l'utilisateur peut se connecter en mode hors ligne
  Future<bool> canLoginOffline() async {
    final status = await checkOfflineAuthStatus();
    return status.canAuthenticate;
  }

  /// Met à jour le cache des données utilisateur
  Future<void> updateUserDataCache(
    User user,
    Map<String, dynamic> userData,
  ) async {
    try {
      final db = await _databaseService.database;

      // Stocker les données utilisateur dans la base de données locale
      await db.insert('user_data_cache', {
        'user_id': user.id,
        'data_type': 'profile',
        'data': jsonEncode(userData),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      debugPrint('OfflineAuthService: User data cached for ${user.id}');
    } catch (e) {
      debugPrint('OfflineAuthService: Error caching user data: $e');
    }
  }

  /// Récupère les données utilisateur mises en cache
  Future<Map<String, dynamic>?> getCachedUserData(String userId) async {
    try {
      final db = await _databaseService.database;

      final List<Map<String, dynamic>> results = await db.query(
        'user_data_cache',
        where: 'user_id = ? AND data_type = ?',
        whereArgs: [userId, 'profile'],
        orderBy: 'timestamp DESC',
        limit: 1,
      );

      if (results.isNotEmpty) {
        final cachedData = results.first;
        final dataStr = cachedData['data'] as String;
        return jsonDecode(dataStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('OfflineAuthService: Error getting cached user data: $e');
    }

    return null;
  }
}

/// Status de l'authentification offline
class OfflineAuthStatus {
  final bool canAuthenticate;
  final User? user;
  final bool tokenExpired;
  final DateTime? tokenExpiry;
  final String reason;

  OfflineAuthStatus({
    required this.canAuthenticate,
    this.user,
    this.tokenExpired = false,
    this.tokenExpiry,
    required this.reason,
  });

  @override
  String toString() {
    return 'OfflineAuthStatus(canAuthenticate: $canAuthenticate, tokenExpired: $tokenExpired, reason: $reason)';
  }
}
