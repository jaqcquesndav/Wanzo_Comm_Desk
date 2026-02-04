import 'package:flutter/foundation.dart';
import '../models/api_response.dart';
import '../exceptions/api_exceptions.dart';
import '../../features/inventory/models/product.dart';
import './api_client.dart';

class ProductApiService {
  final ApiClient _apiClient;

  ProductApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<ApiResponse<List<Product>>> getProducts({
    Map<String, String>? queryParameters,
  }) async {
    try {
      final response = await _apiClient.get(
        'products',
        queryParameters: queryParameters,
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

        // Handle paginated response: {data: [...], ...} or {items: [...], ...} or {products: [...], ...}
        List<dynamic> productsList;
        if (data is List) {
          productsList = data;
        } else if (data is Map<String, dynamic>) {
          // Try 'data' first (API response format), then 'items', then 'products'
          productsList =
              (data['data'] as List?) ??
              (data['items'] as List?) ??
              (data['products'] as List?) ??
              [];
          debugPrint(
            '📊 Products API - Extracted ${productsList.length} products from response',
          );
        } else {
          productsList = [];
        }

        final products =
            productsList
                .map(
                  (productJson) =>
                      Product.fromJson(productJson as Map<String, dynamic>),
                )
                .toList();
        return ApiResponse<List<Product>>(
          success: true,
          data: products,
          message:
              response['message'] as String? ??
              'Products fetched successfully.',
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
        'Failed to fetch products: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Product>> getProductById(String id) async {
    try {
      final response = await _apiClient.get('products/$id', requiresAuth: true);
      if (response != null && response['data'] != null) {
        final product = Product.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        return ApiResponse<Product>(
          success: true,
          data: product,
          message:
              response['message'] as String? ?? 'Product fetched successfully.',
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
        'Failed to fetch product: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Product>> createProduct(Product product) async {
    try {
      final response = await _apiClient.post(
        'products',
        body: product.toJson(),
        requiresAuth: true,
      );
      if (response != null && response['data'] != null) {
        final createdProduct = Product.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        return ApiResponse<Product>(
          success: true,
          data: createdProduct,
          message:
              response['message'] as String? ?? 'Product created successfully.',
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
        'Failed to create product: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Product>> updateProduct(String id, Product product) async {
    try {
      final response = await _apiClient.put(
        'products/$id',
        body: product.toJson(),
        requiresAuth: true,
      );
      if (response != null && response['data'] != null) {
        final updatedProduct = Product.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        return ApiResponse<Product>(
          success: true,
          data: updatedProduct,
          message:
              response['message'] as String? ?? 'Product updated successfully.',
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
        'Failed to update product: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<void>> deleteProduct(String id) async {
    try {
      final response = await _apiClient.delete(
        'products/$id',
        requiresAuth: true,
      );
      return ApiResponse<void>(
        success: true,
        message:
            response['message'] as String? ?? 'Product deleted successfully.',
        statusCode: response['statusCode'] as int? ?? 200,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to delete product: An unexpected error occurred. $e',
      );
    }
  }
}
