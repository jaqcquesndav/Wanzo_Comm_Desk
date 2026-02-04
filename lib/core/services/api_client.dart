import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env_config.dart'; // Import pour la configuration d'environnement
import '../../features/auth/services/auth0_service.dart'; // Import pour le service Auth0
import '../exceptions/api_exceptions.dart'; // Import des exceptions personnalisées
import 'reauth_service.dart'; // Import du service de ré-authentification
import 'api_circuit_breaker.dart'; // Import du circuit breaker

class ApiClient {
  final String _baseUrl;
  final http.Client _httpClient;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Auth0Service? _auth0Service;
  final ReauthService _reauthService = ReauthService.instance;
  final ApiCircuitBreaker _circuitBreaker = ApiCircuitBreaker.instance;

  // Timeouts recommandés par le backend
  static const int connectTimeoutMs = 10000; // 10 secondes
  static const int receiveTimeoutMs = 15000; // 15 secondes
  static const int adhaTimeoutMs =
      120000; // 120 secondes pour ADHA (AI peut prendre du temps)

  // Public getter for baseUrl
  String get baseUrl => _baseUrl;

  // Private constructor
  ApiClient._internal({
    http.Client? httpClient,
    Auth0Service? auth0Service,
    bool useApiGateway = true, // Default to use API Gateway
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrl = EnvConfig.getBaseUrl(useApiGateway: useApiGateway);

  // Singleton instance with Auth0Service
  static final ApiClient _instance = ApiClient._internal(
    auth0Service: null, // This will be set in configure method
    useApiGateway: true,
  );

  // Configure the instance with Auth0Service
  static void configure({Auth0Service? auth0Service}) {
    _instance._auth0Service = auth0Service;
    if (auth0Service != null) {
      _instance._reauthService.configure(auth0Service);
    }
  }

  // Factory constructor to return the singleton instance
  factory ApiClient() => _instance;
  Future<Map<String, String>> getHeaders({bool requiresAuth = false}) async {
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
      HttpHeaders.acceptHeader: 'application/json',
    };

    if (requiresAuth) {
      if (_auth0Service != null) {
        // Utiliser Auth0Service pour obtenir le token d'accès (recommandé)
        final String? token = await _auth0Service?.getAccessToken();
        if (token != null) {
          headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
        }
      } else {
        // Fallback à la méthode précédente
        String? token = await _secureStorage.read(key: 'auth_token');
        headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Méthode privée pour nettoyer l'endpoint (enlever les slashes en début/fin)
  String _cleanEndpoint(String endpoint) {
    // Supprimer les slashes au début et à la fin
    return endpoint.trim().replaceAll(RegExp(r'^/+|/+$'), '');
  }

  // ============= LOGGING =============
  /// Active/désactive les logs détaillés (mettre à false en production)
  static const bool _enableVerboseLogs = true;

  /// Log une requête API sortante
  void _logRequest(String method, Uri url, {dynamic body}) {
    if (!_enableVerboseLogs) return;
    debugPrint(
      '\n╔══════════════════════════════════════════════════════════════',
    );
    debugPrint('║ 📤 API REQUEST');
    debugPrint(
      '╠══════════════════════════════════════════════════════════════',
    );
    debugPrint('║ $method $url');
    if (body != null) {
      try {
        final prettyBody = const JsonEncoder.withIndent('  ').convert(body);
        debugPrint('║ Body:');
        for (var line in prettyBody.split('\n')) {
          debugPrint('║   $line');
        }
      } catch (_) {
        debugPrint('║ Body: $body');
      }
    }
    debugPrint(
      '╚══════════════════════════════════════════════════════════════\n',
    );
  }

  /// Log une réponse API entrante
  void _logResponse(
    String method,
    Uri url,
    int statusCode,
    dynamic responseBody,
  ) {
    if (!_enableVerboseLogs) return;
    final isSuccess = statusCode >= 200 && statusCode < 300;
    final icon = isSuccess ? '✅' : '❌';
    final statusText = isSuccess ? 'SUCCESS' : 'ERROR';

    debugPrint(
      '\n╔══════════════════════════════════════════════════════════════',
    );
    debugPrint('║ $icon API RESPONSE - $statusText');
    debugPrint(
      '╠══════════════════════════════════════════════════════════════',
    );
    debugPrint('║ $method $url');
    debugPrint('║ Status: $statusCode');
    debugPrint(
      '╠──────────────────────────────────────────────────────────────',
    );
    debugPrint('║ Response Body:');
    if (responseBody != null) {
      try {
        final decoded =
            responseBody is String ? jsonDecode(responseBody) : responseBody;
        final prettyBody = const JsonEncoder.withIndent('  ').convert(decoded);
        for (var line in prettyBody.split('\n')) {
          debugPrint('║   $line');
        }
      } catch (_) {
        debugPrint('║   $responseBody');
      }
    } else {
      debugPrint('║   (empty)');
    }
    debugPrint(
      '╚══════════════════════════════════════════════════════════════\n',
    );
  }

  /// Retourne l'URL complète pour un endpoint donné (pour les MultipartRequest)
  /// Cette méthode construit l'URL avec le préfixe commerce/api/v1
  String getFullUrl(String endpoint) {
    final String deviceCompatibleBaseUrl = EnvConfig.getDeviceCompatibleUrl(
      EnvConfig.commerceBaseUrl,
    );
    final cleanedEndpoint = _cleanEndpoint(endpoint);
    return '$deviceCompatibleBaseUrl/$cleanedEndpoint';
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool requiresAuth = false,
    bool bypassCircuitBreaker = false,
  }) async {
    // Vérifier le circuit breaker avant de faire la requête
    if (!bypassCircuitBreaker && !_circuitBreaker.canExecute) {
      debugPrint(
        '⛔ GET $endpoint bloqué par circuit breaker (retry dans ${_circuitBreaker.timeUntilRetry}s)',
      );
      throw NetworkException(
        'Service temporarily unavailable. Retry in ${_circuitBreaker.timeUntilRetry}s',
        endpoint: endpoint,
      );
    }

    // Utiliser commerceBaseUrl qui contient déjà /commerce/api/v1
    final String deviceCompatibleBaseUrl = EnvConfig.getDeviceCompatibleUrl(
      EnvConfig.commerceBaseUrl,
    );

    // Nettoyer l'endpoint
    final cleanedEndpoint = _cleanEndpoint(endpoint);

    final url = Uri.parse(
      '$deviceCompatibleBaseUrl/$cleanedEndpoint',
    ).replace(queryParameters: queryParameters);

    _logRequest('GET', url);

    try {
      final response = await _httpClient
          .get(url, headers: await getHeaders(requiresAuth: requiresAuth))
          .timeout(Duration(milliseconds: receiveTimeoutMs));

      _logResponse('GET', url, response.statusCode, response.body);

      final result = handleResponse(response, endpoint);
      _circuitBreaker.recordSuccess();
      return result;
    } on SocketException {
      _circuitBreaker.recordFailure(reason: 'SocketException');
      throw NetworkException(
        'Could not connect to the server',
        endpoint: endpoint,
      );
    } on HttpException {
      _circuitBreaker.recordFailure(reason: 'HttpException');
      throw NetworkException('Could not find the server', endpoint: endpoint);
    } on FormatException {
      throw ResponseFormatException('Bad response format', endpoint: endpoint);
    } catch (e) {
      if (e is ApiException) {
        // Les erreurs 5xx indiquent un problème serveur
        if (e is ServerException) {
          _circuitBreaker.recordFailure(
            reason: 'ServerException ${e.statusCode}',
          );
        }
        rethrow;
      }
      _circuitBreaker.recordFailure(
        reason: e.toString().substring(
          0,
          (e.toString().length > 50) ? 50 : e.toString().length,
        ),
      );
      throw NetworkException(
        'An unexpected error occurred: ${e.toString()}',
        endpoint: endpoint,
      );
    }
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool requiresAuth = false,
    int? customTimeoutMs, // Timeout personnalisé en millisecondes
    bool bypassCircuitBreaker = false,
  }) async {
    // Vérifier le circuit breaker avant de faire la requête
    if (!bypassCircuitBreaker && !_circuitBreaker.canExecute) {
      debugPrint(
        '⛔ POST $endpoint bloqué par circuit breaker (retry dans ${_circuitBreaker.timeUntilRetry}s)',
      );
      throw NetworkException(
        'Service temporarily unavailable. Retry in ${_circuitBreaker.timeUntilRetry}s',
        endpoint: endpoint,
      );
    }

    // Utiliser commerceBaseUrl qui contient déjà /commerce/api/v1
    final String deviceCompatibleBaseUrl = EnvConfig.getDeviceCompatibleUrl(
      EnvConfig.commerceBaseUrl,
    );

    // Nettoyer l'endpoint
    final cleanedEndpoint = _cleanEndpoint(endpoint);

    final url = Uri.parse('$deviceCompatibleBaseUrl/$cleanedEndpoint');

    // Utiliser le timeout personnalisé si fourni, sinon le timeout par défaut
    final timeoutMs = customTimeoutMs ?? receiveTimeoutMs;

    _logRequest('POST', url, body: body);

    try {
      final response = await _httpClient
          .post(
            url,
            headers: await getHeaders(requiresAuth: requiresAuth),
            body: jsonEncode(body),
          )
          .timeout(Duration(milliseconds: timeoutMs));

      _logResponse('POST', url, response.statusCode, response.body);

      final result = handleResponse(response, endpoint);
      _circuitBreaker.recordSuccess();
      return result;
    } on SocketException {
      _circuitBreaker.recordFailure(reason: 'SocketException');
      throw NetworkException(
        'Could not connect to the server',
        endpoint: endpoint,
      );
    } on HttpException {
      _circuitBreaker.recordFailure(reason: 'HttpException');
      throw NetworkException('Could not find the server', endpoint: endpoint);
    } on FormatException {
      throw ResponseFormatException('Bad response format', endpoint: endpoint);
    } catch (e) {
      if (e is ApiException) {
        if (e is ServerException) {
          _circuitBreaker.recordFailure(
            reason: 'ServerException ${e.statusCode}',
          );
        }
        rethrow;
      }
      _circuitBreaker.recordFailure(
        reason: e.toString().substring(
          0,
          (e.toString().length > 50) ? 50 : e.toString().length,
        ),
      );
      throw NetworkException(
        'An unexpected error occurred: ${e.toString()}',
        endpoint: endpoint,
      );
    }
  }

  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    bool requiresAuth = false,
    bool bypassCircuitBreaker = false,
  }) async {
    // Vérifier le circuit breaker avant de faire la requête
    if (!bypassCircuitBreaker && !_circuitBreaker.canExecute) {
      debugPrint('⛔ PUT $endpoint bloqué par circuit breaker');
      throw NetworkException(
        'Service temporarily unavailable. Retry in ${_circuitBreaker.timeUntilRetry}s',
        endpoint: endpoint,
      );
    }

    // Utiliser commerceBaseUrl qui contient déjà /commerce/api/v1
    final String deviceCompatibleBaseUrl = EnvConfig.getDeviceCompatibleUrl(
      EnvConfig.commerceBaseUrl,
    );

    // Nettoyer l'endpoint
    final cleanedEndpoint = _cleanEndpoint(endpoint);

    final url = Uri.parse('$deviceCompatibleBaseUrl/$cleanedEndpoint');

    _logRequest('PUT', url, body: body);

    try {
      final response = await _httpClient
          .put(
            url,
            headers: await getHeaders(requiresAuth: requiresAuth),
            body: jsonEncode(body),
          )
          .timeout(Duration(milliseconds: receiveTimeoutMs));

      _logResponse('PUT', url, response.statusCode, response.body);

      final result = handleResponse(response, endpoint);
      _circuitBreaker.recordSuccess();
      return result;
    } on SocketException {
      _circuitBreaker.recordFailure(reason: 'SocketException');
      throw NetworkException(
        'Could not connect to the server',
        endpoint: endpoint,
      );
    } on HttpException {
      _circuitBreaker.recordFailure(reason: 'HttpException');
      throw NetworkException('Could not find the server', endpoint: endpoint);
    } on FormatException {
      throw ResponseFormatException('Bad response format', endpoint: endpoint);
    } catch (e) {
      if (e is ApiException) {
        if (e is ServerException) {
          _circuitBreaker.recordFailure(reason: 'ServerException');
        }
        rethrow;
      }
      _circuitBreaker.recordFailure(reason: 'Unknown');
      throw NetworkException(
        'An unexpected error occurred: ${e.toString()}',
        endpoint: endpoint,
      );
    }
  }

  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    bool requiresAuth = false,
    bool bypassCircuitBreaker = false,
  }) async {
    // Vérifier le circuit breaker avant de faire la requête
    if (!bypassCircuitBreaker && !_circuitBreaker.canExecute) {
      debugPrint('⛔ PATCH $endpoint bloqué par circuit breaker');
      throw NetworkException(
        'Service temporarily unavailable. Retry in ${_circuitBreaker.timeUntilRetry}s',
        endpoint: endpoint,
      );
    }

    // Utiliser commerceBaseUrl qui contient déjà /commerce/api/v1
    final String deviceCompatibleBaseUrl = EnvConfig.getDeviceCompatibleUrl(
      EnvConfig.commerceBaseUrl,
    );

    // Nettoyer l'endpoint
    final cleanedEndpoint = _cleanEndpoint(endpoint);

    final url = Uri.parse('$deviceCompatibleBaseUrl/$cleanedEndpoint');

    _logRequest('PATCH', url, body: body);

    try {
      final response = await _httpClient
          .patch(
            url,
            headers: await getHeaders(requiresAuth: requiresAuth),
            body: jsonEncode(body),
          )
          .timeout(Duration(milliseconds: receiveTimeoutMs));

      _logResponse('PATCH', url, response.statusCode, response.body);

      final result = handleResponse(response, endpoint);
      _circuitBreaker.recordSuccess();
      return result;
    } on SocketException {
      _circuitBreaker.recordFailure(reason: 'SocketException');
      throw NetworkException(
        'Could not connect to the server',
        endpoint: endpoint,
      );
    } on HttpException {
      _circuitBreaker.recordFailure(reason: 'HttpException');
      throw NetworkException('Could not find the server', endpoint: endpoint);
    } on FormatException {
      throw ResponseFormatException('Bad response format', endpoint: endpoint);
    } catch (e) {
      if (e is ApiException) {
        if (e is ServerException) {
          _circuitBreaker.recordFailure(reason: 'ServerException');
        }
        rethrow;
      }
      _circuitBreaker.recordFailure(reason: 'Unknown');
      throw NetworkException(
        'An unexpected error occurred: ${e.toString()}',
        endpoint: endpoint,
      );
    }
  }

  Future<dynamic> delete(
    String endpoint, {
    bool requiresAuth = false,
    bool bypassCircuitBreaker = false,
  }) async {
    // Vérifier le circuit breaker avant de faire la requête
    if (!bypassCircuitBreaker && !_circuitBreaker.canExecute) {
      debugPrint('⛔ DELETE $endpoint bloqué par circuit breaker');
      throw NetworkException(
        'Service temporarily unavailable. Retry in ${_circuitBreaker.timeUntilRetry}s',
        endpoint: endpoint,
      );
    }

    // Utiliser commerceBaseUrl qui contient déjà /commerce/api/v1
    final String deviceCompatibleBaseUrl = EnvConfig.getDeviceCompatibleUrl(
      EnvConfig.commerceBaseUrl,
    );

    // Nettoyer l'endpoint
    final cleanedEndpoint = _cleanEndpoint(endpoint);

    final url = Uri.parse('$deviceCompatibleBaseUrl/$cleanedEndpoint');

    _logRequest('DELETE', url);

    try {
      final response = await _httpClient
          .delete(url, headers: await getHeaders(requiresAuth: requiresAuth))
          .timeout(Duration(milliseconds: receiveTimeoutMs));

      _logResponse('DELETE', url, response.statusCode, response.body);

      final result = handleResponse(response, endpoint);
      _circuitBreaker.recordSuccess();
      return result;
    } on SocketException {
      _circuitBreaker.recordFailure(reason: 'SocketException');
      throw NetworkException(
        'Could not connect to the server',
        endpoint: endpoint,
      );
    } on HttpException {
      _circuitBreaker.recordFailure(reason: 'HttpException');
      throw NetworkException('Could not find the server', endpoint: endpoint);
    } on FormatException {
      throw ResponseFormatException('Bad response format', endpoint: endpoint);
    } catch (e) {
      if (e is ApiException) {
        if (e is ServerException) {
          _circuitBreaker.recordFailure(reason: 'ServerException');
        }
        rethrow;
      }
      _circuitBreaker.recordFailure(reason: 'Unknown');
      throw NetworkException(
        'An unexpected error occurred: ${e.toString()}',
        endpoint: endpoint,
      );
    }
  }

  Future<http.Response> postMultipart(
    String endpoint, {
    required File file,
    required String fileField,
    Map<String, String>? fields,
    bool requiresAuth = false,
  }) async {
    // Utiliser commerceBaseUrl qui contient déjà /commerce/api/v1
    final String deviceCompatibleBaseUrl = EnvConfig.getDeviceCompatibleUrl(
      EnvConfig.commerceBaseUrl,
    );

    // Nettoyer l'endpoint
    final cleanedEndpoint = _cleanEndpoint(endpoint);

    final url = Uri.parse('$deviceCompatibleBaseUrl/$cleanedEndpoint');

    _logRequest(
      'POST (Multipart)',
      url,
      body: {'file': file.path, 'fields': fields},
    );

    try {
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(await getHeaders(requiresAuth: requiresAuth));
      if (fields != null) {
        request.fields.addAll(fields);
      }
      request.files.add(
        await http.MultipartFile.fromPath(
          fileField,
          file.path,
          // contentType: MediaType('image', 'jpeg'), // Example, adjust as needed
        ),
      );
      final streamedResponse = await _httpClient
          .send(request)
          .timeout(Duration(milliseconds: receiveTimeoutMs));
      final response = await http.Response.fromStream(streamedResponse);

      _logResponse('POST (Multipart)', url, response.statusCode, response.body);

      // Vérifier les erreurs dans la réponse multipart
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final exception = _createExceptionFromResponse(
          response.statusCode,
          response.body,
          endpoint,
          response.headers,
        );

        // Si c'est une erreur d'authentification, déclencher la ré-authentification
        if (exception is AuthenticationException) {
          _reauthService.handleAuthException(exception);
        }

        throw exception;
      }

      // We return the raw http.Response here because _handleResponse expects JSON
      // and multipart responses might not always be JSON or might need different handling.
      // The caller will handle parsing.
      return response;
    } on SocketException {
      throw NetworkException(
        'Could not connect to the server',
        endpoint: endpoint,
      );
    } on HttpException {
      throw NetworkException('Could not find the server', endpoint: endpoint);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(
        'An unexpected error occurred during multipart POST: ${e.toString()}',
        endpoint: endpoint,
      );
    }
  }

  // Made public by removing underscore
  dynamic handleResponse(http.Response response, [String? endpoint]) {
    final statusCode = response.statusCode;
    final responseBody = response.body;

    if (statusCode >= 200 && statusCode < 300) {
      if (responseBody.isEmpty) {
        return null; // Or some other indicator of success with no content
      }
      try {
        return jsonDecode(responseBody);
      } catch (e) {
        // If decoding fails but status is OK, it might be a plain text response
        // Or it could be an issue if JSON was expected.
        // For now, returning the raw body. Consider logging this.
        return responseBody;
      }
    } else {
      // Créer l'exception appropriée et déclencher la ré-authentification si nécessaire
      final exception = _createExceptionFromResponse(
        statusCode,
        responseBody,
        endpoint,
        response.headers,
      );

      // Si c'est une erreur d'authentification, déclencher la ré-authentification
      if (exception is AuthenticationException) {
        _reauthService.handleAuthException(exception);
      }

      throw exception;
    }
  }

  /// Crée l'exception appropriée basée sur la réponse HTTP
  ApiException _createExceptionFromResponse(
    int statusCode,
    String responseBody,
    String? endpoint,
    Map<String, String> headers,
  ) {
    // Tenter de décoder le corps de la réponse pour extraire des détails
    dynamic decodedBody;
    try {
      decodedBody = jsonDecode(responseBody);
    } catch (e) {
      decodedBody = responseBody;
    }

    // Extraire le message d'erreur depuis la réponse si possible
    String message = _extractErrorMessage(decodedBody, statusCode);

    switch (statusCode) {
      case 400:
        // Debug logging pour les erreurs 400
        // ignore: avoid_print
        print('[ApiClient] ⚠️ Erreur 400 sur endpoint: $endpoint');
        // ignore: avoid_print
        print('[ApiClient] ⚠️ Response body: $decodedBody');
        final validationErrors = ApiExceptionFactory.extractValidationErrors(
          decodedBody,
        );
        // ignore: avoid_print
        print('[ApiClient] ⚠️ Validation errors: $validationErrors');
        return BadRequestException(
          message,
          endpoint: endpoint,
          responseBody: decodedBody,
          validationErrors: validationErrors,
        );
      case 401:
        return AuthenticationException(
          message,
          endpoint: endpoint,
          responseBody: decodedBody,
        );
      case 403:
        return AuthorizationException(
          message,
          endpoint: endpoint,
          responseBody: decodedBody,
        );
      case 404:
        return NotFoundException(
          message,
          endpoint: endpoint,
          responseBody: decodedBody,
        );
      case 429:
        final retryAfter = ApiExceptionFactory.extractRetryAfter(headers);
        return RateLimitException(
          message,
          endpoint: endpoint,
          responseBody: decodedBody,
          retryAfter: retryAfter,
        );
      default:
        if (statusCode >= 500 && statusCode < 600) {
          return ServerException(
            message,
            statusCode: statusCode,
            endpoint: endpoint,
            responseBody: decodedBody,
          );
        }
        return ServerException(
          message,
          statusCode: statusCode,
          endpoint: endpoint,
          responseBody: decodedBody,
        );
    }
  }

  /// Extrait le message d'erreur depuis le corps de la réponse
  String _extractErrorMessage(dynamic responseBody, int statusCode) {
    if (responseBody is Map<String, dynamic>) {
      // Essayer différents champs pour le message d'erreur
      if (responseBody.containsKey('message')) {
        return responseBody['message'] as String;
      }
      if (responseBody.containsKey('error')) {
        final error = responseBody['error'];
        if (error is String) return error;
        if (error is Map && error.containsKey('message')) {
          return error['message'] as String;
        }
      }
      if (responseBody.containsKey('detail')) {
        return responseBody['detail'] as String;
      }
    }

    // Messages par défaut basés sur le code de statut
    switch (statusCode) {
      case 400:
        return 'Bad request - The request could not be understood by the server';
      case 401:
        return 'Unauthorized - Authentication is required';
      case 403:
        return 'Forbidden - You do not have permission to access this resource';
      case 404:
        return 'Resource not found';
      case 429:
        return 'Too many requests - Rate limit exceeded';
      case 500:
        return 'Internal server error';
      case 502:
        return 'Bad gateway';
      case 503:
        return 'Service unavailable';
      case 504:
        return 'Gateway timeout';
      default:
        return 'HTTP error occurred (Status: $statusCode)';
    }
  }

  // Method to close the http client when it's no longer needed.
  // Call this in your app's dispose method or when the ApiClient is no longer in use.
  void dispose() {
    _httpClient.close();
  }
}
