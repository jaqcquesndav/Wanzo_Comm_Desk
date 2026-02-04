import 'package:flutter/foundation.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/features/operations/models/operation.dart';

/// Service API pour la gestion centralisée des opérations
class OperationsApiService {
  final ApiClient _apiClient;

  OperationsApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Récupère la liste des opérations avec filtrage
  Future<ApiResponse<List<Operation>>> getOperations({
    OperationType? type,
    DateTime? startDate,
    DateTime? endDate,
    String? relatedPartyId,
    String? status,
    double? minAmount,
    double? maxAmount,
    String? sortBy,
    String? sortOrder,
    int? page,
    int? limit,
  }) async {
    try {
      final Map<String, String> queryParams = {};
      if (type != null) queryParams['type'] = type.name;
      if (startDate != null) {
        queryParams['dateFrom'] = startDate.toIso8601String();
      }
      if (endDate != null) queryParams['dateTo'] = endDate.toIso8601String();
      if (relatedPartyId != null) {
        queryParams['relatedPartyId'] = relatedPartyId;
      }
      if (status != null) queryParams['status'] = status;
      if (minAmount != null) queryParams['minAmount'] = minAmount.toString();
      if (maxAmount != null) queryParams['maxAmount'] = maxAmount.toString();
      if (sortBy != null) queryParams['sortBy'] = sortBy;
      if (sortOrder != null) queryParams['sortOrder'] = sortOrder;
      if (page != null) queryParams['page'] = page.toString();
      if (limit != null) queryParams['limit'] = limit.toString();

      final response = await _apiClient.get(
        'operations',
        queryParameters: queryParams,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        var data = response['data'];

        // Handle nested response structure
        List<dynamic> operationsList;
        if (data is List) {
          operationsList = data;
        } else if (data is Map<String, dynamic>) {
          // Try 'operations' first, then 'data', then 'items'
          operationsList =
              (data['operations'] as List?) ??
              (data['data'] as List?) ??
              (data['items'] as List?) ??
              [];
          debugPrint(
            '📊 Operations API - Extracted ${operationsList.length} operations from response',
          );
        } else {
          operationsList = [];
        }

        final operations =
            operationsList
                .map((json) => Operation.fromJson(json as Map<String, dynamic>))
                .toList();

        return ApiResponse<List<Operation>>(
          success: true,
          data: operations,
          message:
              response['message'] as String? ??
              'Opérations récupérées avec succès',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response?['statusCode'] as int? ?? 500,
          'Format de réponse invalide du serveur',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec de la récupération des opérations: $e');
    }
  }

  /// Récupère le résumé des opérations par période
  Future<ApiResponse<Map<String, dynamic>>> getOperationsSummary({
    required String period, // 'day', 'week', 'month', 'year'
    DateTime? date,
  }) async {
    try {
      final Map<String, String> queryParams = {'period': period};
      if (date != null) queryParams['date'] = date.toIso8601String();

      final response = await _apiClient.get(
        'operations/summary',
        queryParameters: queryParams,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response['data'] as Map<String, dynamic>,
          message:
              response['message'] as String? ?? 'Résumé récupéré avec succès',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response?['statusCode'] as int? ?? 500,
          'Format de réponse invalide du serveur',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec de la récupération du résumé: $e');
    }
  }

  /// Exporte des opérations en PDF ou Excel
  Future<ApiResponse<Map<String, dynamic>>> exportOperations({
    OperationType? type,
    required DateTime startDate,
    required DateTime endDate,
    String? relatedPartyId,
    String? status,
    required String format, // 'pdf' ou 'excel'
    bool includeDetails = true,
    String? groupBy, // 'date', 'type', 'party'
  }) async {
    try {
      final Map<String, dynamic> body = {
        'dateFrom': startDate.toIso8601String(),
        'dateTo': endDate.toIso8601String(),
        'format': format,
        'includeDetails': includeDetails,
      };

      if (type != null) body['type'] = type.name;
      if (relatedPartyId != null) body['relatedPartyId'] = relatedPartyId;
      if (status != null) body['status'] = status;
      if (groupBy != null) body['groupBy'] = groupBy;

      final response = await _apiClient.post(
        'operations/export',
        body: body,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response['data'] as Map<String, dynamic>,
          message:
              response['message'] as String? ?? 'Export généré avec succès',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response?['statusCode'] as int? ?? 500,
          'Format de réponse invalide du serveur',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec de l\'export des opérations: $e');
    }
  }

  /// Récupère les détails d'une opération spécifique
  Future<ApiResponse<Operation>> getOperationById(String id) async {
    try {
      final response = await _apiClient.get(
        'operations/$id',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final operation = Operation.fromJson(
          response['data'] as Map<String, dynamic>,
        );

        return ApiResponse<Operation>(
          success: true,
          data: operation,
          message:
              response['message'] as String? ??
              'Opération récupérée avec succès',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response?['statusCode'] as int? ?? 500,
          'Format de réponse invalide du serveur',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec de la récupération de l\'opération: $e');
    }
  }

  /// Récupère la timeline des opérations récentes
  Future<ApiResponse<List<Map<String, dynamic>>>> getOperationsTimeline({
    int limit = 10,
  }) async {
    try {
      final Map<String, String> queryParams = {'limit': limit.toString()};

      final response = await _apiClient.get(
        'operations/timeline',
        queryParameters: queryParams,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final timeline =
            (response['data'] as List)
                .map((json) => json as Map<String, dynamic>)
                .toList();

        return ApiResponse<List<Map<String, dynamic>>>(
          success: true,
          data: timeline,
          message:
              response['message'] as String? ??
              'Timeline récupérée avec succès',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response?['statusCode'] as int? ?? 500,
          'Format de réponse invalide du serveur',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec de la récupération de la timeline: $e');
    }
  }
}
