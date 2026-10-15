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
/// avec l'`expenseId` de sa dépense. Tant que la dépense attend son envoi, le
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

  /// La dépense locale [localExpenseId] a reçu l'id serveur [serverExpenseId] :
  /// envoie le mouvement en attente. Conservé si l'envoi échoue.
  static Future<void> release(
    String localExpenseId,
    String serverExpenseId,
  ) async {
    final box = await _box();
    final raw = box.get(localExpenseId);
    if (raw is! String) return;
    final tx = StockTransaction.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    ).copyWith(referenceId: serverExpenseId);
    try {
      final res = await InventoryApiServiceImpl(
        ApiClient(),
      ).createStockTransaction(tx, expenseId: serverExpenseId);
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
