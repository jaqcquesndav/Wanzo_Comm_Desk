import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../config/environment.dart';

/// Constantes de configuration pour l'application
class AppConfig {
  /// Configuration Auth0 - utilise les variables d'environnement
  static String get auth0Domain =>
      dotenv.env['AUTH0_DOMAIN'] ?? 'dev-wanzo.us.auth0.com';
  static String get auth0ClientId =>
      dotenv.env['AUTH0_CLIENT_ID'] ?? 'Xm7YJXs0LGX5iG1KLR8wPlmK8gnjVrns';
  static String get auth0RedirectUri =>
      dotenv.env['AUTH0_REDIRECT_URI'] ?? 'com.wanzo.app://login-callback';

  /// URL de l'API - utilise la configuration d'environnement
  static String get apiBaseUrl => Environment.baseUrl;

  /// Délai d'attente pour les requêtes API
  static const int apiTimeoutSeconds = 30;

  /// Version de l'application
  static const String appVersion = '1.0.0';

  /// Mode de développement (true pour développement, false pour production)
  static const bool devMode = true;
}
