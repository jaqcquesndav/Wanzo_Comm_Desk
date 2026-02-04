import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart'; // Added for Hive
import 'package:uuid/uuid.dart'; // Added for generating local IDs
import '../models/expense.dart';
import '../services/expense_api_service.dart';

class ExpenseRepository {
  final ExpenseApiService _expenseApiService;
  static const _expensesBoxName = 'expenses'; // Added Hive box name
  late final Box<Expense> _expensesBox; // Added Hive box instance
  final _uuid = const Uuid(); // Added Uuid instance

  ExpenseRepository({required ExpenseApiService expenseApiService})
    : _expenseApiService = expenseApiService;

  Future<void> init() async {
    _expensesBox = await Hive.openBox<Expense>(
      _expensesBoxName,
    ); // Open Hive box
    debugPrint("ExpenseRepository initialized with API service and Hive box.");
  }

  Future<List<Expense>> getAllExpenses() async {
    // First, return local expenses
    final localExpenses = _expensesBox.values.toList();
    if (localExpenses.isNotEmpty) {
      debugPrint("Returning expenses from local Hive box.");
      return localExpenses;
    }
    // If local is empty, try fetching from API (optional, depends on desired offline strategy)
    // For a strict "offline-first" where data must be explicitly synced,
    // you might not even call the API here unless a sync is triggered.
    // However, for a "load from cache, then update from network" strategy:
    debugPrint("Local expenses empty, fetching from API...");
    final apiResponse = await _expenseApiService.getExpenses();

    if (apiResponse.success && apiResponse.data != null) {
      // Save API expenses to local box for future offline access
      for (var expense in apiResponse.data!) {
        // Assuming expense.id from API is the correct key
        // If API expenses don't have a local-compatible ID, adjust accordingly
        await _expensesBox.put(expense.id, expense);
      }
      debugPrint(
        "Fetched and saved ${apiResponse.data!.length} expenses from API to Hive.",
      );
      return apiResponse.data!;
    } else {
      debugPrint("Error fetching expenses from API: ${apiResponse.message}");
      // If API fails and local is empty, return empty list
      return [];
    }
  }

  Future<Expense?> getExpenseById(String id) async {
    // Try to get from local box using the provided id as a key first.
    // This assumes 'id' might be a server ID (if synced) or a localId (if created offline and used as key).
    var expense = _expensesBox.get(id);
    if (expense != null) {
      debugPrint(
        "Returning expense $id directly from local Hive box (used as key).",
      );
      return expense;
    }

    // If not found by direct key lookup, iterate and check both id and localId fields.
    // This is a fallback if the 'id' parameter doesn't match the Hive key directly.
    for (var e in _expensesBox.values) {
      if (e.id == id || (e.localId != null && e.localId == id)) {
        debugPrint(
          "Returning expense $id from local Hive box (found by iterating and matching id/localId).",
        );
        return e;
      }
    }

    // If not in local, try API
    debugPrint("Expense $id not in local Hive box, fetching from API...");
    final apiResponse = await _expenseApiService.getExpenseById(id);

    if (apiResponse.success && apiResponse.data != null) {
      // Cache the expense from API using its ID as key
      final apiExpense = apiResponse.data!;
      await _expensesBox.put(apiExpense.id, apiExpense);
      return apiExpense;
    } else {
      debugPrint(
        "Error fetching expense by ID $id from API: ${apiResponse.message}",
      );
      return null;
    }
  }

