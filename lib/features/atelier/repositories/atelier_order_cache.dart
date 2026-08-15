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

  String _key(String? businessUnitId) =>
      (businessUnitId == null || businessUnitId.isEmpty) ? 'all' : businessUnitId;

  Future<void> save(String? businessUnitId, List<AtelierOrder> orders) async {
    try {
      final box = await _box();
      await box.put(
        _key(businessUnitId),
        jsonEncode(orders.map((o) => o.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('AtelierOrderCache.save ignoré: $e');
    }
  }

  Future<List<AtelierOrder>> load(String? businessUnitId) async {
    try {
      final box = await _box();
      final raw = box.get(_key(businessUnitId));
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
