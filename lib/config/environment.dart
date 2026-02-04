// lib/config/environment.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// DEPRECATED: Utiliser EnvConfig à la place pour toutes les nouvelles implémentations
/// Cette classe reste pour compatibilité avec l'ancien code
class Environment {
  static const String DEV = 'dev';
  static const String STAGING = 'staging';
  static const String PROD = 'prod';

  static const String currentEnvironment = DEV;

  /// Utilise maintenant les variables d'environnement depuis .env
  static String get baseUrl {
    // Lire depuis .env en priorité
    final apiGatewayUrl = dotenv.env['API_GATEWAY_URL'];
    if (apiGatewayUrl != null && apiGatewayUrl.isNotEmpty) {
      return apiGatewayUrl;
    }

    // Fallback sur l'ancienne logique si .env n'est pas chargé
    switch (currentEnvironment) {
      case DEV:
        return "http://192.168.1.65:8000";
      case STAGING:
        return "https://api-staging.wanzzo.com";
      case PROD:
        return "https://api.wanzzo.com";
      default:
        return "http://192.168.1.65:8000";
    }
  }

  /// URL de base pour l'API Commerce (gestion commerciale)
  static String get commerceApiBaseUrl {
    final commerceUrl = dotenv.env['COMMERCE_API_URL'];
    if (commerceUrl != null && commerceUrl.isNotEmpty) {
      return commerceUrl;
    }
    // Fallback: utiliser le baseUrl avec le préfixe commerce
    return '$baseUrl/commerce/api/v1';
  }
}
