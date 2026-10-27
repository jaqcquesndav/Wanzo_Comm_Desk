import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart'; // Added for Hive
import 'package:uuid/uuid.dart'; // Added for generating local IDs
import '../models/expense.dart';
import '../services/expense_api_service.dart';
import '../../../core/cancellation/document_cancellation.dart';
import '../../../core/cancellation/pending_cancellations.dart';
import '../../../core/models/operation_payment.dart';

/// Résultat d'un règlement enregistré sur une dette fournisseur.
class ExpensePaymentOutcome {
  final Expense expense;
  final bool synced;
  final String message;

  const ExpensePaymentOutcome({
    required this.expense,
    required this.synced,
    required this.message,
  });
}

class ExpenseRepository {
  final ExpenseApiService _expenseApiService;
  static const _expensesBoxName = 'expenses'; // Added Hive box name

  /// File d'attente des règlements fournisseurs saisis hors ligne.
  static const _pendingPaymentsBoxName = 'pendingExpensePayments';

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

  /// Dépenses actives d'une liste : les dépenses annulées sont conservées
  /// pour la trace mais n'entrent dans aucun total.
  static List<Expense> activeOnly(Iterable<Expense> expenses) =>
      expenses.where((e) => !e.isCancelled).toList();

  /// Dépenses créées pendant cette session, par identifiant local : un
  /// nouvel essai avec le même localId rend la dépense déjà enregistrée.
  final Map<String, Expense> _createdByLocalId = {};

  /// Toutes les dépenses ; les dépenses annulées sont écartées, sauf
  /// [includeCancelled] (liste, filtre « Annulées »).
  Future<List<Expense>> getAllExpenses({bool includeCancelled = false}) async {
    List<Expense> scope(Iterable<Expense> all) =>
        includeCancelled ? all.toList() : activeOnly(all);

    // Les règlements saisis hors ligne repartent à chaque relecture de la
    // liste : `expenses/sync` n'existe pas, sans cette file la tranche serait
    // perdue au prochain rafraîchissement depuis le serveur.
    await flushPendingPayments();
    await flushPendingCancellations();

    // First, return local expenses
    final localExpenses = _expensesBox.values.toList();
    if (localExpenses.isNotEmpty) {
      debugPrint("Returning expenses from local Hive box.");
      return scope(localExpenses);
    }
    // If local is empty, try fetching from API (optional, depends on desired offline strategy)
    // For a strict "offline-first" where data must be explicitly synced,
    // you might not even call the API here unless a sync is triggered.
    // However, for a "load from cache, then update from network" strategy:
    debugPrint("Local expenses empty, fetching from API...");
    // Toutes les pages : le serveur plafonne à 10 par défaut (100 au plus) ;
    // sans pagination, seules les 10 dernières dépenses revenaient.
    final toutes = await fetchAllExpensesFromApi();
    if (toutes == null) return [];
    for (var expense in toutes) {
      await _expensesBox.put(expense.id, expense);
    }
    debugPrint("Fetched and saved ${toutes.length} expenses from API to Hive.");
    return scope(toutes);
  }

