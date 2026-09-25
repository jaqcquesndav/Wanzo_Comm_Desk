import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';

import '../models/salon_service.dart';
import '../services/salon_api_service.dart';

/// Stockage LOCAL de la carte des PRESTATIONS du salon (offline-first).
///
/// Choix délibéré, identique à `MenuRepository` du restaurant : box Hive
/// `String` (clé = `SalonService.id`, valeur = JSON de la prestation), SANS
/// `TypeAdapter` ni `typeId` — aucune migration Hive.
///
/// **Synchronisation.** Chaque prestation ajoutée, modifiée ou supprimée part
/// AUSSITÔT au serveur. Auparavant elle ne partait qu'au bouton « Publier », et
/// le chargement suivant REMPLAÇAIT la liste locale par celle du serveur : une
/// prestation non publiée était effacée au premier « Actualiser », et perdue à
/// la réinstallation. Les suppressions ne partaient jamais.
///
/// Deux listes locales tiennent ce que le serveur n'a pas encore confirmé :
/// les prestations EN ATTENTE d'envoi et les suppressions EN ATTENTE. Elles
/// sont rejouées à chaque synchronisation en ligne ; le serveur fait foi pour
/// tout le reste.
class SalonServiceRepository {
  static const _boxName = 'salon_services';
  static const _syncBoxName = 'salon_services_sync';
  static const _cleEnAttente = 'en_attente';
  static const _cleSuppressions = 'suppressions';
  static const _cleInitialise = 'initialise';

  final SalonApiService _api;

  SalonServiceRepository({SalonApiService? api})
      : _api = api ?? SalonApiService();

  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box<String>(_boxName)
        : await Hive.openBox<String>(_boxName);
    return _box!;
  }

  Future<Box<String>> _openSyncBox() async {
    return Hive.isBoxOpen(_syncBoxName)
        ? Hive.box<String>(_syncBoxName)
        : await Hive.openBox<String>(_syncBoxName);
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

  /// Charge la carte en la réconciliant avec le serveur quand il répond.
  ///
  /// Pousse d'abord ce qui attend, puis lit le serveur : ses prestations
  /// remplacent les copies locales, sauf celles modifiées ici et pas encore
  /// confirmées. Une prestation que le serveur ne connaît plus, et qui
  /// n'attend pas d'envoi, a été retirée ailleurs : elle est retirée ici aussi.
  /// Hors ligne : la carte locale, telle quelle.
  Future<List<SalonService>> loadAllSynced() async {
    try {
      await _initialiserSiBesoin();
      await _rejouerEnAttente();

      final remote = await _api.getServices();
      final box = await _openBox();
      final sync = await _openSyncBox();
      final attente = _lireEnsemble(sync, _cleEnAttente);
      final suppressions = _lireEnsemble(sync, _cleSuppressions);
      final idsServeur = <String>{};

      for (final r in remote) {
        idsServeur.add(r.id);
        if (suppressions.contains(r.id) || attente.contains(r.id)) continue;
        await box.put(r.id, jsonEncode(r.toJson()));
      }

      // Jamais sur une réponse vide : une réponse vide accidentelle
      // effacerait toute la carte de l'appareil.
      if (idsServeur.isNotEmpty) {
        for (final id in box.keys.whereType<String>().toList()) {
          if (!idsServeur.contains(id) && !attente.contains(id)) {
            await box.delete(id);
          }
        }
      }
    } catch (_) {
      // Hors ligne ou serveur indisponible : carte locale.
    }
    return loadAll();
  }

  /// Crée ou met à jour une prestation : localement, puis au serveur.
  /// Si l'envoi n'aboutit pas, elle reste en attente pour la prochaine fois.
  Future<void> upsert(SalonService service) async {
    final box = await _openBox();
    await box.put(service.id, jsonEncode(service.toJson()));

    final sync = await _openSyncBox();
    final attente = _lireEnsemble(sync, _cleEnAttente)..add(service.id);
    await _ecrireEnsemble(sync, _cleEnAttente, attente);

    if (await _envoyer([service])) {
      attente.remove(service.id);
      await _ecrireEnsemble(sync, _cleEnAttente, attente);
    }
  }

  /// Supprime une prestation : localement, puis au serveur. Tant que le
  /// serveur ne l'a pas confirmé, la suppression reste en attente et la
  /// prestation ne revient pas.
  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);

    final sync = await _openSyncBox();
    final attente = _lireEnsemble(sync, _cleEnAttente)..remove(id);
    await _ecrireEnsemble(sync, _cleEnAttente, attente);
    final suppressions = _lireEnsemble(sync, _cleSuppressions)..add(id);
    await _ecrireEnsemble(sync, _cleSuppressions, suppressions);

    if (await _supprimer(id)) {
      suppressions.remove(id);
      await _ecrireEnsemble(sync, _cleSuppressions, suppressions);
    }
  }

  /// Après une publication complète réussie, plus rien n'attend.
  Future<void> marquerToutPublie() async {
    final sync = await _openSyncBox();
    await _ecrireEnsemble(sync, _cleEnAttente, <String>{});
  }

  /// Premier passage avec cette version : les prestations déjà présentes sur
  /// l'appareil n'ont peut-être jamais été publiées. On les met toutes en
  /// attente d'envoi, plutôt que de les croire synchronisées et de les effacer
  /// à la première lecture du serveur.
  Future<void> _initialiserSiBesoin() async {
    final sync = await _openSyncBox();
    if (sync.get(_cleInitialise) == '1') return;
    final box = await _openBox();
    final attente = _lireEnsemble(sync, _cleEnAttente)
      ..addAll(box.keys.whereType<String>());
    await _ecrireEnsemble(sync, _cleEnAttente, attente);
    await sync.put(_cleInitialise, '1');
  }

  Future<void> _rejouerEnAttente() async {
    final sync = await _openSyncBox();
    final box = await _openBox();

    final suppressions = _lireEnsemble(sync, _cleSuppressions);
    for (final id in suppressions.toList()) {
      if (await _supprimer(id)) suppressions.remove(id);
    }
    await _ecrireEnsemble(sync, _cleSuppressions, suppressions);

    final attente = _lireEnsemble(sync, _cleEnAttente);
    if (attente.isEmpty) return;
    final aEnvoyer =
        (await loadAll()).where((s) => attente.contains(s.id)).toList();
    if (aEnvoyer.isNotEmpty && await _envoyer(aEnvoyer)) {
      attente.removeAll(aEnvoyer.map((s) => s.id));
    }
    attente.removeWhere((id) => !box.containsKey(id));
    await _ecrireEnsemble(sync, _cleEnAttente, attente);
  }

  /// Vrai si le serveur a pris les prestations. Le serveur conserve l'id
  /// fourni par l'appareil : un renvoi ne crée jamais de doublon.
  Future<bool> _envoyer(List<SalonService> services) async {
    try {
      await _api.bulkUpsertServices(services);
      return true;
    } on OfflineQueuedException {
      return false;
    } catch (e) {
      debugPrint('SalonServiceRepository: envoi reporté ($e)');
      return false;
    }
  }

  /// Vrai si la prestation n'existe plus côté serveur.
  Future<bool> _supprimer(String id) async {
    try {
      await _api.deleteService(id);
      return true;
    } on NotFoundException {
      return true;
    } on OfflineQueuedException {
      return false;
    } catch (e) {
      debugPrint('SalonServiceRepository: suppression reportée ($e)');
      return false;
    }
  }
}