  Future<Expense> addExpense(Expense expense, {List<File>? imageFiles}) async {
    // Generate a local ID if the expense doesn't have one (e.g., for purely local creation)
    // The current Expense model has 'id' (server) and 'localId'.
    // We'll use localId for Hive key if it's a new local-only record.
    // If expense.id is already set (e.g. from server), use that.

    String hiveKey;
    Expense expenseToSave;

    if (expense.localId != null && expense.localId!.isNotEmpty) {
      hiveKey = expense.localId!;
      expenseToSave = expense;
    } else {
      final newLocalId = _uuid.v4();
      hiveKey = newLocalId;
      expenseToSave = expense.copyWith(
        localId: newLocalId,
        syncStatus: "pending",
      ); // Mark as pending sync
    }

    await _expensesBox.put(hiveKey, expenseToSave);
    debugPrint("Expense saved locally with key: $hiveKey");

    // Try to sync with API
    // The API service\'s createExpense expects individual fields, not an Expense object.
    // We need to adapt this. For now, let\'s assume we pass the necessary fields from expenseToSave.
    debugPrint(
      "[ExpenseRepository] Calling createExpense API. Image files count: ${imageFiles?.length ?? 0}",
    );
    final apiResponse = await _expenseApiService.createExpense(
      expenseToSave.date,
      expenseToSave.amount,
      expenseToSave.motif,
      expenseToSave.category.name, // Using category.name as per model
      expenseToSave.paymentMethod ?? '', // Corrected syntax for empty string
      expenseToSave.supplierId,
      attachments: imageFiles,
      paidAmount: expenseToSave.paidAmount ?? 0.0,
      paymentStatus:
          (expenseToSave.paymentStatus ?? ExpensePaymentStatus.unpaid).name,
      supplierName: expenseToSave.supplierName,
      currencyCode: expenseToSave.currencyCode,
      exchangeRate: expenseToSave.exchangeRate,
    );

    if (apiResponse.success && apiResponse.data != null) {
      final createdExpenseFromApi = apiResponse.data!;
      debugPrint(
        "[ExpenseRepository] createExpense API success. URLs from API: ${createdExpenseFromApi.attachmentUrls}",
      );

      // If API call is successful, update local record with server ID and clear sync status
      final syncedExpense = expenseToSave.copyWith(
        id: createdExpenseFromApi.id, // Use server ID
        syncStatus: "synced",
        attachmentUrls:
            createdExpenseFromApi.attachmentUrls, // Update with server URLs
      );

      await _expensesBox.put(
        createdExpenseFromApi.id,
        syncedExpense,
      ); // Use server ID as key now
      if (hiveKey != createdExpenseFromApi.id) {
        // If we used a localId as key initially
        await _expensesBox.delete(hiveKey); // Remove the entry with localId key
      }

      debugPrint(
        "[ExpenseRepository] Expense synced with API. Local record updated with server ID: ${createdExpenseFromApi.id}. Attachment URLs: ${syncedExpense.attachmentUrls}",
      );
      return syncedExpense;
    } else {
      debugPrint(
        "[ExpenseRepository] Failed to sync new expense with API: ${apiResponse.message}. It remains local with key $hiveKey. Attachment URLs on expenseToSave: ${expenseToSave.attachmentUrls}",
      );
      // Expense is already saved locally with syncStatus: "pending"
      return expenseToSave; // Return the local version
    }
  }

  Future<Expense> updateExpense(
    Expense expense, {
    List<File>? imageFiles,
    List<String>? attachmentUrlsToRemove,
  }) async {
    // Assume expense.id is the server ID and is the key in Hive for synced items.
    // If it\'s a local-only item not yet synced, expense.localId might be the key.

    String hiveKey = expense.id; // Prefer server ID if available
    if (_expensesBox.get(hiveKey) == null && expense.localId != null) {
      // If not found by server ID, try localId (for items not yet synced)
      hiveKey = expense.localId!;
    }

    final expenseToUpdate = expense.copyWith(syncStatus: "pending_update");
    await _expensesBox.put(hiveKey, expenseToUpdate);
    debugPrint(
      "[ExpenseRepository] Expense updated locally with key: $hiveKey, marked for sync. Initial attachment URLs: ${expenseToUpdate.attachmentUrls}",
    );

    debugPrint(
      "[ExpenseRepository] Calling updateExpense API for ID: ${expense.id}. New image files: ${imageFiles?.length ?? 0}, URLs to remove: ${attachmentUrlsToRemove?.length ?? 0}",
    );
    final apiResponse = await _expenseApiService.updateExpense(
      expense.id, // Server ID is required for update
      expenseToUpdate.date,
      expenseToUpdate.amount,
      expenseToUpdate.motif,
      expenseToUpdate
          .category
          .name, // Ensure category.name is used as per model
      expenseToUpdate.paymentMethod,
      expenseToUpdate.supplierId,
      newAttachments: imageFiles,
      attachmentUrlsToRemove: attachmentUrlsToRemove,
      paidAmount: expenseToUpdate.paidAmount ?? 0.0,
      paymentStatus:
          (expenseToUpdate.paymentStatus ?? ExpensePaymentStatus.unpaid).name,
      supplierName: expenseToUpdate.supplierName,
      currencyCode: expenseToUpdate.currencyCode,
      exchangeRate: expenseToUpdate.exchangeRate,
    );

    if (apiResponse.success && apiResponse.data != null) {
      final updatedExpenseFromApi = apiResponse.data!;
      debugPrint(
        "[ExpenseRepository] updateExpense API success. URLs from API: ${updatedExpenseFromApi.attachmentUrls}",
      );

      final syncedExpense = expenseToUpdate.copyWith(
        syncStatus: "synced",
        attachmentUrls:
            updatedExpenseFromApi
                .attachmentUrls, // Update with latest server URLs
      );

      await _expensesBox.put(
        syncedExpense.id,
        syncedExpense,
      ); // Ensure it\'s stored with server ID as key
      debugPrint(
        "[ExpenseRepository] Expense update synced with API for ID: ${syncedExpense.id}. Final attachment URLs: ${syncedExpense.attachmentUrls}",
      );
      return syncedExpense;
    } else {
      debugPrint(
        "[ExpenseRepository] Failed to sync updated expense with API: ${apiResponse.message}. It remains local with key $hiveKey. Attachment URLs on expenseToUpdate: ${expenseToUpdate.attachmentUrls}",
      );
      return expenseToUpdate; // Return local version with pending_update status
    }
  }

