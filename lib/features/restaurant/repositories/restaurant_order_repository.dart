import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/restaurant_order.dart';

/// Persistance locale des commandes restaurant.
///
/// Choix délibéré : box Hive de `String` (JSON), PAS de `TypeAdapter` dédié →
/// aucun `typeId` supplémentaire, donc aucun risque de collision ni de
/// migration Hive. La clé est l'id de la commande.
class RestaurantOrderRepository {
  static const _boxName = 'restaurant_orders_box';
  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box<String>(_boxName)
        : await Hive.openBox<String>(_boxName);
    return _box!;
  }

  /// Charge toutes les commandes, triées de la plus récente à la plus ancienne.
  Future<List<RestaurantOrder>> loadAll() async {
    final box = await _openBox();
    final orders = <RestaurantOrder>[];
    for (final raw in box.values) {
      try {
        orders.add(
          RestaurantOrder.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        // Entrée corrompue ignorée — ne bloque pas le chargement du service.
      }
    }
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  Future<void> save(RestaurantOrder order) async {
    final box = await _openBox();
    await box.put(order.id, jsonEncode(order.toJson()));
  }

  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }
}
