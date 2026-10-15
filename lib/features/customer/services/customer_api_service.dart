import 'package:flutter/foundation.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/features/customer/models/customer.dart';

/// Service API pour la gestion des clients
class CustomerApiService {
  final ApiClient _apiClient;

  CustomerApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Récupère tous les clients avec pagination et recherche
  Future<ApiResponse<List<Customer>>> getCustomers({
    int? page,
    int? limit,
    String? search,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final Map<String, String> queryParams = {};
      if (page != null) queryParams['page'] = page.toString();
      if (limit != null) queryParams['limit'] = limit.toString();
      if (search != null) queryParams['search'] = search;
      if (sortBy != null) queryParams['sortBy'] = sortBy;
      if (sortOrder != null) queryParams['sortOrder'] = sortOrder;

      final response = await _apiClient.get(
        'customers',
        queryParameters: queryParams,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        var data = response['data'];

        // Handle nested response structure: { data: { customers: [...], ... } }
        List<dynamic> customersList;
        if (data is List) {
          customersList = data;
        } else if (data is Map<String, dynamic>) {
          // Try 'customers' first (API response format), then 'items', then 'data'
          customersList =
              (data['customers'] as List?) ??
              (data['items'] as List?) ??
              (data['data'] as List?) ??
              [];
          debugPrint(
            '📊 Features/Customers API - Extracted ${customersList.length} customers from response',
          );
        } else {
          customersList = [];
        }

        final customers =
            customersList
                .map((json) => Customer.fromJson(json as Map<String, dynamic>))
                .toList();

        return ApiResponse<List<Customer>>(
          success: true,
          data: customers,
          message:
              response['message'] as String? ?? 'Clients récupérés avec succès',
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
      throw ServerException('Échec de la récupération des clients: $e');
    }
  }

  /// Crée un nouveau client
  Future<ApiResponse<Customer>> createCustomer(Customer customer) async {
    try {
      final response = await _apiClient.post(
        'customers',
        body: customer.toJson(),
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final createdCustomer = Customer.fromJson(
          response['data'] as Map<String, dynamic>,
        );

        return ApiResponse<Customer>(
          success: true,
          data: createdCustomer,
          message: response['message'] as String? ?? 'Client créé avec succès',
          statusCode: response['statusCode'] as int? ?? 201,
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
      throw ServerException('Échec de la création du client: $e');
    }
  }

  /// Récupère un client par son ID
  Future<ApiResponse<Customer>> getCustomerById(String id) async {
    try {
      final response = await _apiClient.get(
        'customers/$id',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final customer = Customer.fromJson(
          response['data'] as Map<String, dynamic>,
        );

        return ApiResponse<Customer>(
          success: true,
          data: customer,
          message:
              response['message'] as String? ?? 'Client récupéré avec succès',
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
      throw ServerException('Échec de la récupération du client: $e');
    }
  }

  /// Met à jour un client
  Future<ApiResponse<Customer>> updateCustomer(
    String id,
    Customer customer,
  ) async {
    try {
      final response = await _apiClient.patch(
        'customers/$id',
        body: customer.toJson(),
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final updatedCustomer = Customer.fromJson(
          response['data'] as Map<String, dynamic>,
        );

        return ApiResponse<Customer>(
          success: true,
          data: updatedCustomer,
          message:
              response['message'] as String? ?? 'Client mis à jour avec succès',
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
      throw ServerException('Échec de la mise à jour du client: $e');
    }
  }

  /// Supprime un client (soft delete)
  Future<ApiResponse<void>> deleteCustomer(String id) async {
    try {
      final response = await _apiClient.delete(
        'customers/$id',
        requiresAuth: true,
        // Suppression confirmée par le serveur, jamais rejouée à l'insu.
        queueOffline: false,
      );

      return ApiResponse<void>(
        success: true,
        data: null,
        message:
            response?['message'] as String? ?? 'Client supprimé avec succès',
        statusCode: response?['statusCode'] as int? ?? 200,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec de la suppression du client: $e');
    }
  }

  /// Récupère l'historique des ventes d'un client
  Future<ApiResponse<List<Map<String, dynamic>>>> getCustomerSales(
    String customerId,
  ) async {
    try {
      final response = await _apiClient.get(
        'customers/$customerId/sales',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final sales =
            (response['data'] as List)
                .map((json) => json as Map<String, dynamic>)
                .toList();

        return ApiResponse<List<Map<String, dynamic>>>(
          success: true,
          data: sales,
          message:
              response['message'] as String? ??
              'Historique des ventes récupéré avec succès',
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
      throw ServerException(
        'Échec de la récupération de l\'historique des ventes: $e',
      );
    }
  }

  /// Récupère l'historique des paiements d'un client
  Future<ApiResponse<List<Map<String, dynamic>>>> getCustomerPayments(
    String customerId,
  ) async {
    try {
      final response = await _apiClient.get(
        'customers/$customerId/payments',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final payments =
            (response['data'] as List)
                .map((json) => json as Map<String, dynamic>)
                .toList();

        return ApiResponse<List<Map<String, dynamic>>>(
          success: true,
          data: payments,
          message:
              response['message'] as String? ??
              'Historique des paiements récupéré avec succès',
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
      throw ServerException(
        'Échec de la récupération de l\'historique des paiements: $e',
      );
    }
  }

  /// Synchronise les clients locaux avec le serveur
  Future<ApiResponse<List<Customer>>> syncCustomers(
    List<Customer> localCustomers,
  ) async {
    try {
      final response = await _apiClient.post(
        'customers/sync',
        body: {
          'customers':
              localCustomers.map((customer) => customer.toJson()).toList(),
        },
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final syncedCustomers =
            (response['data'] as List)
                .map((json) => Customer.fromJson(json as Map<String, dynamic>))
                .toList();

        return ApiResponse<List<Customer>>(
          success: true,
          data: syncedCustomers,
          message:
              response['message'] as String? ??
              'Clients synchronisés avec succès',
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
      throw ServerException('Échec de la synchronisation des clients: $e');
    }
  }

  /// Récupère les statistiques d'un client
  Future<ApiResponse<Map<String, dynamic>>> getCustomerStats(
    String customerId,
  ) async {
    try {
      final response = await _apiClient.get(
        'customers/$customerId/stats',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response['data'] as Map<String, dynamic>,
          message:
              response['message'] as String? ??
              'Statistiques récupérées avec succès',
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
      throw ServerException('Échec de la récupération des statistiques: $e');
    }
  }
}
