import 'package:flutter/foundation.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/features/financing/models/financing_request.dart';
import 'dart:io';
import 'package:wanzo/core/services/image_upload_service.dart';

class FinancingApiService {
  final ApiClient _apiClient;
  final ImageUploadService _imageUploadService;

  FinancingApiService({
    ApiClient? apiClient,
    ImageUploadService? imageUploadService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _imageUploadService = imageUploadService ?? ImageUploadService();

  /// Récupère la liste des demandes de financement
  /// Paramètres optionnels:
  /// - status: statut de la demande (pending, approved, rejected, etc.)
  /// - type: type de financement (cashCredit, investmentCredit, leasing, etc.)
  /// - financialProduct: produit financier (cashFlow, investment, equipment, etc.)
  Future<ApiResponse<List<FinancingRequest>>> getFinancingRequests({
    String? status,
    FinancingType? type,
    FinancialProduct? financialProduct,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? page,
    int? limit,
  }) async {
    try {
      final Map<String, String> queryParams = {};
      if (page != null) queryParams['page'] = page.toString();
      if (limit != null) queryParams['limit'] = limit.toString();
      if (status != null) queryParams['status'] = status;
      if (type != null) queryParams['type'] = type.toString().split('.').last;
      if (financialProduct != null) {
        queryParams['financialProduct'] =
            financialProduct.toString().split('.').last;
      }
      if (dateFrom != null) {
        queryParams['dateFrom'] = dateFrom.toIso8601String();
      }
      if (dateTo != null) queryParams['dateTo'] = dateTo.toIso8601String();

      final response = await _apiClient.get(
        'financing-requests',
        queryParameters: queryParams,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final requests =
            (response['data'] as List)
                .map(
                  (reqJson) => FinancingRequest.fromJson(
                    reqJson as Map<String, dynamic>,
                  ),
                )
                .toList();

        return ApiResponse<List<FinancingRequest>>(
          success: true,
          data: requests,
          message:
              response['message'] as String? ??
              'Demandes de financement récupérées avec succès.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Format de réponse invalide du serveur',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Échec de récupération des demandes de financement: Une erreur inattendue est survenue. $e',
      );
    }
  }

  /// Crée une nouvelle demande de financement
  /// Paramètres:
  /// - request: La demande de financement à créer
  /// - attachments: Liste de fichiers à joindre à la demande (optionnel)
  Future<ApiResponse<FinancingRequest>> createFinancingRequest(
    FinancingRequest request, {
    List<File>? attachments,
  }) async {
    try {
      // Collecter tous les fichiers à uploader
      List<File> filesToUpload = [];

      // 1. Fichiers passés explicitement en paramètre
      if (attachments != null && attachments.isNotEmpty) {
        filesToUpload.addAll(attachments);
      }

      // 2. Fichiers référencés dans attachmentPaths (chemins locaux)
      if (request.attachmentPaths != null &&
          request.attachmentPaths!.isNotEmpty) {
        for (final path in request.attachmentPaths!) {
          // Vérifier si c'est un chemin local (pas une URL)
          if (!path.startsWith('http')) {
            final file = File(path);
            if (await file.exists()) {
              filesToUpload.add(file);
            }
          }
        }
      }

      // Uploader vers Cloudinary
      List<String>? attachmentUrls;
      if (filesToUpload.isNotEmpty) {
        debugPrint(
          "[FinancingAPI] 📤 Starting image uploads: ${filesToUpload.length} files",
        );
        // Utiliser uploadImagesWithDetails pour une gestion d'erreurs robuste
        // Ne lance jamais d'exception - continue même si certains uploads échouent
        final uploadResult = await _imageUploadService.uploadImagesWithDetails(
          filesToUpload,
        );
        attachmentUrls =
            uploadResult.successfulUrls.isNotEmpty
                ? uploadResult.successfulUrls
                : null;

        // Log des fichiers échoués (mais on continue quand même)
        if (uploadResult.hasFailures) {
          debugPrint(
            "[FinancingAPI] ⚠️ Some attachments failed to upload: ${uploadResult.failedPaths.length} failed",
          );
          for (final failedPath in uploadResult.failedPaths) {
            debugPrint(
              "  - $failedPath: ${uploadResult.errorMessages[failedPath]}",
            );
          }
        }
        if (uploadResult.hasSuccessfulUploads) {
          debugPrint(
            "[FinancingAPI] ✅ Image upload successful: ${uploadResult.successfulUrls.length} URLs",
          );
        }
      }

      // Préparer le payload
      final Map<String, dynamic> requestData = request.toJson();
      requestData.remove(
        'attachmentPaths',
      ); // CRITIQUE: Ne pas envoyer les chemins locaux au backend
      if (attachmentUrls != null && attachmentUrls.isNotEmpty) {
        requestData['attachmentUrls'] = attachmentUrls;
      }

      // Faire la requête API
      final response = await _apiClient.post(
        'financing-requests',
        body: requestData,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final createdRequest = FinancingRequest.fromJson(
          response['data'] as Map<String, dynamic>,
        );

        return ApiResponse<FinancingRequest>(
          success: true,
          data: createdRequest,
          message:
              response['message'] as String? ??
              'Demande de financement créée avec succès.',
          statusCode: response['statusCode'] as int? ?? 201,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Format de réponse invalide du serveur',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Échec de création de la demande de financement: Une erreur inattendue est survenue. $e',
      );
    }
  }

  /// Récupère une demande de financement par son ID
  Future<ApiResponse<FinancingRequest>> getFinancingRequestById(
    String id,
  ) async {
    try {
      final response = await _apiClient.get(
        'financing-requests/$id',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final request = FinancingRequest.fromJson(
          response['data'] as Map<String, dynamic>,
        );

        return ApiResponse<FinancingRequest>(
          success: true,
          data: request,
          message:
              response['message'] as String? ??
              'Demande de financement récupérée avec succès.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Format de réponse invalide du serveur',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Échec de récupération de la demande de financement: Une erreur inattendue est survenue. $e',
      );
    }
  }

  /// Met à jour une demande de financement existante
  /// Paramètres:
  /// - id: ID de la demande à mettre à jour
  /// - request: Les nouvelles données de la demande
  /// - newAttachments: Liste de nouveaux fichiers à joindre (optionnel)
  Future<ApiResponse<FinancingRequest>> updateFinancingRequest(
    String id,
    FinancingRequest request, {
    List<File>? newAttachments,
  }) async {
    try {
      // Collecter tous les fichiers à uploader
      List<File> filesToUpload = [];

      // 1. Nouveaux fichiers passés explicitement en paramètre
      if (newAttachments != null && newAttachments.isNotEmpty) {
        filesToUpload.addAll(newAttachments);
      }

      // 2. Fichiers référencés dans attachmentPaths (chemins locaux)
      if (request.attachmentPaths != null &&
          request.attachmentPaths!.isNotEmpty) {
        for (final path in request.attachmentPaths!) {
          // Vérifier si c'est un chemin local (pas une URL)
          if (!path.startsWith('http')) {
            final file = File(path);
            if (await file.exists()) {
              filesToUpload.add(file);
            }
          }
        }
      }

      // Uploader vers Cloudinary
      List<String>? newAttachmentUrls;
      if (filesToUpload.isNotEmpty) {
        debugPrint(
          "[FinancingAPI] 📤 Uploading ${filesToUpload.length} new attachments for update...",
        );
        final uploadResult = await _imageUploadService.uploadImagesWithDetails(
          filesToUpload,
        );
        if (uploadResult.hasSuccessfulUploads) {
          newAttachmentUrls = uploadResult.successfulUrls;
          debugPrint(
            "[FinancingAPI] ✅ ${newAttachmentUrls.length} attachments uploaded successfully",
          );
        }
        if (uploadResult.hasFailures) {
          debugPrint(
            "[FinancingAPI] ⚠️ ${uploadResult.failedPaths.length} attachments failed to upload",
          );
        }
      }

      // Préparer le payload
      final Map<String, dynamic> requestData = request.toJson();
      requestData.remove(
        'attachmentPaths',
      ); // CRITIQUE: Ne pas envoyer les chemins locaux au backend

      // Ajouter les nouvelles URLs Cloudinary uploadées
      if (newAttachmentUrls != null && newAttachmentUrls.isNotEmpty) {
        // Récupérer les URLs existantes du JSON ou une liste vide
        final existingUrls =
            (requestData['attachmentUrls'] as List<dynamic>?) ?? [];
        requestData['attachmentUrls'] = [...existingUrls, ...newAttachmentUrls];
      }

      final response = await _apiClient.put(
        'financing-requests/$id',
        body: requestData,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final updatedRequest = FinancingRequest.fromJson(
          response['data'] as Map<String, dynamic>,
        );

        return ApiResponse<FinancingRequest>(
          success: true,
          data: updatedRequest,
          message:
              response['message'] as String? ??
              'Demande de financement mise à jour avec succès.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Format de réponse invalide du serveur',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Échec de mise à jour de la demande de financement: Une erreur inattendue est survenue. $e',
      );
    }
  }

  /// Supprime une demande de financement
  Future<ApiResponse<void>> deleteFinancingRequest(String id) async {
    try {
      final response = await _apiClient.delete(
        'financing-requests/$id',
        requiresAuth: true,
      );

      return ApiResponse<void>(
        success: true,
        data: null,
        message:
            response != null && response['message'] != null
                ? response['message'] as String
                : 'Demande de financement supprimée avec succès.',
        statusCode:
            response != null && response['statusCode'] != null
                ? response['statusCode'] as int
                : 200,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Échec de suppression de la demande de financement: Une erreur inattendue est survenue. $e',
      );
    }
  }

  /// Approuve une demande de financement
  Future<ApiResponse<FinancingRequest>> approveFinancingRequest(
    String id, {
    required DateTime approvalDate,
    double? interestRate,
    int? termMonths,
    double? monthlyPayment,
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        'approvalDate': approvalDate.toIso8601String(),
        'status': 'approved',
      };

      if (interestRate != null) {
        requestData['interestRate'] = interestRate;
      }
      if (termMonths != null) {
        requestData['termMonths'] = termMonths;
      }
      if (monthlyPayment != null) {
        requestData['monthlyPayment'] = monthlyPayment;
      }

      final response = await _apiClient.put(
        'financing-requests/$id/approve',
        body: requestData,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final approvedRequest = FinancingRequest.fromJson(
          response['data'] as Map<String, dynamic>,
        );

        return ApiResponse<FinancingRequest>(
          success: true,
          data: approvedRequest,
          message:
              response['message'] as String? ??
              'Demande de financement approuvée avec succès.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Format de réponse invalide du serveur',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Échec d\'approbation de la demande de financement: Une erreur inattendue est survenue. $e',
      );
    }
  }

  /// Débloque les fonds pour une demande de financement
  Future<ApiResponse<FinancingRequest>> disburseFunds(
    String id, {
    required DateTime disbursementDate,
    List<DateTime>? scheduledPayments,
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        'disbursementDate': disbursementDate.toIso8601String(),
        'status': 'disbursed',
      };

      if (scheduledPayments != null) {
        requestData['scheduledPayments'] =
            scheduledPayments.map((date) => date.toIso8601String()).toList();
      }

      final response = await _apiClient.put(
        'financing-requests/$id/disburse',
        body: requestData,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final disbursedRequest = FinancingRequest.fromJson(
          response['data'] as Map<String, dynamic>,
        );

        return ApiResponse<FinancingRequest>(
          success: true,
          data: disbursedRequest,
          message:
              response['message'] as String? ?? 'Fonds débloqués avec succès.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Format de réponse invalide du serveur',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Échec de déblocage des fonds: Une erreur inattendue est survenue. $e',
      );
    }
  }

  /// Enregistre un paiement pour une demande de financement
  Future<ApiResponse<FinancingRequest>> recordPayment(
    String id, {
    required DateTime paymentDate,
    required double amount,
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        'paymentDate': paymentDate.toIso8601String(),
        'amount': amount,
      };

      final response = await _apiClient.post(
        'financing-requests/$id/payments',
        body: requestData,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final updatedRequest = FinancingRequest.fromJson(
          response['data'] as Map<String, dynamic>,
        );

        return ApiResponse<FinancingRequest>(
          success: true,
          data: updatedRequest,
          message:
              response['message'] as String? ??
              'Paiement enregistré avec succès.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Format de réponse invalide du serveur',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Échec d\'enregistrement du paiement: Une erreur inattendue est survenue. $e',
      );
    }
  }

  /// Récupère le score de crédit de l'entreprise
  /// NOTE: Cet endpoint n'est pas encore implémenté côté backend (XGBoost en attente)
  /// Retourne une valeur par défaut en cas d'erreur 404
  Future<ApiResponse<Map<String, dynamic>>> getCreditScore() async {
    try {
      final response = await _apiClient.get(
        'financing/credit-score',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response['data'] as Map<String, dynamic>,
          message:
              response['message'] as String? ??
              'Score de crédit récupéré avec succès.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Format de réponse invalide du serveur',
          responseBody: response,
        );
      }
    } on NotFoundException {
      // L'endpoint credit-score n'est pas encore implémenté côté backend
      // Retourner une valeur par défaut
      debugPrint(
        '⚠️ [FinancingApiService] Endpoint credit-score non disponible (backend non implémenté)',
      );
      return ApiResponse<Map<String, dynamic>>(
        success: true,
        data: {
          'creditScore': null,
          'message':
              'Score de crédit non disponible - fonctionnalité en cours de développement',
          'available': false,
        },
        message: 'Score de crédit non disponible',
        statusCode: 200,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Échec de récupération du score de crédit: Une erreur inattendue est survenue. $e',
      );
    }
  }

  /// Télécharge une pièce jointe pour une demande de financement
  Future<ApiResponse<String>> uploadAttachment(
    String requestId,
    File file,
  ) async {
    try {
      // Utilise le service d'upload d'image avec retry pour télécharger le fichier
      final String? fileUrl = await _imageUploadService.uploadImageWithRetry(
        file,
      );

      if (fileUrl != null) {
        // Enregistre l'URL de la pièce jointe dans la demande de financement
        final response = await _apiClient.post(
          'financing-requests/$requestId/attachments',
          body: {'fileUrl': fileUrl},
          requiresAuth: true,
        );

        if (response != null && response['success'] == true) {
          return ApiResponse<String>(
            success: true,
            data: fileUrl,
            message: 'Pièce jointe téléchargée avec succès.',
            statusCode: 200,
          );
        } else {
          throw ApiExceptionFactory.fromStatusCode(
            response != null ? response['statusCode'] as int? ?? 500 : 500,
            'Échec de l\'enregistrement de la pièce jointe: ${response != null ? response['message'] as String? ?? 'Raison inconnue' : 'Réponse null'}',
            responseBody: response,
          );
        }
      } else {
        throw ServerException(
          'Échec du téléchargement de la pièce jointe: Impossible d\'obtenir l\'URL de l\'image',
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Erreur inattendue lors du téléchargement de la pièce jointe: $e',
      );
    }
  }
}
