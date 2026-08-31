import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/stylist.dart';

/// Cache LOCAL des coiffeurs (offline-first). Les coiffeurs sont persistés côté
/// backend, mais on garde une copie locale pour les servir quand le réseau est
/// indisponible (sélection sur un ticket hors-ligne).
///
/// Même motif que la carte : box Hive `String` (clé = `Stylist.id`, valeur =
/// JSON), sans `TypeAdapter` — aucune migration Hive.
class SalonStylistCache {
  static const _boxName = 'salon_stylists';
  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box<String>(_boxName)
        : await Hive.openBox<String>(_boxName);
    return _box!;
  }

  /// Dernière liste connue de coiffeurs (repli hors-ligne).
  Future<List<Stylist>> load() async {
    final box = await _openBox();
    final items = <Stylist>[];
    for (final value in box.values) {
      try {
        items.add(Stylist.fromJson(jsonDecode(value) as Map<String, dynamic>));
      } catch (_) {
        // Entrée corrompue : ignorée.
      }
    }
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  /// Remplace le cache par la liste fournie (après un fetch backend réussi).
  Future<void> save(List<Stylist> stylists) async {
    final box = await _openBox();
    await box.clear();
    for (final s in stylists) {
      await box.put(s.id, jsonEncode(s.toCreateJson()..['id'] = s.id));
    }
  }
}
