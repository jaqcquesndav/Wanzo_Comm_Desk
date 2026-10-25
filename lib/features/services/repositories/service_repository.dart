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

  /// Remplace dans le cache la PORTION lue sur le serveur ([inScope] : le
  /// mode et le metier demandes) par la liste du backend. Les services des
  /// autres metiers ne sont jamais touches (la lecture est filtree par metier,
  /// vider toute la boite effacait la carte des autres ateliers), les
  /// ecritures locales en attente sont gardees, et une reponse vide ne purge
  /// rien (serveur muet ou filtre momentanement faux).
  Future<void> replaceFromServer(
    List<ServiceItem> serverItems, {
    bool Function(ServiceItem item)? inScope,
  }) async {
    final box = await _openBox();
    if (serverItems.isEmpty) return;
    final serverIds = {for (final s in serverItems) s.id};
    for (final entry in box.toMap().entries) {
      try {
        final item = ServiceItem.fromJson(
          jsonDecode(entry.value) as Map<String, dynamic>,
        );
        if (item.pendingSync) continue;
        if (serverIds.contains(item.id)) continue;
        if (inScope == null || inScope(item)) await box.delete(entry.key);
      } catch (_) {/* entree illisible : ignoree */}
    }
    for (final s in serverItems) {
      await box.put(s.id, jsonEncode(s.toLocalJson()));
    }
  }

  Future<List<ServiceItem>> pendingItems() async =>
      (await loadAll()).where((s) => s.pendingSync).toList();
}