  /// Lit toutes les pages de `GET expenses` (100 par page) jusqu'à une page
  /// incomplète. `null` si une page a échoué (liste incomplète : ne rien
  /// purger sur cette base).
  Future<List<Expense>?> fetchAllExpensesFromApi({int maxPages = 100}) async {
    const taille = 100;
    final toutes = <Expense>[];
    for (var page = 1; page <= maxPages; page++) {
      final res = await _expenseApiService.getExpenses(
        page: page,
        limit: taille,
        // Annulées comprises : le cache les garde au statut annulé.
        includeCancelled: true,
      );
      if (!res.success || res.data == null) {
        debugPrint("Error fetching expenses from API: ${res.message}");
        return null;
      }
      toutes.addAll(res.data!);
      if (res.data!.length < taille) break;
    }
    return toutes;
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

    // Même localId à chaque essai (double appui, reprise après erreur) : la
    // dépense déjà enregistrée est rendue, sans second envoi.
    final already = _createdByLocalId[expense.localId ?? ''];
    if (already != null) {
      debugPrint("Dépense ${expense.localId} déjà enregistrée, pas de doublon.");
      return already;
    }

    if (expense.localId != null && expense.localId!.isNotEmpty) {
      hiveKey = expense.localId!;
      expenseToSave =
          expense.syncStatus == null
              ? expense.copyWith(syncStatus: "pending")
              : expense;
    } else {
      final newLocalId = _uuid.v4();
      hiveKey = newLocalId;
      expenseToSave = expense.copyWith(
        localId: newLocalId,
        syncStatus: "pending",
      ); // Mark as pending sync
    }

    await _expensesBox.put(hiveKey, expenseToSave);
    _createdByLocalId[hiveKey] = expenseToSave;
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
      // Sans ces champs le serveur reçoit une dépense anonyme : une avance
      // versée à un coiffeur n'apparaît alors dans aucun relevé.
      performerId: expenseToSave.performerId,
      performerName: expenseToSave.performerName,
      subCategory: expenseToSave.subCategory,
      beneficiary: expenseToSave.beneficiary,
      notes: expenseToSave.notes,
      localId: expenseToSave.localId,
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
        await PendingCancellations.instance.rekey(
          CancellableDocument.expense,
          hiveKey,
          createdExpenseFromApi.id,
        );
      }

      debugPrint(
        "[ExpenseRepository] Expense synced with API. Local record updated with server ID: ${createdExpenseFromApi.id}. Attachment URLs: ${syncedExpense.attachmentUrls}",
      );
      // L'avertissement de doublon accompagne la dépense rendue à l'écran,
      // il n'est jamais conservé.
      final result = syncedExpense.copyWith(
        possibleDuplicateOf: createdExpenseFromApi.possibleDuplicateOf,
      );
      _createdByLocalId[hiveKey] = result;
      return result;
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
      // Sans ces champs le serveur reçoit une dépense anonyme : une avance
      // versée à un coiffeur n'apparaît alors dans aucun relevé.
      performerId: expenseToUpdate.performerId,
      performerName: expenseToUpdate.performerName,
      subCategory: expenseToUpdate.subCategory,
      beneficiary: expenseToUpdate.beneficiary,
      notes: expenseToUpdate.notes,
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

  // ══════════════════════════════════════════════════════════════════════════
  // RÈGLEMENT EN PLUSIEURS TRANCHES (dettes fournisseurs)
  // ══════════════════════════════════════════════════════════════════════════

  Future<Box> _pendingPaymentsBox() => Hive.openBox(_pendingPaymentsBoxName);

