import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/services/image_upload_service.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/core/models/api_response.dart';

/// Interface standardisée pour les opérations d'API des dépenses
abstract class ExpenseApiService {
  /// Récupère la liste des dépenses avec filtrage et pagination
  Future<ApiResponse<List<Expense>>> getExpenses({
    int? page,
    int? limit,
    String? dateFrom,
    String? dateTo,
    String? categoryId,
    String? sortBy,
    String? sortOrder,
  });

  /// Crée une nouvelle dépense
  Future<ApiResponse<Expense>> createExpense(
    DateTime date,
    double amount,
    String motif,
    String categoryId,
    String? paymentMethod,
    String? supplierId, {
    List<File>? attachments,
    double? paidAmount,
    String? paymentStatus,
    String? supplierName,
    String? currencyCode,
    double? exchangeRate,
  });

  /// Récupère une dépense par son ID
  Future<ApiResponse<Expense>> getExpenseById(String id);

  /// Met à jour une dépense existante
  Future<ApiResponse<Expense>> updateExpense(
    String id,
    DateTime? date,
    double? amount,
    String? motif,
    String? categoryId,
    String? paymentMethod,
    String? supplierId, {
    List<File>? newAttachments,
    List<String>? attachmentUrlsToRemove,
    double? paidAmount,
    String? paymentStatus,
    String? supplierName,
    String? currencyCode,
    double? exchangeRate,
  });

  /// Supprime une dépense
  Future<ApiResponse<void>> deleteExpense(String id);

  /// Récupère la liste des catégories de dépenses
  Future<ApiResponse<List<Map<String, dynamic>>>> getExpenseCategories();

  /// Crée une nouvelle catégorie de dépense
  Future<ApiResponse<Map<String, dynamic>>> createExpenseCategory(
    String name,
    String? description,
    String type,
  );

  /// Met à jour une catégorie de dépense
  Future<ApiResponse<Map<String, dynamic>>> updateExpenseCategory(
    String id,
    String? name,
    String? description,
    String? type,
  );

  /// Supprime une catégorie de dépense
  Future<ApiResponse<void>> deleteExpenseCategory(String id);
}

/// Implémentation du service API des dépenses
class ExpenseApiServiceImpl implements ExpenseApiService {
  final ApiClient _apiClient;
  final ImageUploadService _imageUploadService;

  ExpenseApiServiceImpl(this._apiClient, this._imageUploadService);

