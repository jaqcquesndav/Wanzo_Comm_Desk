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
}

/// Envoi au serveur. Par défaut : ApiClient avec file d'écritures hors ligne
/// (l'écriture est rejouée au retour du réseau, dans l'ordre).
typedef CashSessionSender = Future<void> Function(String endpoint, Map<String, dynamic> body);

Future<void> _defaultSender(String endpoint, Map<String, dynamic> body) async {
  try {
    await ApiClient().post(endpoint, body: body, requiresAuth: true);
  } on OfflineQueuedException {
    // En file : rejouée automatiquement.
  } catch (e) {
    // Refus ou panne : la session reste valable sur l'appareil.
    debugPrint('⚠️ Caisse : envoi $endpoint non abouti ($e)');
  }
}

/// Ouverture, suivi et clôture de la caisse du jour, hors ligne d'abord.
///
/// Une seule session ouverte à la fois sur l'appareil. Les ventes, règlements
/// et dépenses enregistrés pendant qu'elle est ouverte y sont rattachés par
/// [recordMovement] (appelé par les blocs de vente et de dépense).
class CashSessionService {
  CashSessionService({CashSessionStore? store, CashSessionSender? sender})
    : _store = store ?? HiveCashSessionStore(),
      _send = sender ?? _defaultSender;

  static CashSessionService instance = CashSessionService();

  final CashSessionStore _store;
  final CashSessionSender _send;
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
    await _send('cash-sessions', _openPayload(session));
    return session;
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
    return closed;
  }
}
