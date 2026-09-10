import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/atelier_order.dart';

/// Cache local (offline) des commandes atelier.
///
/// Les commandes sont persistées côté backend (source de vérité). Ce cache sert
/// UNIQUEMENT à afficher la dernière liste connue quand le réseau est
/// indisponible. Box `Box<String>` (JSON), clé = businessUnitId ('all' par
/// défaut) → aucun TypeAdapter, aucune migration.
class AtelierOrderCache {
  static const _boxName = 'atelier_orders_cache';

  Future<Box<String>> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<String>(_boxName);
    return Hive.openBox<String>(_boxName);
  }

  // Clé scindée par BU ET par métier : sans le métier, un atelier multi-métiers
  // (couture + imprimerie sur la même BU) mélangerait ses commandes hors-ligne.
  String _key(String? businessUnitId, String? metier) {
    final bu =
        (businessUnitId == null || businessUnitId.isEmpty) ? 'all' : businessUnitId;
    return (metier == null || metier.isEmpty) ? bu : '$bu::$metier';
  }

  Future<void> save(String? businessUnitId, List<AtelierOrder> orders,
      {String? metier}) async {
    try {
      final box = await _box();
      await box.put(
        _key(businessUnitId, metier),
        jsonEncode(orders.map((o) => o.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('AtelierOrderCache.save ignoré: $e');
    }
  }

  Future<List<AtelierOrder>> load(String? businessUnitId,
      {String? metier}) async {
    try {
      final box = await _box();
      final raw = box.get(_key(businessUnitId, metier));
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AtelierOrder.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('AtelierOrderCache.load ignoré: $e');
      return const [];
    }
  }
}
