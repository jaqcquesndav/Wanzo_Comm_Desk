import 'dart:async';
import 'package:flutter/foundation.dart';
import '../exceptions/api_exceptions.dart';
import 'api_client.dart';
import 'reauth_service.dart';

/// Intercepteur pour gérer automatiquement la ré-authentification des requêtes API
class ApiReauthInterceptor {
  final ApiClient _apiClient;
  final ReauthService _reauthService;
  final int _maxRetries;

  ApiReauthInterceptor({
    required ApiClient apiClient,
    ReauthService? reauthService,
    int maxRetries = 1,
  })  : _apiClient = apiClient,
        _reauthService = reauthService ?? ReauthService.instance,
        _maxRetries = maxRetries;

  /// Exécute une requête avec gestion automatique de ré-authentification
  Future<T> executeWithReauth<T>(
    Future<T> Function() request, {
    bool requiresAuth = false,
  }) async {
    int retryCount = 0;
    
    while (retryCount <= _maxRetries) {
      try {
        return await request();
      } on AuthenticationException {
        debugPrint('Tentative de ré-authentification automatique (tentative ${retryCount + 1}/${_maxRetries + 1})');
        
        if (retryCount >= _maxRetries) {
          // Nombre maximum de tentatives atteint
          debugPrint('Nombre maximum de tentatives de ré-authentification atteint');
          rethrow;
        }

        if (!requiresAuth) {
          // Si la requête ne nécessite pas d'authentification mais renvoie 401,
          // il y a probablement un problème plus profond
          rethrow;
        }

        // Tenter la ré-authentification
        final reauthSuccess = await _reauthService.attemptReauth();
        
        if (!reauthSuccess) {
          // La ré-authentification a échoué, propager l'exception
          debugPrint('Ré-authentification échouée');
          rethrow;
        }

        // Ré-authentification réussie, incrémenter le compteur et retenter
        retryCount++;
        debugPrint('Ré-authentification réussie, nouvelle tentative de la requête');
        
        // Petite pause avant de retenter
        await Future.delayed(Duration(milliseconds: 500));
        
      } on NetworkException catch (networkEx) {
        if (networkEx.isRetryable && retryCount < _maxRetries) {
          debugPrint('Erreur réseau récupérable, nouvelle tentative (${retryCount + 1}/${_maxRetries + 1})');
          retryCount++;
          
          // Pause progressive pour les erreurs réseau
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
        } else {
          rethrow;
        }
      } on ServerException catch (serverEx) {
        if (serverEx.isRetryable && retryCount < _maxRetries) {
          debugPrint('Erreur serveur récupérable, nouvelle tentative (${retryCount + 1}/${_maxRetries + 1})');
          retryCount++;
          
          // Pause progressive pour les erreurs serveur
          await Future.delayed(Duration(milliseconds: 2000 * retryCount));
        } else {
          rethrow;
        }
      } on RateLimitException catch (rateLimitEx) {
        if (retryCount < _maxRetries) {
          final waitTime = rateLimitEx.retryAfter ?? Duration(seconds: 60);
          debugPrint('Limite de taux atteinte, attente de ${waitTime.inSeconds} secondes');
          
          await Future.delayed(waitTime);
          retryCount++;
        } else {
          rethrow;
        }
      }
    }

    // Ce point ne devrait jamais être atteint
    throw NetworkException('Erreur inattendue dans l\'intercepteur de ré-authentification');
  }

  /// Méthode utilitaire pour les requêtes GET avec ré-authentification
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool requiresAuth = false,
  }) async {
    return executeWithReauth(
      () => _apiClient.get(endpoint, queryParameters: queryParameters, requiresAuth: requiresAuth),
      requiresAuth: requiresAuth,
    );
  }

  /// Méthode utilitaire pour les requêtes POST avec ré-authentification
  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool requiresAuth = false,
  }) async {
    return executeWithReauth(
      () => _apiClient.post(endpoint, body: body, requiresAuth: requiresAuth),
      requiresAuth: requiresAuth,
    );
  }

  /// Méthode utilitaire pour les requêtes PUT avec ré-authentification
  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    bool requiresAuth = false,
  }) async {
    return executeWithReauth(
      () => _apiClient.put(endpoint, body: body, requiresAuth: requiresAuth),
      requiresAuth: requiresAuth,
    );
  }

  /// Méthode utilitaire pour les requêtes DELETE avec ré-authentification
  Future<dynamic> delete(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    return executeWithReauth(
      () => _apiClient.delete(endpoint, requiresAuth: requiresAuth),
      requiresAuth: requiresAuth,
    );
  }
}

/// Extension pour ApiClient pour faciliter l'utilisation de l'intercepteur
extension ApiClientReauth on ApiClient {
  /// Crée un intercepteur de ré-authentification pour ce client
  ApiReauthInterceptor createInterceptor({
    ReauthService? reauthService,
    int maxRetries = 1,
  }) {
    return ApiReauthInterceptor(
      apiClient: this,
      reauthService: reauthService,
      maxRetries: maxRetries,
    );
  }
}
