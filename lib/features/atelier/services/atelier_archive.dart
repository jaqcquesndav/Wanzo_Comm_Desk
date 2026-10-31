import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/atelier_order.dart';

/// Une fiche atelier, pressing ou garage qui porte de l'argent (réglée, ou
/// avance encaissée) n'est jamais supprimée : elle s'archive. Seul un
/// brouillon sans encaissement ni avance peut l'être (fiche saisie par
/// erreur). Une fiche annulée avant tout encaissement compte aussi comme
/// brouillon.
bool atelierOrderDeletable(AtelierOrder order) {
  final hasMoney =
      order.advanceAmount > 0.009 ||
      (order.saleId != null && order.saleId!.trim().isNotEmpty) ||
      order.status == AtelierOrderStatus.paid;
  if (hasMoney) return false;
  return order.status == AtelierOrderStatus.draft ||
      order.status == AtelierOrderStatus.cancelled;
}

/// Ancienne archive tenue sur l'appareil seulement (avant les routes
/// `atelier/orders/:id/archive`). Elle ne sert plus qu'à la MIGRATION : les
/// fiches qu'elle contient sont archivées une fois sur le serveur, puis
/// retirées d'ici (voir `AtelierOrdersCubit.migrateLocalArchive`). Le serveur
/// est la référence (`archivedAt` sur la fiche).
class AtelierArchive {
  static const boxName = 'atelier_archived_orders';

  AtelierArchive._();
  static final AtelierArchive instance = AtelierArchive._();

  /// Identifiants archivés (copie mémoire écoutée par le tableau).
  final ValueNotifier<Set<String>> archived = ValueNotifier(const {});
  bool _loaded = false;

  Future<Box> _box() async =>
      Hive.isBoxOpen(boxName) ? Hive.box(boxName) : Hive.openBox(boxName);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final box = await _box();
      archived.value = {for (final k in box.keys) k.toString()};
    } catch (e) {
      debugPrint('⚠️ Archive atelier illisible ($e)');
    }
    _loaded = true;
  }

  bool isArchived(String id) => archived.value.contains(id);

  Future<void> archive(String id) async {
    await load();
    archived.value = {...archived.value, id};
    try {
      await (await _box()).put(id, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('⚠️ Archive atelier non enregistrée ($e)');
    }
  }

  Future<void> unarchive(String id) async {
    await load();
    archived.value = {...archived.value}..remove(id);
    try {
      await (await _box()).delete(id);
    } catch (e) {
      debugPrint('⚠️ Archive atelier : retrait impossible ($e)');
    }
  }

  @visibleForTesting
  void resetForTest() {
    archived.value = const {};
    _loaded = false;
  }
}
