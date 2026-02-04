import 'package:flutter/foundation.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/features/transactions/models/financial_transaction.dart'; // Assurez-vous que ce modèle existe

class FinancialTransactionApiService {
  final ApiClient _apiClient;

  FinancialTransactionApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<ApiResponse<List<FinancialTransaction>>> getFinancialTransactions({
    int? page,
    int? limit,
    String? dateFrom,
    String? dateTo,
    String? type,
    String? status,
    String? paymentMethodId,
  }) async {
    try {
      final Map<String, String> queryParams = {};
      if (page != null) queryParams['page'] = page.toString();
      if (limit != null) queryParams['limit'] = limit.toString();
      if (dateFrom != null) queryParams['dateFrom'] = dateFrom;
      if (dateTo != null) queryParams['dateTo'] = dateTo;
      if (type != null) queryParams['type'] = type;
      if (status != null) queryParams['status'] = status;
      if (paymentMethodId != null) {
        queryParams['paymentMethodId'] = paymentMethodId;
      }

      final response = await _apiClient.get(
        'financial-transactions',
        queryParameters: queryParams,
        requiresAuth: true,
      );
      if (response != null && response['data'] != null) {
        var data = response['data'];

        // Handle nested response structure
        List<dynamic> transactionsList;
        if (data is List) {
          transactionsList = data;
        } else if (data is Map<String, dynamic>) {
          // Try 'transactions' first, then 'data', then 'items'
          transactionsList =
              (data['transactions'] as List?) ??
              (data['data'] as List?) ??
              (data['items'] as List?) ??
              [];
          debugPrint(
            '📊 Transactions API - Extracted ${transactionsList.length} transactions from response',
          );
        } else {
          transactionsList = [];
        }

        final transactions =
            transactionsList
                .map(
                  (transJson) => FinancialTransaction.fromJson(
                    transJson as Map<String, dynamic>,
                  ),
                )
                .toList();
        return ApiResponse<List<FinancialTransaction>>(
          success: true,
          data: transactions,
          message:
              response['message'] as String? ??
              'Financial transactions fetched successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
          // paginationInfo: response['pagination'] // Si l'API retourne des infos de pagination
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Invalid response data format from server',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to fetch financial transactions: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<FinancialTransaction>> createFinancialTransaction(
    FinancialTransaction transaction,
  ) async {
    try {
      final response = await _apiClient.post(
        'financial-transactions',
        body: transaction.toJson(),
        requiresAuth: true,
      );
      if (response != null && response['data'] != null) {
        final createdTransaction = FinancialTransaction.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        return ApiResponse<FinancialTransaction>(
          success: true,
          data: createdTransaction,
          message:
              response['message'] as String? ??
              'Financial transaction created successfully.',
          statusCode: response['statusCode'] as int? ?? 201,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Invalid response data format from server',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to create financial transaction: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<FinancialTransaction>> getFinancialTransactionById(
    String id,
  ) async {
    try {
      final response = await _apiClient.get(
        'financial-transactions/$id',
        requiresAuth: true,
      );
      if (response != null && response['data'] != null) {
        final transaction = FinancialTransaction.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        return ApiResponse<FinancialTransaction>(
          success: true,
          data: transaction,
          message:
              response['message'] as String? ??
              'Financial transaction fetched successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Invalid response data format from server',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to fetch financial transaction: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<FinancialTransaction>> updateFinancialTransaction(
    String id,
    FinancialTransaction transaction,
  ) async {
    try {
      // Utiliser PATCH au lieu de PUT conformément à la documentation API
      final response = await _apiClient.patch(
        'financial-transactions/$id',
        body: transaction.toJson(),
        requiresAuth: true,
      );
      if (response != null && response['data'] != null) {
        final updatedTransaction = FinancialTransaction.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        return ApiResponse<FinancialTransaction>(
          success: true,
          data: updatedTransaction,
          message:
              response['message'] as String? ??
              'Financial transaction updated successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Invalid response data format from server',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to update financial transaction: An unexpected error occurred. $e',
      );
    }
  }

  /// Supprime une transaction financière
  /// Documentation API: DELETE /commerce/api/v1/financial-transactions/{id}
  Future<ApiResponse<void>> deleteFinancialTransaction(String id) async {
    try {
      final response = await _apiClient.delete(
        'financial-transactions/$id',
        requiresAuth: true,
      );
      return ApiResponse<void>(
        success: true,
        data: null,
        message:
            response?['message'] as String? ??
            'Financial transaction deleted successfully.',
        statusCode: response?['statusCode'] as int? ?? 200,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to delete financial transaction: An unexpected error occurred. $e',
      );
    }
  }

  /// Récupère le résumé des transactions financières
  /// Documentation API: GET /commerce/api/v1/financial-transactions/summary
  Future<ApiResponse<Map<String, dynamic>>> getFinancialTransactionsSummary({
    String? startDate,
    String? endDate,
    List<String>? transactionTypes,
    List<String>? statuses,
    String? customerId,
    String? supplierId,
    String? businessUnitId,
  }) async {
    try {
      final Map<String, String> queryParams = {};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (transactionTypes != null && transactionTypes.isNotEmpty) {
        for (int i = 0; i < transactionTypes.length; i++) {
          queryParams['transactionTypes[$i]'] = transactionTypes[i];
        }
      }
      if (statuses != null && statuses.isNotEmpty) {
        for (int i = 0; i < statuses.length; i++) {
          queryParams['statuses[$i]'] = statuses[i];
        }
      }
      if (customerId != null) queryParams['customerId'] = customerId;
      if (supplierId != null) queryParams['supplierId'] = supplierId;
      if (businessUnitId != null) {
        queryParams['businessUnitId'] = businessUnitId;
      }

      final response = await _apiClient.get(
        'financial-transactions/summary',
        queryParameters: queryParams,
        requiresAuth: true,
      );
      if (response != null && response['data'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response['data'] as Map<String, dynamic>,
          message:
              response['message'] as String? ??
              'Transaction summary fetched successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Invalid response data format from server',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to fetch transaction summary: An unexpected error occurred. $e',
      );
    }
  }

  /// Met à jour le statut d'une transaction
  /// Documentation API: PATCH /commerce/api/v1/financial-transactions/{id}/status
  Future<ApiResponse<FinancialTransaction>> updateTransactionStatus(
    String id,
    TransactionStatus newStatus,
  ) async {
    try {
      final response = await _apiClient.patch(
        'financial-transactions/$id/status',
        body: {'status': newStatus.apiValue},
        requiresAuth: true,
      );
      if (response != null && response['data'] != null) {
        final updatedTransaction = FinancialTransaction.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        return ApiResponse<FinancialTransaction>(
          success: true,
          data: updatedTransaction,
          message:
              response['message'] as String? ??
              'Transaction status updated successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Invalid response data format from server',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to update transaction status: An unexpected error occurred. $e',
      );
    }
  }
}
