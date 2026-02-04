import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/models/api_response.dart'; // Ajout de l'import
import 'package:wanzo/features/inventory/models/product.dart';
import 'package:wanzo/features/inventory/models/stock_transaction.dart';

abstract class InventoryApiService {
  Future<ApiResponse<List<Product>>> getProducts({
    int? page,
    int? limit,
    String? category,
    String? sortBy,
    String? sortOrder,
    String? searchQuery,
  });

  Future<ApiResponse<Product>> createProduct(Product product, {File? image});

  Future<ApiResponse<Product>> getProductById(String id);

  Future<ApiResponse<Product>> updateProduct(
    String id,
    Product product, {
    File? image,
    bool? removeImage,
  });

  Future<ApiResponse<void>> deleteProduct(String id);

  Future<ApiResponse<List<StockTransaction>>> getStockTransactions({
    String? productId,
    int? page,
    int? limit,
    StockTransactionType? type,
    String? dateFrom,
    String? dateTo,
  });

  Future<ApiResponse<StockTransaction>> createStockTransaction(
    StockTransaction transaction,
  );

  Future<ApiResponse<StockTransaction>> getStockTransactionById(String id);

  // Future<ApiResponse<StockTransaction>> updateStockTransaction(String id, StockTransaction transaction); // Usually not updated
  // Future<ApiResponse<void>> deleteStockTransaction(String id); // Usually not deleted
}

class InventoryApiServiceImpl implements InventoryApiService {
  final ApiClient _apiClient;

  InventoryApiServiceImpl(this._apiClient);
  @override
  Future<ApiResponse<List<Product>>> getProducts({
    int? page,
    int? limit,
    String? category,
    String? sortBy,
    String? sortOrder,
    String? searchQuery,
  }) async {
    try {
      final queryParameters = <String, String>{
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
        if (category != null) 'category': category,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (searchQuery != null) 'q': searchQuery,
      };
      final response = await _apiClient.get(
        'products',
        queryParameters: queryParameters,
        requiresAuth: true,
      );
      // Gérer les différents formats de réponse
      List<dynamic> data;
      if (response is List) {
        data = response;
      } else if (response is Map) {
        var responseData = response['data'];

        // Handle double-envelope response: {success, data: {success, data: ...}}
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('success') &&
            responseData.containsKey('data')) {
          responseData = responseData['data'];
        }

        // Handle paginated response: {items: [...], meta: {...}} or {data: [...]} or {products: [...]}
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map<String, dynamic>) {
          data =
              (responseData['data'] as List?) ??
              (responseData['products'] as List?) ??
              (responseData['items'] as List?) ??
              [];
        } else {
          data = [];
        }
      } else {
        data = [];
      }
      final products =
          data
              .map((json) => Product.fromJson(json as Map<String, dynamic>))
              .toList();