  Future<void> deleteExpense(String id) async {
    // Here, 'id' could be a server ID or a localId if not yet synced.
    // For simplicity, we'll assume we try to delete by this ID in local Hive first.
    // A more robust solution would involve a 'markedForDeletion' status for offline.

    final expenseToDelete = _expensesBox.get(id);
    if (expenseToDelete == null) {
      debugPrint("Expense with ID $id not found locally for deletion.");
      // Optionally, still try to tell API to delete if we think it might exist on server
      // await _expenseApiService.deleteExpense(id);
      return;
    }

    await _expensesBox.delete(id);
    debugPrint("Expense with ID $id deleted locally.");

    // If the expense had a server ID (i.e., it was synced), tell the API to delete it.
    // The 'id' passed to this function should ideally be the server ID if known.
    // If 'id' is a localId of an unsynced item, this API call might not be relevant or might fail.
    if (expenseToDelete.id.isNotEmpty &&
        expenseToDelete.id != expenseToDelete.localId) {
      // Check if it has a server ID
      final apiResponse = await _expenseApiService.deleteExpense(
        expenseToDelete.id,
      );
      if (apiResponse.success) {
        debugPrint(
          "Deletion request for expense ID ${expenseToDelete.id} sent to API successfully.",
        );
      } else {
        debugPrint(
          "Failed to sync expense deletion with API for ID $id: ${apiResponse.message}",
        );
        // If API deletion fails, we might need to re-add it to a "pending deletion" list locally.
        // For now, it's deleted locally.
        // Consider adding it back with a 'pending_delete' status:
        // await _expensesBox.put(id, expenseToDelete.copyWith(syncStatus: "pending_delete"));
      }
    }
  }

  Future<List<Expense>> getExpensesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Filter local expenses
    return _expensesBox.values.where((expense) {
      return !expense.date.isBefore(startDate) &&
          !expense.date.isAfter(
            endDate.add(const Duration(days: 1)),
          ); // Inclusive end date
    }).toList();
  }

  Future<List<Expense>> getExpensesByCategory(ExpenseCategory category) async {
    // Filter local expenses
    return _expensesBox.values
        .where((expense) => expense.category == category)
        .toList();
  }

  // Category Management Methods
  Future<List<Map<String, dynamic>>> getExpenseCategories() async {
    try {
      final response = await _expenseApiService.getExpenseCategories();
      if (response.success && response.data != null) {
        return response.data!;
      }
      debugPrint("Failed to fetch expense categories: ${response.message}");
      return [];
    } catch (e) {
      debugPrint("Error fetching expense categories: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> createExpenseCategory({
    required String name,
    String? description,
    required String type,
  }) async {
    try {
      final response = await _expenseApiService.createExpenseCategory(
        name,
        description,
        type,
      );
      if (response.success && response.data != null) {
        debugPrint("Created expense category: $name");
        return response.data;
      }
      debugPrint("Failed to create expense category: ${response.message}");
      return null;
    } catch (e) {
      debugPrint("Error creating expense category: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateExpenseCategory({
    required String id,
    String? name,
    String? description,
    String? type,
  }) async {
    try {
      final response = await _expenseApiService.updateExpenseCategory(
        id,
        name,
        description,
        type,
      );
      if (response.success && response.data != null) {
        debugPrint("Updated expense category: $id");
        return response.data;
      }
      debugPrint("Failed to update expense category: ${response.message}");
      return null;
    } catch (e) {
      debugPrint("Error updating expense category: $e");
      return null;
    }
  }

  Future<bool> deleteExpenseCategory(String id) async {
    try {
      final response = await _expenseApiService.deleteExpenseCategory(id);
      if (response.success) {
        debugPrint("Deleted expense category: $id");
        return true;
      }
      debugPrint("Failed to delete expense category: ${response.message}");
      return false;
    } catch (e) {
      debugPrint("Error deleting expense category: $e");
      return false;
    }
  }
}
