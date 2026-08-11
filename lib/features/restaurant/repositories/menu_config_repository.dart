import 'package:hive/hive.dart';

import '../models/menu_course.dart';

/// Configuration locale de la CARTE : quels produits sont au menu et dans
/// quelle catégorie (entrée, plat, dessert, boisson…).
///
/// Choix délibéré : box Hive `String` (clé = productId, valeur = nom de la
/// [MenuCourse]), PAS de `TypeAdapter` ni de modification de l'entité `Product`
/// → aucun `typeId`, aucune migration, aucun impact backend. Un produit absent
/// de cette table est un stock ordinaire (n'apparaît pas à la carte).
class MenuConfigRepository {
  static const _boxName = 'restaurant_menu_config';
  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box<String>(_boxName)
        : await Hive.openBox<String>(_boxName);
    return _box!;
  }

  /// Map productId → catégorie de carte, pour tous les produits configurés.
  Future<Map<String, MenuCourse>> loadAll() async {
    final box = await _openBox();
    final result = <String, MenuCourse>{};
    for (final key in box.keys) {
      final value = box.get(key);
      if (key is String && value != null) {
        result[key] = MenuCourseX.fromValue(value);
      }
    }
    return result;
  }

  /// Ajoute/déplace un produit dans une catégorie de la carte.
  Future<void> setCourse(String productId, MenuCourse course) async {
    final box = await _openBox();
    await box.put(productId, course.apiValue);
  }

  /// Retire un produit de la carte (redevient stock ordinaire).
  Future<void> removeFromMenu(String productId) async {
    final box = await _openBox();
    await box.delete(productId);
  }

  Future<bool> isOnMenu(String productId) async {
    final box = await _openBox();
    return box.containsKey(productId);
  }
}