  /// Enregistre une tranche de règlement sur une dépense.
  ///
  /// Chemin nominal : `POST expenses/:id/payments` (le serveur recalcule le
  /// cumul et le statut, aucun cumul côté client). Repli si l'endpoint n'est
  /// pas disponible : PATCH avec le cumul. Repli hors ligne : application
  /// locale + mise en file de synchronisation.
  Future<ExpensePaymentOutcome> recordPayment(
    Expense expense,
    PaymentDraft payment,
  ) async {
    final newPaid = (expense.paidAmount ?? 0.0) + payment.amount;
    final capped = newPaid > expense.amount ? expense.amount : newPaid;
    final fullyPaid = newPaid + 0.01 >= expense.amount;

    // 1. Application optimiste locale (offline-first).
    final optimistic = expense.copyWith(
      paidAmount: capped,
      paymentStatus:
          fullyPaid ? ExpensePaymentStatus.paid : ExpensePaymentStatus.partial,
      paymentMethod: payment.method,
      syncStatus: 'pending_update',
    );
    final hiveKey =
        _expensesBox.get(expense.id) != null
            ? expense.id
            : (expense.localId ?? expense.id);
    await _expensesBox.put(hiveKey, optimistic);

    // 2. Endpoint dédié aux tranches.
    final response = await _expenseApiService.recordExpensePayment(
      expense.id,
      payment,
    );

    if (response.success && response.data != null) {
      final serverExpense = response.data!;
      // GARDE ANTI-ÉCRASEMENT : on ne remplace le cache optimiste que si le
      // serveur a réellement pris la tranche en compte.
      if ((serverExpense.paidAmount ?? 0.0) + 0.01 < capped) {
        throw StateError(
          'Le serveur n\'a pas enregistré la tranche de paiement.',
        );
      }
      final synced = serverExpense.copyWith(syncStatus: 'synced');
      await _expensesBox.put(synced.id, synced);
      return ExpensePaymentOutcome(
        expense: synced,
        synced: true,
        message: 'Paiement enregistré.',
      );
    }

    debugPrint(
      "[ExpenseRepository] Endpoint expenses/:id/payments indisponible "
      "(${response.message}) - repli sur PATCH",
    );

    // 3. Repli : PATCH classique avec le cumul.
    final patched = await updateExpense(optimistic);
    if (patched.syncStatus == 'synced') {
      if ((patched.paidAmount ?? 0.0) + 0.01 < capped) {
        throw StateError('Le serveur n\'a pas enregistré le montant payé.');
      }
      return ExpensePaymentOutcome(
        expense: patched,
        synced: true,
        message: 'Paiement enregistré.',
      );
    }

    await _enqueuePayment(expense.id, payment);
    return ExpensePaymentOutcome(
      expense: optimistic,
      synced: false,
      message: 'Paiement enregistré hors ligne, il sera synchronisé.',
    );
  }

  /// Liste les tranches de règlement d'une dépense (vide si indisponible).
  Future<List<OperationPayment>> getExpensePayments(String expenseId) async {
    try {
      return await _expenseApiService
          .getExpensePayments(expenseId)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint("Historique des règlements indisponible: $e");
      return const <OperationPayment>[];
    }
  }

  Future<void> _enqueuePayment(String expenseId, PaymentDraft payment) async {
    try {
      final box = await _pendingPaymentsBox();
      await box.put(_uuid.v4(), <String, dynamic>{
        'expenseId': expenseId,
        ...payment.toRequestBody(),
      });
      debugPrint("Règlement mis en file pour la dépense $expenseId");
    } catch (e) {
      debugPrint("Impossible de mettre le règlement en file: $e");
    }
  }

