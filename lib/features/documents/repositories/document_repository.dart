import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/document_model.dart';
import '../services/document_api_service.dart';

class DocumentRepository {
  final DocumentApiService _apiService;

  DocumentRepository({required DocumentApiService apiService})
    : _apiService = apiService;

  /// Upload un nouveau document
  Future<Document?> uploadDocument({
    required File file,
    required String entityId,
    required DocumentRelatedEntityType entityType,
  }) async {
    try {
      final response = await _apiService.uploadDocument(
        file: file,
        entityId: entityId,
        entityType: entityType,
      );
      if (response.success && response.data != null) {
        debugPrint("Document uploaded successfully: ${response.data!.id}");
        return response.data;
      }
      debugPrint("Failed to upload document: ${response.message}");
      return null;
    } catch (e) {
      debugPrint("Error uploading document: $e");
      return null;
    }
  }

  /// Récupère la liste des documents avec filtres
  Future<List<Document>> getDocuments({
    String? entityId,
    String? entityType,
    String? documentType,
    int? page,
    int? limit,
  }) async {
    try {
      final response = await _apiService.getDocuments(
        entityId: entityId,
        entityType: entityType,
        documentType: documentType,
        page: page,
        limit: limit,
      );
      if (response.success && response.data != null) {
        debugPrint("Fetched ${response.data!.length} documents");
        return response.data!;
      }
      debugPrint("Failed to fetch documents: ${response.message}");
      return [];
    } catch (e) {
      debugPrint("Error fetching documents: $e");
      return [];
    }
  }

  /// Récupère un document par son ID
  Future<Document?> getDocumentById(String id) async {
    try {
      final response = await _apiService.getDocumentById(id);
      if (response.success && response.data != null) {
        return response.data;
      }
      debugPrint("Failed to fetch document: ${response.message}");
      return null;
    } catch (e) {
      debugPrint("Error fetching document: $e");
      return null;
    }
  }

  /// Télécharge un document
  Future<File?> downloadDocument(String id) async {
    try {
      final response = await _apiService.downloadDocument(id);
      if (response.success) {
        debugPrint("Document download initiated: ${response.message}");
        // Dans une implémentation réelle, vous retourneriez le fichier téléchargé
        return response.data;
      }
      debugPrint("Failed to download document: ${response.message}");
      return null;
    } catch (e) {
      debugPrint("Error downloading document: $e");
      return null;
    }
  }

  /// Met à jour les métadonnées d'un document
  Future<Document?> updateDocument(
    String id, {
    String? name,
    String? description,
    String? documentType,
  }) async {
    try {
      final response = await _apiService.updateDocument(
        id,
        name: name,
        description: description,
        documentType: documentType,
      );
      if (response.success && response.data != null) {
        debugPrint("Document updated successfully: $id");
        return response.data;
      }
      debugPrint("Failed to update document: ${response.message}");
      return null;
    } catch (e) {
      debugPrint("Error updating document: $e");
      return null;
    }
  }

  /// Supprime un document
  Future<bool> deleteDocument(String id) async {
    try {
      final response = await _apiService.deleteDocument(id);
      if (response.success) {
        debugPrint("Document deleted successfully: $id");
        return true;
      }
      debugPrint("Failed to delete document: ${response.message}");
      return false;
    } catch (e) {
      debugPrint("Error deleting document: $e");
      return false;
    }
  }

  /// Récupère les documents liés à une entité spécifique
  Future<List<Document>> getEntityDocuments({
    required String entityId,
    required String entityType,
  }) async {
    return getDocuments(entityId: entityId, entityType: entityType);
  }
}
