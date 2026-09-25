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
    await retirerEnAttente(id);
  }

  // ── Commandes pas encore confirmees par le serveur ─────────────────────────
  //
  // Une commande modifiee ici mais pas encore acceptee par le serveur ne doit
  // pas etre ecrasee par la copie du serveur, plus ancienne, au chargement
  // suivant : c'est ainsi que des plats deja saisis disparaissaient.

  static const _syncBoxName = 'restaurant_orders_sync';
  static const _cleEnAttente = 'en_attente';

  Future<Box<String>> _openSyncBox() async => Hive.isBoxOpen(_syncBoxName)
      ? Hive.box<String>(_syncBoxName)
      : await Hive.openBox<String>(_syncBoxName);

  Future<Set<String>> enAttente() async {
    final brut = (await _openSyncBox()).get(_cleEnAttente);
    if (brut == null || brut.isEmpty) return <String>{};
    try {
      return (jsonDecode(brut) as List).map((e) => e.toString()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _ecrireEnAttente(Set<String> ids) async =>
      (await _openSyncBox()).put(_cleEnAttente, jsonEncode(ids.toList()));

  Future<void> marquerEnAttente(String id) async =>
      _ecrireEnAttente((await enAttente())..add(id));

  Future<void> retirerEnAttente(String id) async {
    final ids = await enAttente();
    if (ids.remove(id)) await _ecrireEnAttente(ids);
  }
}
