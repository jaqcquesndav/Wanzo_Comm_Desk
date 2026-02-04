/// Exceptions personnalisées pour l'API client
/// Provides more robust error handling with specific exception types
library;

/// Exception de base pour toutes les erreurs API
abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic responseBody;
  final String? endpoint;
  final DateTime timestamp;

  ApiException(
    this.message, {
    this.statusCode,
    this.responseBody,
    this.endpoint,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('$runtimeType: $message');
    if (statusCode != null) {
      buffer.write(' (Status Code: $statusCode)');
    }
    if (endpoint != null) {
      buffer.write(' [Endpoint: $endpoint]');
    }
    return buffer.toString();
  }

  /// Retourne true si l'erreur est récupérable (peut être retentée)
  bool get isRetryable => false;

  /// Retourne true si l'erreur nécessite une ré-authentification
  bool get requiresReauth => false;
}

/// Exception pour les erreurs réseau (connectivité, timeout, etc.)
class NetworkException extends ApiException {
  NetworkException(
    super.message, {
    super.endpoint,
    super.responseBody,
  });

  @override
  bool get isRetryable => true;
}

/// Exception pour les erreurs d'authentification (401)
class AuthenticationException extends ApiException {
  AuthenticationException(
    super.message, {
    super.endpoint,
    super.responseBody,
  }) : super(statusCode: 401);

  @override
  bool get requiresReauth => true;
}

/// Exception pour les erreurs d'autorisation (403)
class AuthorizationException extends ApiException {
  AuthorizationException(
    super.message, {
    super.endpoint,
    super.responseBody,
  }) : super(statusCode: 403);
}

/// Exception pour les requêtes malformées (400)
class BadRequestException extends ApiException {
  final Map<String, dynamic>? validationErrors;

  BadRequestException(
    super.message, {
    super.endpoint,
    super.responseBody,
    this.validationErrors,
  }) : super(statusCode: 400);
}

/// Exception pour les ressources non trouvées (404)
class NotFoundException extends ApiException {
  NotFoundException(
    super.message, {
    super.endpoint,
    super.responseBody,
  }) : super(statusCode: 404);
}

/// Exception pour les erreurs serveur (5xx)
class ServerException extends ApiException {
  ServerException(
    super.message, {
    super.statusCode,
    super.endpoint,
    super.responseBody,
  });

  @override
  bool get isRetryable => true;
}

/// Exception pour les erreurs de limite de taux (429)
class RateLimitException extends ApiException {
  final Duration? retryAfter;

  RateLimitException(
    super.message, {
    super.endpoint,
    super.responseBody,
    this.retryAfter,
  }) : super(statusCode: 429);

  @override
  bool get isRetryable => true;
}

/// Exception pour les erreurs de format de réponse
class ResponseFormatException extends ApiException {
  ResponseFormatException(
    super.message, {
    super.endpoint,
    super.responseBody,
  });
}

/// Exception pour les timeouts
class TimeoutException extends ApiException {
  final Duration timeout;

  TimeoutException(
    super.message, {
    required this.timeout,
    super.endpoint,
  });

  @override
  bool get isRetryable => true;
}

/// Utilitaire pour créer des exceptions spécifiques basées sur le code de statut
class ApiExceptionFactory {
  static ApiException fromStatusCode(
    int statusCode,
    String message, {
    String? endpoint,
    dynamic responseBody,
  }) {
    switch (statusCode) {
      case 400:
        return BadRequestException(
          message,
          endpoint: endpoint,
          responseBody: responseBody,
        );
      case 401:
        return AuthenticationException(
          message,
          endpoint: endpoint,
          responseBody: responseBody,
        );
      case 403:
        return AuthorizationException(
          message,
          endpoint: endpoint,
          responseBody: responseBody,
        );
      case 404:
        return NotFoundException(
          message,
          endpoint: endpoint,
          responseBody: responseBody,
        );
      case 429:
        return RateLimitException(
          message,
          endpoint: endpoint,
          responseBody: responseBody,
        );
      default:
        if (statusCode >= 500 && statusCode < 600) {
          return ServerException(
            message,
            statusCode: statusCode,
            endpoint: endpoint,
            responseBody: responseBody,
          );
        }
        return ServerException(
          message,
          statusCode: statusCode,
          endpoint: endpoint,
          responseBody: responseBody,
        );
    }
  }

  /// Extrait les erreurs de validation depuis une réponse 400
  static Map<String, dynamic>? extractValidationErrors(dynamic responseBody) {
    if (responseBody is Map<String, dynamic>) {
      if (responseBody.containsKey('errors')) {
        return responseBody['errors'] as Map<String, dynamic>?;
      }
      if (responseBody.containsKey('validation_errors')) {
        return responseBody['validation_errors'] as Map<String, dynamic>?;
      }
      if (responseBody.containsKey('fields')) {
        return responseBody['fields'] as Map<String, dynamic>?;
      }
    }
    return null;
  }

  /// Extrait le temps d'attente depuis un header Retry-After
  static Duration? extractRetryAfter(Map<String, String> headers) {
    final retryAfterHeader = headers['retry-after'] ?? headers['Retry-After'];
    if (retryAfterHeader != null) {
      final seconds = int.tryParse(retryAfterHeader);
      if (seconds != null) {
        return Duration(seconds: seconds);
      }
    }
    return null;
  }
}
