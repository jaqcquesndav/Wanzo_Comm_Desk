import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
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
/// se mélange jamais à celle d'une autre au changement de contexte.
///
/// **Synchronisation.** Chaque plat ajouté, modifié ou supprimé part AUSSITÔT
/// au serveur. Auparavant il ne partait qu'au bouton « Publier » : les plats
/// jamais publiés n'existaient que sur l'appareil et disparaissaient à la
/// réinstallation, pendant que le lien de table montrait une carte ancienne.
/// Les suppressions ne partaient jamais : un plat retiré restait publié et
/// revenait à la synchronisation suivante.
///
/// Deux listes locales tiennent ce qui n'est pas encore confirmé par le
/// serveur : les plats EN ATTENTE d'envoi, et les suppressions EN ATTENTE.
/// Elles sont rejouées à chaque synchronisation en ligne. Le serveur fait foi
/// pour tout le reste.
class MenuRepository {
  /// Préfixe du nom de box. Le nom EFFECTIF est suffixé par le `companyId`
  /// courant afin d'isoler la carte par société. Repli sur le préfixe nu quand
  /// le contexte n'est pas encore chargé.
  static const _boxPrefix = 'restaurant_menu_items';

  /// Ancienne box (non scopée par société), migrée une seule fois vers la box
  /// scopée pour ne pas perdre la carte locale des installations antérieures.
  static const _legacyBoxName = 'restaurant_menu_items';

  /// Box de suivi de synchronisation, scopée par société comme la carte.
  static const _syncPrefix = 'restaurant_menu_sync';
  static const _cleEnAttente = 'en_attente';
  static const _cleSuppressions = 'suppressions';
  static const _cleInitialise = 'initialise';

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

  // ── Suivi de synchronisation ────────────────────────────────────────────

  Future<Box<String>> _openSyncBox() async {
    final companyId = BusinessContextService().companyId;
    final name = (companyId != null && companyId.isNotEmpty)
        ? '${_syncPrefix}_$companyId'
        : _syncPrefix;
    return Hive.isBoxOpen(name)
        ? Hive.box<String>(name)
        : await Hive.openBox<String>(name);
  }

