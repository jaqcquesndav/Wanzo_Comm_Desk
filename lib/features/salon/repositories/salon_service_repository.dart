import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/salon_service.dart';

/// Stockage LOCAL de la carte des PRESTATIONS du salon (offline-first).
///
/// Choix délibéré, identique à `MenuRepository` du restaurant : box Hive
/// `String` (clé = `SalonService.id`, valeur = JSON de la prestation), SANS
/// `TypeAdapter` ni `typeId` — aucune migration Hive, aucun impact backend.
/// La carte est authorée hors-ligne puis publiée en masse (`bulk-upsert`).
class SalonServiceRepository {
  static const _boxName = 'salon_services';
  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box<String>(_boxName)
        : await Hive.openBox<String>(_boxName);
    return _box!;
  }

  /// Toutes les prestations, triées par catégorie (public → technique →
  /// mains/pieds) puis par position, puis par nom.
  Future<List<SalonService>> loadAll() async {
    final box = await _openBox();
    final items = <SalonService>[];
    for (final value in box.values) {
      try {
        final map = jsonDecode(value) as Map<String, dynamic>;
        items.add(SalonService.fromJson(map));
      } catch (_) {
        // Entrée corrompue : ignorée plutôt que de casser toute la carte.
      }
    }
    items.sort((a, b) {
      final byCat = a.category.order.compareTo(b.category.order);
      if (byCat != 0) return byCat;
      final byPos = a.position.compareTo(b.position);
      if (byPos != 0) return byPos;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  /// Crée ou met à jour une prestation (clé = son id).
  Future<void> upsert(SalonService service) async {
    final box = await _openBox();
    await box.put(service.id, jsonEncode(service.toJson()));
  }

  /// Supprime une prestation de la carte locale.
  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }

  /// Remplace intégralement la carte locale (utilisé après un import depuis le
  /// backend). Vide la box puis réécrit les entrées fournies.
  Future<void> replaceAll(List<SalonService> services) async {
    final box = await _openBox();
    await box.clear();
    for (final s in services) {
      await box.put(s.id, jsonEncode(s.toJson()));
    }
  }
}
