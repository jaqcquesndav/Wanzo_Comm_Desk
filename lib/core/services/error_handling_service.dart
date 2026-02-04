import 'dart:async';
import 'package:flutter/foundation.dart';
import '../exceptions/api_exceptions.dart';
import 'logging_service.dart';
import 'reauth_service.dart';

/// Gestionnaire d'erreurs global pour l'application
class ErrorHandlingService {
  static ErrorHandlingService? _instance;
  final LoggingService _logger = LoggingService.instance;
  final ReauthService _reauthService = ReauthService.instance;
  
  // Callbacks pour les différents types d'erreurs
  final List<Function(ApiException)> _apiErrorHandlers = [];
  final List<Function(Object, StackTrace)> _globalErrorHandlers = [];
  
  static ErrorHandlingService get instance {
    _instance ??= ErrorHandlingService._internal();
    return _instance!;
  }

  ErrorHandlingService._internal();

  /// Initialise le gestionnaire d'erreurs global
  void initialize() {
    // Capturer les erreurs Flutter non gérées
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // Capturer les erreurs dans la zone non gérées
    PlatformDispatcher.instance.onError = (error, stack) {
      _handlePlatformError(error, stack);
      return true;
    };

    _logger.info('ErrorHandlingService initialized');
  }

  /// Ajoute un gestionnaire pour les erreurs API
  void addApiErrorHandler(Function(ApiException) handler) {
    _apiErrorHandlers.add(handler);
  }

  /// Ajoute un gestionnaire pour les erreurs globales
  void addGlobalErrorHandler(Function(Object, StackTrace) handler) {
    _globalErrorHandlers.add(handler);
  }

  /// Gère une erreur API de manière centralisée
  Future<void> handleApiError(ApiException error) async {
    _logger.apiError(error.endpoint ?? 'unknown', error);

    // Gestion spéciale pour les erreurs d'authentification
    if (error is AuthenticationException) {
      await _reauthService.handleAuthException(error);
    }

    // Appeler tous les gestionnaires enregistrés
    for (final handler in _apiErrorHandlers) {
      try {
        handler(error);
      } catch (e, stack) {
        _logger.error('Error in API error handler', error: e, stackTrace: stack);
      }
    }
  }

  /// Gère les erreurs Flutter
  void _handleFlutterError(FlutterErrorDetails details) {
    _logger.critical(
      'Flutter Error: ${details.summary}',
      error: details.exception,
      stackTrace: details.stack,
      context: {
        'library': details.library,
        'context': details.context?.toString(),
      },
    );

    // En mode debug, utiliser le gestionnaire par défaut de Flutter
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  }

  /// Gère les erreurs de plateforme
  bool _handlePlatformError(Object error, StackTrace stack) {
    _logger.critical(
      'Platform Error: ${error.toString()}',
      error: error,
      stackTrace: stack,
    );

    // Appeler tous les gestionnaires globaux
    for (final handler in _globalErrorHandlers) {
      try {
        handler(error, stack);
      } catch (e, s) {
        _logger.error('Error in global error handler', error: e, stackTrace: s);
      }
    }

    return true;
  }

  /// Exécute une fonction avec gestion d'erreurs
  Future<T?> executeWithErrorHandling<T>(
    Future<T> Function() operation, {
    String? operationName,
    Map<String, dynamic>? context,
    T? defaultValue,
    bool rethrowApiErrors = true,
  }) async {
    final startTime = DateTime.now();
    
    try {
      _logger.debug('Starting operation: ${operationName ?? 'unknown'}', context: context);
      
      final result = await operation();
      
      final duration = DateTime.now().difference(startTime);
      _logger.performance(operationName ?? 'operation', duration, context: context);
      
      return result;
    } on ApiException catch (e) {
      await handleApiError(e);
      
      if (rethrowApiErrors) {
        rethrow;
      } else {
        return defaultValue;
      }
    } catch (e, stack) {
      _logger.error(
        'Unexpected error in operation: ${operationName ?? 'unknown'}',
        error: e,
        stackTrace: stack,
        context: context,
      );
      
      // Appeler les gestionnaires globaux
      for (final handler in _globalErrorHandlers) {
        try {
          handler(e, stack);
        } catch (handlerError, handlerStack) {
          _logger.error('Error in global error handler', 
                       error: handlerError, stackTrace: handlerStack);
        }
      }
      
      return defaultValue;
    }
  }

  /// Crée un wrapper pour les fonctions avec gestion d'erreurs automatique
  Function wrapWithErrorHandling(
    Function originalFunction, {
    String? operationName,
    Map<String, dynamic>? context,
  }) {
    return (args) async {
      return executeWithErrorHandling(
        () async => await originalFunction(args),
        operationName: operationName,
        context: context,
      );
    };
  }

  /// Vérifie la santé de l'application
  Future<ApplicationHealthStatus> checkApplicationHealth() async {
    final healthChecks = <String, bool>{};
    final issues = <String>[];

    try {
      // Vérifier l'état du logging
      healthChecks['logging'] = _logger.isInitialized;
      if (!_logger.isInitialized) {
        issues.add('Logging service not initialized');
      }

      // Vérifier l'état de la ré-authentification
      final tokenValid = await _reauthService.isTokenValid();
      healthChecks['authentication'] = tokenValid;
      if (!tokenValid) {
        issues.add('Authentication token invalid or missing');
      }

      // Vérifier la connectivité réseau (si possible)
      // TODO: Ajouter une vérification de connectivité réseau

      final isHealthy = issues.isEmpty;
      
      _logger.info('Application health check completed', context: {
        'healthy': isHealthy,
        'checks': healthChecks,
        'issues': issues,
      });

      return ApplicationHealthStatus(
        isHealthy: isHealthy,
        checks: healthChecks,
        issues: issues,
        timestamp: DateTime.now(),
      );
    } catch (e, stack) {
      _logger.error('Error during health check', error: e, stackTrace: stack);
      
      return ApplicationHealthStatus(
        isHealthy: false,
        checks: {'health_check': false},
        issues: ['Health check failed: ${e.toString()}'],
        timestamp: DateTime.now(),
      );
    }
  }

  /// Nettoie les ressources
  void dispose() {
    _apiErrorHandlers.clear();
    _globalErrorHandlers.clear();
  }
}

/// Statut de santé de l'application
class ApplicationHealthStatus {
  final bool isHealthy;
  final Map<String, bool> checks;
  final List<String> issues;
  final DateTime timestamp;

  ApplicationHealthStatus({
    required this.isHealthy,
    required this.checks,
    required this.issues,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'isHealthy': isHealthy,
      'checks': checks,
      'issues': issues,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Extension pour faciliter l'utilisation de la gestion d'erreurs
extension ErrorHandlingExtension on Future {
  /// Ajoute une gestion d'erreurs automatique à un Future
  Future<T?> withErrorHandling<T>({
    String? operationName,
    Map<String, dynamic>? context,
    T? defaultValue,
    bool rethrowApiErrors = true,
  }) {
    return ErrorHandlingService.instance.executeWithErrorHandling<T>(
      () async => await this as T,
      operationName: operationName,
      context: context,
      defaultValue: defaultValue,
      rethrowApiErrors: rethrowApiErrors,
    );
  }
}
