import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../core/exceptions/api_exceptions.dart';
import '../../../core/services/api_client.dart';
import '../models/cash_session.dart';

/// Stockage des sessions (JSON par localId). Remplaçable dans les tests.
abstract class CashSessionStore {
  Future<List<Map<String, dynamic>>> loadAll();
  Future<void> save(String localId, Map<String, dynamic> json);
  Future<void> delete(String localId);
}

class HiveCashSessionStore implements CashSessionStore {
  static const boxName = 'cash_sessions';
  Future<Box<String>> _box() async =>
      Hive.isBoxOpen(boxName) ? Hive.box<String>(boxName) : Hive.openBox<String>(boxName);

  @override
  Future<List<Map<String, dynamic>>> loadAll() async {
    final box = await _box();
    return [
      for (final raw in box.values)
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
    ];
  }

  @override
  Future<void> save(String localId, Map<String, dynamic> json) async {
    final box = await _box();
    await box.put(localId, jsonEncode(json));
  }

  @override
  Future<void> delete(String localId) async {
    final box = await _box();
    await box.delete(localId);
  }
}

/// Envoi au serveur. Par défaut : ApiClient avec file d'écritures hors ligne
/// (l'écriture est rejouée au retour du réseau, dans l'ordre).
typedef CashSessionSender = Future<void> Function(String endpoint, Map<String, dynamic> body);

/// Une caisse est déjà ouverte pour ce caissier (409 du serveur), sur un
/// autre appareil ou par une ouverture précédente. [serverSession] est la
/// session renvoyée par le serveur, à reprendre si l'utilisateur le veut.
class CashSessionConflict implements Exception {
  final Map<String, dynamic>? serverSession;
  const CashSessionConflict([this.serverSession]);

  String get message =>
      'Une caisse est déjà ouverte pour vous sur un autre appareil. Clôturez-la ou reprenez-la.';

  @override
  String toString() => message;
}

Map<String, dynamic>? _sessionIn(dynamic body) {
  if (body is! Map) return null;
  if (body['openedAt'] != null && body['status'] != null) {
    return Map<String, dynamic>.from(body);
  }
  for (final key in const ['details', 'data']) {
    final v = body[key];
    if (v is List && v.isNotEmpty) {
      final found = _sessionIn(v.first);
      if (found != null) return found;
    } else {
      final found = _sessionIn(v);
      if (found != null) return found;
    }
  }
  return null;
}

/// Session ouverte du caissier sur le serveur (null si aucune ou hors ligne).
typedef CashSessionFetcher = Future<Map<String, dynamic>?> Function();

Future<Map<String, dynamic>?> _defaultFetcher() async {
  try {
    final res = await ApiClient().get('cash-sessions/current', requiresAuth: true);
    return _sessionIn(res);
  } catch (_) {
    return null;
  }
}

Future<void> _defaultSender(String endpoint, Map<String, dynamic> body) async {
  try {
    await ApiClient().post(endpoint, body: body, requiresAuth: true);
  } on OfflineQueuedException {
    // En file : rejouée automatiquement.
  } on ApiException catch (e) {
    if (e.statusCode == 409) {
      throw CashSessionConflict(_sessionIn(e.responseBody) ?? await _defaultFetcher());
    }
    // Autre refus ou panne : la session reste valable sur l'appareil.
    debugPrint('⚠️ Caisse : envoi $endpoint non abouti ($e)');
  } catch (e) {
    debugPrint('⚠️ Caisse : envoi $endpoint non abouti ($e)');
  }
}

/// Ouverture, suivi et clôture de la caisse du jour, hors ligne d'abord.
///
/// Une seule session ouverte à la fois sur l'appareil. Les ventes, règlements
/// et dépenses enregistrés pendant qu'elle est ouverte y sont rattachés par
/// [recordMovement] (appelé par les blocs de vente et de dépense).
class CashSessionService {
  CashSessionService({
    CashSessionStore? store,
    CashSessionSender? sender,
    CashSessionFetcher? fetcher,
  }) : _store = store ?? HiveCashSessionStore(),
       _send = sender ?? _defaultSender,
       _fetch = fetcher ?? _defaultFetcher;

  static CashSessionService instance = CashSessionService();

  final CashSessionStore _store;
  final CashSessionSender _send;
  final CashSessionFetcher _fetch;
  final _uuid = const Uuid();

  /// Session ouverte (null si la caisse est fermée). Les écrans l'écoutent.
  final ValueNotifier<CashSession?> current = ValueNotifier<CashSession?>(null);
  bool _loaded = false;
  List<CashSession> _all = [];

