import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/services/image_upload_service.dart';
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
    // Produits désactivés compris (`includeInactive=true`).
    bool includeInactive = false,
  });

  Future<ApiResponse<Product>> createProduct(Product product, {File? image});

  Future<ApiResponse<Product>> getProductById(String id);

  Future<ApiResponse<Product>> updateProduct(
    String id,
    Product product, {
    File? image,
    bool? removeImage,
  });

  /// `DELETE products/:id` : 200 `{ deleted, deactivated }` (un produit vendu
  /// ou mouvementé est désactivé, jamais effacé). Un serveur plus ancien
  /// répond 204 sans corps : `data` est alors null.
  Future<ApiResponse<ProductRemovalResult?>> deleteProduct(String id);

  Future<ApiResponse<List<StockTransaction>>> getStockTransactions({
    String? productId,
    int? page,
    int? limit,
    StockTransactionType? type,
    String? dateFrom,
    String? dateTo,
  });

  /// [expenseId] : dépense d'achat qui porte cet approvisionnement (achat et
  /// dette déjà comptabilisés par elle, le serveur ne passe que 311 / 6031).
  Future<ApiResponse<StockTransaction>> createStockTransaction(
    StockTransaction transaction, {
    String? expenseId,
  });

  Future<ApiResponse<StockTransaction>> getStockTransactionById(String id);

  // Future<ApiResponse<StockTransaction>> updateStockTransaction(String id, StockTransaction transaction); // Usually not updated
  // Future<ApiResponse<void>> deleteStockTransaction(String id); // Usually not deleted
}

class InventoryApiServiceImpl implements InventoryApiService {
  final ApiClient _apiClient;
  final ImageUploadService _imageUploadService;

