import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/api_response.dart';
import '../exceptions/api_exceptions.dart';
import '../../features/sales/models/sale.dart';
import './api_client.dart';
import './image_upload_service.dart';

class SaleApiService {
  final ApiClient _apiClient;
  final ImageUploadService _imageUploadService;

  SaleApiService({ApiClient? apiClient, ImageUploadService? imageUploadService})
    : _apiClient = apiClient ?? ApiClient(),
      _imageUploadService = imageUploadService ?? ImageUploadService();

  /// Convertit un Sale en DTO optimisé pour l'API
  /// Envoie seulement les champs nécessaires, réduisant le payload de ~90%
  Map<String, dynamic> _saleToCreateDto(Sale sale) {
    return {
      if (sale.localId != null) 'localId': sale.localId,
      'date': sale.date.toIso8601String(),
      if (sale.dueDate != null) 'dueDate': sale.dueDate!.toIso8601String(),
      if (sale.customerId != null) 'customerId': sale.customerId,
      'customerName': sale.customerName,
      'paymentMethod': sale.paymentMethod,
      if (sale.paymentReference != null)
        'paymentReference': sale.paymentReference,
      'exchangeRate': sale.transactionExchangeRate ?? 1.0,
      if (sale.notes != null) 'notes': sale.notes,
      'amountPaidInCdf': sale.paidAmountInCdf,
      if (sale.transactionCurrencyCode != null)
        'currencyCode': sale.transactionCurrencyCode,
      if (sale.discountPercentage > 0)
        'discountPercentage': sale.discountPercentage,
      // Pièces jointes - URLs Cloudinary
      if (sale.attachmentUrls != null && sale.attachmentUrls!.isNotEmpty)
        'attachmentUrls': sale.attachmentUrls,
      // NOTE: localAttachmentPaths ne doit PAS être envoyé au backend
      // Les fichiers locaux sont uploadés vers Cloudinary avant l'envoi
      // Champs Business Unit
      if (sale.companyId != null) 'companyId': sale.companyId,
      if (sale.businessUnitId != null) 'businessUnitId': sale.businessUnitId,
      if (sale.businessUnitCode != null)
        'businessUnitCode': sale.businessUnitCode,
      // Items optimisés (sans les champs recalculés par le backend)
      'items':
          sale.items
              .map(
                (item) => {
                  if (item.productId != null) 'productId': item.productId,
                  'productName': item.productName,
                  'quantity': item.quantity,
                  'unitPrice': item.unitPrice,
                  if (item.discount != null && item.discount! > 0)
                    'discount': item.discount,
                  'currencyCode': item.currencyCode,
                  'itemType': item.itemType.name,
                  if (item.taxRate != null) 'taxRate': item.taxRate,
                  if (item.notes != null) 'notes': item.notes,
                },
              )
              .toList(),
    };
  }

