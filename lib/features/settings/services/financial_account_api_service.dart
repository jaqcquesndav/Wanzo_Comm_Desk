import 'package:flutter/foundation.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/services/api_client.dart';
import '../models/financial_account.dart';

/// Service API pour la gestion des comptes financiers
class FinancialAccountApiService {
  final ApiClient _apiClient;

  FinancialAccountApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Utilitaire pour extraire les données de la réponse API (gère les structures imbriquées)
  dynamic _extractData(Map<String, dynamic>? response) {
    if (response == null) return null;

    debugPrint(
      '💳 [FinancialAccountApiService] Extracting data from response...',
    );
    debugPrint(
      '💳 [FinancialAccountApiService] Response keys: ${response.keys.toList()}',
    );

    // Cas 1: {data: {...}} ou {data: [...]}
    if (response.containsKey('data')) {
      final data = response['data'];
      debugPrint(
        '💳 [FinancialAccountApiService] Found "data" key, type: ${data.runtimeType}',
      );

      // Cas 1.1: {data: {data: {...}}} - double imbrication
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        debugPrint(
          '💳 [FinancialAccountApiService] Found nested "data.data", extracting...',
        );
        return data['data'];
      }
      return data;
    }

    // Cas 2: Réponse directe sans wrapper
    debugPrint(
      '💳 [FinancialAccountApiService] No "data" wrapper, returning raw response',
    );
    return response;
  }

  /// Récupérer tous les comptes financiers de l'utilisateur
  Future<ApiResponse<List<FinancialAccount>>> getFinancialAccounts({
    int? page,
    int? limit,
    FinancialAccountType? type,
  }) async {
    try {
      final Map<String, String> queryParams = {};
      if (page != null) queryParams['page'] = page.toString();
      if (limit != null) queryParams['limit'] = limit.toString();
      if (type != null) queryParams['type'] = type.name;

      debugPrint('💳 [FinancialAccountApiService] GET financial-accounts');
      debugPrint('💳 [FinancialAccountApiService] Query params: $queryParams');

      final response = await _apiClient.get(
        'financial-accounts',
        queryParameters: queryParams,
        requiresAuth: true,
        includeBusinessContext:
            true, // Inclure companyId/businessUnitId pour isolation multi-tenant
      );

      debugPrint('💳 [FinancialAccountApiService] Response: $response');

      if (response != null) {
        final data = _extractData(response as Map<String, dynamic>);

        // Handle nested response structure
        List<dynamic> accountsList;
        if (data is List) {
          accountsList = data;
          debugPrint(
            '💳 [FinancialAccountApiService] Data is a List with ${accountsList.length} items',
          );
        } else if (data is Map<String, dynamic>) {
          // Try 'accounts' first, then 'data', then 'items'
          accountsList =
              (data['accounts'] as List?) ??
              (data['data'] as List?) ??
              (data['items'] as List?) ??
              [];
          debugPrint(
            '💳 [FinancialAccountApiService] Extracted ${accountsList.length} accounts from nested structure',
          );
        } else {
          debugPrint(
            '💳 [FinancialAccountApiService] WARNING: Unexpected data format: ${data.runtimeType}',
          );
          accountsList = [];
        }

        debugPrint(
          '💳 [FinancialAccountApiService] Parsing ${accountsList.length} accounts...',
        );
        final accounts = <FinancialAccount>[];

        for (var i = 0; i < accountsList.length; i++) {
          try {
            final json = accountsList[i] as Map<String, dynamic>;
            debugPrint(
              '💳 [FinancialAccountApiService] Account [$i] raw: $json',
            );
            final account = FinancialAccount.fromJson(json);
            debugPrint(
              '💳 [FinancialAccountApiService] Account [$i] parsed: ${account.accountName}',
            );
            accounts.add(account);
          } catch (e) {
            debugPrint(
              '💳 [FinancialAccountApiService] ERROR parsing account [$i]: $e',
            );
          }
        }

        return ApiResponse<List<FinancialAccount>>(
          success: true,
          data: accounts,
          message:
              response['message'] as String? ??
              'Comptes financiers récupérés avec succès',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        debugPrint('💳 [FinancialAccountApiService] ERROR: Response is null');
        throw ApiExceptionFactory.fromStatusCode(
          500,
          'Format de réponse invalide du serveur',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('💳 [FinancialAccountApiService] EXCEPTION: $e');
      throw ServerException(
        'Échec de la récupération des comptes financiers: $e',
      );
    }
  }

  /// Créer un nouveau compte financier
  Future<ApiResponse<FinancialAccount>> createFinancialAccount(
    FinancialAccount account,
  ) async {
    try {
      final body = account.toJson();
      debugPrint('💳 [FinancialAccountApiService] POST financial-accounts');
      debugPrint('💳 [FinancialAccountApiService] Request body: $body');

      // Mise en file hors ligne permise : le serveur est idempotent sur l'id
      // attribué par l'app, un rejeu ne crée jamais de doublon.
      final response = await _apiClient.post(
        'financial-accounts',
        body: body,
        requiresAuth: true,
      );

      debugPrint('💳 [FinancialAccountApiService] Response: $response');

      if (response != null) {
        final data = _extractData(response as Map<String, dynamic>);

        if (data is Map<String, dynamic>) {
          debugPrint(
            '💳 [FinancialAccountApiService] Parsing created account...',
          );
          final createdAccount = FinancialAccount.fromJson(data);
          debugPrint(
            '💳 [FinancialAccountApiService] Created account: ${createdAccount.accountName}',
          );

          return ApiResponse<FinancialAccount>(
            success: true,
            data: createdAccount,
            message:
                response['message'] as String? ??
                'Compte financier créé avec succès',
            statusCode: response['statusCode'] as int? ?? 201,
          );
        }
      }

      throw ApiExceptionFactory.fromStatusCode(
        response?['statusCode'] as int? ?? 500,
        'Format de réponse invalide du serveur',
        responseBody: response,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('💳 [FinancialAccountApiService] EXCEPTION: $e');
      throw ServerException('Échec de la création du compte financier: $e');
    }
  }

  /// Récupérer un compte financier par son ID
  Future<ApiResponse<FinancialAccount>> getFinancialAccountById(
    String id,
  ) async {
    try {
      debugPrint('💳 [FinancialAccountApiService] GET financial-accounts/$id');

      final response = await _apiClient.get(
        'financial-accounts/$id',
        requiresAuth: true,
      );

      debugPrint('💳 [FinancialAccountApiService] Response: $response');

      if (response != null) {
        final data = _extractData(response as Map<String, dynamic>);

        if (data is Map<String, dynamic>) {
          final account = FinancialAccount.fromJson(data);
          debugPrint(
            '💳 [FinancialAccountApiService] Retrieved account: ${account.accountName}',
          );

          return ApiResponse<FinancialAccount>(
            success: true,
            data: account,
            message:
                response['message'] as String? ??
                'Compte financier récupéré avec succès',
            statusCode: response['statusCode'] as int? ?? 200,
          );
        }
      }

      throw ApiExceptionFactory.fromStatusCode(
        response?['statusCode'] as int? ?? 500,
        'Format de réponse invalide du serveur',
        responseBody: response,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('💳 [FinancialAccountApiService] EXCEPTION: $e');
      throw ServerException('Échec de la récupération du compte financier: $e');
    }
  }

  /// Mettre à jour un compte financier
  Future<ApiResponse<FinancialAccount>> updateFinancialAccount(
    String id,
    FinancialAccount account,
  ) async {
    try {
      final body = account.toJson();
      debugPrint('💳 [FinancialAccountApiService] PUT financial-accounts/$id');
      debugPrint('💳 [FinancialAccountApiService] Request body: $body');

      final response = await _apiClient.put(
        'financial-accounts/$id',
        body: body,
        requiresAuth: true,
      );

      debugPrint('💳 [FinancialAccountApiService] Response: $response');

      if (response != null) {
        final data = _extractData(response as Map<String, dynamic>);

        if (data is Map<String, dynamic>) {
          final updatedAccount = FinancialAccount.fromJson(data);
          debugPrint(
            '💳 [FinancialAccountApiService] Updated account: ${updatedAccount.accountName}',
          );

          return ApiResponse<FinancialAccount>(
            success: true,
            data: updatedAccount,
            message:
                response['message'] as String? ??
                'Compte financier mis à jour avec succès',
            statusCode: response['statusCode'] as int? ?? 200,
          );
        }
      }

      throw ApiExceptionFactory.fromStatusCode(
        response?['statusCode'] as int? ?? 500,
        'Format de réponse invalide du serveur',
        responseBody: response,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('💳 [FinancialAccountApiService] EXCEPTION: $e');
      throw ServerException('Échec de la mise à jour du compte financier: $e');
    }
  }

  /// Supprimer un compte financier
  Future<ApiResponse<void>> deleteFinancialAccount(String id) async {
    try {
      debugPrint(
        '💳 [FinancialAccountApiService] DELETE financial-accounts/$id',
      );

      final response = await _apiClient.delete(
        'financial-accounts/$id',
        requiresAuth: true,
      );

      debugPrint('💳 [FinancialAccountApiService] Response: $response');

      return ApiResponse<void>(
        success: true,
        data: null,
        message:
            response?['message'] as String? ??
            'Compte financier supprimé avec succès',
        statusCode: response?['statusCode'] as int? ?? 200,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('💳 [FinancialAccountApiService] EXCEPTION: $e');
      throw ServerException('Échec de la suppression du compte financier: $e');
    }
  }

  /// Définir un compte comme compte par défaut
  Future<ApiResponse<FinancialAccount>> setDefaultAccount(String id) async {
    try {
      debugPrint(
        '💳 [FinancialAccountApiService] PUT financial-accounts/$id/set-default',
      );

      final response = await _apiClient.put(
        'financial-accounts/$id/set-default',
        requiresAuth: true,
      );

      debugPrint('💳 [FinancialAccountApiService] Response: $response');

      if (response != null) {
        final data = _extractData(response as Map<String, dynamic>);

        if (data is Map<String, dynamic>) {
          final updatedAccount = FinancialAccount.fromJson(data);
          debugPrint(
            '💳 [FinancialAccountApiService] Set default account: ${updatedAccount.accountName}',
          );

          return ApiResponse<FinancialAccount>(
            success: true,
            data: updatedAccount,
            message:
                response['message'] as String? ??
                'Compte par défaut défini avec succès',
            statusCode: response['statusCode'] as int? ?? 200,
          );
        }
      }

      throw ApiExceptionFactory.fromStatusCode(
        response?['statusCode'] as int? ?? 500,
        'Format de réponse invalide du serveur',
        responseBody: response,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('💳 [FinancialAccountApiService] EXCEPTION: $e');
      throw ServerException('Échec de la définition du compte par défaut: $e');
    }
  }

  /// Synchroniser les comptes locaux avec le serveur
  Future<ApiResponse<List<FinancialAccount>>> syncAccounts(
    List<FinancialAccount> localAccounts,
  ) async {
    try {
      final body = {
        'accounts': localAccounts.map((account) => account.toJson()).toList(),
      };
      debugPrint(
        '💳 [FinancialAccountApiService] POST financial-accounts/sync',
      );
      debugPrint(
        '💳 [FinancialAccountApiService] Syncing ${localAccounts.length} accounts',
      );

      // Jamais mise en file : la synchronisation est relancée à chaque
      // chargement et au retour du réseau, un rejeu différé ferait doublon.
      final response = await _apiClient.post(
        'financial-accounts/sync',
        body: body,
        requiresAuth: true,
        queueOffline: false,
      );

      debugPrint('💳 [FinancialAccountApiService] Response: $response');

      if (response != null) {
        final data = _extractData(response as Map<String, dynamic>);

        List<dynamic> accountsList;
        if (data is List) {
          accountsList = data;
        } else if (data is Map<String, dynamic>) {
          accountsList =
              (data['accounts'] as List?) ??
              (data['data'] as List?) ??
              (data['items'] as List?) ??
              [];
        } else {
          accountsList = [];
        }

        debugPrint(
          '💳 [FinancialAccountApiService] Synced ${accountsList.length} accounts from server',
        );

        final syncedAccounts = <FinancialAccount>[];
        for (var i = 0; i < accountsList.length; i++) {
          try {
            final json = accountsList[i] as Map<String, dynamic>;
            final account = FinancialAccount.fromJson(json);
            syncedAccounts.add(account);
          } catch (e) {
            debugPrint(
              '💳 [FinancialAccountApiService] ERROR parsing synced account [$i]: $e',
            );
          }
        }

        return ApiResponse<List<FinancialAccount>>(
          success: true,
          data: syncedAccounts,
          message:
              response['message'] as String? ??
              'Comptes synchronisés avec succès',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      }

      throw ApiExceptionFactory.fromStatusCode(
        500,
        'Format de réponse invalide du serveur',
        responseBody: response,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('💳 [FinancialAccountApiService] EXCEPTION: $e');
      throw ServerException('Échec de la synchronisation des comptes: $e');
    }
  }
}
