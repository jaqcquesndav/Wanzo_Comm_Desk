import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/environment.dart';
import '../../features/auth/services/auth0_service.dart';
import '../../features/auth/services/offline_auth_service.dart';
import '../utils/connectivity_service.dart';
import 'database_service.dart';

/// Service pour gérer les appels API
class ApiService {
  static final ApiService _instance = ApiService._internal();

  /// Instance unique du service (singleton)
  factory ApiService() => _instance;

  final Auth0Service _auth0Service;
  final ConnectivityService _connectivityService;
  final DatabaseService _databaseService;

  ApiService._internal()
    : _connectivityService = ConnectivityService(),
      _databaseService = DatabaseService(),
      _auth0Service = Auth0Service(
        offlineAuthService: OfflineAuthService(
          secureStorage: const FlutterSecureStorage(),
          databaseService: DatabaseService(),
          connectivityService: ConnectivityService(),
        ),
      );

  // Configuration de l'API - utilise la variable d'environnement
  // IMPORTANT: Utiliser commerceApiBaseUrl pour accéder via API Gateway avec préfixe /commerce/api/v1
  static String get _apiBaseUrl => Environment.commerceApiBaseUrl;
  static String get apiBaseUrl => _apiBaseUrl;
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _cacheExpiration = Duration(hours: 24);

  // Timer pour la synchronisation périodique
  Timer? _syncTimer;

  /// Initialise le service
  Future<void> init() async {
    await _connectivityService.init();
    await _auth0Service.init();
    _startPeriodicSync(); // Démarrer la synchronisation périodique
  }

  /// Récupère une réponse mise en cache
  Future<Map<String, dynamic>?> _getCachedResponse(
    String url,
    String method,
  ) async {
    return await _databaseService.getCachedApiResponse(url, method);
  }

  /// Vérifie si la requête peut utiliser le cache
  bool _canUseCache(String method) {
    return method == 'GET'; // Seules les requêtes GET sont mises en cache
  }

  /// Enregistre une opération pour synchronisation ultérieure
  Future<void> _storeForSync(
    String endpoint,
    String method,
    Map<String, dynamic>? body,
  ) async {
    await _databaseService.savePendingOperation(
      endpoint: endpoint,
      method: method,
      body: body,
    );
  }

