import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'offline_write_queue.dart';
import '../config/env_config.dart'; // Import pour la configuration d'environnement
import '../../features/auth/services/auth0_service.dart'; // Import pour le service Auth0
import '../exceptions/api_exceptions.dart'; // Import des exceptions personnalisées
import 'reauth_service.dart'; // Import du service de ré-authentification
import 'api_circuit_breaker.dart'; // Import du circuit breaker
import 'account_block_notifier.dart';
import 'business_context_service.dart'; // Contexte multi-tenant (companyId / businessUnitId)

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

  /// Source de jeton prioritaire (ordinateur : le service d'authentification
  /// desktop, qui renouvelle le jeton avant son expiration). `null` ou jeton
  /// absent : repli sur [Auth0Service].
  Future<String?> Function()? _tokenProvider;

  // Configure the instance with Auth0Service
  static void configure({
    Auth0Service? auth0Service,
    Future<String?> Function()? tokenProvider,
  }) {
    _instance._auth0Service = auth0Service;
    _instance._tokenProvider = tokenProvider;
    if (auth0Service != null) {
      _instance._reauthService.configure(auth0Service);
    }
  }

  /// Client distinct du singleton, sur un client HTTP fourni (tests).
  @visibleForTesting
  factory ApiClient.withHttpClient(http.Client httpClient) =>
      ApiClient._internal(httpClient: httpClient);

  // Factory constructor to return the singleton instance
  factory ApiClient() => _instance;
  Future<Map<String, String>> getHeaders({bool requiresAuth = false}) async {
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
      HttpHeaders.acceptHeader: 'application/json',
    };

    if (requiresAuth) {
      String? token;
      if (_tokenProvider != null) {
        try {
          token = await _tokenProvider!();
        } catch (e) {
          debugPrint('ApiClient: source de jeton indisponible : $e');
        }
      }
      if ((token == null || token.isEmpty) && _auth0Service != null) {
        // Utiliser Auth0Service pour obtenir le token d'accès (recommandé)
        token = await _auth0Service?.getAccessToken();
      } else if (token == null || token.isEmpty) {
        // Fallback à la méthode précédente. Stockage illisible (clé
        // régénérée, absent en test) : pas de jeton plutôt qu'un plantage.
        try {
          token = await _secureStorage.read(key: 'auth_token');
        } catch (e) {
          debugPrint('ApiClient: lecture du jeton impossible : $e');
        }
      }
      // Jamais d'en-tête « Bearer null » : sans jeton, le serveur répond 401
      // et la reconnexion prend le relais.
      if (token != null && token.isNotEmpty) {
        headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      } else {
        debugPrint('ApiClient: aucun jeton disponible pour cette requête');
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
  // Logs verbeux (URL, headers, corps) DÉSACTIVÉS en release pour ne pas exposer
  // de données sensibles (tokens, PII) dans les logs de l'appareil.
  static const bool _enableVerboseLogs = !kReleaseMode;

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

  // ── Écritures hors ligne ───────────────────────────────────────────────────
  // Les modules récents passent tous par ce client, qui n'avait aucune gestion
  // du hors ligne : leurs écritures levaient une erreur réseau et la saisie de
  // l'utilisateur était perdue. Toute écriture qui échoue pour une raison
  // RÉSEAU est désormais conservée et rejouée dans l'ordre au retour de la
  // connexion. On ne renvoie jamais un faux succès : l'appelant reçoit une
  // OfflineQueuedException explicite.
  static const Set<String> _queueableMethods = {
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
  };

  /// Met l'écriture en file puis lève l'exception adaptée. Si la mise en file
  /// échoue (stockage indisponible), on relaie l'erreur réseau d'origine pour
  /// ne rien masquer.
  Future<Never> _queueWriteOrThrow(
    String method,
    String endpoint,
    dynamic body,
    bool requiresAuth,
    ApiException networkError, {
    bool enabled = true,
  }) async {
    if (!enabled || !_queueableMethods.contains(method.toUpperCase())) {
      throw networkError;
    }
    final queued = await OfflineWriteQueue.instance.enqueue(
      method: method,
      endpoint: endpoint,
      body: body,
      requiresAuth: requiresAuth,
      scope: _currentCompanyScope(),
    );
    if (!queued) throw networkError;
    throw OfflineQueuedException(endpoint: endpoint);
  }

  /// Entreprise de la session courante (null si inconnue).
  String? _currentCompanyScope() {
    try {
      return BusinessContextService().companyId;
    } catch (_) {
      return null;
    }
  }

  /// Rejoue les écritures conservées hors ligne. À appeler au retour du
  /// réseau. Retourne le bilan pour permettre un rafraîchissement des écrans.
  Future<OfflineReplayReport> replayPendingWrites() {
    return OfflineWriteQueue.instance.replay(
      currentScope: _currentCompanyScope(),
      // queueOffline: false : l'écriture est DÉJÀ en file. Si le réseau
      // retombe pendant le rejeu, la remettre en file créerait un doublon
      // (elle serait envoyée deux fois au passage suivant).
      send: (method, endpoint, body, requiresAuth) async {
        switch (method.toUpperCase()) {
          case 'POST':
            await post(
              endpoint,
              body: body,
              requiresAuth: requiresAuth,
              bypassCircuitBreaker: true,
              queueOffline: false,
            );
            break;
          case 'PUT':
            await put(
              endpoint,
              body: body,
              requiresAuth: requiresAuth,
              bypassCircuitBreaker: true,
              queueOffline: false,
            );
            break;
          case 'PATCH':
            await patch(
              endpoint,
              body: body,
              requiresAuth: requiresAuth,
              bypassCircuitBreaker: true,
              queueOffline: false,
            );
            break;
          case 'DELETE':
            await delete(
              endpoint,
              requiresAuth: requiresAuth,
              bypassCircuitBreaker: true,
              queueOffline: false,
            );
            break;
          default:
            throw ArgumentError('Méthode non rejouable : $method');
        }
      },
      // Refus DÉFINITIF du serveur : validation, droits, entité disparue. Les
      // rejouer indéfiniment ne ferait qu'empiler des échecs. 408 et 429 sont
      // au contraire temporaires.
      isPermanentFailure: isPermanentReplayFailure,
    );
  }

  /// Refus DÉFINITIF du serveur pour une écriture rejouée : validation,
  /// droits, entité disparue. Restent au contraire en file : les coupures,
  /// 408 et 429, une session expirée (401 : le rejeu au lancement peut partir
  /// avant que le jeton soit prêt, abandonner perdrait la saisie) et un compte
  /// suspendu (403 ACCOUNT_SUSPENDED : la saisie repartira à la réactivation).
  @visibleForTesting
  static bool isPermanentReplayFailure(Object error) {
    if (error is OfflineQueuedException) return false;
    if (error is NetworkException) return false;
    if (error is AuthenticationException) return false;
    if (error is ApiException) {
      final code = error.statusCode;
      if (code == null) return false;
      if (code == 401 || code == 408 || code == 429) return false;
      if (code == 403 &&
          AccountBlockNotifier.lireRefus(error.responseBody) != null) {
        return false;
      }
      return code >= 400 && code < 500;
    }
    return false;
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool requiresAuth = false,
    bool bypassCircuitBreaker = false,
    // true : ajoute companyId / businessUnitId du contexte courant (isolation
    // par unité d'affaires quand le jeton ne porte pas l'unité). Les
    // paramètres explicites de l'appelant restent prioritaires.
    bool includeBusinessContext = false,
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

    Map<String, String>? finalQueryParams = queryParameters;
    if (includeBusinessContext) {
      final contextParams = BusinessContextService().getApiQueryParams();
      if (contextParams.isNotEmpty) {
        finalQueryParams = {...contextParams, ...?queryParameters};
      }
    }

    final url = Uri.parse(
      '$deviceCompatibleBaseUrl/$cleanedEndpoint',
    ).replace(queryParameters: finalQueryParams);

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
    // false : l'appelant gère déjà sa reprise hors ligne (dépenses en
    // attente de synchro) ; mettre aussi en file créerait un doublon.
    bool queueOffline = true,
  }) async {
    // Vérifier le circuit breaker avant de faire la requête
    if (!bypassCircuitBreaker && !_circuitBreaker.canExecute) {
      debugPrint(
        '⛔ POST $endpoint bloqué par circuit breaker (retry dans ${_circuitBreaker.timeUntilRetry}s)',
      );
      // Serveur injoignable : même traitement qu'une coupure, la saisie est
      // conservée. Avant, après quelques échecs hors ligne, le disjoncteur
      // s'ouvrait et les écritures suivantes étaient perdues.
      return _queueWriteOrThrow(
        'POST',
        endpoint,
        body,
        requiresAuth,
        NetworkException(
          'Service temporarily unavailable. Retry in ${_circuitBreaker.timeUntilRetry}s',
          endpoint: endpoint,
        ),
        enabled: queueOffline,
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
            body: jsonEncode(body ?? const <String, dynamic>{}),
          )
          .timeout(Duration(milliseconds: timeoutMs));

      _logResponse('POST', url, response.statusCode, response.body);

      final result = handleResponse(response, endpoint);
      _circuitBreaker.recordSuccess();
      return result;
    } on SocketException {
      _circuitBreaker.recordFailure(reason: 'SocketException');
      return _queueWriteOrThrow(
        'POST',
        endpoint,
        body,
        requiresAuth,
        NetworkException(
          'Could not connect to the server',
          endpoint: endpoint,
        ),
        enabled: queueOffline,
      );
    } on HttpException {
      _circuitBreaker.recordFailure(reason: 'HttpException');
      return _queueWriteOrThrow(
        'POST',
        endpoint,
        body,
        requiresAuth,
        NetworkException('Could not find the server', endpoint: endpoint),
        enabled: queueOffline,
      );
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
    // false : pas de mise en file hors ligne (rejeu déjà en cours, ou
    // action à confirmer par le serveur).
    bool queueOffline = true,
  }) async {
    // Vérifier le circuit breaker avant de faire la requête
    if (!bypassCircuitBreaker && !_circuitBreaker.canExecute) {
      debugPrint('⛔ PUT $endpoint bloqué par circuit breaker');
      return _queueWriteOrThrow(
        'PUT',
        endpoint,
        body,
        requiresAuth,
        NetworkException(
          'Service temporarily unavailable. Retry in ${_circuitBreaker.timeUntilRetry}s',
          endpoint: endpoint,
        ),
        enabled: queueOffline,
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
            body: jsonEncode(body ?? const <String, dynamic>{}),
          )
          .timeout(Duration(milliseconds: receiveTimeoutMs));

      _logResponse('PUT', url, response.statusCode, response.body);

      final result = handleResponse(response, endpoint);
      _circuitBreaker.recordSuccess();
      return result;
    } on SocketException {
      _circuitBreaker.recordFailure(reason: 'SocketException');
      return _queueWriteOrThrow(
        'PUT',
        endpoint,
        body,
        requiresAuth,
        NetworkException(
          'Could not connect to the server',
          endpoint: endpoint,
        ),
        enabled: queueOffline,
      );
    } on HttpException {
      _circuitBreaker.recordFailure(reason: 'HttpException');
      return _queueWriteOrThrow(
        'PUT',
        endpoint,
        body,
        requiresAuth,
        NetworkException('Could not find the server', endpoint: endpoint),
        enabled: queueOffline,
      );
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
    // false : pas de mise en file hors ligne (rejeu déjà en cours, ou
    // action à confirmer par le serveur).
    bool queueOffline = true,
  }) async {
    // Vérifier le circuit breaker avant de faire la requête
    if (!bypassCircuitBreaker && !_circuitBreaker.canExecute) {
      debugPrint('⛔ PATCH $endpoint bloqué par circuit breaker');
      return _queueWriteOrThrow(
        'PATCH',
        endpoint,
        body,
        requiresAuth,
        NetworkException(
          'Service temporarily unavailable. Retry in ${_circuitBreaker.timeUntilRetry}s',
          endpoint: endpoint,
        ),
        enabled: queueOffline,
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
            body: jsonEncode(body ?? const <String, dynamic>{}),
          )
          .timeout(Duration(milliseconds: receiveTimeoutMs));

      _logResponse('PATCH', url, response.statusCode, response.body);

      final result = handleResponse(response, endpoint);
      _circuitBreaker.recordSuccess();
      return result;
    } on SocketException {
      _circuitBreaker.recordFailure(reason: 'SocketException');
      return _queueWriteOrThrow(
        'PATCH',
        endpoint,
        body,
        requiresAuth,
        NetworkException(
          'Could not connect to the server',
          endpoint: endpoint,
        ),
        enabled: queueOffline,
      );
    } on HttpException {
      _circuitBreaker.recordFailure(reason: 'HttpException');
      return _queueWriteOrThrow(
        'PATCH',
        endpoint,
        body,
        requiresAuth,
        NetworkException('Could not find the server', endpoint: endpoint),
        enabled: queueOffline,
      );
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
    // false : suppression à confirmer par le serveur (refus possible),
    // jamais rejouée plus tard à l'insu de l'utilisateur.
    bool queueOffline = true,
  }) async {
    // Vérifier le circuit breaker avant de faire la requête
    if (!bypassCircuitBreaker && !_circuitBreaker.canExecute) {
      debugPrint('⛔ DELETE $endpoint bloqué par circuit breaker');
      return _queueWriteOrThrow(
        'DELETE',
        endpoint,
        null,
        requiresAuth,
        NetworkException(
          'Service temporarily unavailable. Retry in ${_circuitBreaker.timeUntilRetry}s',
          endpoint: endpoint,
        ),
        enabled: queueOffline,
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
      return _queueWriteOrThrow(
        'DELETE',
        endpoint,
        null,
        requiresAuth,
        NetworkException(
          'Could not connect to the server',
          endpoint: endpoint,
        ),
        enabled: queueOffline,
      );
    } on HttpException {
      _circuitBreaker.recordFailure(reason: 'HttpException');
      return _queueWriteOrThrow(
        'DELETE',
        endpoint,
        null,
        requiresAuth,
        NetworkException('Could not find the server', endpoint: endpoint),
        enabled: queueOffline,
      );
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
        // Compte ferme : le portail refuse tout avec un code stable. On le
        // signale une fois, l'interface cede la place. Sans cela l'app se
        // chargeait normalement puis restait vide, chaque ecran echouant en
        // silence.
        final refus = AccountBlockNotifier.lireRefus(decodedBody);
        if (refus != null) AccountBlockNotifier.instance.signal(refus);
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
        // Erreurs de validation : liste de messages.
        final message = responseBody['message'];
        if (message is List) return message.join(', ');
        if (message != null) return message.toString();
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
