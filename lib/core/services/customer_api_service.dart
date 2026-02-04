import 'package:flutter/foundation.dart';
import '../models/api_response.dart';
import '../exceptions/api_exceptions.dart';
import '../../features/customer/models/customer.dart';
import './api_client.dart';

class CustomerApiService {
  final ApiClient _apiClient;

  CustomerApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<ApiResponse<List<Customer>>> getCustomers({
    Map<String, String>? queryParams,
  }) async {
    try {
      final response = await _apiClient.get(
        'customers',
        queryParameters: queryParams,
        requiresAuth: true,
      );
      if (response != null && response['data'] != null) {
        var data = response['data'];

        // Handle double-envelope response: {success, data: {success, data: ...}}
        if (data is Map<String, dynamic> &&
            data.containsKey('success') &&
            data.containsKey('data')) {
          data = data['data'];
        }

        // Handle paginated response: {customers: [...], ...} or {items: [...], ...} or {data: [...], ...}
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
            '📊 Customers API - Extracted ${customersList.length} customers from response',
          );
        } else {
          customersList = [];
        }

        final customers =
            customersList
                .map(
                  (customerJson) =>
                      Customer.fromJson(customerJson as Map<String, dynamic>),
                )
                .toList();
        return ApiResponse<List<Customer>>(
          success: true,
          data: customers,
          message:
              response['message'] as String? ??
              'Customers fetched successfully.',
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
        'Failed to fetch customers: An unexpected error occurred. $e',
      );
    }
  }

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
              response['message'] as String? ??
              'Customer fetched successfully.',
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
        'Failed to fetch customer: An unexpected error occurred. $e',
      );
    }
  }

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
          message:
              response['message'] as String? ??
              'Customer created successfully.',
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
        'Failed to create customer: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Customer>> updateCustomer(
    String id,
    Customer customer,
  ) async {
    try {
      final response = await _apiClient.put(
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
              response['message'] as String? ??
              'Customer updated successfully.',
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
        'Failed to update customer: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<void>> deleteCustomer(String id) async {
    try {
      final response = await _apiClient.delete(
        'customers/$id',
        requiresAuth: true,
      );
      return ApiResponse<void>(
        success: true,
        message:
            response['message'] as String? ?? 'Customer deleted successfully.',
        statusCode: response['statusCode'] as int? ?? 200,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to delete customer: An unexpected error occurred. $e',
      );
    }
  }
}