  Future<ApiResponse<List<Sale>>> getSales({
    Map<String, String>? queryParameters,
  }) async {
    try {
      final response = await _apiClient.get(
        'sales',
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

        // Handle paginated response: {sales: [...], ...} or {data: [...], ...} or {items: [...], ...}
        List<dynamic> salesList;
        if (data is List) {
          salesList = data;
        } else if (data is Map<String, dynamic>) {
          // Try 'sales' first (API response format), then 'data', then 'items'
          salesList =
              (data['sales'] as List?) ??
              (data['data'] as List?) ??
              (data['items'] as List?) ??
              [];
          debugPrint(
            '📊 Sales API - Extracted ${salesList.length} sales from response',
          );
        } else {
          salesList = [];
        }

        final sales =
            salesList
                .map(
                  (saleJson) => Sale.fromJson(saleJson as Map<String, dynamic>),
                )
                .toList();
        return ApiResponse<List<Sale>>(
          success: true,
          data: sales,
          message:
              response['message'] as String? ?? 'Sales fetched successfully.',
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
        'Failed to fetch sales: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Sale>> getSaleById(String id) async {
    try {
      final response = await _apiClient.get('sales/$id', requiresAuth: true);
      if (response != null && response['data'] != null) {
        final sale = Sale.fromJson(response['data'] as Map<String, dynamic>);
        return ApiResponse<Sale>(
          success: true,
          data: sale,
          message:
              response['message'] as String? ?? 'Sale fetched successfully.',
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
        'Failed to fetch sale: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Sale>> createSale(Sale sale) async {
    try {
      // Upload local attachments to Cloudinary first
      List<String>? uploadedUrls;
      if (sale.localAttachmentPaths != null &&
          sale.localAttachmentPaths!.isNotEmpty) {
        final files = <File>[];
        for (final path in sale.localAttachmentPaths!) {
          final file = File(path);
          if (await file.exists()) {
            files.add(file);
          }
        }
        if (files.isNotEmpty) {
          debugPrint(
            '[SaleAPI] 📤 Uploading ${files.length} local attachments to Cloudinary...',
          );
          final uploadResult = await _imageUploadService
              .uploadImagesWithDetails(files);
          if (uploadResult.hasSuccessfulUploads) {
            uploadedUrls = uploadResult.successfulUrls;
            debugPrint(
              '[SaleAPI] ✅ ${uploadedUrls.length} attachments uploaded successfully',
            );
          }
          if (uploadResult.hasFailures) {
            debugPrint(
              '[SaleAPI] ⚠️ ${uploadResult.failedPaths.length} attachments failed to upload',
            );
          }
        }
      }

      // Utiliser DTO optimisé au lieu de sale.toJson() pour réduire le payload de ~90%
      final body = _saleToCreateDto(sale);

      // TOUJOURS supprimer localAttachmentPaths du payload
      body.remove('localAttachmentPaths');

      // Ajouter les URLs Cloudinary uploadées
      if (uploadedUrls != null && uploadedUrls.isNotEmpty) {
        body['attachmentUrls'] = [
          ...(sale.attachmentUrls ?? []),
          ...uploadedUrls,
        ];
      }

      debugPrint(
        '📤 Envoi vente optimisée: ${body.keys.length} champs au lieu du modèle complet',
      );

      final response = await _apiClient.post(
        'sales',
        body: body,
        requiresAuth: true,
      );
      if (response != null && response['data'] != null) {
        final createdSale = Sale.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        return ApiResponse<Sale>(
          success: true,
          data: createdSale,
          message:
              response['message'] as String? ?? 'Sale created successfully.',
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
        'Failed to create sale: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Sale>> updateSale(String id, Sale sale) async {
    try {
      // Upload local attachments to Cloudinary first
      List<String>? uploadedUrls;
      if (sale.localAttachmentPaths != null &&
          sale.localAttachmentPaths!.isNotEmpty) {
        final files = <File>[];
        for (final path in sale.localAttachmentPaths!) {
          final file = File(path);
          if (await file.exists()) {
            files.add(file);
          }
        }
        if (files.isNotEmpty) {
          debugPrint(
            '[SaleAPI] 📤 Uploading ${files.length} local attachments for update...',
          );
          final uploadResult = await _imageUploadService
              .uploadImagesWithDetails(files);
          if (uploadResult.hasSuccessfulUploads) {
            uploadedUrls = uploadResult.successfulUrls;
            debugPrint(
              '[SaleAPI] ✅ ${uploadedUrls.length} attachments uploaded successfully',
            );
          }
        }
      }

      // Utiliser DTO optimisé
      final body = _saleToCreateDto(sale);

      // TOUJOURS supprimer localAttachmentPaths du payload
      body.remove('localAttachmentPaths');

      // Ajouter les URLs Cloudinary uploadées
      if (uploadedUrls != null && uploadedUrls.isNotEmpty) {
        body['attachmentUrls'] = [
          ...(sale.attachmentUrls ?? []),
          ...uploadedUrls,
        ];
      }

      final response = await _apiClient.put(
        'sales/$id',
        body: body,
        requiresAuth: true,
      );
      if (response != null && response['data'] != null) {
        final updatedSale = Sale.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        return ApiResponse<Sale>(
          success: true,
          data: updatedSale,
          message:
              response['message'] as String? ?? 'Sale updated successfully.',
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
        'Failed to update sale: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<void>> deleteSale(String id) async {
    try {
      final response = await _apiClient.delete('sales/$id', requiresAuth: true);
      return ApiResponse<void>(
        success: true,
        message: response['message'] as String? ?? 'Sale deleted successfully.',
        statusCode: response['statusCode'] as int? ?? 200,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to delete sale: An unexpected error occurred. $e',
      );
    }
  }
}