  Future<void> load() async {
    if (_loaded) return;
    try {
      _all = [
        for (final j in await _store.loadAll()) CashSession.fromJson(j),
      ];
    } catch (e) {
      debugPrint('⚠️ Caisse : lecture locale impossible ($e)');
      _all = [];
    }
    _loaded = true;
    current.value = _all.where((s) => s.isOpen).fold<CashSession?>(
      null,
      (latest, s) => latest == null || s.openedAt.isAfter(latest.openedAt) ? s : latest,
    );
  }

  /// Sessions clôturées, de la plus récente à la plus ancienne.
  Future<List<CashSession>> history() async {
    await load();
    final closed = _all.where((s) => !s.isOpen).toList()
      ..sort((a, b) => (b.closedAt ?? b.openedAt).compareTo(a.closedAt ?? a.openedAt));
    return closed;
  }

  Future<void> _persist(CashSession s) async {
    _all = [..._all.where((x) => x.localId != s.localId), s];
    await _store.save(s.localId, s.toJson());
  }

  Map<String, dynamic> _openPayload(CashSession s) => {
    'localId': s.localId,
    'openedAt': s.openedAt.toUtc().toIso8601String(),
    'openingFloat': s.openingFloat,
    if (s.registerLabel != null) 'registerLabel': s.registerLabel,
  };

  /// Ouvre la caisse avec son fonds par devise.
  Future<CashSession> open(
    Map<String, double> openingFloat, {
    String? openedByName,
    String? registerLabel,
    DateTime? at,
  }) async {
    await load();
    if (current.value != null) {
      throw StateError('Une caisse est déjà ouverte : clôturez-la d\'abord.');
    }
    final float = <String, double>{
      for (final e in openingFloat.entries)
        if (e.value > 0) e.key.toUpperCase(): cashRound(e.value),
    };
    if (openingFloat.values.any((v) => v < 0)) {
      throw ArgumentError('Le fonds d\'ouverture ne peut pas être négatif.');
    }
    final session = CashSession(
      localId: _uuid.v4(),
      status: 'open',
      openedAt: at ?? DateTime.now(),
      openedByName: openedByName,
      registerLabel: registerLabel,
      openingFloat: float,
    );
    await _persist(session);
    current.value = session;
    try {
      await _send('cash-sessions', _openPayload(session));
    } on CashSessionConflict {
      // Le serveur a déjà une caisse ouverte pour ce caissier : l'ouverture
      // locale est annulée, l'écran propose de reprendre celle du serveur.
      _all = _all.where((s) => s.localId != session.localId).toList();
      await _store.delete(session.localId);
      current.value = null;
      rethrow;
    }
    return session;
  }

  /// Reprend sur cet appareil la caisse ouverte renvoyée par le serveur.
  Future<CashSession> resume(Map<String, dynamic> server) async {
    await load();
    final localId = (server['localId'] ?? server['id']).toString();
    final existing = _all.where((s) => s.localId == localId).toList();
    final session = existing.isNotEmpty && existing.first.isOpen
        ? existing.first
        : CashSession(
            localId: localId,
            status: 'open',
            openedAt: DateTime.parse(server['openedAt'].toString()).toLocal(),
            openedByName: server['openedByName'] as String?,
            registerLabel: server['registerLabel'] as String?,
            openingFloat: {
              for (final e in ((server['openingFloat'] as Map?) ?? const {}).entries)
                e.key.toString(): (e.value as num).toDouble(),
            },
          );
    final previous = current.value;
    if (previous != null && previous.localId != localId) {
      throw StateError('Clôturez d\'abord la caisse ouverte sur cet appareil.');
    }
    await _persist(session);
    current.value = session;
    return session;
  }

  /// Caisse ouverte sur le serveur pour ce caissier, si elle n'est pas celle
  /// de cet appareil (ouverture refusée au rejeu hors ligne, autre appareil).
  /// Null s'il n'y a rien à signaler ou hors ligne.
  Future<Map<String, dynamic>?> serverConflict() async {
    await load();
    final server = await _fetch();
    if (server == null) return null;
    final localId = (server['localId'] ?? server['id']).toString();
    if (current.value?.localId == localId) return null;
    return server;
  }

