import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Ventes rétablies dont l'encaissement en espèces n'a pu être remis dans
/// une caisse (aucune caisse ouverte au moment du rétablissement). La fiche
/// affiche « Encaissement à reprendre en caisse » jusqu'à ce que
/// l'encaissement soit repris dans une caisse ouverte : le tiroir reste
/// ainsi d'accord avec la comptabilité, qui repropose l'écriture.
class CashReentryFlags {
  static const boxName = 'cash_reentry_flags';

  CashReentryFlags._();
  static final CashReentryFlags instance = CashReentryFlags._();

  final ValueNotifier<Set<String>> flagged = ValueNotifier(const {});
  bool _loaded = false;

  Future<Box> _box() async =>
      Hive.isBoxOpen(boxName) ? Hive.box(boxName) : Hive.openBox(boxName);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final box = await _box();
      flagged.value = {for (final k in box.keys) k.toString()};
    } catch (e) {
      debugPrint('⚠️ Encaissements à reprendre illisibles ($e)');
    }
    _loaded = true;
  }

  bool isFlagged(String saleId) => flagged.value.contains(saleId);

  Future<void> flag(String saleId) async {
    await load();
    flagged.value = {...flagged.value, saleId};
    try {
      await (await _box()).put(saleId, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('⚠️ Encaissement à reprendre non noté ($e)');
    }
  }

  Future<void> clear(String saleId) async {
    await load();
    if (!flagged.value.contains(saleId)) return;
    flagged.value = {...flagged.value}..remove(saleId);
    try {
      await (await _box()).delete(saleId);
    } catch (e) {
      debugPrint('⚠️ Encaissement à reprendre : retrait impossible ($e)');
    }
  }

  @visibleForTesting
  void resetForTest() {
    flagged.value = const {};
    _loaded = false;
  }
}
