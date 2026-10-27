import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'document_cancellation.dart';

/// Annulation ou rétablissement saisi hors ligne, en attente d'envoi.
@immutable
class PendingCancellation {
  final CancellableDocument doc;
  final String id;

  /// `cancel` ou `restore`.
  final String action;
  final String? reason;
  final DateTime at;

  const PendingCancellation({
    required this.doc,
    required this.id,
    required this.action,
    this.reason,
    required this.at,
  });

  bool get isCancel => action == PendingCancellations.cancel;

  Map<String, dynamic> toMap() => {
    'doc': doc.name,
    'id': id,
    'action': action,
    if (reason != null) 'reason': reason,
    'at': at.toIso8601String(),
  };

  static PendingCancellation? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final doc = CancellableDocument.values
        .where((d) => d.name == raw['doc'])
        .firstOrNull;
    final id = raw['id'];
    final action = raw['action'];
    if (doc == null || id is! String || id.isEmpty || action is! String) {
      return null;
    }
    return PendingCancellation(
      doc: doc,
      id: id,
      action: action,
      reason: raw['reason'] as String?,
      at: DateTime.tryParse(raw['at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// File des annulations saisies hors ligne, rejouée à chaque synchronisation.
///
/// Une seule entrée par pièce (clé `doc:id`) : la dernière intention fait foi.
/// Annuler puis rétablir une pièce avant tout envoi efface l'entrée, le
/// serveur n'a rien à apprendre.
class PendingCancellations {
  static const boxName = 'pendingDocumentCancellations';
  static const cancel = 'cancel';
  static const restore = 'restore';

  PendingCancellations._();
  static final PendingCancellations instance = PendingCancellations._();

  /// Copie mémoire, pour que les fusions de synchronisation (synchrones)
  /// sachent qu'une pièce attend son annulation.
  final Map<String, PendingCancellation> _memory = {};
  bool _loaded = false;

  static String _key(CancellableDocument doc, String id) => '${doc.name}:$id';

  Future<Box> _box() async =>
      Hive.isBoxOpen(boxName) ? Hive.box(boxName) : Hive.openBox(boxName);

  Future<void> _load() async {
    if (_loaded) return;
    try {
      final box = await _box();
      for (final raw in box.values) {
        final p = PendingCancellation.fromMap(raw);
        if (p != null) _memory[_key(p.doc, p.id)] = p;
      }
    } catch (e) {
      debugPrint('⚠️ File des annulations illisible ($e)');
    }
    _loaded = true;
  }

  /// Met une annulation ou un rétablissement en file.
  Future<void> enqueue(
    CancellableDocument doc,
    String id,
    String action, {
    String? reason,
  }) async {
    await _load();
    final key = _key(doc, id);
    final previous = _memory[key];
    // Annulée puis rétablie (ou l'inverse) avant tout envoi : rien à dire au
    // serveur.
    if (previous != null && previous.action != action) {
      await _remove(key);
      return;
    }
    final entry = PendingCancellation(
      doc: doc,
      id: id,
      action: action,
      reason: reason,
      at: DateTime.now(),
    );
    _memory[key] = entry;
    try {
      final box = await _box();
      await box.put(key, entry.toMap());
    } catch (e) {
      debugPrint('⚠️ Annulation non mise en file ($e)');
    }
  }

  /// Action en attente pour cette pièce, ou null.
  Future<PendingCancellation?> pendingFor(
    CancellableDocument doc,
    String id,
  ) async {
    await _load();
    return _memory[_key(doc, id)];
  }

  /// Vrai si une annulation ou un rétablissement attend pour cette pièce
  /// (lecture synchrone de la copie mémoire).
  bool isPending(CancellableDocument doc, String id) =>
      _memory.containsKey(_key(doc, id));

  /// Entrées en attente d'un type de pièce.
  Future<List<PendingCancellation>> entries(CancellableDocument doc) async {
    await _load();
    return _memory.values.where((p) => p.doc == doc).toList();
  }

  /// Retire l'entrée d'une pièce (envoyée, ou refusée pour de bon).
  Future<void> done(CancellableDocument doc, String id) =>
      _remove(_key(doc, id));

  /// La pièce a reçu son identifiant serveur : l'entrée le suit.
  Future<void> rekey(CancellableDocument doc, String oldId, String newId) async {
    if (oldId == newId || oldId.isEmpty || newId.isEmpty) return;
    await _load();
    final previous = _memory[_key(doc, oldId)];
    if (previous == null) return;
    await _remove(_key(doc, oldId));
    await enqueue(doc, newId, previous.action, reason: previous.reason);
  }

  Future<void> _remove(String key) async {
    _memory.remove(key);
    try {
      final box = await _box();
      await box.delete(key);
    } catch (e) {
      debugPrint('⚠️ File des annulations : retrait impossible ($e)');
    }
  }

  /// Tests : oublie la copie mémoire (la boîte est relue au prochain accès).
  @visibleForTesting
  void resetForTest() {
    _memory.clear();
    _loaded = false;
  }
}
