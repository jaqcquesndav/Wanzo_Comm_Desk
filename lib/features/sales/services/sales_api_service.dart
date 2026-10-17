import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/services/image_upload_service.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/core/models/operation_payment.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/sales/services/sale_dto.dart';

/// Service API pour la gestion des ventes
class SalesApiService {
  final ApiClient _apiClient;
  final ImageUploadService _imageUploadService;

  SalesApiService({
    ApiClient? apiClient,
    ImageUploadService? imageUploadService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _imageUploadService = imageUploadService ?? ImageUploadService();

  /// Corps de requête : construction UNIQUE partagée avec la synchronisation
  /// (voir [saleToApiDto] pour le contrat backend).
  Map<String, dynamic> _saleToCreateDto(Sale sale, {bool includeItems = true}) =>
      saleToApiDto(sale, includeItems: includeItems);

  /// TOUTES les ventes, page par page jusqu'à une page incomplète (le
  /// backend renvoie 10 ventes quand `limit` est absent).
  Future<ApiResponse<List<Sale>>> getAllSalesPaged({
    int pageSize = salesPageSize,
  }) async {
    final all = <Sale>[];
    for (var page = 1; page <= salesMaxPages; page++) {
      final res = await getSales(page: page, limit: pageSize);
      if (!res.success) return res;
      final batch = res.data ?? const <Sale>[];
      all.addAll(batch);
      if (batch.length < pageSize) break;
    }
    return ApiResponse<List<Sale>>(
      success: true,
      data: all,
      message: 'Ventes récupérées avec succès',
      statusCode: 200,
    );
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
        // companyId / businessUnitId du contexte : isolation par unité.
        includeBusinessContext: true,
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

        // Une vente mal formée est ignorée (et tracée) au lieu de faire
        // échouer toute la liste.
        final sales = parseSaleList(salesList);

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
        // Hors ligne : la vente reste `pending` et la synchro la crée ;
        // la mettre aussi en file la créerait deux fois.
        queueOffline: false,
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
        // Hors ligne, le dépôt met déjà la tranche dans SA file (rejeu
        // idempotent) : la mettre aussi dans la file générique la ferait
        // compter deux fois au retour du réseau.
        queueOffline: false,
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
  ///
  /// Contrat `CompleteSaleDto` : `paidAmountInCdf` (OBLIGATOIRE, montant EN CDF
  /// de ce règlement), `paymentMethod`, `paymentReference`. Sans corps, le
  /// serveur répondait 400.
  Future<ApiResponse<Sale>> completeSale(
    String id, {
    required double paidAmountInCdf,
    String? paymentMethod,
    String? paymentReference,
  }) async {
    try {
      final response = await _apiClient.put(
        'sales/$id/complete',
        body: <String, dynamic>{
          'paidAmountInCdf': paidAmountInCdf,
          if (paymentMethod != null && paymentMethod.isNotEmpty)
            'paymentMethod': paymentMethod,
          if (paymentReference != null && paymentReference.trim().isNotEmpty)
            'paymentReference': paymentReference.trim(),
        },
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
  Future<ApiResponse<Sale>> cancelSale(String id, {String? reason}) async {
    try {
      final response = await _apiClient.put(
        'sales/$id/cancel',
        body: <String, dynamic>{
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
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