  @override
  Future<ApiResponse<List<Expense>>> getExpenses({
    int? page,
    int? limit,
    String? dateFrom,
    String? dateTo,
    String? categoryId,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final queryParameters = <String, String>{
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
        if (categoryId != null) 'categoryId': categoryId,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      final response = await _apiClient.get(
        'expenses',
        queryParameters: queryParameters,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        var data = response['data'];

        // Handle nested response structure
        List<dynamic> expensesList;
        if (data is List) {
          expensesList = data;
        } else if (data is Map<String, dynamic>) {
          // Try 'expenses' first, then 'data', then 'items'
          expensesList =
              (data['expenses'] as List?) ??
              (data['data'] as List?) ??
              (data['items'] as List?) ??
              [];
          debugPrint(
            '📊 Expenses API - Extracted ${expensesList.length} expenses from response',
          );
        } else {
          expensesList = [];
        }

        final expenses =
            expensesList
                .map((json) => Expense.fromJson(json as Map<String, dynamic>))
                .toList();

        return ApiResponse<List<Expense>>(
          success: true,
          data: expenses,
          message:
              response['message'] as String? ??
              'Expenses fetched successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        return ApiResponse<List<Expense>>(
          success: false,
          data: [],
          message: 'Failed to fetch expenses: Invalid response format',
          statusCode: 500,
        );
      }
    } catch (e) {
      return ApiResponse<List<Expense>>(
        success: false,
        data: [],
        message: 'Failed to fetch expenses: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<Expense>> createExpense(
    DateTime date,
    double amount,
    String motif,
    String categoryId,
    String? paymentMethod,
    String? supplierId, {
    List<File>? attachments,
    double? paidAmount,
    String? paymentStatus,
    String? supplierName,
    String? currencyCode,
    double? exchangeRate,
  }) async {
    try {
      List<String>? attachmentUrls;
      if (attachments != null && attachments.isNotEmpty) {
        debugPrint(
          "Starting image uploads for expense creation: ${attachments.length} files",
        );
        // Utiliser uploadImagesWithDetails pour une gestion d'erreurs robuste
        // Ne lance jamais d'exception - continue même si certains uploads échouent
        final uploadResult = await _imageUploadService.uploadImagesWithDetails(
          attachments,
        );
        attachmentUrls =
            uploadResult.successfulUrls.isNotEmpty
                ? uploadResult.successfulUrls
                : null;

        // Log des fichiers échoués (mais on continue quand même)
        if (uploadResult.hasFailures) {
          debugPrint(
            "⚠️ Some attachments failed to upload: ${uploadResult.failedPaths.length} failed",
          );
          for (final failedPath in uploadResult.failedPaths) {
            debugPrint(
              "  - $failedPath: ${uploadResult.errorMessages[failedPath]}",
            );
          }
        }
        if (uploadResult.hasSuccessfulUploads) {
          debugPrint(
            "✅ Image upload successful: ${uploadResult.successfulUrls.length} URLs",
          );
        }
      }

      // Construire le corps de la requête JSON
      final Map<String, dynamic> body = {
        'date': date.toIso8601String(),
        'motif': motif,
        'amount': amount,
        'category': categoryId,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (supplierId != null) 'supplierId': supplierId,
        if (paidAmount != null) 'paidAmount': paidAmount,
        if (paymentStatus != null) 'paymentStatus': paymentStatus,
        if (supplierName != null) 'supplierName': supplierName,
        if (currencyCode != null) 'currencyCode': currencyCode,
        if (exchangeRate != null) 'exchangeRate': exchangeRate,
        if (attachmentUrls != null && attachmentUrls.isNotEmpty)
          'attachmentUrls': attachmentUrls,
      };

      debugPrint("[ExpenseAPI] Creating expense with body: $body");

      // Utiliser une requête JSON standard (pas multipart)
      final response = await _apiClient.post(
        'expenses',
        body: body,
        requiresAuth: true,
      );

      // Le ApiClient.post retourne déjà le JSON décodé
      if (response != null && response['data'] != null) {
        final expense = Expense.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        debugPrint(
          "[ExpenseAPI] ✅ Create expense success. Attachment URLs: ${expense.attachmentUrls}",
        );
        return ApiResponse<Expense>(
          success: true,
          data: expense,
          message:
              response['message'] as String? ?? 'Expense created successfully.',
          statusCode: response['statusCode'] as int? ?? 201,
        );
      } else {
        debugPrint(
          "[ExpenseAPI] ❌ Create expense failed - Invalid response format",
        );
        return ApiResponse<Expense>(
          success: false,
          data: null,
          message: 'Failed to create expense: Invalid response format',
          statusCode: 500,
        );
      }
    } catch (e) {
      debugPrint("[ExpenseAPI] ❌ Error creating expense: $e");
      return ApiResponse<Expense>(
        success: false,
        data: null,
        message: 'Error creating expense: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<Expense>> getExpenseById(String id) async {
    try {
      final response = await _apiClient.get('expenses/$id', requiresAuth: true);

      if (response != null && response['data'] != null) {
        final expense = Expense.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        return ApiResponse<Expense>(
          success: true,
          data: expense,
          message:
              response['message'] as String? ?? 'Expense fetched successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        return ApiResponse<Expense>(
          success: false,
          data: null,
          message: 'Failed to fetch expense: Invalid response format',
          statusCode: 500,
        );
      }
    } catch (e) {
      return ApiResponse<Expense>(
        success: false,
        data: null,
        message: 'Failed to fetch expense: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<Expense>> updateExpense(
    String id,
    DateTime? date,
    double? amount,
    String? motif,
    String? categoryId,
    String? paymentMethod,
    String? supplierId, {
    List<File>? newAttachments,
    List<String>? attachmentUrlsToRemove,
    double? paidAmount,
    String? paymentStatus,
    String? supplierName,
    String? currencyCode,
    double? exchangeRate,
  }) async {
    try {
      List<String>? uploadedAttachmentUrls;
      if (newAttachments != null && newAttachments.isNotEmpty) {
        debugPrint(
          "Starting image uploads for expense update: ${newAttachments.length} files",
        );
        // Utiliser uploadImagesWithDetails pour une gestion d'erreurs robuste
        // Ne lance jamais d'exception - continue même si certains uploads échouent
        final uploadResult = await _imageUploadService.uploadImagesWithDetails(
          newAttachments,
        );
        uploadedAttachmentUrls =
            uploadResult.successfulUrls.isNotEmpty
                ? uploadResult.successfulUrls
                : null;

        // Log des fichiers échoués (mais on continue quand même)
        if (uploadResult.hasFailures) {
          debugPrint(
            "⚠️ Some attachments failed to upload: ${uploadResult.failedPaths.length} failed",
          );
          for (final failedPath in uploadResult.failedPaths) {
            debugPrint(
              "  - $failedPath: ${uploadResult.errorMessages[failedPath]}",
            );
          }
        }
        if (uploadResult.hasSuccessfulUploads) {
          debugPrint(
            "✅ Image upload successful: ${uploadResult.successfulUrls.length} URLs",
          );
        }
      }

      // Construire le corps de la requête JSON
      final Map<String, dynamic> body = {
        if (date != null) 'date': date.toIso8601String(),
        if (amount != null) 'amount': amount,
        if (motif != null) 'motif': motif,
        if (categoryId != null) 'category': categoryId,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (supplierId != null) 'supplierId': supplierId,
        if (paidAmount != null) 'paidAmount': paidAmount,
        if (paymentStatus != null) 'paymentStatus': paymentStatus,
        if (supplierName != null) 'supplierName': supplierName,
        if (currencyCode != null) 'currencyCode': currencyCode,
        if (exchangeRate != null) 'exchangeRate': exchangeRate,
        if (uploadedAttachmentUrls != null && uploadedAttachmentUrls.isNotEmpty)
          'newAttachmentUrls': uploadedAttachmentUrls,
        if (attachmentUrlsToRemove != null && attachmentUrlsToRemove.isNotEmpty)
          'attachmentUrlsToRemove': attachmentUrlsToRemove,
      };

      debugPrint("[ExpenseAPI] Updating expense $id with body: $body");

      // Utiliser une requête JSON standard (pas multipart)
      final response = await _apiClient.patch(
        'expenses/$id',
        body: body,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final expense = Expense.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        debugPrint(
          "[ExpenseAPI] ✅ Update expense success. Attachment URLs: ${expense.attachmentUrls}",
        );
        return ApiResponse<Expense>(
          success: true,
          data: expense,
          message:
              response['message'] as String? ?? 'Expense updated successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        debugPrint(
          "[ExpenseAPI] ❌ Update expense failed - Invalid response format",
        );
        return ApiResponse<Expense>(
          success: false,
          data: null,
          message: 'Failed to update expense: Invalid response format',
          statusCode: 500,
        );
      }
    } catch (e) {
      debugPrint("[ExpenseAPI] ❌ Error updating expense: $e");
      return ApiResponse<Expense>(
        success: false,
        data: null,
        message: 'Error updating expense: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<void>> deleteExpense(String id) async {
    try {
      await _apiClient.delete('expenses/$id', requiresAuth: true);
      return ApiResponse<void>(
        success: true,
        data: null,
        message: 'Expense deleted successfully.',
        statusCode: 200,
      );
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        data: null,
        message: 'Failed to delete expense: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<List<Map<String, dynamic>>>> getExpenseCategories() async {
    try {
      final response = await _apiClient.get(
        'expenses/categories',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final categories =
            (response['data'] as List)
                .map((json) => json as Map<String, dynamic>)
                .toList();

        return ApiResponse<List<Map<String, dynamic>>>(
          success: true,
          data: categories,
          message:
              response['message'] as String? ??
              'Categories fetched successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        return ApiResponse<List<Map<String, dynamic>>>(
          success: false,
          data: [],
          message: 'Failed to fetch categories: Invalid response format',
          statusCode: 500,
        );
      }
    } catch (e) {
      return ApiResponse<List<Map<String, dynamic>>>(
        success: false,
        data: [],
        message: 'Failed to fetch categories: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> createExpenseCategory(
    String name,
    String? description,
    String type,
  ) async {
    try {
      final requestBody = {
        'name': name,
        'type': type,
        if (description != null) 'description': description,
      };

      final response = await _apiClient.post(
        'expenses/categories',
        body: requestBody,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response['data'] as Map<String, dynamic>,
          message:
              response['message'] as String? ??
              'Category created successfully.',
          statusCode: response['statusCode'] as int? ?? 201,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          data: null,
          message: 'Failed to create category: Invalid response format',
          statusCode: 500,
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: 'Failed to create category: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> updateExpenseCategory(
    String id,
    String? name,
    String? description,
    String? type,
  ) async {
    try {
      final requestBody = <String, dynamic>{
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (type != null) 'type': type,
      };

      final response = await _apiClient.patch(
        'expenses/categories/$id',
        body: requestBody,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response['data'] as Map<String, dynamic>,
          message:
              response['message'] as String? ??
              'Category updated successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          data: null,
          message: 'Failed to update category: Invalid response format',
          statusCode: 500,
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        data: null,
        message: 'Failed to update category: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<void>> deleteExpenseCategory(String id) async {
    try {
      await _apiClient.delete('expenses/categories/$id', requiresAuth: true);
      return ApiResponse<void>(
        success: true,
        data: null,
        message: 'Category deleted successfully.',
        statusCode: 200,
      );
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        data: null,
        message: 'Failed to delete category: ${e.toString()}',
        statusCode: 500,
      );
    }
  }
}