  /// Effectue une requête GET
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    return _request(uri: _buildUri(endpoint, queryParams), method: 'GET');
  }

  /// Effectue une requête POST
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    return _request(uri: _buildUri(endpoint), method: 'POST', body: body);
  }

  /// Effectue une requête PUT
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    return _request(uri: _buildUri(endpoint), method: 'PUT', body: body);
  }

  /// Effectue une requête DELETE
  Future<Map<String, dynamic>> delete(String endpoint) async {
    return _request(uri: _buildUri(endpoint), method: 'DELETE');
  }

  /// Effectue une requête POST avec un fichier (multipart)
  Future<Map<String, dynamic>> postMultipart({
    required String endpoint,
    required File file,
    String fileField = 'file', // Nom du champ pour le fichier
    Map<String, String>? fields, // Champs texte supplémentaires
  }) async {
    final uri = _buildUri(endpoint);
    final token = await _auth0Service.getAccessToken();

    if (!_connectivityService.isConnected) {
      debugPrint(
        'Mode hors ligne: Enregistrement du téléversement de fichier pour synchronisation ultérieure.',
      );
      await _databaseService.savePendingFileUpload(
        endpoint: endpoint,
        filePath: file.path,
        fileField: fileField,
        fields: fields,
      );
      return {
        'success': true,
        'message':
            'Fichier enregistré pour téléversement ultérieur en mode hors ligne.',
        'offline_pending': true,
      };
    }

    try {
      var request = http.MultipartRequest('POST', uri);

      // Ajouter les en-têtes
      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      // Ajouter les champs texte
      if (fields != null) {
        request.fields.addAll(fields);
      }

      // Ajouter le fichier
      request.files.add(
        await http.MultipartFile.fromPath(fileField, file.path),
      );

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return {};
        }
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _handleHttpError(response);
        throw Exception(
          'HTTP error ${response.statusCode} occurred. _handleHttpError should have thrown.',
        );
      }
    } on SocketException catch (e) {
      debugPrint(
        'Erreur de socket lors de l\'envoi du fichier à $endpoint: $e',
      );
      throw Exception(
        'Problème de connexion réseau lors de l\'envoi du fichier à $endpoint.',
      );
    } on TimeoutException catch (e) {
      debugPrint(
        'Délai d\'attente dépassé lors de l\'envoi du fichier à $endpoint: $e',
      );
      throw Exception(
        'L\'envoi du fichier à $endpoint a pris trop de temps. Veuillez réessayer.',
      );
    } catch (e) {
      debugPrint('Erreur lors de l\'envoi du fichier à $endpoint: $e');
      throw Exception(
        'Une erreur s\'est produite lors de l\'envoi du fichier à $endpoint: $e',
      );
    }
  }

  /// Construit l'URI pour la requête
  Uri _buildUri(String endpoint, [Map<String, dynamic>? queryParams]) {
    String tempBaseUrl = _apiBaseUrl;
    // Remove all trailing slashes from base URL
    while (tempBaseUrl.endsWith('/')) {
      tempBaseUrl = tempBaseUrl.substring(0, tempBaseUrl.length - 1);
    }

    String tempEndpoint = endpoint;
    // Remove all leading slashes from endpoint
    while (tempEndpoint.startsWith('/')) {
      tempEndpoint = tempEndpoint.substring(1);
    }

    // Ensures a single slash between base and endpoint
    final url = '$tempBaseUrl/$tempEndpoint';

    if (queryParams != null && queryParams.isNotEmpty) {
      return Uri.parse(url).replace(
        queryParameters: queryParams.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      );
    }

    return Uri.parse(url);
  }

  /// Effectue une requête HTTP avec gestion des erreurs et du token d'authentification
  Future<Map<String, dynamic>> _request({
    required Uri uri,
    required String method,
    Map<String, dynamic>? body,
    bool useOfflineCache = true,
  }) async {
    try {
      if (!_connectivityService.isConnected) {
        debugPrint(
          'Mode hors ligne: tentative de récupération des données du cache pour $uri',
        );
        if (useOfflineCache) {
          final cachedData = await _getCachedResponse(uri.toString(), method);
          if (cachedData != null) {
            return cachedData;
          }
        }

        if (method != 'GET') {
          String endpointPathToSave = uri.path;
          // If uri.path somehow contains the full base URL (e.g. if endpoint was an absolute URL string), remove it.
          // This makes it robust even if _buildUri was passed an absolute path for `endpoint`.
          if (endpointPathToSave.startsWith(_apiBaseUrl)) {
            endpointPathToSave = endpointPathToSave.substring(
              _apiBaseUrl.length,
            );
          }

          // Remove all leading slashes to ensure a clean relative path like "feature/action"
          while (endpointPathToSave.startsWith('/')) {
            endpointPathToSave = endpointPathToSave.substring(1);
          }

          await _databaseService.savePendingOperation(
            endpoint: endpointPathToSave, // Use the cleaned relative path
            method: method,
            body: body,
          );
          debugPrint(
            'Opération enregistrée pour synchronisation ultérieure: $method $endpointPathToSave',
          );
          return {
            'success': true,
            'message': 'Opération enregistrée pour synchronisation ultérieure',
          };
        }

        throw SocketException(
          'Aucune connexion Internet disponible et aucune donnée en cache pour $uri',
        );
      }

      final token = await _auth0Service.getAccessToken();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      http.Response response;

      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(_timeout);
          break;

        case 'POST':
          response = await http
              .post(
                uri,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(_timeout);
          break;

        case 'PUT':
          response = await http
              .put(
                uri,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(_timeout);
          break;

        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(_timeout);
          break;

        default:
          throw Exception('Méthode HTTP non supportée: $method');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return {};
        }

        final responseData = jsonDecode(response.body) as Map<String, dynamic>;

        if (method == 'GET' && useOfflineCache) {
          await _databaseService.cacheApiResponse(
            url: uri.toString(),
            method: method,
            response: responseData,
            expiration: _cacheExpiration,
          );
        }

        return responseData;
      } else {
        _handleHttpError(response);
        throw Exception(
          'Erreur HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on SocketException catch (e) {
      debugPrint('Erreur de socket: $e');

      if (_canUseCache(method)) {
        final cachedResponse = await _getCachedResponse(uri.toString(), method);
        if (cachedResponse != null) {
          debugPrint(
            'Utilisation de la réponse en cache pour: ${uri.toString()}',
          );
          return cachedResponse;
        }
      }

      if (!_canUseCache(method) && body != null) {
        String pathOnly = uri.path;
        if (pathOnly.startsWith(_apiBaseUrl)) {
          pathOnly = pathOnly.substring(_apiBaseUrl.length);
        }
        if (pathOnly.startsWith('/')) {
          pathOnly = pathOnly.substring(1);
        }
        await _storeForSync(pathOnly, method, body);
        debugPrint(
          'Opération stockée pour synchronisation ultérieure: $method $pathOnly',
        );
        return {
          'success': true,
          'message': 'Opération stockée pour synchronisation ultérieure',
        };
      }

      throw Exception(
        'Problème de connexion réseau. Veuillez vérifier votre connexion Internet.',
      );
    } on TimeoutException catch (e) {
      debugPrint('Délai d\'attente dépassé pour $uri: $e');

      if (_canUseCache(method)) {
        final cachedResponse = await _getCachedResponse(uri.toString(), method);
        if (cachedResponse != null) {
          debugPrint(
            'Utilisation de la réponse en cache pour: ${uri.toString()}',
          );
          return cachedResponse;
        }
      }

      throw Exception('La requête a pris trop de temps. Veuillez réessayer.');
    } catch (e) {
      debugPrint('Erreur lors de la requête API pour $uri: $e');
      throw Exception('Une erreur s\'est produite: $e');
    }
  }

  /// Gère les erreurs HTTP spécifiques
  void _handleHttpError(http.Response response) {
    final statusCode = response.statusCode;

    switch (statusCode) {
      case 401:
        debugPrint('Erreur 401: Non autorisé');
        throw Exception('Session expirée. Veuillez vous reconnecter.');

      case 403:
        debugPrint('Erreur 403: Accès refusé');
        throw Exception(
          'Vous n\'avez pas les droits nécessaires pour effectuer cette action.',
        );

      case 404:
        debugPrint('Erreur 404: Ressource non trouvée');
        throw Exception('La ressource demandée n\'existe pas.');

      case 500:
      case 502:
      case 503:
      case 504:
        debugPrint('Erreur serveur: ${response.statusCode}');
        throw Exception(
          'Une erreur serveur s\'est produite. Veuillez réessayer plus tard.',
        );

      default:
        debugPrint(
          'Erreur HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage =
              errorData['message'] ??
              errorData['error'] ??
              'Une erreur s\'est produite.';
          throw Exception(errorMessage);
        } catch (_) {
          throw Exception(
            'Une erreur s\'est produite (${response.statusCode}).',
          );
        }
    }
  }

  // --- Synchronisation des données en attente ---

  /// Démarre la synchronisation périodique des opérations en attente
  void _startPeriodicSync() {
    _syncPendingOperations();
    _syncPendingFileUploads();

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (_connectivityService.isConnected) {
        debugPrint(
          "Vérification périodique pour les opérations et fichiers en attente...",
        );
        await _syncPendingOperations();
        await _syncPendingFileUploads();
      } else {
        debugPrint("Mode hors ligne, synchronisation périodique ignorée.");
      }
    });
  }

  /// Synchronise les opérations en attente (POST, PUT, DELETE)
  Future<void> _syncPendingOperations() async {
    if (!_connectivityService.isConnected) return;

    final pendingOperations = await _databaseService.getPendingOperations();
    if (pendingOperations.isEmpty) {
      debugPrint("Aucune opération en attente à synchroniser.");
      return;
    }

    debugPrint(
      "Synchronisation de ${pendingOperations.length} opération(s) en attente...",
    );

    for (final operation in pendingOperations) {
      final String id = operation['id'] as String;
      final String endpoint = operation['endpoint'] as String;
      final String method = operation['method'] as String;
      final Map<String, dynamic>? body =
          operation['body'] as Map<String, dynamic>?;

      try {
        debugPrint("Tentative de synchronisation: $method $endpoint");
        await _request(
          uri: _buildUri(endpoint),
          method: method,
          body: body,
          useOfflineCache: false,
        );
        await _databaseService.markOperationAsSynchronized(id);
        debugPrint("Opération $id synchronisée avec succès.");
      } catch (e) {
        debugPrint("Échec de la synchronisation de l'opération $id: $e");
      }
    }
    debugPrint("Synchronisation des opérations en attente terminée.");
  }

  /// Synchronise les téléversements de fichiers en attente
  Future<void> _syncPendingFileUploads() async {
    if (!_connectivityService.isConnected) return;

    final pendingUploads = await _databaseService.getPendingFileUploads();
    if (pendingUploads.isEmpty) {
      debugPrint("Aucun téléversement de fichier en attente à synchroniser.");
      return;
    }

    debugPrint(
      "Synchronisation de ${pendingUploads.length} téléversement(s) de fichier(s) en attente...",
    );

    const maxAttempts = 3;

    for (final uploadJob in pendingUploads) {
      final String id = uploadJob['id'] as String;
      final String endpoint = uploadJob['endpoint'] as String;
      final String filePath = uploadJob['filePath'] as String;
      final String fileField = uploadJob['fileField'] as String;
      final Map<String, String>? fields =
          uploadJob['fields'] as Map<String, String>?;
      final int attempts = uploadJob['attempts'] as int;

      if (attempts >= maxAttempts) {
        debugPrint(
          "Téléversement $id a atteint le nombre maximum de tentatives ($maxAttempts). Abandon.",
        );
        continue;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint(
          "Fichier pour le téléversement $id ($filePath) n'existe plus. Suppression de la tâche.",
        );
        await _databaseService.deletePendingFileUpload(id);
        continue;
      }

      try {
        debugPrint(
          "Tentative de synchronisation du téléversement de fichier: $endpoint, fichier: $filePath",
        );
        await _performActualPostMultipart(
          endpoint: endpoint,
          file: file,
          fileField: fileField,
          fields: fields,
        );
        await _databaseService.deletePendingFileUpload(id);
        debugPrint("Téléversement de fichier $id synchronisé avec succès.");
      } catch (e) {
        debugPrint(
          "Échec de la synchronisation du téléversement de fichier $id (tentative ${attempts + 1}): $e",
        );
        await _databaseService.updatePendingFileUploadAttempts(
          id,
          attempts + 1,
        );
      }
    }
    debugPrint(
      "Synchronisation des téléversements de fichiers en attente terminée.",
    );
  }

  /// Méthode interne pour effectuer réellement le postMultipart sans logique de sauvegarde offline
  Future<Map<String, dynamic>> _performActualPostMultipart({
    required String endpoint,
    required File file,
    String fileField = 'file',
    Map<String, String>? fields,
  }) async {
    final uri = _buildUri(endpoint);
    final token = await _auth0Service.getAccessToken();

    try {
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      if (fields != null) {
        request.fields.addAll(fields);
      }
      request.files.add(
        await http.MultipartFile.fromPath(fileField, file.path),
      );

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return {};
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _handleHttpError(response);
        throw Exception(
          'Erreur HTTP ${response.statusCode} lors du téléversement effectif. _handleHttpError aurait dû lever.',
        );
      }
    } on SocketException catch (e) {
      debugPrint(
        'Erreur de socket lors du téléversement effectif pour $endpoint: $e',
      );
      throw Exception(
        'Problème de connexion réseau lors du téléversement effectif pour $endpoint.',
      );
    } on TimeoutException catch (e) {
      debugPrint(
        'Délai dépassé lors du téléversement effectif pour $endpoint: $e',
      );
      throw Exception(
        'Le téléversement effectif pour $endpoint a pris trop de temps.',
      );
    } catch (e) {
      debugPrint('Erreur lors du téléversement effectif pour $endpoint: $e');
      throw Exception(
        'Une erreur s\'est produite lors du téléversement effectif pour $endpoint: $e',
      );
    }
  }

  /// Arrête la synchronisation périodique
  void dispose() {
    _syncTimer?.cancel();
  }
}
