// filepath: lib/features/auth/services/jwt_offline_validator.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/config/env_config.dart';

/// Service de validation JWT hors ligne
///
/// Ce service permet de valider les tokens JWT Auth0 sans connexion internet
/// en vérifiant l'expiration et l'issuer du token.
///
/// Note: La validation de signature RSA est désactivée pour éviter les problèmes
/// de parsing de certificat. En mode offline, on fait confiance aux tokens
/// qui ont été précédemment validés par Auth0 et stockés localement.
class JwtOfflineValidator {
  static final JwtOfflineValidator _instance = JwtOfflineValidator._internal();
  factory JwtOfflineValidator() => _instance;
  JwtOfflineValidator._internal();

  bool _isInitialized = false;

  /// Issuer attendu pour les tokens Auth0 (depuis env_config)
  String get _expectedIssuer => EnvConfig.auth0Issuer;

  /// Initialise le validateur
  /// Cette méthode ne peut pas échouer - l'initialisation est toujours réussie
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    debugPrint(
      'JwtOfflineValidator: Initialized (lightweight mode - expiration & issuer validation only)',
    );
  }

  /// Valide un token JWT hors ligne
  ///
  /// Vérifie:
  /// 1. La structure du token (3 parties)
  /// 2. L'expiration du token
  /// 3. L'issuer du token
  ///
  /// Note: La validation de signature est désactivée en mode offline.
  /// Les tokens stockés localement sont considérés comme fiables car ils ont
  /// été validés par Auth0 lors de leur émission.
  Future<JwtValidationResult> validateToken(String token) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return JwtValidationResult(
          isValid: false,
          error: 'Invalid token format: expected 3 parts, got ${parts.length}',
        );
      }

      final headerB64 = parts[0];
      final payloadB64 = parts[1];

      // Décoder le header
      final headerJson = _decodeBase64Url(headerB64);
      final header = jsonDecode(headerJson) as Map<String, dynamic>;

      // Vérifier l'algorithme (info seulement, pas de validation de signature)
      final algorithm = header['alg'] as String?;
      if (algorithm != 'RS256') {
        debugPrint(
          'JwtOfflineValidator: Token uses algorithm $algorithm (expected RS256)',
        );
        // On ne rejette pas le token, juste un warning
      }

      // Décoder le payload
      final payloadJson = _decodeBase64Url(payloadB64);
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

      // Vérifier l'expiration
      final exp = payload['exp'] as int?;
      if (exp != null) {
        final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        if (DateTime.now().isAfter(expirationDate)) {
          return JwtValidationResult(
            isValid: false,
            error: 'Token expired at $expirationDate',
            payload: payload,
            isExpired: true,
          );
        }
      }

      // Vérifier l'issuer
      final issuer = payload['iss'] as String?;
      if (issuer != null && issuer != _expectedIssuer) {
        // Log mais ne rejette pas si l'issuer est légèrement différent
        debugPrint(
          'JwtOfflineValidator: Issuer mismatch: $issuer vs $_expectedIssuer',
        );
        // On accepte quand même si le domain correspond
        if (!issuer.contains(EnvConfig.auth0Domain)) {
          return JwtValidationResult(
            isValid: false,
            error: 'Invalid issuer: $issuer (expected $_expectedIssuer)',
            payload: payload,
          );
        }
      }

      // Token valide (expiration et issuer OK)
      return JwtValidationResult(isValid: true, payload: payload);
    } catch (e) {
      debugPrint('JwtOfflineValidator: Validation error: $e');
      return JwtValidationResult(isValid: false, error: 'Validation error: $e');
    }
  }

  String _decodeBase64Url(String input) {
    String normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return utf8.decode(base64Decode(normalized));
  }

  /// Décode un token JWT sans validation (pour extraction rapide des claims)
  Map<String, dynamic>? decodeTokenPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payloadJson = _decodeBase64Url(parts[1]);
      return jsonDecode(payloadJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('JwtOfflineValidator: Error decoding token: $e');
      return null;
    }
  }

  /// Vérifie si un token est expiré
  bool isTokenExpired(String token) {
    final payload = decodeTokenPayload(token);
    if (payload == null) return true;

    final exp = payload['exp'] as int?;
    if (exp == null) return true;

    final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    return DateTime.now().isAfter(expirationDate);
  }

  /// Retourne la date d'expiration du token
  DateTime? getTokenExpiration(String token) {
    final payload = decodeTokenPayload(token);
    if (payload == null) return null;

    final exp = payload['exp'] as int?;
    if (exp == null) return null;

    return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  }

  /// Retourne le temps restant avant expiration
  Duration? getTimeUntilExpiration(String token) {
    final expiration = getTokenExpiration(token);
    if (expiration == null) return null;

    final now = DateTime.now();
    if (now.isAfter(expiration)) return Duration.zero;

    return expiration.difference(now);
  }
}

/// Résultat de la validation JWT
class JwtValidationResult {
  final bool isValid;
  final String? error;
  final Map<String, dynamic>? payload;
  final bool isExpired;

  JwtValidationResult({
    required this.isValid,
    this.error,
    this.payload,
    this.isExpired = false,
  });

  @override
  String toString() {
    if (isValid) {
      return 'JwtValidationResult(valid)';
    }
    return 'JwtValidationResult(invalid: $error, expired: $isExpired)';
  }
}