  Set<String> _lireEnsemble(Box<String> box, String cle) {
    final brut = box.get(cle);
    if (brut == null || brut.isEmpty) return <String>{};
    try {
      return (jsonDecode(brut) as List).map((e) => e.toString()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _ecrireEnsemble(Box<String> box, String cle, Set<String> v) =>
      box.put(cle, jsonEncode(v.toList()));

  /// Premier passage avec cette version : les plats deja presents sur
  /// l'appareil n'ont peut-etre jamais ete publies. On les met tous en
  /// attente d'envoi, plutot que de les croire synchronises et de les effacer
  /// a la premiere lecture du serveur.
  Future<void> _initialiserSiBesoin() async {
    final sync = await _openSyncBox();
    if (sync.get(_cleInitialise) == '1') return;
    final box = await _openBox();
    final attente = _lireEnsemble(sync, _cleEnAttente)
      ..addAll(box.keys.whereType<String>());
    await _ecrireEnsemble(sync, _cleEnAttente, attente);
    await sync.put(_cleInitialise, '1');
  }

  /// Rejoue les envois et suppressions pas encore confirmes. Ce qui echoue
  /// reste en attente pour la prochaine fois.
  Future<void> _rejouerEnAttente() async {
    final sync = await _openSyncBox();
    final box = await _openBox();

    final suppressions = _lireEnsemble(sync, _cleSuppressions);
    for (final id in suppressions.toList()) {
      if (await _supprimerAuServeur(id)) suppressions.remove(id);
    }
    await _ecrireEnsemble(sync, _cleSuppressions, suppressions);

    final attente = _lireEnsemble(sync, _cleEnAttente);
    if (attente.isEmpty) return;
    final ordre = await loadAll();
    for (var i = 0; i < ordre.length; i++) {
      final plat = ordre[i];
      if (!attente.contains(plat.id)) continue;
      if (await _envoyerAuServeur(plat, i)) attente.remove(plat.id);
    }
    // Un id en attente dont le plat n'existe plus localement n'a rien a envoyer.
    attente.removeWhere((id) => !box.containsKey(id));
    await _ecrireEnsemble(sync, _cleEnAttente, attente);
  }

  /// Vrai si le serveur a pris le plat. Faux s'il faut reessayer plus tard
  /// (hors ligne : l'ecriture est deja en file cote ApiClient ; erreur serveur).
  Future<bool> _envoyerAuServeur(MenuItem plat, int position) async {
    try {
      await _api.upsertMenuItem(plat, position);
      return true;
    } on OfflineQueuedException {
      return false;
    } catch (e) {
      debugPrint('MenuRepository: envoi du plat ${plat.id} reporte ($e)');
      return false;
    }
  }

  /// Vrai si le plat n'existe plus cote serveur (supprime, ou jamais publie).
  Future<bool> _supprimerAuServeur(String id) async {
    try {
      await _api.deleteMenuItem(id);
      return true;
    } on NotFoundException {
      return true;
    } on OfflineQueuedException {
      return false;
    } catch (e) {
      debugPrint('MenuRepository: suppression du plat $id reportee ($e)');
      return false;
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
      await _initialiserSiBesoin();
      // D'abord pousser ce qui attend, pour que la lecture qui suit le reflete.
      await _rejouerEnAttente();

      final remote = await _api.getMenuItems();
      final box = await _openBox();
      final sync = await _openSyncBox();
      final attente = _lireEnsemble(sync, _cleEnAttente);
      final suppressions = _lireEnsemble(sync, _cleSuppressions);
      final idsServeur = <String>{};

      for (final remoteItem in remote) {
        idsServeur.add(remoteItem.id);
        // Supprime ici mais pas encore la-bas : ne pas le faire revenir.
        if (suppressions.contains(remoteItem.id)) continue;
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
        // Une modification locale pas encore confirmee l'emporte sur la
        // version du serveur, qui est plus ancienne.
        if (attente.contains(remoteItem.id)) continue;
        await box.put(merged.id, jsonEncode(merged.toJson()));
      }

      // Un plat que le serveur ne connait plus, et qui n'attend pas d'envoi,
      // a ete retire ailleurs (autre poste) : on le retire aussi ici. Jamais
      // sur une reponse vide : une reponse vide accidentelle effacerait toute
      // la carte de l'appareil, piege deja rencontre sur la synchronisation.
      if (idsServeur.isNotEmpty) {
        for (final id in box.keys.whereType<String>().toList()) {
          if (!idsServeur.contains(id) && !attente.contains(id)) {
            await box.delete(id);
          }
        }
      }
    } catch (_) {
      // Réseau indisponible / erreur backend : repli sur la carte locale.
    }
    return loadAll();
  }

  /// Crée ou met à jour un plat (clé = son id).
  ///
  /// Ecrit localement puis envoie aussitot. Si l'envoi n'aboutit pas, le plat
  /// reste en attente et partira a la prochaine synchronisation en ligne.
  Future<void> upsert(MenuItem item) async {
    final box = await _openBox();
    await box.put(item.id, jsonEncode(item.toJson()));

    final sync = await _openSyncBox();
    final attente = _lireEnsemble(sync, _cleEnAttente)..add(item.id);
    await _ecrireEnsemble(sync, _cleEnAttente, attente);

    final ordre = await loadAll();
    final position = ordre.indexWhere((p) => p.id == item.id);
    if (await _envoyerAuServeur(item, position < 0 ? 0 : position)) {
      attente.remove(item.id);
      await _ecrireEnsemble(sync, _cleEnAttente, attente);
    }
  }

  /// Supprime un plat de la carte.
  ///
  /// Retire localement puis au serveur. Tant que le serveur ne l'a pas
  /// confirme, la suppression reste en attente : le plat ne revient pas.
  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);

    final sync = await _openSyncBox();
    final attente = _lireEnsemble(sync, _cleEnAttente)..remove(id);
    await _ecrireEnsemble(sync, _cleEnAttente, attente);
    final suppressions = _lireEnsemble(sync, _cleSuppressions)..add(id);
    await _ecrireEnsemble(sync, _cleSuppressions, suppressions);

    if (await _supprimerAuServeur(id)) {
      suppressions.remove(id);
      await _ecrireEnsemble(sync, _cleSuppressions, suppressions);
    }
  }

  /// Apres une publication complete reussie, plus rien n'attend.
  Future<void> marquerToutPublie() async {
    final sync = await _openSyncBox();
    await _ecrireEnsemble(sync, _cleEnAttente, <String>{});
  }
}
