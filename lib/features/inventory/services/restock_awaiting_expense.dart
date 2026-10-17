import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/features/inventory/models/stock_transaction.dart';
import 'package:wanzo/features/inventory/services/inventory_api_service.dart';

/// Entrées de stock d'un réapprovisionnement dont la dépense d'achat n'a pas
/// encore d'identifiant serveur (saisie hors ligne).
///
/// L'achat doit être compté une seule fois : le mouvement `purchase` part
/// avec l'`expenseId` de sa dépense (le serveur passe alors 311 / 6031, sans
/// seconde dette fournisseur). Tant que la dépense attend son envoi, le
/// mouvement n'est appliqué qu'en local et gardé ici ; il part dès que la
/// synchronisation des dépenses connaît l'identifiant serveur.
class RestockAwaitingExpense {
  RestockAwaitingExpense._();

  static const _boxName = 'restock_awaiting_expense';

  static Future<Box> _box() =>
      Hive.isBoxOpen(_boxName)
          ? Future.value(Hive.box(_boxName))
          : Hive.openBox(_boxName);

  /// Garde le mouvement jusqu'à l'envoi de la dépense [expenseId] (id local).
  static Future<void> remember(String expenseId, StockTransaction tx) async {
    final box = await _box();
    await box.put(expenseId, jsonEncode(tx.toJson()));
  }

  /// Mouvement en attente pour cette dépense locale, `null` s'il n'y en a pas.
  static Future<StockTransaction?> pendingFor(String localExpenseId) async {
    try {
      final raw = (await _box()).get(localExpenseId);
      if (raw is! String) return null;
      return StockTransaction.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// La dépense locale [localExpenseId] a reçu l'id serveur [serverExpenseId] :
  /// envoie le mouvement en attente (voie unique `POST stock-transactions`,
  /// avec `expenseId`). Conservé pour la prochaine synchronisation si l'envoi
  /// échoue. [api] : service à utiliser (tests), sinon le client de l'app.
  static Future<void> release(
    String localExpenseId,
    String serverExpenseId, {
    InventoryApiService? api,
  }) async {
    final box = await _box();
    final raw = box.get(localExpenseId);
    if (raw is! String) return;
    final tx = StockTransaction.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    ).copyWith(referenceId: serverExpenseId);
    try {
      final res = await (api ?? InventoryApiServiceImpl(ApiClient()))
          .createStockTransaction(tx, expenseId: serverExpenseId);
      // Hors ligne : repris par la file du client HTTP, avec son expenseId.
      if (!res.success && res.error is! OfflineQueuedException) {
        debugPrint('[Restock] Entrée de stock refusée : ${res.message}');
        return;
      }
    } catch (e) {
      debugPrint('[Restock] Entrée de stock non envoyée : $e');
      return;
    }
    await box.delete(localExpenseId);
  }
}