  /// Rejoue les règlements fournisseurs saisis hors ligne.
  Future<void> flushPendingPayments() async {
    Box box;
    try {
      box = await _pendingPaymentsBox();
    } catch (e) {
      debugPrint("File des règlements inaccessible: $e");
      return;
    }
    if (box.isEmpty) return;

    for (final key in box.keys.toList()) {
      final raw = box.get(key);
      if (raw is! Map) {
        await box.delete(key);
        continue;
      }
      final expenseId = raw['expenseId'] as String?;
      final amount = (raw['amount'] as num?)?.toDouble();
      if (expenseId == null || amount == null || amount <= 0) {
        await box.delete(key);
        continue;
      }
      final draft = PaymentDraft(
        amount: amount,
        currencyCode: raw['currencyCode'] as String? ?? 'CDF',
        exchangeRate: (raw['exchangeRate'] as num?)?.toDouble(),
        method: raw['method'] as String? ?? 'Espèces',
        paidAt:
            DateTime.tryParse(raw['paidAt'] as String? ?? '') ?? DateTime.now(),
        reference: raw['reference'] as String?,
      );
      final response = await _expenseApiService.recordExpensePayment(
        expenseId,
        draft,
      );
      if (response.success && response.data != null) {
        final synced = response.data!.copyWith(syncStatus: 'synced');
        await _expensesBox.put(synced.id, synced);
        await box.delete(key);
        debugPrint("Règlement en file synchronisé (dépense $expenseId)");
      } else {
        debugPrint(
          "Règlement en file non synchronisé (dépense $expenseId): ${response.message}",
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ANNULATION ET RÉTABLISSEMENT (une dépense n'est jamais effacée)
  // ══════════════════════════════════════════════════════════════════════════

  /// Clé Hive d'une dépense : identifiant serveur, sinon local.
  String _keyOf(Expense expense) =>
      _expensesBox.get(expense.id) != null
          ? expense.id
          : (expense.localId ?? expense.id);

  /// Dépense encore jamais envoyée au serveur.
  static bool awaitsServerCreation(Expense? local) =>
      local != null &&
      (local.syncStatus == 'pending' ||
          local.id.isEmpty ||
          (local.localId != null && local.id == local.localId));

  /// Annule une dépense avec son motif. Elle reste dans le cache au statut
  /// annulé. Hors ligne, ou dépense pas encore envoyée : l'annulation entre
  /// dans la file. Un refus du serveur la rend à son état ([StateError]).
  Future<CancellationOutcome<Expense>> cancelExpense(
    Expense expense,
    String reason, {
    String? actorName,
    String? actorId,
  }) async {
    final error = validateCancelReason(reason);
    if (error != null) throw StateError(error);
    final motif = reason.trim();
    final key = _keyOf(expense);
    final current = _expensesBox.get(key) ?? expense;
    final queueId = current.id.isNotEmpty ? current.id : key;
    if (current.isCancelled &&
        !PendingCancellations.instance.isPending(
          CancellableDocument.expense,
          queueId,
        )) {
      return CancellationOutcome(
        document: current,
        synced: current.syncStatus == 'synced',
        message: 'Cette dépense est déjà annulée.',
      );
    }

    final local = current.copyWith(
      status: Expense.cancelledStatus,
      cancelledAt: DateTime.now(),
      cancelledByName: actorName,
      cancelledById: actorId,
      cancelReason: motif,
    );
    await _expensesBox.put(key, local);

    Future<CancellationOutcome<Expense>> queued(String message) async {
      await PendingCancellations.instance.enqueue(
        CancellableDocument.expense,
        queueId,
        PendingCancellations.cancel,
        reason: motif,
      );
      return CancellationOutcome(document: local, synced: false, message: message);
    }

    if (awaitsServerCreation(current)) {
      return queued('Dépense annulée sur l\'appareil, la synchronisation suivra.');
    }
    try {
      final server = (await _expenseApiService.cancelExpense(
        current.id,
        reason: motif,
      )).copyWith(syncStatus: 'synced');
      // Le serveur ne renvoie pas toujours le statut : la dépense reste annulée.
      final stored =
          server.isCancelled
              ? server
              : server.copyWith(
                status: Expense.cancelledStatus,
                cancelledAt: local.cancelledAt,
                cancelledByName: local.cancelledByName,
                cancelledById: local.cancelledById,
                cancelReason: motif,
              );
      await _expensesBox.put(key, stored);
      await PendingCancellations.instance.done(
        CancellableDocument.expense,
        queueId,
      );
      return CancellationOutcome(
        document: stored,
        synced: true,
        message: 'Dépense annulée.',
      );
    } catch (e) {
      if (isServerRefusal(e)) {
        await _expensesBox.put(key, current);
        throw StateError(
          refusalMessage(e, fallback: 'Annulation refusée par le serveur.'),
        );
      }
      debugPrint("Annulation de la dépense ${current.id} mise en file: $e");
      return queued('Dépense annulée hors ligne, elle sera synchronisée.');
    }
  }

  /// Rétablit une dépense annulée. Une annulation encore en file est
  /// simplement retirée ; sinon le serveur doit confirmer (en ligne).
  Future<CancellationOutcome<Expense>> restoreExpense(
    Expense expense, {
    String? reason,
  }) async {
    final key = _keyOf(expense);
    final current = _expensesBox.get(key) ?? expense;
    final queueId = current.id.isNotEmpty ? current.id : key;
    final restoredLocally = current.copyWith(clearCancellation: true);
    final pending = await PendingCancellations.instance.pendingFor(
      CancellableDocument.expense,
      queueId,
    );
    if (pending != null && pending.isCancel) {
      await PendingCancellations.instance.done(
        CancellableDocument.expense,
        queueId,
      );
      await _expensesBox.put(key, restoredLocally);
      return CancellationOutcome(
        document: restoredLocally,
        synced: current.syncStatus == 'synced',
        message: 'Dépense rétablie.',
      );
    }
    try {
      final server = (await _expenseApiService.restoreExpense(
        current.id,
        reason: reason,
      )).copyWith(syncStatus: 'synced', clearCancellation: true);
      await _expensesBox.put(key, server);
      return CancellationOutcome(
        document: server,
        synced: true,
        message: 'Dépense rétablie.',
      );
    } catch (e) {
      if (isMissingRoute(e)) {
        throw StateError(
          'Le rétablissement n\'est pas encore disponible sur le serveur.',
        );
      }
      if (isServerRefusal(e)) {
        throw StateError(
          refusalMessage(e, fallback: 'Rétablissement refusé par le serveur.'),
        );
      }
      throw StateError(
        'Rétablissement impossible hors ligne. Réessayez une fois connecté.',
      );
    }
  }

  /// Rejoue les annulations de dépenses saisies hors ligne.
  Future<void> flushPendingCancellations() async {
    List<PendingCancellation> pending;
    try {
      pending = await PendingCancellations.instance.entries(
        CancellableDocument.expense,
      );
    } catch (_) {
      return;
    }
    for (final p in pending) {
      final local = _expensesBox.get(p.id);
      if (awaitsServerCreation(local)) continue;
      try {
        final server =
            p.isCancel
                ? await _expenseApiService.cancelExpense(
                  p.id,
                  reason: p.reason ?? 'Annulation',
                )
                : await _expenseApiService.restoreExpense(
                  p.id,
                  reason: p.reason,
                );
        final keep =
            p.isCancel && !server.isCancelled && local != null
                ? local.copyWith(syncStatus: 'synced')
                : server.copyWith(syncStatus: 'synced');
        await _expensesBox.put(p.id, keep);
        await PendingCancellations.instance.done(
          CancellableDocument.expense,
          p.id,
        );
      } catch (e) {
        if (isServerRefusal(e) && !isMissingRoute(e)) {
          await PendingCancellations.instance.done(
            CancellableDocument.expense,
            p.id,
          );
          debugPrint("Annulation refusée (dépense ${p.id}): $e");
        } else {
          debugPrint("Annulation en file non envoyée (dépense ${p.id}): $e");
        }
      }
    }
  }

  /// Dépenses d'une période (dépenses annulées écartées : tableau de bord,
  /// rapports).
  Future<List<Expense>> getExpensesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Filter local expenses
    return _expensesBox.values.where((expense) {
      return !expense.isCancelled &&
          !expense.date.isBefore(startDate) &&
          !expense.date.isAfter(
            endDate.add(const Duration(days: 1)),
          ); // Inclusive end date
    }).toList();
  }

  Future<List<Expense>> getExpensesByCategory(ExpenseCategory category) async {
    // Filter local expenses
    return _expensesBox.values
        .where((expense) => !expense.isCancelled && expense.category == category)
        .toList();
  }

  /// Récupérer les dépenses liées à un fournisseur
  Future<List<Expense>> getExpensesBySupplier(String supplierId) async {
    return _expensesBox.values
        .where(
          (expense) => !expense.isCancelled && expense.supplierId == supplierId,
        )
        .toList();
  }

  /// Calculer le total des dettes fournisseurs (dépenses non entièrement payées)
  Future<double> getTotalPayables() async {
    final unpaid = _expensesBox.values.where((expense) {
      if (expense.isCancelled) return false;
      final status = expense.paymentStatus;
      return status == ExpensePaymentStatus.unpaid ||
          status == ExpensePaymentStatus.partial ||
          status == ExpensePaymentStatus.credit;
    });
    return unpaid.fold<double>(0, (total, expense) {
      final paid = expense.paidAmount ?? 0.0;
      return total + (expense.amount - paid);
    });
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

  /// Vider le cache local des dépenses (à utiliser lors du changement de business unit)
  Future<void> clearLocalCache() async {
    await _expensesBox.clear();
    debugPrint("Cache local des dépenses vidé");
  }
}
