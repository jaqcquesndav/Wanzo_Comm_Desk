import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/service_item.dart';

/// Cache LOCAL du catalogue des services (offline-first), même choix que la
/// carte du restaurant et les prestations du salon : box Hive `String`
/// (clé = id du service, valeur = JSON), sans TypeAdapter ni migration Hive.
class ServiceRepository {
  static const _boxName = 'services_catalog';
  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box<String>(_boxName)
        : await Hive.openBox<String>(_boxName);
    return _box!;
  }

  /// Tous les services du cache, triés par position puis nom.
  Future<List<ServiceItem>> loadAll() async {
    final box = await _openBox();
    final items = <ServiceItem>[];
    for (final value in box.values) {
      try {
        items.add(ServiceItem.fromJson(jsonDecode(value) as Map<String, dynamic>));
      } catch (_) {
        // Entrée corrompue : ignorée plutôt que de casser tout le catalogue.
      }
    }
    items.sort((a, b) {
      final byPos = a.position.compareTo(b.position);
      if (byPos != 0) return byPos;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  Future<ServiceItem?> getById(String id) async {
    final box = await _openBox();
    final raw = box.get(id);
    if (raw == null) return null;
    try {
      return ServiceItem.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsert(ServiceItem item) async {
    final box = await _openBox();
    await box.put(item.id, jsonEncode(item.toLocalJson()));
  }

  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }

  /// Remplace le cache par la liste du backend, en conservant les écritures
  /// locales encore en attente de synchronisation.
  Future<void> replaceFromServer(List<ServiceItem> serverItems) async {
    final box = await _openBox();
    final pending = <String, String>{};
    for (final entry in box.toMap().entries) {
      try {
        final map = jsonDecode(entry.value) as Map<String, dynamic>;
        if (map['pendingSync'] == true) pending[entry.key.toString()] = entry.value;
      } catch (_) {/* ignorée */}
    }
    await box.clear();
    for (final s in serverItems) {
      await box.put(s.id, jsonEncode(s.toLocalJson()));
    }
    for (final e in pending.entries) {
      await box.put(e.key, e.value);
    }
  }

  Future<List<ServiceItem>> pendingItems() async =>
      (await loadAll()).where((s) => s.pendingSync).toList();
}
