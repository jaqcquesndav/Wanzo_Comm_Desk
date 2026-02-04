import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// Utilitaire pour valider les tokens JWT
class TokenValidator {
  /// Vérifie si un token JWT est valide
  static bool isTokenValid(String? token) {
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      // Vérifier si le token est expiré
      if (JwtDecoder.isExpired(token)) {
        debugPrint('TokenValidator: Token expiré');
        return false;
      }

      // Récupérer les claims du token
      final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

      // Vérifier l'audience du token (si présente)
      final audience = decodedToken['aud'];
      if (audience != null) {
        if (audience is List) {
          if (!audience.contains('https://api.wanzo.com')) {
            debugPrint('TokenValidator: Audience invalide (liste): $audience');
            return false;
          }
        } else if (audience is String && audience != 'https://api.wanzo.com') {
          debugPrint('TokenValidator: Audience invalide (string): $audience');
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('TokenValidator: Erreur lors de la validation du token: $e');
      return false;
    }
  }

  /// Décode un token JWT et retourne ses claims
  static Map<String, dynamic>? decodeToken(String? token) {
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      return JwtDecoder.decode(token);
    } catch (e) {
      debugPrint('TokenValidator: Erreur lors du décodage du token: $e');
      return null;
    }
  }

  /// Vérifie si un token JWT contient une permission spécifique
  static bool hasPermission(String? token, String permission) {
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      
      // Vérifier les permissions dans le token
      // Les permissions peuvent être stockées de différentes façons selon la configuration d'Auth0
      // Ici, nous vérifions plusieurs champs courants
      
      // Vérifier dans le champ 'permissions'
      final permissions = decodedToken['permissions'];
      if (permissions is List && permissions.contains(permission)) {
        return true;
      }

      // Vérifier dans le champ 'scope'
      final scope = decodedToken['scope'];
      if (scope is String && scope.split(' ').contains(permission)) {
        return true;
      }

      // Vérifier dans un namespace personnalisé (pratique courante avec Auth0)
      final customNamespace = decodedToken['https://wanzo.app/permissions'];
      if (customNamespace is List && customNamespace.contains(permission)) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('TokenValidator: Erreur lors de la vérification des permissions: $e');
      return false;
    }
  }

  /// Récupère la date d'expiration d'un token JWT
  static DateTime? getExpirationDate(String? token) {
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      return JwtDecoder.getExpirationDate(token);
    } catch (e) {
      debugPrint('TokenValidator: Erreur lors de la récupération de la date d\'expiration: $e');
      return null;
    }
  }

  /// Récupère la durée restante avant expiration d'un token JWT
  static Duration getRemainingTime(String? token) {
    if (token == null || token.isEmpty) {
      return Duration.zero;
    }

    try {
      final DateTime? expirationDate = getExpirationDate(token);
      if (expirationDate == null) {
        return Duration.zero;
      }

      final now = DateTime.now();
      if (expirationDate.isBefore(now)) {
        return Duration.zero;
      }

      return expirationDate.difference(now);
    } catch (e) {
      debugPrint('TokenValidator: Erreur lors du calcul de la durée restante: $e');
      return Duration.zero;
    }
  }
}
