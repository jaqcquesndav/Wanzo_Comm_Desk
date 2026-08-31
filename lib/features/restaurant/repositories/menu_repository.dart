import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/menu_course.dart';
import '../models/menu_item.dart';

/// Stockage local de la CARTE : le catalogue des plats (entités [MenuItem]
/// authorées directement, distinctes du stock).
///
/// Choix délibéré : box Hive `String` (clé = `MenuItem.id`, valeur = JSON du
/// plat), PAS de `TypeAdapter` ni de `typeId` — même motif que les commandes et
/// `MenuConfigRepository`. Aucune migration, aucun impact backend.
class MenuRepository {
  static const _boxName = 'restaurant_menu_items';
  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box<String>(_boxName)
        : await Hive.openBox<String>(_boxName);
    return _box!;
  }

  /// Tous les plats de la carte, triés par service (entrée → plat → …) puis
  /// par nom.
  Future<List<MenuItem>> loadAll() async {
    final box = await _openBox();
    final items = <MenuItem>[];
    for (final value in box.values) {
      try {
        final map = jsonDecode(value) as Map<String, dynamic>;
        items.add(MenuItem.fromJson(map));
      } catch (_) {
        // Entrée corrompue : on l'ignore plutôt que de casser toute la carte.
      }
    }
    items.sort((a, b) {
      final byCourse = a.course.order.compareTo(b.course.order);
      if (byCourse != 0) return byCourse;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  /// Crée ou met à jour un plat (clé = son id).
  Future<void> upsert(MenuItem item) async {
    final box = await _openBox();
    await box.put(item.id, jsonEncode(item.toJson()));
  }

  /// Supprime un plat de la carte.
  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }
}
