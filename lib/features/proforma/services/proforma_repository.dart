import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../core/exceptions/api_exceptions.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/business_context_service.dart';
import '../models/proforma.dart';

/// Résultat d'une conversion : la proforma à jour et, selon la pièce
/// d'origine, la vente créée (facture) ou la réservation confirmée.
class ProformaConversion {
  final Proforma proforma;
  final Map<String, dynamic>? sale;
  final Map<String, dynamic>? reservation;
  const ProformaConversion(this.proforma, {this.sale, this.reservation});
}

/// Proformas : sur l'appareil d'abord (hors ligne autorisé, numéro
/// provisoire), puis envoyées au serveur qui donne le numéro définitif.
///
/// Une proforma n'écrit rien en comptabilité et ne bouge pas le stock : seule
/// sa conversion en facture le fait, côté serveur, par la chaîne vente.
class ProformaRepository {
  /// Une boîte par entreprise : un poste qui change d'entreprise ne voit ni
  /// n'envoie jamais les proformas d'une autre.
  static String get _boiteNom =>
      'proformas_v1_${BusinessContextService().companyId ?? 'sans_entreprise'}';
  static const _cleAppareil = '_appareil';
  static const _cleCompteur = '_compteur';

  final ApiClient _api;
  static final ValueNotifier<int> changes = ValueNotifier(0);

  ProformaRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  Future<Box<String>> _boite() async => Hive.isBoxOpen(_boiteNom)
      ? Hive.box<String>(_boiteNom)
      : await Hive.openBox<String>(_boiteNom);

  static dynamic _deballer(dynamic r) {
    dynamic d = r;
    while (d is Map && d.containsKey('data') && d['data'] != null) {
      d = d['data'];
    }
    return d;
  }

