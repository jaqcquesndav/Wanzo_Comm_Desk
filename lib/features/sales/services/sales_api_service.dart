import 'package:flutter/foundation.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/features/sales/models/sale.dart';

/// Service API pour la gestion des ventes
class SalesApiService {
  final ApiClient _apiClient;

  SalesApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Convertit un Sale en DTO optimisé pour l'API
  /// Envoie seulement les champs nécessaires, réduisant le payload de ~90%
  Map<String, dynamic> _saleToCreateDto(Sale sale) {
    return {
      if (sale.localId != null) 'localId': sale.localId,
      'date': sale.date.toIso8601String(),
      if (sale.customerId != null) 'customerId': sale.customerId,
      'customerName': sale.customerName,
      'paymentMethod': sale.paymentMethod,
      'exchangeRate': sale.transactionExchangeRate ?? 1.0,
      if (sale.notes != null) 'notes': sale.notes,
      'amountPaidInCdf': sale.paidAmountInCdf,
      if (sale.transactionCurrencyCode != null)
        'currencyCode': sale.transactionCurrencyCode,
      if (sale.discountPercentage > 0)
        'discountPercentage': sale.discountPercentage,
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

  /// Récupère toutes les ventes avec filtres
  Future<ApiResponse<List<Sale>>> getSales({
    int? page,
    int? limit,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? customerId,
    SaleStatus? status,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final Map<String, String> queryParams = {};
      if (page != null) queryParams['page'] = page.toString();
      if (limit != null) queryParams['limit'] = limit.toString();
      if (dateFrom != null) {
        queryParams['dateFrom'] = dateFrom.toIso8601String();
      }
      if (dateTo != null) queryParams['dateTo'] = dateTo.toIso8601String();
      if (customerId != null) queryParams['customerId'] = customerId;
      if (status != null) queryParams['status'] = status.name;
      if (sortBy != null) queryParams['sortBy'] = sortBy;
      if (sortOrder != null) queryParams['sortOrder'] = sortOrder;

      final response = await _apiClient.get(
        'sales',
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
            '📊 Features/Sales API - Extracted ${salesList.length} sales from response',
          );
        } else {
          salesList = [];
        }

        final sales =
            salesList
                .map((json) => Sale.fromJson(json as Map<String, dynamic>))
                .toList();

        return ApiResponse<List<Sale>>(
          success: true,
          data: sales,
          message:
              response['message'] as String? ?? 'Ventes récupérées avec succès',
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
      throw ServerException('Échec de la récupération des ventes: $e');
    }
  }

  /// Crée une nouvelle vente
  Future<ApiResponse<Sale>> createSale(Sale sale) async {
    try {
      // Utiliser DTO optimisé au lieu de sale.toJson() pour réduire le payload de ~90%
      final body = _saleToCreateDto(sale);
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
          message: response['message'] as String? ?? 'Vente créée avec succès',
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
      throw ServerException('Échec de la création de la vente: $e');
    }
  }

  /// Récupère une vente par son ID
  Future<ApiResponse<Sale>> getSaleById(String id) async {
    try {
      final response = await _apiClient.get('sales/$id', requiresAuth: true);

      if (response != null && response['data'] != null) {
        final sale = Sale.fromJson(response['data'] as Map<String, dynamic>);

        return ApiResponse<Sale>(
          success: true,
          data: sale,
          message:
              response['message'] as String? ?? 'Vente récupérée avec succès',
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
      throw ServerException('Échec de la récupération de la vente: $e');
    }
  }

  /// Met à jour une vente
  Future<ApiResponse<Sale>> updateSale(String id, Sale sale) async {
    try {
      // Utiliser DTO optimisé au lieu de sale.toJson()
      final body = _saleToCreateDto(sale);

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
              response['message'] as String? ?? 'Vente mise à jour avec succès',
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
      throw ServerException('Échec de la mise à jour de la vente: $e');
    }
  }

  /// Supprime une vente
  Future<ApiResponse<void>> deleteSale(String id) async {
    try {
      final response = await _apiClient.delete('sales/$id', requiresAuth: true);

      return ApiResponse<void>(
        success: true,
        data: null,
        message:
            response?['message'] as String? ?? 'Vente supprimée avec succès',
        statusCode: response?['statusCode'] as int? ?? 200,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec de la suppression de la vente: $e');
    }
  }

  /// Marque une vente comme complétée
  Future<ApiResponse<Sale>> completeSale(String id) async {
    try {
      final response = await _apiClient.put(
        'sales/$id/complete',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final completedSale = Sale.fromJson(
          response['data'] as Map<String, dynamic>,
        );

        return ApiResponse<Sale>(
          success: true,
          data: completedSale,
          message:
              response['message'] as String? ?? 'Vente marquée comme complétée',
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
      throw ServerException('Échec de la complétion de la vente: $e');
    }
  }

  /// Annule une vente
  Future<ApiResponse<Sale>> cancelSale(String id) async {
    try {
      final response = await _apiClient.put(
        'sales/$id/cancel',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final cancelledSale = Sale.fromJson(
          response['data'] as Map<String, dynamic>,
        );

        return ApiResponse<Sale>(
          success: true,
          data: cancelledSale,
          message:
              response['message'] as String? ?? 'Vente annulée avec succès',
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
      throw ServerException('Échec de l\'annulation de la vente: $e');
    }
  }

  /// Synchronise les ventes locales avec le serveur
  /// Le backend attend une liste directe de ventes et retourne un objet avec
  /// `synced` (liste des ventes synchronisées) et `errors` (liste des erreurs)
  Future<ApiResponse<List<Sale>>> syncSales(List<Sale> localSales) async {
    try {
      // Utiliser DTO optimisé pour réduire le payload de ~90%
      final optimizedSales =
          localSales.map((sale) => _saleToCreateDto(sale)).toList();
      debugPrint('📤 Sync ${localSales.length} ventes avec payload optimisé');

      final response = await _apiClient.post(
        'sales/sync',
        body: optimizedSales,
        requiresAuth: true,
      );

      // Le backend retourne un objet avec 'synced' et 'errors'
      if (response != null && response['synced'] != null) {
        final syncedSales =
            (response['synced'] as List)
                .map((json) => Sale.fromJson(json as Map<String, dynamic>))
                .toList();

        // Log les erreurs s'il y en a
        if (response['errors'] != null &&
            (response['errors'] as List).isNotEmpty) {
          for (var error in response['errors'] as List) {
            debugPrint(
              'Sync error for localId ${error['localId']}: ${error['error']}',
            );
          }
        }

        return ApiResponse<List<Sale>>(
          success: true,
          data: syncedSales,
          message: 'Ventes synchronisées avec succès',
          statusCode: 200,
        );
      } else if (response != null && response['data'] != null) {
        // Fallback pour compatibilité avec ancien format de réponse
        final syncedSales =
            (response['data'] as List)
                .map((json) => Sale.fromJson(json as Map<String, dynamic>))
                .toList();

        return ApiResponse<List<Sale>>(
          success: true,
          data: syncedSales,
          message:
              response['message'] as String? ??
              'Ventes synchronisées avec succès',
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
      throw ServerException('Échec de la synchronisation des ventes: $e');
    }
  }

  /// Récupère les statistiques de ventes
  Future<ApiResponse<Map<String, dynamic>>> getSalesStats({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final Map<String, String> queryParams = {};
      if (dateFrom != null) {
        queryParams['dateFrom'] = dateFrom.toIso8601String();
      }
      if (dateTo != null) queryParams['dateTo'] = dateTo.toIso8601String();

      final response = await _apiClient.get(
        'sales/stats',
        queryParameters: queryParams,
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
