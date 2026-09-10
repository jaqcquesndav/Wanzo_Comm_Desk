import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// File d'attente des ÉCRITURES effectuées hors ligne.
///
/// PROBLÈME RÉSOLU : les modules récents (espaces et réservations, baux,
/// restaurant, atelier, conciergerie, actifs, production) passent tous par
/// `ApiClient`, qui n'avait aucune gestion du hors ligne. Leurs lectures
/// retombaient bien sur un cache local, mais leurs ÉCRITURES se contentaient de
/// lever une erreur réseau : la saisie de l'utilisateur était simplement
/// perdue. Seul l'ancien `ApiService` disposait d'une file d'attente, et les
/// modules récents ne l'utilisent pas.
///
/// Ce que fait cette file, et ce qu'elle ne fait pas :
///  - elle CONSERVE l'écriture (méthode, endpoint, corps) dans une box Hive
///    dédiée, et la rejoue dans l'ORDRE au retour du réseau ;
///  - elle ne fabrique JAMAIS de fausse réponse de succès. L'appelant reçoit
///    une [OfflineQueuedException] explicite, pour que l'interface dise la
///    vérité (« enregistré hors ligne ») au lieu d'afficher une entité créée
///    qui n'existe pas encore côté serveur.
///
/// Une opération rejetée par le serveur pour une raison DÉFINITIVE (4xx autre
/// que 408/429) est abandonnée avec une trace : la rejouer indéfiniment ne
/// ferait qu'empiler des échecs.
class OfflineWriteQueue {
  OfflineWriteQueue._();

  static final OfflineWriteQueue instance = OfflineWriteQueue._();

  static const String _boxName = 'offline_write_queue';

  /// Nombre maximal d'écritures conservées. Au delà, la plus ancienne est
  /// abandonnée : mieux vaut perdre la plus vieille saisie que faire grossir
  /// indéfiniment le stockage local.
  static const int maxEntries = 500;

  Future<Box>? _boxFuture;

  Future<Box> _box() {
    return _boxFuture ??= Hive.isBoxOpen(_boxName)
        ? Future.value(Hive.box(_boxName))
        : Hive.openBox(_boxName);
  }

  /// Ajoute une écriture à rejouer. Best-effort : si le stockage local est
  /// indisponible, on ne masque pas l'échec réseau pour autant.
  Future<bool> enqueue({
    required String method,
    required String endpoint,
    dynamic body,
    bool requiresAuth = true,
  }) async {
    try {
      final box = await _box();
      if (box.length >= maxEntries) {
        final oldest = box.keys.first;
        await box.delete(oldest);
        debugPrint(
          '[OfflineWriteQueue] File pleine ($maxEntries) : plus ancienne écriture abandonnée',
        );
      }
      await box.add(<String, dynamic>{
        'method': method.toUpperCase(),
        'endpoint': endpoint,
        // Le corps est stocké en JSON : une box non typée ne sait pas
        // sérialiser des objets arbitraires.
        'body': body == null ? null : jsonEncode(body),
        'requiresAuth': requiresAuth,
        'queuedAt': DateTime.now().toIso8601String(),
        'attempts': 0,
      });
      debugPrint('[OfflineWriteQueue] $method $endpoint mis en file');
      return true;
    } catch (e) {
      debugPrint('[OfflineWriteQueue] Mise en file impossible : $e');
      return false;
    }
  }

  /// Nombre d'écritures en attente (0 si le stockage est indisponible).
  Future<int> pendingCount() async {
    try {
      return (await _box()).length;
    } catch (_) {
      return 0;
    }
  }

  /// Rejoue les écritures en attente, dans l'ordre, en s'arrêtant à la
  /// première erreur réseau (le réseau est retombé : inutile d'insister).
  ///
  /// [send] exécute réellement l'appel. Il doit lever une erreur en cas
  /// d'échec ; [isPermanentFailure] distingue un refus définitif du serveur
  /// d'une simple coupure.
  Future<OfflineReplayReport> replay({
    required Future<void> Function(
      String method,
      String endpoint,
      dynamic body,
      bool requiresAuth,
    ) send,
    required bool Function(Object error) isPermanentFailure,
  }) async {
    int replayed = 0;
    int abandoned = 0;
    Box box;
    try {
      box = await _box();
    } catch (_) {
      return const OfflineReplayReport(replayed: 0, abandoned: 0, remaining: 0);
    }

    // Copie des clés : on modifie la box pendant l'itération.
    for (final key in box.keys.toList()) {
      final raw = box.get(key);
      if (raw is! Map) {
        await box.delete(key);
        continue;
      }
      final entry = Map<String, dynamic>.from(raw);
      final bodyJson = entry['body'] as String?;
      dynamic body;
      if (bodyJson != null) {
        try {
          body = jsonDecode(bodyJson);
        } catch (_) {
          // Corps illisible : l'opération n'est pas rejouable.
          await box.delete(key);
          abandoned++;
          continue;
        }
      }

      try {
        await send(
          entry['method'] as String? ?? 'POST',
          entry['endpoint'] as String? ?? '',
          body,
          entry['requiresAuth'] as bool? ?? true,
        );
        await box.delete(key);
        replayed++;
      } catch (e) {
        if (isPermanentFailure(e)) {
          debugPrint(
            '[OfflineWriteQueue] Abandon définitif de '
            '${entry['method']} ${entry['endpoint']} : $e',
          );
          await box.delete(key);
          abandoned++;
          continue;
        }
        // Échec temporaire : on incrémente le compteur et on s'arrête pour
        // préserver l'ORDRE des écritures.
        entry['attempts'] = (entry['attempts'] as int? ?? 0) + 1;
        await box.put(key, entry);
        debugPrint(
          '[OfflineWriteQueue] Rejeu interrompu sur '
          '${entry['method']} ${entry['endpoint']} : $e',
        );
        break;
      }
    }

    final report = OfflineReplayReport(
      replayed: replayed,
      abandoned: abandoned,
      remaining: box.length,
    );
    if (replayed > 0 || abandoned > 0) {
      debugPrint('[OfflineWriteQueue] $report');
    }
    return report;
  }

  /// Vide la file (déconnexion, changement de société).
  Future<void> clear() async {
    try {
      await (await _box()).clear();
    } catch (_) {
      // ignoré
    }
  }
}

/// Bilan d'un rejeu.
class OfflineReplayReport {
  final int replayed;
  final int abandoned;
  final int remaining;

  const OfflineReplayReport({
    required this.replayed,
    required this.abandoned,
    required this.remaining,
  });

  bool get isEmpty => replayed == 0 && abandoned == 0;

  @override
  String toString() =>
      'rejouées: $replayed, abandonnées: $abandoned, restantes: $remaining';
}
