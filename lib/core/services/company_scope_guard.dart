import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/cache_management_service.dart';

/// Dernière entreprise confirmée par le serveur, gardée sur disque.
///
/// Un membre retiré de son entreprise garde un compte valide : le serveur le
/// renvoie simplement sans entreprise. Deux règles en découlent :
/// - les données locales de l'ancienne entreprise sont effacées dès que le
///   serveur annonce une autre entreprise, ou aucune ;
/// - hors ligne, si la dernière réponse connue disait « sans entreprise »,
///   l'ancienne session n'est jamais rouverte.
///
/// Jusqu'ici l'ancienne entreprise ne vivait qu'en mémoire : un redémarrage
/// hors ligne rouvrait les anciennes données. Seule une RÉPONSE du serveur
/// change ce qui est gardé ici ; un refus (403) ou une coupure n'y touche pas,
/// si bien qu'un accès suspendu (réversible) ne purge rien.
class CompanyScopeGuard {
  CompanyScopeGuard({Future<void> Function()? purge, CompanyScopeStore? store})
    : _purge = purge ?? _purgeCachesMetier,
      _store = store ?? SharedPreferencesCompanyScopeStore();

  static final CompanyScopeGuard instance = CompanyScopeGuard();

  final Future<void> Function() _purge;
  final CompanyScopeStore _store;

  CompanyScopeSnapshot? _cache;
  bool _charge = false;

  static Future<void> _purgeCachesMetier() async {
    final service = CacheManagementService.instance;
    // Pas encore prêt : ne rien noter, la purge sera retentée à la réponse
    // suivante plutôt que d'être oubliée.
    if (!service.isInitialized) {
      throw StateError('CacheManagementService non initialisé');
    }
    await service.clearAllBusinessUnitData();
  }

  /// Ce que le serveur a dit en dernier, ou `null` si rien n'est connu.
  Future<CompanyScopeSnapshot?> lastKnown() async {
    if (!_charge) {
      try {
        _cache = await _store.read();
      } catch (e) {
        debugPrint('CompanyScopeGuard: lecture impossible : $e');
      }
      _charge = true;
    }
    return _cache;
  }

  /// Hors ligne : la dernière réponse du serveur, pour CE compte, disait-elle
  /// « sans entreprise » ?
  Future<bool> lastKnownWithoutCompany(String userId) async {
    final connu = await lastKnown();
    return connu != null && connu.userId == userId && !connu.hasCompany;
  }

  /// Enregistre une réponse du serveur. Purge les données locales si
  /// l'entreprise gardée n'est plus la même (y compris « plus aucune »).
  /// Retourne `true` si une purge a eu lieu.
  Future<bool> recordServerAnswer({
    required String userId,
    String? companyId,
    String? revokedFromCompanyId,
  }) async {
    final precedent = await lastKnown();
    final suivant = CompanyScopeSnapshot(
      userId: userId,
      companyId: _vide(companyId) ? null : companyId,
      revokedFromCompanyId:
          _vide(revokedFromCompanyId) ? null : revokedFromCompanyId,
    );

    var purge = false;
    if (precedent != null &&
        precedent.hasCompany &&
        precedent.companyId != suivant.companyId) {
      try {
        await _purge();
        purge = true;
        debugPrint(
          'CompanyScopeGuard: entreprise ${precedent.companyId} quittée, '
          'données locales effacées',
        );
      } catch (e) {
        // Rien n'est noté : la purge sera retentée à la prochaine réponse.
        debugPrint('CompanyScopeGuard: purge impossible : $e');
        return false;
      }
    }

    if (precedent != suivant) {
      try {
        await _store.write(suivant);
        _cache = suivant;
      } catch (e) {
        // Rien de gardé : on ne retient en mémoire que ce qui survivra à un
        // redémarrage, sinon les deux divergeraient.
        debugPrint('CompanyScopeGuard: écriture impossible : $e');
      }
    }
    return purge;
  }

  static bool _vide(String? valeur) => valeur == null || valeur.trim().isEmpty;
}

/// Instantané gardé sur disque.
@immutable
class CompanyScopeSnapshot {
  const CompanyScopeSnapshot({
    required this.userId,
    this.companyId,
    this.revokedFromCompanyId,
  });

  final String userId;

  /// `null` : le serveur a dit « sans entreprise ».
  final String? companyId;

  /// Entreprise dont le compte a été retiré, si le serveur l'a dit.
  final String? revokedFromCompanyId;

  bool get hasCompany => companyId != null;
  bool get wasRevoked => !hasCompany && revokedFromCompanyId != null;

  @override
  bool operator ==(Object other) =>
      other is CompanyScopeSnapshot &&
      other.userId == userId &&
      other.companyId == companyId &&
      other.revokedFromCompanyId == revokedFromCompanyId;

  @override
  int get hashCode => Object.hash(userId, companyId, revokedFromCompanyId);
}

/// Support de stockage (remplaçable dans les tests).
abstract class CompanyScopeStore {
  Future<CompanyScopeSnapshot?> read();
  Future<void> write(CompanyScopeSnapshot snapshot);
}

/// Stockage en mémoire, pour les tests.
class MemoryCompanyScopeStore implements CompanyScopeStore {
  MemoryCompanyScopeStore([this.snapshot]);

  CompanyScopeSnapshot? snapshot;

  @override
  Future<CompanyScopeSnapshot?> read() async => snapshot;

  @override
  Future<void> write(CompanyScopeSnapshot value) async => snapshot = value;
}

class SharedPreferencesCompanyScopeStore implements CompanyScopeStore {
  static const _cleUtilisateur = 'company_scope.user_id';
  static const _cleEntreprise = 'company_scope.company_id';
  static const _cleRetrait = 'company_scope.revoked_from_company_id';

  @override
  Future<CompanyScopeSnapshot?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_cleUtilisateur);
    if (userId == null || userId.isEmpty) return null;
    final companyId = prefs.getString(_cleEntreprise);
    final revoked = prefs.getString(_cleRetrait);
    return CompanyScopeSnapshot(
      userId: userId,
      companyId: (companyId == null || companyId.isEmpty) ? null : companyId,
      revokedFromCompanyId:
          (revoked == null || revoked.isEmpty) ? null : revoked,
    );
  }

  @override
  Future<void> write(CompanyScopeSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleUtilisateur, snapshot.userId);
    await prefs.setString(_cleEntreprise, snapshot.companyId ?? '');
    await prefs.setString(_cleRetrait, snapshot.revokedFromCompanyId ?? '');
  }
}