  /// Code de l'appareil (4 caractères, gardé) pour les numéros provisoires.
  Future<String> _appareil(Box<String> box) async {
    final existant = box.get(_cleAppareil);
    if (existant != null && existant.isNotEmpty) return existant;
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    final code =
        List.generate(4, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
    await box.put(_cleAppareil, code);
    return code;
  }

  /// Prochain numéro provisoire : PF-PROV, code de l'appareil, rang.
  Future<String> _provisoire(Box<String> box) async {
    final code = await _appareil(box);
    final n = (int.tryParse(box.get(_cleCompteur) ?? '') ?? 0) + 1;
    await box.put(_cleCompteur, '$n');
    return 'PF-PROV-$code-$n';
  }

  Future<void> _garder(Proforma p) async {
    await (await _boite()).put(p.id, jsonEncode(p.toJson()));
    changes.value++;
  }

  /// Proformas connues sur l'appareil, les plus récentes d'abord.
  Future<List<Proforma>> local() async {
    final box = await _boite();
    final out = <Proforma>[];
    for (final k in box.keys) {
      if (k is! String || k.startsWith('_')) continue;
      try {
        out.add(Proforma.fromJson(
            jsonDecode(box.get(k)!) as Map<String, dynamic>));
      } catch (_) {}
    }
    out.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    return out;
  }

  Future<Proforma?> byId(String id) async {
    final brut = (await _boite()).get(id);
    if (brut == null) return null;
    return Proforma.fromJson(jsonDecode(brut) as Map<String, dynamic>);
  }

  /// Proformas d'une pièce (une commande, une réservation).
  Future<List<Proforma>> forSource(String sourceId) async =>
      (await local()).where((p) => p.sourceId == sourceId).toList();

  /// Émet une proforma : numéro provisoire, gardée sur l'appareil, puis
  /// envoyée (numéro définitif) si le réseau le permet.
  Future<Proforma> create({
    required String sourceType,
    String? sourceId,
    String? customerId,
    String? customerName,
    String? contactName,
    required List<ProformaLine> lines,
    String currencyCode = 'CDF',
    double exchangeRate = 1,
    int validityDays = 30,
    String? notes,
  }) async {
    final box = await _boite();
    final now = DateTime.now();
    final p = Proforma(
      id: const Uuid().v4(),
      provisionalNumber: await _provisoire(box),
      sourceType: sourceType,
      sourceId: sourceId,
      customerId: customerId,
      customerName: customerName,
      contactName: contactName,
      lines: lines,
      currencyCode: currencyCode.toUpperCase(),
      exchangeRate: exchangeRate > 0 ? exchangeRate : 1,
      validUntil: DateTime(now.year, now.month, now.day)
          .add(Duration(days: validityDays)),
      notes: notes,
      issuedAt: now,
    );
    await _garder(p);
    return (await _envoyer(p)) ?? p;
  }

  /// Envoie une proforma ; rend la version du serveur, ou `null` hors ligne.
  Future<Proforma?> _envoyer(Proforma p) async {
    try {
      final res = await _api.post('proformas',
          body: p.toApiJson(), requiresAuth: true, queueOffline: false);
      final data = _deballer(res);
      if (data is! Map) return null;
      final serveur =
          Proforma.fromJson(Map<String, dynamic>.from(data), synced: true);
      // Le numéro provisoire reste connu (il a pu être imprimé).
      final fusion = Proforma.fromJson({
        ...serveur.toJson(),
        'provisionalNumber': p.provisionalNumber,
      }, synced: true);
      await _garder(fusion);
      return fusion;
    } catch (_) {
      return null;
    }
  }

  /// Envoie les proformas restées sur l'appareil (hors ligne) : chacune
  /// reçoit son numéro définitif. Rend le nombre de proformas envoyées.
  Future<int> syncPending() async {
    // Sans entreprise connue, rien n'est envoyé (cloisonnement).
    if (BusinessContextService().companyId == null) return 0;
    var n = 0;
    for (final p in await local()) {
      if (p.synced) continue;
      if (await _envoyer(p) != null) n++;
    }
    return n;
  }

  /// Relit les proformas du serveur, puis envoie celles restées sur
  /// l'appareil. Hors ligne, la liste locale reste affichée.
  Future<List<Proforma>> refresh() async {
    await syncPending();
    try {
      final res = await _api.get('proformas', requiresAuth: true);
      final data = _deballer(res);
      if (data is List) {
        final locales = {for (final p in await local()) p.id: p};
        for (final e in data) {
          if (e is! Map) continue;
          final s = Proforma.fromJson(Map<String, dynamic>.from(e), synced: true);
          final loc = locales[s.id];
          await _garder(Proforma.fromJson({
            ...s.toJson(),
            if (loc?.provisionalNumber != null && s.provisionalNumber == null)
              'provisionalNumber': loc!.provisionalNumber,
          }, synced: true));
        }
      }
    } catch (_) {}
    return local();
  }

  /// Proforma d'une réservation (séjour ou salle, folio compris), calculée par
  /// le serveur exactement comme la facture. Réseau requis.
  Future<Proforma> fromReservation(String reservationId, {String? notes}) async {
    final res = await _api.post(
      'proformas/from-reservation/$reservationId',
      body: {'id': const Uuid().v4(), if (notes != null) 'notes': notes},
      requiresAuth: true,
      queueOffline: false,
    );
    final data = _deballer(res);
    final p = Proforma.fromJson(Map<String, dynamic>.from(data as Map),
        synced: true);
    await _garder(p);
    return p;
  }

  /// Annule une proforma. Gardée sur l'appareil puis envoyée (le statut
  /// part avec la proforma) : hors ligne, l'annulation suit à la synchro.
  Future<Proforma> cancel(Proforma p) async {
    final c = p.copyWith(status: ProformaStatus.cancelled, synced: false);
    await _garder(c);
    return (await _envoyer(c)) ?? c;
  }

  /// Marque convertie une proforma soldée ailleurs (commande du restaurant
  /// encaissée, vente du formulaire) : gardée puis envoyée avec son statut,
  /// rejouée à la synchronisation si le réseau manque.
  Future<void> markConverted(Proforma p, {String? saleId}) async {
    final c = p.copyWith(
        status: ProformaStatus.converted, convertedSaleId: saleId, synced: false);
    await _garder(c);
    await _envoyer(c);
  }

  /// Convertit en facture (vente, sur compte client ou réglée) ou en
  /// réservation confirmée. Réseau requis : le numéro de facture et la
  /// comptabilité sont au serveur. Une proforma encore provisoire est
  /// d'abord envoyée.
  Future<ProformaConversion> convert(Proforma p, {String paymentMethod = 'credit'}) async {
    var cible = p;
    if (!p.synced) {
      final envoyee = await _envoyer(p);
      if (envoyee == null) {
        throw NetworkException(
            'Convertir demande le réseau : la proforma doit recevoir son numéro définitif.');
      }
      cible = envoyee;
    }
    final res = await _api.post('proformas/${cible.id}/convert',
        body: {'paymentMethod': paymentMethod},
        requiresAuth: true,
        queueOffline: false);
    final data = _deballer(res);
    if (data is! Map) throw NetworkException('Réponse inattendue du serveur.');
    final proforma = Proforma.fromJson(
        {
          ...Map<String, dynamic>.from(data['proforma'] as Map),
          'provisionalNumber': cible.provisionalNumber,
        },
        synced: true);
    await _garder(proforma);
    return ProformaConversion(
      proforma,
      sale: data['sale'] is Map ? Map<String, dynamic>.from(data['sale']) : null,
      reservation: data['reservation'] is Map
          ? Map<String, dynamic>.from(data['reservation'])
          : null,
    );
  }
}
