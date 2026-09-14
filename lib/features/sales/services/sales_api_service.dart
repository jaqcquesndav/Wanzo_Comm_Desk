import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/services/image_upload_service.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/core/models/operation_payment.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/features/sales/models/sale.dart';

/// Service API pour la gestion des ventes
class SalesApiService {
  final ApiClient _apiClient;
  final ImageUploadService _imageUploadService;

  SalesApiService({
    ApiClient? apiClient,
    ImageUploadService? imageUploadService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _imageUploadService = imageUploadService ?? ImageUploadService();

  /// Convertit un Sale en DTO optimisé pour l'API
  /// Envoie seulement les champs nécessaires, réduisant le payload de ~90%
  ///
  /// [includeItems] à `false` pour un PATCH qui ne touche pas aux lignes
  /// (règlement, changement de statut) : le backend ne recalcule alors pas le
  /// stock et il n'y a aucun risque de rejet sur un identifiant de ligne
  /// (« SaleItem with ID not found in this sale »).
  Map<String, dynamic> _saleToCreateDto(Sale sale, {bool includeItems = true}) {
    return {
      if (sale.localId != null) 'localId': sale.localId,
      // Mode métier ayant produit la vente (colonne mode du journal comptable).
      'sourceMode': BusinessContextService().activityMode.apiValue,
      'date': sale.date.toIso8601String(),
      if (sale.dueDate != null) 'dueDate': sale.dueDate!.toIso8601String(),
      if (sale.customerId != null) 'customerId': sale.customerId,
      // Client de passage : si aucun customerId reel, le backend fait un
      // find-or-create du Customer via ce numero (base fidelite).
      if (sale.customerPhoneNumber != null &&
          sale.customerPhoneNumber!.isNotEmpty)
        'customerPhoneNumber': sale.customerPhoneNumber,
      'customerName': sale.customerName,
      'paymentMethod': sale.paymentMethod,
      if (sale.paymentReference != null)
        'paymentReference': sale.paymentReference,
      'exchangeRate': sale.transactionExchangeRate ?? 1.0,
      if (sale.notes != null) 'notes': sale.notes,
      // Montant payé : les deux DTO backend NE portent PAS le même nom.
      //   CreateSaleDto -> amountPaidInCdf
      //   UpdateSaleDto -> paidAmountInCdf
      // Le ValidationPipe est en `whitelist: true` : la clé inconnue est
      // silencieusement supprimée (le serveur répondait 200 sans rien changer,
      // le règlement était perdu). On émet donc les deux noms, chaque DTO ne
      // retient que le sien.
      'amountPaidInCdf': sale.paidAmountInCdf,
      'paidAmountInCdf': sale.paidAmountInCdf,
      if (sale.paidAmountInTransactionCurrency != null &&
          sale.paidAmountInTransactionCurrency! > 0)
        'paidAmountInTransactionCurrency': sale.paidAmountInTransactionCurrency,
      // Statut : accepté par les DTO de création et de mise à jour. Sans lui,
      // un passage en « partiellement payée » / « terminée » n'était jamais
      // transmis au serveur.
      'status': sale.status.name,
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
      if (includeItems)
        'items':
          sale.items
              .map(
                (item) => {
                  // L'identifiant de ligne DOIT être renvoyé sur un PATCH :
                  // sans lui, le backend recrée les lignes et re-décrémente le
                  // stock à chaque mise à jour. Il n'est émis que s'il est
                  // réellement connu du serveur (non vide), sinon le backend
                  // rejette la requête (« SaleItem with ID not found »).
                  if (item.id != null && item.id!.isNotEmpty) 'id': item.id,
                  if (item.productId != null) 'productId': item.productId,
                  'productName': item.productName,
                  'quantity': item.quantity,
                  'unitPrice': item.unitPrice,
                  if (item.discount != null && item.discount! > 0)
                    'discount': item.discount,
                  'currencyCode': item.currencyCode,
                  'itemType': item.itemType.name,
                  // Service du catalogue (page Offre) et palier de prix retenu.
                  if (item.serviceId != null && item.serviceId!.isNotEmpty)
                    'serviceId': item.serviceId,
                  if (item.priceTierCode != null && item.priceTierCode!.isNotEmpty)
                    'priceTierCode': item.priceTierCode,
                  if (item.taxRate != null) 'taxRate': item.taxRate,
                  if (item.notes != null) 'notes': item.notes,
                  // Mode salon : exécutant + commission figée (émis seulement
                  // si renseignés).
                  if (item.performerId != null) 'performerId': item.performerId,
                  if (item.performerName != null)
                    'performerName': item.performerName,
                  if (item.commissionRate != null)
                    'commissionRate': item.commissionRate,
                  if (item.commissionAmount != null)
                    'commissionAmount': item.commissionAmount,
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
            '[SalesAPI] 📤 Uploading ${files.length} local attachments to Cloudinary...',
          );
          final uploadResult = await _imageUploadService
              .uploadImagesWithDetails(files);
          if (uploadResult.hasSuccessfulUploads) {
            uploadedUrls = uploadResult.successfulUrls;
            debugPrint(
              '[SalesAPI] ✅ ${uploadedUrls.length} attachments uploaded successfully',
            );
          }
          if (uploadResult.hasFailures) {
            debugPrint(
              '[SalesAPI] ⚠️ ${uploadResult.failedPaths.length} attachments failed to upload',
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
  ///
  /// [includeItems] à `false` quand seule l'entête change (règlement, statut) :
  /// les lignes ne sont pas renvoyées, donc le backend ne retouche pas le stock
  /// et ne peut pas rejeter un identifiant de ligne inconnu.
  Future<ApiResponse<Sale>> updateSale(
    String id,
    Sale sale, {
    bool includeItems = true,
  }) async {
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
            '[SalesAPI] 📤 Uploading ${files.length} local attachments for update...',
          );
          final uploadResult = await _imageUploadService
              .uploadImagesWithDetails(files);
          if (uploadResult.hasSuccessfulUploads) {
            uploadedUrls = uploadResult.successfulUrls;
            debugPrint(
              '[SalesAPI] ✅ ${uploadedUrls.length} attachments uploaded successfully',
            );
          }
        }
      }

      // Utiliser DTO optimisé
      final body = _saleToCreateDto(sale, includeItems: includeItems);

      // TOUJOURS supprimer localAttachmentPaths du payload
      body.remove('localAttachmentPaths');

      // Ajouter les URLs Cloudinary uploadées
      if (uploadedUrls != null && uploadedUrls.isNotEmpty) {
        body['attachmentUrls'] = [
          ...(sale.attachmentUrls ?? []),
          ...uploadedUrls,
        ];
      }

      // PATCH et non PUT : le backend n'expose que `PATCH sales/:id`
      // (`UpdateSaleDto`). Le PUT retournait un 404/405 avalé plus haut, donc
      // le règlement n'était jamais appliqué côté serveur.
      final response = await _apiClient.patch(
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

  /// Enregistre UNE tranche de règlement sur une vente.
  ///
  /// `POST sales/:id/payments` avec `{ amount, currencyCode?, exchangeRate?,
  /// method, reference?, paidAt? }`. Le serveur recalcule lui-même le cumul
  /// payé et le statut, puis renvoie la vente à jour : aucun cumul côté client,
  /// donc pas de tranche perdue en cas de saisie concurrente.
  ///
  /// Lève une exception si l'endpoint n'est pas (encore) déployé, ce qui permet
  /// au repository de se replier sur le PATCH classique.
  Future<ApiResponse<Sale>> recordSalePayment(
    String id,
    PaymentDraft payment,
  ) async {
    try {
      final response = await _apiClient.post(
        'sales/$id/payments',
        body: payment.toRequestBody(),
        requiresAuth: true,
      );

      if (response is Map<String, dynamic>) {
        final saleData =
            (response['data'] is Map<String, dynamic>)
                ? response['data'] as Map<String, dynamic>
                : response;
        return ApiResponse<Sale>(
          success: true,
          data: Sale.fromJson(saleData),
          message: response['message'] as String? ?? 'Paiement enregistré',
          statusCode: response['statusCode'] as int? ?? 201,
        );
      }
      throw ApiExceptionFactory.fromStatusCode(
        500,
        'Format de réponse invalide du serveur',
        responseBody: response,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec de l\'enregistrement du paiement: $e');
    }
  }

  /// Liste les tranches de règlement d'une vente (`GET sales/:id/payments`).
  ///
  /// Retourne une liste vide plutôt qu'une erreur si l'historique détaillé
  /// n'est pas disponible : l'historique est un confort d'affichage, il ne doit
  /// jamais empêcher la consultation de la vente.
  Future<List<OperationPayment>> getSalePayments(String id) async {
    try {
      final response = await _apiClient.get(
        'sales/$id/payments',
        requiresAuth: true,
      );
      return OperationPayment.listFrom(response);
    } catch (e) {
      debugPrint('[SalesAPI] ⚠️ Historique des règlements indisponible: $e');
      return const <OperationPayment>[];
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
      // IMPORTANT: Supprimer localAttachmentPaths de chaque DTO
      final optimizedSales =
          localSales.map((sale) {
            final dto = _saleToCreateDto(sale);
            dto.remove(
              'localAttachmentPaths',
            ); // Ne jamais envoyer les chemins locaux au backend
            return dto;
          }).toList();
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
