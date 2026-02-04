import 'package:flutter/foundation.dart';
import '../../features/auth/services/auth0_service.dart';
import 'api_client.dart';
import 'logging_service.dart';
import 'error_handling_service.dart';
import 'reauth_service.dart';

/// Service d'initialisation de l'application pour la production
class AppInitializationService {
  static AppInitializationService? _instance;
  bool _isInitialized = false;
  
  static AppInitializationService get instance {
    _instance ??= AppInitializationService._internal();
    return _instance!;
  }

  AppInitializationService._internal();

  /// Initialise tous les services de l'application
  Future<void> initialize({
    Auth0Service? auth0Service,
    bool enableErrorReporting = true,
    bool enablePerformanceMonitoring = true,
  }) async {
    if (_isInitialized) {
      debugPrint('App already initialized');
      return;
    }

    try {
      debugPrint('Starting app initialization...');
      final startTime = DateTime.now();

      // 1. Initialiser le service de logging en premier
      await _initializeLogging();

      final logger = LoggingService.instance;
      logger.info('Starting application initialization');

      // 2. Initialiser la gestion d'erreurs globale
      await _initializeErrorHandling(enableErrorReporting);

      // 3. Initialiser les services d'authentification
      await _initializeAuthServices(auth0Service);

      // 4. Initialiser l'API client
      _initializeApiClient(auth0Service);

      // 5. Nettoyer les anciens logs
      await _cleanupOldData();

      // 6. Vérifier la santé de l'application
      await _performHealthCheck();

      final duration = DateTime.now().difference(startTime);
      logger.performance('app_initialization', duration);
      logger.info('Application initialization completed successfully');

      _isInitialized = true;
      debugPrint('App initialization completed in ${duration.inMilliseconds}ms');

    } catch (e, stackTrace) {
      debugPrint('Failed to initialize application: $e');
      
      // Même si l'initialisation échoue partiellement, on peut continuer
      // mais on log l'erreur
      if (LoggingService.instance.isInitialized) {
        LoggingService.instance.critical(
          'Application initialization failed',
          error: e,
          stackTrace: stackTrace,
        );
      }
      
      // En production, on peut vouloir afficher une erreur à l'utilisateur
      // ou envoyer un rapport d'erreur
      if (kReleaseMode) {
        // TODO: Envoyer le rapport d'erreur au service de monitoring
      }
      
      rethrow;
    }
  }

  /// Initialise le service de logging
  Future<void> _initializeLogging() async {
    await LoggingService.instance.initialize();
    debugPrint('✓ Logging service initialized');
  }

  /// Initialise la gestion d'erreurs globale
  Future<void> _initializeErrorHandling(bool enableErrorReporting) async {
    final errorHandler = ErrorHandlingService.instance;
    errorHandler.initialize();

    if (enableErrorReporting) {
      // Ajouter des gestionnaires d'erreurs personnalisés pour la production
      errorHandler.addApiErrorHandler((error) {
        _handleProductionApiError(error);
      });

      errorHandler.addGlobalErrorHandler((error, stack) {
        _handleProductionGlobalError(error, stack);
      });
    }

    debugPrint('✓ Error handling service initialized');
  }

  /// Initialise les services d'authentification
  Future<void> _initializeAuthServices(Auth0Service? auth0Service) async {
    if (auth0Service != null) {
      // Configurer le service de ré-authentification
      ReauthService.instance.configure(auth0Service);
      
      // Ajouter des callbacks pour les événements d'authentification
      ReauthService.instance.onAuthenticationRequired(() {
        LoggingService.instance.warning('Authentication required - redirecting to login');
      });

      ReauthService.instance.onAuthenticationSuccess(() {
        LoggingService.instance.info('Re-authentication successful');
      });

      ReauthService.instance.onAuthenticationFailure(() {
        LoggingService.instance.error('Re-authentication failed');
      });
    }

    debugPrint('✓ Auth services initialized');
  }

  /// Initialise l'API client
  void _initializeApiClient(Auth0Service? auth0Service) {
    ApiClient.configure(auth0Service: auth0Service);
    debugPrint('✓ API client configured');
  }

  /// Nettoie les anciennes données
  Future<void> _cleanupOldData() async {
    try {
      // Nettoyer les anciens logs
      await LoggingService.instance.cleanOldLogs(maxDays: 7);
      
      // TODO: Ajouter d'autres tâches de nettoyage si nécessaire
      // - Cache des images
      // - Données temporaires
      // - Fichiers d'export anciens
      
      debugPrint('✓ Old data cleanup completed');
    } catch (e) {
      LoggingService.instance.warning('Failed to cleanup old data', error: e);
    }
  }

  /// Vérifie la santé de l'application
  Future<void> _performHealthCheck() async {
    try {
      final healthStatus = await ErrorHandlingService.instance.checkApplicationHealth();
      
      if (healthStatus.isHealthy) {
        LoggingService.instance.info('Application health check passed');
      } else {
        LoggingService.instance.warning(
          'Application health check failed',
          context: {
            'issues': healthStatus.issues,
            'checks': healthStatus.checks,
          },
        );
      }
      
      debugPrint('✓ Health check completed');
    } catch (e) {
      LoggingService.instance.error('Health check failed', error: e);
    }
  }

  /// Gère les erreurs API en production
  void _handleProductionApiError(dynamic error) {
    // En production, on peut vouloir :
    // - Envoyer les erreurs à un service de monitoring (Sentry, Firebase Crashlytics)
    // - Afficher des messages d'erreur appropriés à l'utilisateur
    // - Collecter des métriques d'erreurs
    
    if (kReleaseMode) {
      // TODO: Intégrer avec un service de monitoring
      // Example: Sentry.captureException(error);
    }
  }

  /// Gère les erreurs globales en production
  void _handleProductionGlobalError(Object error, StackTrace stack) {
    // En production, on peut vouloir :
    // - Envoyer les erreurs critiques à un service de monitoring
    // - Sauvegarder l'état de l'application avant le crash
    // - Afficher un écran d'erreur approprié
    
    if (kReleaseMode) {
      // TODO: Intégrer avec un service de monitoring
      // Example: Sentry.captureException(error, stackTrace: stack);
    }
  }

  /// Vérifie si l'application est initialisée
  bool get isInitialized => _isInitialized;

  /// Réinitialise l'application (pour les tests)
  @visibleForTesting
  void reset() {
    _isInitialized = false;
    _instance = null;
  }

  /// Nettoie les ressources avant la fermeture de l'application
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      LoggingService.instance.info('Starting application shutdown');

      // Nettoyer les services dans l'ordre inverse de l'initialisation
      ErrorHandlingService.instance.dispose();
      ReauthService.instance.dispose();
      
      // Sauvegarder les logs finaux si nécessaire
      await LoggingService.instance.exportLogs();
      
      LoggingService.instance.info('Application shutdown completed');
      
      _isInitialized = false;
    } catch (e) {
      debugPrint('Error during app disposal: $e');
    }
  }
}

/// Extension pour faciliter l'initialisation dans main()
extension AppInitialization on void {
  /// Initialise l'application avec configuration par défaut
  static Future<void> initializeApp({
    Auth0Service? auth0Service,
    bool enableErrorReporting = true,
    bool enablePerformanceMonitoring = true,
  }) async {
    await AppInitializationService.instance.initialize(
      auth0Service: auth0Service,
      enableErrorReporting: enableErrorReporting,
      enablePerformanceMonitoring: enablePerformanceMonitoring,
    );
  }
}
