import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:wanzo/core/services/business_context_service.dart';

import '../models/menu_course.dart';
import '../models/menu_item.dart';
import '../services/restaurant_api_service.dart';

/// Stockage local de la CARTE : le catalogue des plats (entités [MenuItem]
/// authorées directement, distinctes du stock).
///
/// Choix délibéré : box Hive `String` (clé = `MenuItem.id`, valeur = JSON du
/// plat), PAS de `TypeAdapter` ni de `typeId` — même motif que les commandes.
/// Aucune migration, aucun impact backend.
///
/// La box est SCOPÉE par société (`companyId`) : la carte d'une entreprise ne
/// se mélange jamais à celle d'une autre au changement de contexte. La carte
/// publiée sur le backend redescend via [loadAllSynced] pour être partagée entre
/// tous les postes/appareils (correctif « la carte a disparu »).
class MenuRepository {
  /// Préfixe du nom de box. Le nom EFFECTIF est suffixé par le `companyId`
  /// courant afin d'isoler la carte par société. Repli sur le préfixe nu quand
  /// le contexte n'est pas encore chargé.
  static const _boxPrefix = 'restaurant_menu_items';

  /// Ancienne box (non scopée par société), migrée une seule fois vers la box
  /// scopée pour ne pas perdre la carte locale des installations antérieures.
  static const _legacyBoxName = 'restaurant_menu_items';

  final RestaurantApiService _api;

  MenuRepository({RestaurantApiService? api})
      : _api = api ?? RestaurantApiService();

  Box<String>? _box;
  String? _openBoxName;

  /// Nom de box effectif pour le contexte société courant.
  String get _boxName {
    final companyId = BusinessContextService().companyId;
    return (companyId != null && companyId.isNotEmpty)
        ? '${_boxPrefix}_$companyId'
        : _boxPrefix;
  }

  Future<Box<String>> _openBox() async {
    final name = _boxName;
    if (_box != null && _box!.isOpen && _openBoxName == name) return _box!;
    final box = Hive.isBoxOpen(name)
        ? Hive.box<String>(name)
        : await Hive.openBox<String>(name);
    await _migrateLegacyIfNeeded(box, name);
    _box = box;
    _openBoxName = name;
    return box;
  }

  /// Migration unique : si la box scopée par société est vide et que l'ancienne
  /// box nue (partagée avant le scoping) contient des plats, on les recopie une
  /// fois. Ne s'exécute jamais quand le nom scopé == nom legacy (pas de contexte
  /// société chargé) pour éviter une recopie sur elle-même.
  Future<void> _migrateLegacyIfNeeded(Box<String> box, String name) async {
    if (name == _legacyBoxName) return;
    if (box.isNotEmpty) return;
    if (!Hive.isBoxOpen(_legacyBoxName) &&
        !(await Hive.boxExists(_legacyBoxName))) {
      return;
    }
    final legacy = Hive.isBoxOpen(_legacyBoxName)
        ? Hive.box<String>(_legacyBoxName)
        : await Hive.openBox<String>(_legacyBoxName);
    if (legacy.isEmpty) return;
    for (final key in legacy.keys) {
      final value = legacy.get(key);
      if (key is String && value != null) {
        await box.put(key, value);
      }
    }
  }

  /// Tous les plats de la carte (box locale), triés par service (entrée → plat
  /// → …) puis par nom.
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

  /// Snapshot LOCAL de la carte indexé par id de plat, pour résoudre
  /// `RestaurantOrderLine.productId` → [MenuItem] (photo du plat, catégorie…)
  /// dans les écrans de service (cartes de commande, plan de salle, aperçu,
  /// vignettes). Lecture locale uniquement (aucun appel réseau) : sûr à appeler
  /// au montage d'un écran, y compris hors-ligne.
  ///
  /// Le `productId` d'une ligne de commande est l'id d'un [MenuItem] (la CARTE),
  /// PAS d'un `Product` du stock : la résolution des photos doit donc passer par
  /// ici, pas par l'`InventoryRepository`.
  Future<Map<String, MenuItem>> loadMap() async {
    final items = await loadAll();
    return {for (final it in items) it.id: it};
  }

  /// Charge la carte en FUSIONNANT la version publiée du backend quand on est
  /// EN LIGNE, puis renvoie la carte locale à jour.
  ///
  /// Le backend est la source de vérité de la carte PUBLIÉE : ses plats sont
  /// upsertés par id dans la box locale. Les créations locales encore non
  /// publiées (id absent côté backend) sont CONSERVÉES (jamais supprimées).
  /// Hors-ligne ou en cas d'erreur réseau : repli silencieux sur la box locale
  /// (dernier connu). C'est ce qui fait redescendre la carte publiée dans TOUS
  /// les postes/appareils/réinstallations.
  Future<List<MenuItem>> loadAllSynced() async {
    try {
      final remote = await _api.getMenuItems();
      final box = await _openBox();
      for (final remoteItem in remote) {
        var merged = remoteItem;
        // Conserver l'aperçu local (photoPath) quand le backend n'a pas d'URL
        // réseau, pour ne pas « perdre » l'image d'un plat publié sans upload.
        final localRaw = box.get(remoteItem.id);
        if (localRaw != null &&
            (remoteItem.photoUrl == null || remoteItem.photoUrl!.isEmpty)) {
          try {
            final local = MenuItem.fromJson(
                jsonDecode(localRaw) as Map<String, dynamic>);
            if (local.photoPath != null && local.photoPath!.isNotEmpty) {
              merged = remoteItem.copyWith(photoPath: local.photoPath);
            }
          } catch (_) {
            // Entrée locale corrompue : on garde la version backend telle quelle.
          }
        }
        await box.put(merged.id, jsonEncode(merged.toJson()));
      }
    } catch (_) {
      // Réseau indisponible / erreur backend : repli sur la carte locale.
    }
    return loadAll();
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