  InventoryApiServiceImpl(
    this._apiClient, {
    ImageUploadService? imageUploadService,
  }) : _imageUploadService = imageUploadService ?? ImageUploadService();
  @override
  Future<ApiResponse<List<Product>>> getProducts({
    int? page,
    int? limit,
    String? category,
    String? sortBy,
    String? sortOrder,
    String? searchQuery,
    bool includeInactive = false,
  }) async {
    try {
      final queryParameters = <String, String>{
        // Produits désactivés compris (filtre « Inactifs »).
        if (includeInactive) 'includeInactive': 'true',
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
        if (category != null) 'category': category,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
        // Nom attendu par FilterProductsDto (`q` était ignoré).
        if (searchQuery != null) 'searchQuery': searchQuery,
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
      // Une fiche mal formée ne doit pas vider toute la liste.
      final products = <Product>[];
      for (final item in data) {
        try {
          products.add(Product.fromJson(item as Map<String, dynamic>));
        } catch (e) {
          debugPrint('[InventoryAPI] ⚠️ Fiche article ignorée : $e');
        }
      }

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

      // Vérifier si un imagePath local existe et uploader vers Cloudinary
      String? imageUrl = product.imageUrl;
      if (product.imagePath != null && product.imagePath!.isNotEmpty) {
        final imageFile = File(product.imagePath!);
        if (await imageFile.exists()) {
          try {
            debugPrint(
              '[InventoryAPI] 📤 Uploading local image to Cloudinary...',
            );
            imageUrl = await _imageUploadService.uploadImageWithRetry(
              imageFile,
              publicId: 'product_${product.id}',
            );
            if (imageUrl != null) {
              debugPrint('[InventoryAPI] ✅ Image uploaded: $imageUrl');
            }
          } catch (e) {
            debugPrint('[InventoryAPI] ⚠️ Image upload error: $e');
          }
        }
      }

      // Créer le JSON et SUPPRIMER imagePath (chemin local)
      final productBody = product.toJson();
      productBody.remove(
        'imagePath',
      ); // CRITIQUE: Ne pas envoyer le chemin local au backend
      if (imageUrl != null) {
        productBody['imageUrl'] = imageUrl;
      }

      // Utiliser une requête JSON standard
      final response = await _apiClient.post(
        'products',
        body: productBody,
        requiresAuth: true,
        // Hors ligne : le produit reste `pending` et la synchro le crée ;
        // le mettre aussi en file le créerait deux fois.
        queueOffline: false,
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

  /// Crée un produit avec une image en uploadant d'abord sur Cloudinary
  Future<ApiResponse<Product>> _createProductWithImage(
    Product product,
    File image,
  ) async {
    try {
      // 1. Upload image to Cloudinary first
      debugPrint('📤 Uploading product image to Cloudinary...');
      final imageUrl = await _imageUploadService.uploadImageWithRetry(image);

      if (imageUrl == null) {
        debugPrint('⚠️ Failed to upload image, creating product without image');
      } else {
        debugPrint('✅ Image uploaded: $imageUrl');
      }

      // 2. Create product JSON with imageUrl
      final productJson = product.toJson();
      productJson.remove(
        'imagePath',
      ); // CRITIQUE: Ne pas envoyer le chemin local au backend
      if (imageUrl != null) {
        productJson['imageUrl'] = imageUrl;
      }

      // 3. Send JSON request to API
      final response = await _apiClient.post(
        'products',
        body: productJson,
        requiresAuth: true,
        // Hors ligne : le produit reste `pending` et la synchro le crée ;
        // le mettre aussi en file le créerait deux fois.
        queueOffline: false,
      );

      Map<String, dynamic>? productDataJson;
      if (response is Map<String, dynamic>) {
        if (response['data'] is Map<String, dynamic>) {
          productDataJson = response['data'] as Map<String, dynamic>;
        } else {
          productDataJson = response;
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
      final productData = Product.fromJson(
        Map<String, dynamic>.from(_unwrap(response) as Map),
      );

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

      // Vérifier si un imagePath local existe et uploader vers Cloudinary
      String? imageUrl = product.imageUrl;
      if (product.imagePath != null && product.imagePath!.isNotEmpty) {
        final imageFile = File(product.imagePath!);
        if (await imageFile.exists()) {
          try {
            debugPrint(
              '[InventoryAPI] 📤 Uploading local image to Cloudinary for update...',
            );
            imageUrl = await _imageUploadService.uploadImageWithRetry(
              imageFile,
              publicId: 'product_${product.id}',
            );
            if (imageUrl != null) {
              debugPrint('[InventoryAPI] ✅ Image uploaded: $imageUrl');
            }
          } catch (e) {
            debugPrint('[InventoryAPI] ⚠️ Image upload error: $e');
          }
        }
      }

      // Créer le JSON et SUPPRIMER imagePath (chemin local)
      final Map<String, dynamic> body = {
        ...product.toJson(),
        if (removeImage == true) 'removeImage': true,
      };
      body.remove(
        'imagePath',
      ); // CRITIQUE: Ne pas envoyer le chemin local au backend
      if (imageUrl != null) {
        body['imageUrl'] = imageUrl;
      }

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

  /// Met à jour un produit avec une image en uploadant d'abord sur Cloudinary
  Future<ApiResponse<Product>> _updateProductWithImage(
    String id,
    Product product,
    File image,
    bool? removeImage,
  ) async {
    try {
      // 1. Upload image to Cloudinary first
      debugPrint('📤 Uploading product image to Cloudinary for update...');
      final imageUrl = await _imageUploadService.uploadImageWithRetry(image);

      if (imageUrl == null) {
        debugPrint(
          '⚠️ Failed to upload image, updating product without new image',
        );
      } else {
        debugPrint('✅ Image uploaded: $imageUrl');
      }

      // 2. Create product JSON with imageUrl
      final productJson = product.toJson();
      productJson.remove(
        'imagePath',
      ); // CRITIQUE: Ne pas envoyer le chemin local au backend
      if (imageUrl != null) {
        productJson['imageUrl'] = imageUrl;
      }
      if (removeImage == true) {
        productJson['removeImage'] = true;
      }

      // 3. Send JSON request to API
      final response = await _apiClient.put(
        'products/$id',
        body: productJson,
        requiresAuth: true,
      );

      Map<String, dynamic>? productDataJson;
      if (response is Map<String, dynamic>) {
        if (response['data'] is Map<String, dynamic>) {
          productDataJson = response['data'] as Map<String, dynamic>;
        } else {
          productDataJson = response;
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
  Future<ApiResponse<ProductRemovalResult?>> deleteProduct(String id) async {
    try {
      final response = await _apiClient.delete('products/$id', requiresAuth: true);
      return ApiResponse<ProductRemovalResult?>(
        success: true,
        data: ProductRemovalResult.fromResponse(response),
        message: 'Product deleted successfully',
        statusCode: 200,
      );
    } on ApiException catch (e) {
      return ApiResponse<ProductRemovalResult?>(
        success: false,
        data: null,
        message: e.message,
        statusCode: e.statusCode ?? 500,
      );
    } catch (e) {
      return ApiResponse<ProductRemovalResult?>(
        success: false,
        data: null,
        message: e.toString(),
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
      // Réponse `{success, data: {data: [...], total}}` (intercepteur + page),
      // décimaux en texte : lecture tolérante.
      var data = _unwrap(response);
      if (data is Map) data = data['data'];
      final transactions =
          (data is List ? data : const [])
              .whereType<Map>()
              .map(
                (json) =>
                    StockTransaction.fromApi(Map<String, dynamic>.from(json)),
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

  /// Corps accepté par `POST stock-transactions` (liste blanche du serveur :
  /// tout autre champ est retiré). Le sens vient du type, sauf pour un
  /// ajustement dont le signe est gardé (négatif = sortie).
  static Map<String, dynamic> stockTransactionPayload(
    StockTransaction transaction, {
    String? expenseId,
  }) => transaction.toApiPayload(expenseId: expenseId);

  @override
  Future<ApiResponse<StockTransaction>> createStockTransaction(
    StockTransaction transaction, {
    String? expenseId,
  }) async {
    try {
      final response = await _apiClient.post(
        'stock-transactions',
        body: stockTransactionPayload(transaction, expenseId: expenseId),
        requiresAuth: true,
      );
      // Réponse enveloppée {success, data} : on garde le mouvement local
      // (montants CDF, unité d'affaires) avec l'identifiant du serveur.
      final data = _unwrap(response);
      final serverId = data is Map ? data['id']?.toString() : null;
      return ApiResponse<StockTransaction>(
        success: true,
        data: serverId != null && serverId.isNotEmpty
            ? transaction.copyWith(id: serverId)
            : transaction,
        message: 'Stock transaction created successfully',
        statusCode: 201,
      );
    } on ApiException catch (e) {
      debugPrint('❌ API Exception: ${e.message}');
      return ApiResponse<StockTransaction>(
        success: false,
        data: null,
        message: e.message,
        statusCode: e.statusCode ?? 500,
        // Hors ligne : l'envoi est mis en file et rejoué (pas un refus).
        error: e,
      );
    } catch (e) {
      debugPrint('❌ Error creating stock transaction: $e');
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
      final transactionData = StockTransaction.fromApi(
        Map<String, dynamic>.from(_unwrap(response) as Map),
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

  /// Retire l'enveloppe `{success, data}` posée par l'intercepteur serveur.
  static dynamic _unwrap(dynamic response) =>
      response is Map &&
              response.containsKey('success') &&
              response.containsKey('data')
          ? response['data']
          : response;
}

/// Issue de `DELETE products/:id` : supprimé, ou désactivé (produit vendu ou
/// mouvementé, jamais effacé).
class ProductRemovalResult {
  final bool deleted;
  final bool deactivated;

  const ProductRemovalResult({required this.deleted, required this.deactivated});

  /// Lit `{ deleted, deactivated }`, éventuellement enveloppé. Null pour un
  /// 204 sans corps (serveur plus ancien).
  static ProductRemovalResult? fromResponse(Object? response) {
    Object? data = response;
    for (var i = 0; i < 2 && data is Map && data['data'] is Map; i++) {
      data = data['data'];
    }
    if (data is! Map) return null;
    final deactivated = data['deactivated'];
    final deleted = data['deleted'];
    if (deactivated is! bool && deleted is! bool) return null;
    final isDeactivated = deactivated == true;
    return ProductRemovalResult(
      deleted: deleted is bool ? deleted : !isDeactivated,
      deactivated: isDeactivated,
    );
  }
}
