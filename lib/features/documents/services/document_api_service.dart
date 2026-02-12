import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/services/image_upload_service.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/features/documents/models/document_model.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';

class DocumentApiService {
  final ApiClient _apiClient;
  final ImageUploadService _imageUploadService;

  DocumentApiService({
    ApiClient? apiClient,
    ImageUploadService? imageUploadService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _imageUploadService = imageUploadService ?? ImageUploadService();

  /// Crée un document en uploadant d'abord le fichier vers Cloudinary
  /// puis en envoyant les métadonnées au backend
  Future<ApiResponse<Document>> uploadDocument({
    required File file,
    required String entityId,
    required DocumentRelatedEntityType entityType,
    DocumentType? documentType,
    String? description,
    List<String>? tags,
  }) async {
    try {
      // 1. Upload du fichier vers Cloudinary
      debugPrint('📤 Uploading document to Cloudinary...');
      final cloudinaryUrl = await _imageUploadService.uploadImageWithRetry(
        file,
      );

      if (cloudinaryUrl == null) {
        debugPrint('❌ Failed to upload document to Cloudinary');
        return ApiResponse<Document>(
          success: false,
          data: null,
          message: 'Failed to upload document to Cloudinary',
          statusCode: 500,
        );
      }

      debugPrint('✅ Document uploaded to Cloudinary: $cloudinaryUrl');

      // 2. Préparer les métadonnées du document (CreateDocumentDto)
      final fileName = path.basename(file.path);
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final fileSize = await file.length();

      final documentDto = {
        'fileName': fileName,
        'fileType': mimeType,
        'fileSize': fileSize,
        'url': cloudinaryUrl,
        if (documentType != null)
          'documentType':
              documentType.name.substring(0, 1).toUpperCase() +
              documentType.name.substring(1),
        'relatedToEntityType':
            entityType.name.substring(0, 1).toUpperCase() +
            entityType.name.substring(1),
        'relatedToEntityId': entityId,
        if (description != null) 'description': description,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
      };

      debugPrint('[DocumentAPI] Creating document with DTO: $documentDto');

      // 3. Envoyer les métadonnées au backend
      final response = await _apiClient.post(
        'documents',
        body: documentDto,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final newDocument = Document.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        return ApiResponse<Document>(
          success: true,
          data: newDocument,
          message:
              response['message'] as String? ??
              'Document uploaded successfully.',
          statusCode: response['statusCode'] as int? ?? 201,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response?['statusCode'] as int? ?? 500,
          'Invalid response data format from server for document upload',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Error uploading document: $e');
      throw ServerException(
        'Failed to upload document: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<List<Document>>> getDocuments({
    String? entityId,
    String? entityType,
    String? documentType,
    int? page,
    int? limit,
  }) async {
    try {
      final Map<String, String> queryParams = {};
      // Utiliser les noms de champs du backend DTO
      if (entityId != null) queryParams['relatedToEntityId'] = entityId;
      if (entityType != null) queryParams['relatedToEntityType'] = entityType;
      if (documentType != null) queryParams['documentType'] = documentType;
      if (page != null) queryParams['page'] = page.toString();
      if (limit != null) queryParams['limit'] = limit.toString();

      final response = await _apiClient.get(
        'documents',
        queryParameters: queryParams,
        requiresAuth: true,
      );
      if (response != null && response['data'] != null) {
        final documents =
            (response['data'] as List)
                .map(
                  (docJson) =>
                      Document.fromJson(docJson as Map<String, dynamic>),
                )
                .toList();
        return ApiResponse<List<Document>>(
          success: true,
          data: documents,
          message:
              response['message'] as String? ??
              'Documents fetched successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
          // paginationInfo: response['pagination'] // Si votre API retourne des infos de pagination
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
        'Failed to fetch documents: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Document>> getDocumentById(String id) async {
    try {
      final response = await _apiClient.get(
        'documents/$id',
        requiresAuth: true,
      );
      if (response != null && response['data'] != null) {
        final document = Document.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        return ApiResponse<Document>(
          success: true,
          data: document,
          message:
              response['message'] as String? ??
              'Document fetched successfully.',
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
        'Failed to fetch document: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<void>> deleteDocument(String id) async {
    try {
      await _apiClient.delete('documents/$id', requiresAuth: true);
      // Pour DELETE, une réponse réussie peut ne pas avoir de 'data'.
      // Le simple fait de ne pas avoir d'exception est souvent suffisant.
      return ApiResponse<void>(
        success: true,
        message: 'Document deleted successfully.',
        statusCode: 200, // Ou 204 si le backend retourne No Content
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to delete document: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<File>> downloadDocument(String id) async {
    try {
      // First get the document metadata to retrieve the download URL
      final docResponse = await getDocumentById(id);

      if (docResponse.success && docResponse.data != null) {
        final document = docResponse.data!;
        // Use the url from the document to download
        // This assumes the backend provides a direct download URL
        // You may need to adjust based on your actual API implementation

        return ApiResponse<File>(
          success: true,
          data:
              null, // In a real implementation, you'd download and return the file
          message: 'Document download URL retrieved: ${document.url}',
          statusCode: 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          404,
          'Document not found or unable to retrieve download URL',
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to download document: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Document>> updateDocument(
    String id, {
    String? name,
    String? description,
    String? documentType,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (documentType != null) updateData['documentType'] = documentType;

      final response = await _apiClient.patch(
        'documents/$id',
        body: updateData,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final document = Document.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        return ApiResponse<Document>(
          success: true,
          data: document,
          message:
              response['message'] as String? ??
              'Document updated successfully.',
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
        'Failed to update document: An unexpected error occurred. $e',
      );
    }
  }
}

// Assurez-vous que le modèle Document est défini, par exemple:
// c:\\Users\\DevSpace\\Flutter\\wanzo\\lib\\features\\documents\\models\\document_model.dart
/*
class Document {
  final String id;
  final String fileName;
  final String fileUrl;
  final String documentType;
  final String entityId;
  final String entityType;
  final DateTime uploadedAt;
  final String? description; // Ajouté pour correspondre à l'upload

  Document({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.documentType,
    required this.entityId,
    required this.entityType,
    required this.uploadedAt,
    this.description,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      fileUrl: json['fileUrl'] as String,
      documentType: json['documentType'] as String,
      entityId: json['entityId'] as String,
      entityType: json['entityType'] as String,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      description: json['description'] as String?,
    );
  }
}
*/
