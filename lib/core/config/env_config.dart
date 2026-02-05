import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration des variables d'environnement pour l'application Wanzo
/// Cette classe centralise toutes les URLs et configurations pour les différents environnements
class EnvConfig {
  /// URL de l'API Gateway, point d'entrée principal pour toutes les requêtes
  static String get apiGatewayUrl =>
      dotenv.env['API_GATEWAY_URL'] ?? 'http://localhost:8000';

  /// Adresse IP pour le développement sur appareils physiques
  static String get devIpAddress =>
      dotenv.env['DEV_IP_ADDRESS'] ?? '192.168.1.65';

  /// URLs des services directs (à utiliser uniquement si nécessaire)
  static String get authServiceUrl =>
      dotenv.env['AUTH_SERVICE_URL'] ?? 'http://$devIpAddress:3000/api';
  static String get appMobileServiceUrl =>
      dotenv.env['APP_MOBILE_SERVICE_URL'] ?? 'http://$devIpAddress:3006/api';
  static String get adminServiceUrl =>
      dotenv.env['ADMIN_SERVICE_URL'] ?? 'http://$devIpAddress:3001/api';

  /// Configuration Auth0
  static String get auth0Domain =>
      dotenv.env['AUTH0_DOMAIN'] ?? 'dev-tezmln0tk0g1gouf.eu.auth0.com';
  static String get auth0ClientId =>
      dotenv.env['AUTH0_CLIENT_ID'] ?? '43d64kgsVYyCZHEFsax7zlRBVUiraCKL';
  static String get auth0Audience =>
      dotenv.env['AUTH0_AUDIENCE'] ?? 'https://api.wanzo.com';
  static String get auth0RedirectUri =>
      dotenv.env['AUTH0_REDIRECT_URI'] ?? 'com.wanzo.app://login-callback';
  static String get auth0LogoutUri =>
      dotenv.env['AUTH0_LOGOUT_URI'] ?? 'com.wanzo.app://logout-callback';
  static String get auth0Scheme =>
      dotenv.env['AUTH0_SCHEME'] ?? 'com.example.wanzo'; // Added

  /// Certificat JWKS Auth0 pour validation JWT offline (Base64, sans BEGIN/END CERTIFICATE)
  static String? get auth0JwksCertificate =>
      dotenv.env['AUTH0_JWKS_CERTIFICATE'];

  /// Issuer attendu pour les tokens Auth0
  static String get auth0Issuer => 'https://$auth0Domain/';

  /// Préfixe API pour le commerce service
  static const String commerceApiPrefix = 'commerce/api/v1';

  /// Retourne l'URL de base complète avec le préfixe commerce
  /// Cette URL inclut déjà /commerce/api/v1, les endpoints ne doivent pas le répéter
  static String get commerceBaseUrl => '$apiGatewayUrl/$commerceApiPrefix';

  /// Retourne l'URL appropriée selon l'environnement (dev, staging, prod)
  static String getBaseUrl({bool useApiGateway = true}) {
    // Par défaut, utiliser l'API Gateway comme point d'entrée
    if (useApiGateway) {
      return apiGatewayUrl;
    }

    // Sinon, retourner l'URL du service demandé
    return authServiceUrl;
  }

  /// Remplace localhost par l'adresse IP pour les appareils physiques
  static String getDeviceCompatibleUrl(String url) {
    // Si nous sommes en mode développement sur un appareil physique,
    // il faut remplacer localhost par l'adresse IP de la machine de développement
    final devIpAddress = dotenv.env['DEV_IP_ADDRESS'];

    // Si l'adresse IP est configurée et que l'URL contient localhost
    if (devIpAddress != null &&
        devIpAddress.isNotEmpty &&
        url.contains('localhost')) {
      return url.replaceAll('localhost', devIpAddress);
    }

    // Pour le déploiement en production, assurez-vous que l'URL est absolue et sans localhost
    // Si l'URL contient toujours localhost mais qu'aucune adresse IP n'est configurée,
    // c'est probablement une erreur de configuration
    if (url.contains('localhost')) {
      debugPrint(
        'ATTENTION: URL avec "localhost" utilisée sur un appareil mobile: $url',
      );
      debugPrint(
        'Définissez DEV_IP_ADDRESS dans votre fichier .env ou utilisez une URL absolue.',
      );
    }

    return url;
  }
}