  /// Contre-passe dans sa session (ouverte ou déjà clôturée) les mouvements
  /// d'une vente annulée ou supprimée. Une session clôturée voit son
  /// théorique et son écart recalculés, et le serveur reçoit la correction.
  /// Sans effet si la vente n'est rattachée à aucune caisse ou déjà
  /// contre-passée.
  Future<bool> reverseSale(Set<String> refs, {String? label}) async {
    await load();
    final keys = refs.where((r) => r.isNotEmpty).toSet();
    if (keys.isEmpty) return false;
    for (final s in _all) {
      final originals = s.movements.where(
        (m) =>
            keys.contains(m.ref) &&
            (m.kind == CashMovementKind.sale || m.kind == CashMovementKind.customerPayment),
      );
      if (originals.isEmpty) continue;
      final already = s.movements.any(
        (m) => m.kind == CashMovementKind.saleReversal && keys.contains(m.ref),
      );
      if (already) return false;
      final reversals = [
        for (final m in originals)
          CashMovement(
            at: DateTime.now(),
            kind: CashMovementKind.saleReversal,
            method: m.method,
            currency: m.currency,
            amount: -m.amount,
            label: label ?? 'Annulation ${m.label}',
            ref: m.ref,
          ),
      ];
      var updated = s.copyWith(movements: [...s.movements, ...reversals]);
      if (!updated.isOpen) {
        final expected = updated.expectedCash();
        updated = updated.copyWith(
          expected: expected,
          difference: CashSession.differenceOf(expected, updated.counted ?? const {}),
        );
      }
      await _persist(updated);
      if (updated.isOpen) {
        current.value = updated;
      } else {
        await _send('cash-sessions/${s.localId}/corrections', {
          'expected': updated.expected,
          'summary': updated.summaryJson(),
          'note': reversals.first.label,
        });
      }
      return true;
    }
    return false;
  }

  /// Rattache un mouvement à la caisse ouverte. Sans caisse ouverte, ne fait
  /// rien et renvoie false (l'écran de vente invite alors à l'ouvrir).
  Future<bool> recordMovement(CashMovement movement) async {
    await load();
    final s = current.value;
    if (s == null || movement.amount == 0) return false;
    final updated = s.copyWith(movements: [...s.movements, movement]);
    await _persist(updated);
    current.value = updated;
    return true;
  }

  /// Entrée ou sortie manuelle d'espèces, avec son motif.
  Future<void> addManual({
    required bool entry,
    required double amount,
    required String currency,
    required String reason,
  }) async {
    if (amount <= 0) throw ArgumentError('Montant invalide');
    if (reason.trim().isEmpty) throw ArgumentError('Motif obligatoire');
    if (current.value == null) throw StateError('Aucune caisse ouverte');
    await recordMovement(
      CashMovement(
        at: DateTime.now(),
        kind: entry ? CashMovementKind.manualIn : CashMovementKind.manualOut,
        method: 'cash',
        currency: currency,
        amount: entry ? amount : -amount,
        label: reason.trim(),
      ),
    );
  }

  /// Clôture : montant compté par devise, écart calculé, motif exigé si
  /// écart. Renvoie la session clôturée (pour le rapport Z).
  Future<CashSession> close(
    Map<String, double> counted, {
    String? reason,
    String? closedByName,
    DateTime? at,
  }) async {
    await load();
    final s = current.value;
    if (s == null) throw StateError('Aucune caisse ouverte');
    if (counted.values.any((v) => v < 0)) {
      throw ArgumentError('Un montant compté ne peut pas être négatif.');
    }
    final expected = s.expectedCash();
    final countedClean = {
      for (final e in counted.entries) e.key.toUpperCase(): cashRound(e.value),
    };
    final diff = CashSession.differenceOf(expected, countedClean);
    final motif = reason?.trim();
    if (CashSession.hasDifference(diff) && (motif == null || motif.isEmpty)) {
      throw ArgumentError('Motif obligatoire : le compté diffère du théorique.');
    }
    final closed = s.copyWith(
      status: 'closed',
      closedAt: at ?? DateTime.now(),
      closedByName: closedByName,
      expected: expected,
      counted: countedClean,
      difference: diff,
      differenceReason: (motif == null || motif.isEmpty) ? null : motif,
    );
    await _persist(closed);
    current.value = null;
    try {
      await _send('cash-sessions/${s.localId}/close', {
      'closedAt': closed.closedAt!.toUtc().toIso8601String(),
      'expected': expected,
      'counted': countedClean,
      if (closed.differenceReason != null) 'differenceReason': closed.differenceReason,
      'summary': closed.summaryJson(),
      // L'ouverture voyage avec la clôture : si elle n'est jamais arrivée,
      // le serveur la crée au passage.
      'open': _openPayload(s),
      });
    } on CashSessionConflict {
      // Clôture locale acquise ; le conflit serveur est signalé par
      // [serverConflict] sur l'écran Caisse.
    }
    return closed;
  }
}
