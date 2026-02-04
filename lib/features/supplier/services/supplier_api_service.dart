import 'package:flutter/foundation.dart';
import '../models/supplier.dart';
import '../../../core/services/api_client.dart';
import '../../../core/models/api_response.dart';

/// Service API pour les fournisseurs
abstract class SupplierApiService {
  Future<ApiResponse<List<Supplier>>> getSuppliers({
    int? page,
    int? limit,
    String? sortBy,
    String? sortOrder,
    String? searchQuery,
    // Business Unit filters conformément à la documentation API
    String? companyId,
    String? businessUnitId,
    String? businessUnitType,
  });

  Future<ApiResponse<Supplier>> createSupplier(Supplier supplier);

  Future<ApiResponse<Supplier>> getSupplierById(String id);

  Future<ApiResponse<Supplier>> updateSupplier(String id, Supplier supplier);

  Future<ApiResponse<void>> deleteSupplier(String id);

  Future<ApiResponse<List<Map<String, dynamic>>>> getSupplierPurchases(
    String id,
  );
}

class SupplierApiServiceImpl implements SupplierApiService {
  final ApiClient _apiClient;

  SupplierApiServiceImpl(this._apiClient);

  @override
  Future<ApiResponse<List<Supplier>>> getSuppliers({
    int? page,
    int? limit,
    String? sortBy,
    String? sortOrder,
    String? searchQuery,
    // Business Unit filters
    String? companyId,
    String? businessUnitId,
    String? businessUnitType,
  }) async {
    try {
      final queryParameters = <String, String>{
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (searchQuery != null) 'q': searchQuery,
        // Business Unit filter parameters
        if (companyId != null) 'companyId': companyId,
        if (businessUnitId != null) 'businessUnitId': businessUnitId,
        if (businessUnitType != null) 'businessUnitType': businessUnitType,
      };

      final response = await _apiClient.get(
        'suppliers',
        queryParameters: queryParameters,
        requiresAuth: true,
      );

      if (response != null) {
        if (response is List<dynamic>) {
          final suppliers =
              response
                  .map(
                    (json) => Supplier.fromJson(json as Map<String, dynamic>),
                  )
                  .toList();

          return ApiResponse<List<Supplier>>(
            success: true,
            data: suppliers,
            message: 'Suppliers retrieved successfully',
            statusCode: 200,
          );
        } else if (response is Map<String, dynamic> &&
            response['data'] != null) {
          // Handle nested response: {data: {suppliers: [...], ...}} or {data: [...], ...}
          var data = response['data'];
          List<dynamic> suppliersList;

          if (data is List) {
            suppliersList = data;
          } else if (data is Map<String, dynamic>) {
            suppliersList =
                (data['suppliers'] as List?) ??
                (data['data'] as List?) ??
                (data['items'] as List?) ??
                [];
            debugPrint(
              '📊 Suppliers API - Extracted ${suppliersList.length} suppliers from response',
            );
          } else {
            suppliersList = [];
          }

          final suppliers =
              suppliersList
                  .map(
                    (json) => Supplier.fromJson(json as Map<String, dynamic>),
                  )
                  .toList();

          return ApiResponse<List<Supplier>>(
            success: true,
            data: suppliers,
            message:
                response['message'] as String? ??
                'Suppliers retrieved successfully',
            statusCode: response['statusCode'] as int? ?? 200,
          );
        }
      }

      return ApiResponse<List<Supplier>>(
        success: false,
        data: [],
        message: 'Invalid response format',
        statusCode: 500,
      );
    } catch (e) {
      return ApiResponse<List<Supplier>>(
        success: false,
        data: [],
        message: 'Failed to retrieve suppliers: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<Supplier>> createSupplier(Supplier supplier) async {
    try {
      final response = await _apiClient.post(
        'suppliers',
        body: supplier.toJson(),
        requiresAuth: true,
      );

      if (response != null) {
        final Map<String, dynamic> data;
        if (response is Map<String, dynamic> && response['data'] != null) {
          data = response['data'] as Map<String, dynamic>;
        } else {
          data = response as Map<String, dynamic>;
        }

        final createdSupplier = Supplier.fromJson(data);

        return ApiResponse<Supplier>(
          success: true,
          data: createdSupplier,
          message: 'Supplier created successfully',
          statusCode: 201,
        );
      }

      return ApiResponse<Supplier>(
        success: false,
        data: null,
        message: 'Failed to create supplier: Invalid response',
        statusCode: 500,
      );
    } catch (e) {
      return ApiResponse<Supplier>(
        success: false,
        data: null,
        message: 'Failed to create supplier: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<Supplier>> getSupplierById(String id) async {
    try {
      final response = await _apiClient.get(
        'suppliers/$id',
        requiresAuth: true,
      );

      if (response != null) {
        final Map<String, dynamic> data;
        if (response is Map<String, dynamic> && response['data'] != null) {
          data = response['data'] as Map<String, dynamic>;
        } else {
          data = response as Map<String, dynamic>;
        }

        final supplier = Supplier.fromJson(data);

        return ApiResponse<Supplier>(
          success: true,
          data: supplier,
          message: 'Supplier retrieved successfully',
          statusCode: 200,
        );
      }

      return ApiResponse<Supplier>(
        success: false,
        data: null,
        message: 'Failed to retrieve supplier: Invalid response',
        statusCode: 500,
      );
    } catch (e) {
      return ApiResponse<Supplier>(
        success: false,
        data: null,
        message: 'Failed to retrieve supplier: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<Supplier>> updateSupplier(
    String id,
    Supplier supplier,
  ) async {
    try {
      // Utiliser PATCH au lieu de PUT conformément à la documentation API
      final response = await _apiClient.patch(
        'suppliers/$id',
        body: supplier.toJson(),
        requiresAuth: true,
      );

      if (response != null) {
        final Map<String, dynamic> data;
        if (response is Map<String, dynamic> && response['data'] != null) {
          data = response['data'] as Map<String, dynamic>;
        } else {
          data = response as Map<String, dynamic>;
        }

        final updatedSupplier = Supplier.fromJson(data);

        return ApiResponse<Supplier>(
          success: true,
          data: updatedSupplier,
          message: 'Supplier updated successfully',
          statusCode: 200,
        );
      }

      return ApiResponse<Supplier>(
        success: false,
        data: null,
        message: 'Failed to update supplier: Invalid response',
        statusCode: 500,
      );
    } catch (e) {
      return ApiResponse<Supplier>(
        success: false,
        data: null,
        message: 'Failed to update supplier: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<void>> deleteSupplier(String id) async {
    try {
      await _apiClient.delete('suppliers/$id', requiresAuth: true);

      return ApiResponse<void>(
        success: true,
        data: null,
        message: 'Supplier deleted successfully',
        statusCode: 200,
      );
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        data: null,
        message: 'Failed to delete supplier: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<List<Map<String, dynamic>>>> getSupplierPurchases(
    String id,
  ) async {
    try {
      final response = await _apiClient.get(
        'suppliers/$id/purchases',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final purchases =
            (response['data'] as List)
                .map((json) => json as Map<String, dynamic>)
                .toList();

        return ApiResponse<List<Map<String, dynamic>>>(
          success: true,
          data: purchases,
          message:
              response['message'] as String? ??
              'Purchases retrieved successfully',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      }

      return ApiResponse<List<Map<String, dynamic>>>(
        success: false,
        data: [],
        message: 'Failed to retrieve purchases: Invalid response format',
        statusCode: 500,
      );
    } catch (e) {
      return ApiResponse<List<Map<String, dynamic>>>(
        success: false,
        data: [],
        message: 'Failed to retrieve purchases: ${e.toString()}',
        statusCode: 500,
      );
    }
  }
}