      return ApiResponse<List<Product>>(
        success: true,
        data: products,
        message: 'Products fetched successfully',
        statusCode: 200,
      );
    } on ApiException catch (e) {
      return ApiResponse<List<Product>>(
        success: false,
        data: null,
        message: e.message,
        statusCode: e.statusCode ?? 500,
      );
    } catch (e) {
      return ApiResponse<List<Product>>(
        success: false,
        data: null,
        message: 'Failed to fetch products: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<Product>> createProduct(
    Product product, {
    File? image,
  }) async {
    try {
      // Si une image est fournie, utiliser multipart
      if (image != null) {
        return _createProductWithImage(product, image);
      }

      // Sinon, utiliser une requête JSON standard
      final response = await _apiClient.post(
        'products',
        body: product.toJson(),
        requiresAuth: true,
      );

      // Gérer les différents formats de réponse
      Map<String, dynamic>? productJson;
      if (response is Map<String, dynamic>) {
        // Format: {success, data: {...product...}} ou {success, data: {data: {...product...}}}
        if (response['data'] != null) {
          final data = response['data'];
          if (data is Map<String, dynamic>) {
            // Vérifier si c'est un double-envelope
            if (data.containsKey('data') &&
                data['data'] is Map<String, dynamic>) {
              productJson = data['data'] as Map<String, dynamic>;
            } else {
              productJson = data;
            }
          }
        }
      }

      if (productJson != null) {
        final productData = Product.fromJson(productJson);
        return ApiResponse<Product>(
          success: true,
          data: productData,
          message:
              response['message'] as String? ?? 'Product created successfully',
          statusCode: response['statusCode'] as int? ?? 201,
        );
      } else {
        return ApiResponse<Product>(
          success: false,
          data: null,
          message: 'Failed to create product: Invalid response format',
          statusCode: 500,
        );
      }
    } on ApiException catch (e) {
      return ApiResponse<Product>(
        success: false,
        data: null,
        message: e.message,
        statusCode: e.statusCode ?? 500,
      );
    } catch (e) {
      return ApiResponse<Product>(
        success: false,
        data: null,
        message: 'Failed to create product: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Crée un produit avec une image en utilisant multipart/form-data
  Future<ApiResponse<Product>> _createProductWithImage(
    Product product,
    File image,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(_apiClient.getFullUrl('products')),
      );
      request.headers.addAll(await _apiClient.getHeaders(requiresAuth: true));

      // Ajouter les champs du produit
      final productJson = product.toJson();
      for (final entry in productJson.entries) {
        if (entry.value != null) {
          request.fields[entry.key] = entry.value.toString();
        }
      }

      // Ajouter l'image
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = _apiClient.handleResponse(response);

      Map<String, dynamic>? productDataJson;
      if (responseData is Map<String, dynamic>) {
        if (responseData['data'] is Map<String, dynamic>) {
          productDataJson = responseData['data'] as Map<String, dynamic>;
        } else {
          productDataJson = responseData;
        }
      }

      if (productDataJson != null) {
        final productData = Product.fromJson(productDataJson);
        return ApiResponse<Product>(
          success: true,
          data: productData,
          message: 'Product created successfully',
          statusCode: 201,
        );
      } else {
        return ApiResponse<Product>(
          success: false,
          data: null,
          message: 'Failed to create product: Invalid response format',
          statusCode: 500,
        );
      }
    } on ApiException catch (e) {
      return ApiResponse<Product>(
        success: false,
        data: null,
        message: e.message,
        statusCode: e.statusCode ?? 500,
      );
    } catch (e) {
      return ApiResponse<Product>(
        success: false,
        data: null,
        message: 'Failed to create product: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<Product>> getProductById(String id) async {
    try {
      final response = await _apiClient.get('products/$id', requiresAuth: true);
      final productData = Product.fromJson(response as Map<String, dynamic>);

      return ApiResponse<Product>(
        success: true,
        data: productData,
        message: 'Product fetched successfully',
        statusCode: 200,
      );
    } on ApiException catch (e) {
      return ApiResponse<Product>(
        success: false,
        data: null,
        message: e.message,
        statusCode: e.statusCode ?? 500,
      );
    } catch (e) {
      return ApiResponse<Product>(
        success: false,
        data: null,
        message: 'Failed to fetch product: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<Product>> updateProduct(
    String id,
    Product product, {
    File? image,
    bool? removeImage,
  }) async {
    try {
      // Si une image est fournie, utiliser multipart
      if (image != null) {
        return _updateProductWithImage(id, product, image, removeImage);
      }

      // Sinon, utiliser une requête JSON standard
      final Map<String, dynamic> body = {
        ...product.toJson(),
        if (removeImage == true) 'removeImage': true,
      };

      final response = await _apiClient.put(
        'products/$id',
        body: body,
        requiresAuth: true,
      );

      // Gérer les différents formats de réponse
      Map<String, dynamic>? productJson;
      if (response is Map<String, dynamic>) {
        if (response['data'] != null &&
            response['data'] is Map<String, dynamic>) {
          productJson = response['data'] as Map<String, dynamic>;
        } else if (!response.containsKey('success')) {
          // La réponse est directement les données du produit
          productJson = response;
        }
      }

      if (productJson != null) {
        final updatedProduct = Product.fromJson(productJson);
        return ApiResponse<Product>(
          success: true,
          data: updatedProduct,
          message:
              response['message'] as String? ?? 'Product updated successfully',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        return ApiResponse<Product>(
          success: false,
          data: null,
          message: 'Failed to update product: Invalid response format',
          statusCode: 500,
        );
      }
    } on ApiException catch (e) {
      return ApiResponse<Product>(
        success: false,
        data: null,
        message: e.message,
        statusCode: e.statusCode ?? 500,
      );
    } catch (e) {
      return ApiResponse<Product>(
        success: false,
        data: null,
        message: 'Failed to update product: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Met à jour un produit avec une image en utilisant multipart/form-data
  Future<ApiResponse<Product>> _updateProductWithImage(
    String id,
    Product product,
    File image,
    bool? removeImage,
  ) async {
    try {
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse(_apiClient.getFullUrl('products/$id')),
      );
      request.headers.addAll(await _apiClient.getHeaders(requiresAuth: true));

      // Ajouter les champs du produit
      final productJson = product.toJson();
      for (final entry in productJson.entries) {
        if (entry.value != null) {
          request.fields[entry.key] = entry.value.toString();
        }
      }

      if (removeImage == true) {
        request.fields['removeImage'] = 'true';
      }

      // Ajouter l'image
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = _apiClient.handleResponse(response);

      Map<String, dynamic>? productDataJson;
      if (responseData is Map<String, dynamic>) {
        if (responseData['data'] is Map<String, dynamic>) {
          productDataJson = responseData['data'] as Map<String, dynamic>;
        } else {
          productDataJson = responseData;
        }
      }

      if (productDataJson != null) {
        final updatedProduct = Product.fromJson(productDataJson);
        return ApiResponse<Product>(
          success: true,
          data: updatedProduct,
          message: 'Product updated successfully',
          statusCode: 200,
        );
      } else {
        return ApiResponse<Product>(
          success: false,
          data: null,
          message: 'Failed to update product: Invalid response format',
          statusCode: 500,
        );
      }
    } on ApiException catch (e) {
      return ApiResponse<Product>(
        success: false,
        data: null,
        message: e.message,
        statusCode: e.statusCode ?? 500,
      );
    } catch (e) {
      return ApiResponse<Product>(
        success: false,
        data: null,
        message: 'Failed to update product: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<void>> deleteProduct(String id) async {
    try {
      await _apiClient.delete('products/$id', requiresAuth: true);
      return ApiResponse<void>(
        success: true,
        data: null,
        message: 'Product deleted successfully',
        statusCode: 200,
      );
    } on ApiException catch (e) {
      return ApiResponse<void>(
        success: false,
        data: null,
        message: e.message,
        statusCode: e.statusCode ?? 500,
      );
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        data: null,
        message: 'Failed to delete product: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<List<StockTransaction>>> getStockTransactions({
    String? productId,
    int? page,
    int? limit,
    StockTransactionType? type,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final queryParameters = <String, String>{
        if (productId != null) 'productId': productId,
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
        if (type != null)
          'type':
              type.name, // Assuming enum .name gives the string representation
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
      };
      final response = await _apiClient.get(
        'stock-transactions',
        queryParameters: queryParameters,
        requiresAuth: true,
      );
      // Gérer les deux formats de réponse: liste directe ou objet avec 'data'
      final List<dynamic> data;
      if (response is List) {
        data = response;
      } else if (response is Map && response['data'] != null) {
        data = response['data'] as List<dynamic>;
      } else {
        data = [];
      }
      final transactions =
          data
              .map(
                (json) =>
                    StockTransaction.fromJson(json as Map<String, dynamic>),
              )
              .toList();

      return ApiResponse<List<StockTransaction>>(
        success: true,
        data: transactions,
        message: 'Stock transactions fetched successfully',
        statusCode: 200,
      );
    } on ApiException catch (e) {
      return ApiResponse<List<StockTransaction>>(
        success: false,
        data: null,
        message: e.message,
        statusCode: e.statusCode ?? 500,
      );
    } catch (e) {
      return ApiResponse<List<StockTransaction>>(
        success: false,
        data: null,
        message: 'Failed to fetch stock transactions: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<StockTransaction>> createStockTransaction(
    StockTransaction transaction,
  ) async {
    try {
      final response = await _apiClient.post(
        'stock-transactions',
        body: transaction.toJson(),
        requiresAuth: true,
      );
      final transactionData = StockTransaction.fromJson(
        response as Map<String, dynamic>,
      );

      return ApiResponse<StockTransaction>(
        success: true,
        data: transactionData,
        message: 'Stock transaction created successfully',
        statusCode: 201,
      );
    } on ApiException catch (e) {
      return ApiResponse<StockTransaction>(
        success: false,
        data: null,
        message: e.message,
        statusCode: e.statusCode ?? 500,
      );
    } catch (e) {
      return ApiResponse<StockTransaction>(
        success: false,
        data: null,
        message: 'Failed to create stock transaction: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<StockTransaction>> getStockTransactionById(
    String id,
  ) async {
    try {
      final response = await _apiClient.get(
        'stock-transactions/$id',
        requiresAuth: true,
      );
      final transactionData = StockTransaction.fromJson(
        response as Map<String, dynamic>,
      );

      return ApiResponse<StockTransaction>(
        success: true,
        data: transactionData,
        message: 'Stock transaction fetched successfully',
        statusCode: 200,
      );
    } on ApiException catch (e) {
      return ApiResponse<StockTransaction>(
        success: false,
        data: null,
        message: e.message,
        statusCode: e.statusCode ?? 500,
      );
    } catch (e) {
      return ApiResponse<StockTransaction>(
        success: false,
        data: null,
        message: 'Failed to fetch stock transaction: ${e.toString()}',
        statusCode: 500,
      );
    }
  }
}
