import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../core/exceptions/api_exceptions.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/business_context_service.dart';
import '../../../core/services/currency_service.dart';
import '../../dashboard/models/operation_journal_entry.dart';
import '../cash_access.dart';
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

/// Envoi au serveur. Renvoie la réponse du serveur. Lève
/// [CashSyncDeferred] quand l'envoi doit être rejoué plus tard (hors
/// connexion, 5xx, délai dépassé), [CashSessionConflict] sur un 409 et
/// [CashSessionRefused] sur un autre refus 4xx.
typedef CashSessionSender = Future<dynamic> Function(String endpoint, Map<String, dynamic> body);

/// Envoi pas abouti pour une raison PASSAGÈRE (réseau absent, serveur en
/// panne, délai dépassé) : il reste en attente sur la session et repart au
/// retour du réseau, jamais abandonné.
class CashSyncDeferred implements Exception {
  final String message;
  const CashSyncDeferred(this.message);

  @override
  String toString() => message;
}

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

/// Refus du serveur (4xx autre que le conflit 409) : droits, validation.
/// La caisse reste valable sur l'appareil, mais le motif doit atteindre
/// l'ecran au lieu de disparaitre dans les journaux.
class CashSessionRefused implements Exception {
  final String message;
  const CashSessionRefused(this.message);

  @override
  String toString() => message;
}

/// Propriétaire attendu d'une session : entreprise, unité et utilisateur
/// connectés.
@immutable
class CashSessionIdentity {
  final String? companyId;
  final String? businessUnitId;
  final String? userId;

  const CashSessionIdentity({this.companyId, this.businessUnitId, this.userId});

  String get key => '$companyId|$businessUnitId|$userId';

  bool owns(CashSession s) =>
      s.companyId == companyId && s.businessUnitId == businessUnitId && s.userId == userId;
}

typedef CashIdentityProvider = CashSessionIdentity Function();

CashSessionIdentity _defaultIdentity() {
  try {
    final c = BusinessContextService();
    return CashSessionIdentity(
      companyId: c.companyId,
      businessUnitId: c.businessUnitId,
      userId: c.userId,
    );
  } catch (_) {
    return const CashSessionIdentity();
  }
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

/// Liste `items` d'une réponse paginée, à n'importe quel niveau d'enveloppe.
List<Map<String, dynamic>>? _itemsIn(dynamic body) {
  if (body is List) {
    return [for (final e in body) if (e is Map) Map<String, dynamic>.from(e)];
  }
  if (body is! Map) return null;
  final items = body['items'];
  if (items is List) {
    return [for (final e in items) if (e is Map) Map<String, dynamic>.from(e)];
  }
  for (final key in const ['data', 'result']) {
    final found = _itemsIn(body[key]);
    if (found != null) return found;
  }
  return null;
}

int? _totalPagesIn(dynamic body) {
  if (body is! Map) return null;
  final v = body['totalPages'];
  if (v is num) return v.toInt();
  for (final key in const ['data', 'result']) {
    final found = _totalPagesIn(body[key]);
    if (found != null) return found;
  }
  return null;
}

Map<String, double> _amountsOf(dynamic raw) {
  if (raw is! Map) return {};
  final out = <String, double>{};
  raw.forEach((k, v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v');
    if (n != null) out[k.toString()] = n;
  });
  return out;
}

/// Refus DÉFINITIF (4xx) ou panne PASSAGÈRE ? 401, 408, 429 et un compte
/// suspendu restent passagers : l'envoi repartira.
bool _isPermanent(ApiException e) {
  if (e is OfflineQueuedException || e is NetworkException || e is AuthenticationException) {
    return false;
  }
  final code = e.statusCode;
  if (code == null) return false;
  if (code == 401 || code == 408 || code == 429) return false;
  if (code == 403 && '${e.responseBody}'.contains('ACCOUNT_SUSPENDED')) return false;
  return code >= 400 && code < 500;
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

Future<dynamic> _defaultSender(String endpoint, Map<String, dynamic> body) async {
  try {
    // queueOffline: false : la caisse garde elle-même ses envois en attente
    // (pendingSync) et sait quoi faire d'un refus au rejeu.
    return await ApiClient().post(endpoint, body: body, requiresAuth: true, queueOffline: false);
  } on ApiException catch (e) {
    if (e.statusCode == 409) {
      throw CashSessionConflict(_sessionIn(e.responseBody) ?? await _defaultFetcher());
    }
    if (_isPermanent(e)) throw CashSessionRefused(cashRefusalMessage(e));
    throw CashSyncDeferred(e.message);
  } catch (e) {
    if (e is CashSessionConflict || e is CashSessionRefused || e is CashSyncDeferred) rethrow;
    // Délai dépassé, panne inattendue : on retentera.
    throw CashSyncDeferred('$e');
  }
}

/// Corps d'un mouvement manuel pour le serveur
/// (`POST cash-sessions/:id/movements`, ou `manualMovements` de la clôture).
Map<String, dynamic> manualMovementBody(CashMovement m) => {
  'localId': m.ref,
  'kind': m.kind == CashMovementKind.manualIn ? 'manual_in' : 'manual_out',
  'amount': m.amount.abs(),
  'currency': m.currency,
  if (m.currency != 'CDF' && m.rate != null) 'exchangeRate': m.rate,
  'reason': m.label,
  'at': m.at.toUtc().toIso8601String(),
};

/// Code de refus de la caisse côté serveur : rôle sans caisse.
const kCashAccessDenied = 'CASH_ACCESS_DENIED';

/// Code de refus de la caisse côté serveur : session d'une autre unité.
const kCashSessionOtherUnit = 'CASH_SESSION_OTHER_UNIT';

/// Motif lisible d'un refus 4xx, avec les deux refus d'accès de la caisse.
String cashRefusalMessage(ApiException e) {
  final body = '${e.responseBody}';
  if (body.contains(kCashAccessDenied)) {
    return 'La caisse est réservée à l\'administrateur, au comptable et au caissier.';
  }
  if (body.contains(kCashSessionOtherUnit)) {
    return 'Cette caisse appartient à une autre unité : seules les caisses de votre unité vous sont ouvertes.';
  }
  return e.message.isNotEmpty ? e.message : 'La caisse a été refusée par le serveur (${e.statusCode}).';
}

/// Taux du jour d'une devise (1 devise = n CDF), null si aucun taux
/// exploitable : rien n'est alors envoyé, le serveur prend son taux central
/// (jamais un taux 1 implicite).
typedef CashRateProvider = Future<double?> Function(String currency);

Future<double?> _defaultRate(String currency) async {
  try {
    final cs = CurrencyService();
    await cs.loadSettings();
    return cs.usableRateToCdfForCode(currency);
  } catch (_) {
    return null;
  }
}

/// Envoi d'un dépôt en banque (`cash-sessions/bank-deposits`). Une panne
/// passagère lève [CashSyncDeferred] (le dépôt est gardé en attente avec le
/// MÊME localId) ; un REFUS du serveur (compte inconnu, taux) lève
/// [CashDepositRefused].
typedef CashDepositSender = Future<void> Function(Map<String, dynamic> body);

/// Dépôt refusé par le serveur.
class CashDepositRefused implements Exception {
  final String message;
  const CashDepositRefused(this.message);

  @override
  String toString() => message;
}

Future<void> _defaultDepositSender(Map<String, dynamic> body) async {
  try {
    await ApiClient().post(
      'cash-sessions/bank-deposits',
      body: body,
      requiresAuth: true,
      queueOffline: false,
    );
  } on ApiException catch (e) {
    if (_isPermanent(e) || e.statusCode == 409) throw CashDepositRefused(cashRefusalMessage(e));
    throw CashSyncDeferred(e.message);
  } catch (e) {
    if (e is CashDepositRefused || e is CashSyncDeferred) rethrow;
    throw CashSyncDeferred('$e');
  }
}

/// Une page de l'historique des clôtures lue sur le serveur.
class CashHistoryPage {
  final List<Map<String, dynamic>> items;
  final int totalPages;
  const CashHistoryPage(this.items, this.totalPages);
}

/// Historique des clôtures du serveur (`GET cash-sessions`, paginé). Null
/// si rien n'est lisible (hors ligne sans copie locale).
typedef CashHistoryFetcher = Future<CashHistoryPage?> Function(int page, int limit);

Future<CashHistoryPage?> _defaultHistoryFetcher(int page, int limit) async {
  const boxName = 'cash_sessions_server_history';
  final scope = _defaultIdentity().key;
  final cacheKey = '$scope|$page|$limit';
  Future<Box<String>> box() async =>
      Hive.isBoxOpen(boxName) ? Hive.box<String>(boxName) : Hive.openBox<String>(boxName);
  CashHistoryPage? parse(dynamic res) {
    final items = _itemsIn(res);
    if (items == null) return null;
    return CashHistoryPage(items, _totalPagesIn(res) ?? page);
  }

  try {
    final res = await ApiClient().get(
      'cash-sessions',
      queryParameters: {'status': 'closed', 'page': '$page', 'limit': '$limit'},
      requiresAuth: true,
    );
    final parsed = parse(res);
    if (parsed != null) {
      try {
        await (await box()).put(cacheKey, jsonEncode(res));
      } catch (_) {}
    }
    return parsed;
  } catch (_) {
    // Hors ligne : dernière réponse connue.
    try {
      final raw = (await box()).get(cacheKey);
      return raw == null ? null : parse(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}

/// Filtre d'historique : l'entreprise générale (unité racine).
const kCashRootUnit = '__company__';

/// Écriture au journal des opérations (vue Caisse). Branchée au démarrage.
typedef CashJournalSink = Future<void> Function(OperationJournalEntry entry);

/// Ouverture, suivi et clôture de la caisse du jour, hors ligne d'abord.
///
/// Une seule session ouverte à la fois PAR UTILISATEUR, ENTREPRISE ET UNITÉ.
/// Les ventes, règlements et dépenses enregistrés pendant qu'elle est ouverte
/// y sont rattachés par [recordMovement] (appelé par les blocs de vente et de
/// dépense). Sur un poste partagé, chaque caissier ne voit que sa caisse.
class CashSessionService {
  CashSessionService({
    CashSessionStore? store,
    CashSessionSender? sender,
    CashSessionFetcher? fetcher,
    CashDepositSender? depositSender,
    CashIdentityProvider? identity,
    CashHistoryFetcher? historyFetcher,
    CashUnitScope Function()? unitScope,
    CashRateProvider? rates,
    this.journal,
  }) : _store = store ?? HiveCashSessionStore(),
       _send = sender ?? _defaultSender,
       _fetch = fetcher ?? _defaultFetcher,
       _sendDeposit = depositSender ?? _defaultDepositSender,
       _identity = identity ?? _defaultIdentity,
       _fetchHistory = historyFetcher ?? _defaultHistoryFetcher,
       _unitScope = unitScope ?? currentCashUnitScope,
       _rate = rates ?? _defaultRate;

  static CashSessionService instance = CashSessionService();

  final CashSessionStore _store;
  final CashSessionSender _send;
  final CashSessionFetcher _fetch;
  final CashDepositSender _sendDeposit;
  final CashIdentityProvider _identity;
  final CashHistoryFetcher _fetchHistory;

  /// Périmètre d'unité de l'utilisateur (caissier d'unité : la sienne).
  final CashUnitScope Function() _unitScope;

  /// Unités visibles pour l'utilisateur : la sienne s'il est caissier
  /// d'unité, sinon toutes (filtre libre).
  CashUnitScope get unitScope => _unitScope();
  final _uuid = const Uuid();

  /// Journal des opérations (vue Caisse) : fonds d'ouverture, entrées et
  /// sorties manuelles, dépôts en banque. Null : rien n'est journalisé.
  CashJournalSink? journal;

  final CashRateProvider _rate;

  /// Session ouverte (null si la caisse est fermée). Les écrans l'écoutent.
  final ValueNotifier<CashSession?> current = ValueNotifier<CashSession?>(null);

  /// Dernier refus du serveur (4xx) a afficher sur l'ecran Caisse ; null
  /// quand il n'y a rien a signaler ou que l'utilisateur l'a ferme.
  final ValueNotifier<String?> serverRefusal = ValueNotifier<String?>(null);

  /// Nombre d'envois en attente du réseau (sessions de l'utilisateur).
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  /// Session dont la clôture avait déjà été faite sur le serveur par
  /// quelqu'un d'autre (ou avec un autre comptage). L'écran le signale.
  final ValueNotifier<CashSession?> closedElsewhere = ValueNotifier<CashSession?>(null);

  bool _loaded = false;
  Future<void>? _loading;
  String? _scopeKey;
  List<CashSession> _all = [];
  Future<void>? _syncing;

  final Map<String, CashSession> _serverHistory = {};
  int _serverPage = 0;
  int _serverTotalPages = 1;
  String? _serverScope;
  static const _serverPageSize = 20;

  Future<void> _readStore() async {
    try {
      _all = [
        for (final j in await _store.loadAll()) CashSession.fromJson(j),
      ];
    } catch (e) {
      debugPrint('⚠️ Caisse : lecture locale impossible ($e)');
      _all = [];
    }
    _loaded = true;
  }

  /// Lit les sessions de l'appareil et retient celle de l'utilisateur
  /// connecté. Rappelée à chaque opération : un changement d'utilisateur,
  /// d'entreprise ou d'unité sur le même poste change la caisse visible.
  Future<void> load() async {
    if (!_loaded) {
      _loading ??= _readStore();
      await _loading;
    }
    final id = _identity();
    if (_scopeKey == id.key) return;
    _scopeKey = id.key;
    await _adoptLegacy(id);
    current.value = _all.where((s) => s.isOpen && id.owns(s)).fold<CashSession?>(
      null,
      (latest, s) => latest == null || s.openedAt.isAfter(latest.openedAt) ? s : latest,
    );
    _refreshPendingCount();
  }

  /// Sessions enregistrées avant l'isolation (sans entreprise ni
  /// utilisateur) : affectées UNE fois à l'utilisateur connecté. Sans
  /// entreprise connue, rien n'est affecté.
  Future<void> _adoptLegacy(CashSessionIdentity id) async {
    if (id.companyId == null) return;
    final legacy = _all.where((s) => s.isLegacy).toList();
    for (final s in legacy) {
      await _persist(
        s.copyWith(
          companyId: id.companyId,
          businessUnitId: id.businessUnitId,
          userId: id.userId,
        ),
      );
    }
  }

  bool _isMine(CashSession s) => _identity().owns(s);

  CashSession? _find(String localId) => _all.where((s) => s.localId == localId).firstOrNull;

  void _refreshPendingCount() {
    final id = _identity();
    pendingCount.value = _all
        .where(id.owns)
        .fold<int>(0, (n, s) => n + s.pendingSync.length);
  }

  /// Sessions clôturées, de la plus récente à la plus ancienne : celles de
  /// l'appareil et celles relues du serveur ([refreshServerHistory]).
  ///
  /// Un caissier d'unité ne voit que son unité ([unitScope]). Les autres
  /// peuvent filtrer sur une unité ([unitFilter], [kCashRootUnit] pour
  /// l'entreprise générale) ; null : toutes.
  Future<List<CashSession>> history({String? unitFilter}) async {
    await load();
    final id = _identity();
    final scope = _unitScope();
    bool visible(CashSession s) {
      if (!scope.allows(s.businessUnitId)) return false;
      if (unitFilter == null) return true;
      if (unitFilter == kCashRootUnit) return s.businessUnitId == null || s.businessUnitId == s.companyId;
      return s.businessUnitId == unitFilter;
    }

    final local = _all.where((s) => !s.isOpen && id.owns(s)).toList();
    final known = {for (final s in local) s.localId};
    final merged = [
      ...local,
      if (_serverScope == id.key)
        for (final s in _serverHistory.values)
          if (!known.contains(s.localId) && !s.isOpen) s,
    ].where(visible).toList()
      ..sort((a, b) => (b.closedAt ?? b.openedAt).compareTo(a.closedAt ?? a.openedAt));
    return merged;
  }

  /// Unités présentes dans l'historique (filtre), entreprise générale
  /// comprise ([kCashRootUnit]).
  Future<Set<String>> historyUnits() async {
    final all = await history();
    return {
      for (final s in all)
        (s.businessUnitId == null || s.businessUnitId == s.companyId) ? kCashRootUnit : s.businessUnitId!,
    };
  }

  /// Relit la première page de l'historique du serveur.
  Future<void> refreshServerHistory() async {
    final id = _identity();
    if (_serverScope != id.key) {
      _serverHistory.clear();
      _serverScope = id.key;
    }
    _serverPage = 0;
    _serverTotalPages = 1;
    await loadMoreServerHistory();
  }

  /// Page suivante de l'historique du serveur. Renvoie false s'il n'y a plus
  /// rien à lire (ou hors ligne sans copie).
  Future<bool> loadMoreServerHistory() async {
    if (!hasMoreServerHistory) return false;
    final page = _serverPage + 1;
    CashHistoryPage? res;
    try {
      res = await _fetchHistory(page, _serverPageSize);
    } catch (e) {
      debugPrint('⚠️ Caisse : historique du serveur illisible ($e)');
    }
    if (res == null) return false;
    _serverScope ??= _identity().key;
    for (final j in res.items) {
      try {
        final s = CashSession.fromServer(j);
        _serverHistory[s.localId] = s;
        final id = j['id']?.toString();
        if (id != null && id != s.localId) _serverHistory.remove(id);
      } catch (_) {}
    }
    _serverPage = page;
    _serverTotalPages = res.totalPages;
    return true;
  }

  bool get hasMoreServerHistory => _serverPage < _serverTotalPages;

  Future<void> _persist(CashSession s) async {
    _all = [..._all.where((x) => x.localId != s.localId), s];
    await _store.save(s.localId, s.toJson());
  }

  /// Applique [change] à la session [localId] (dernier état connu), la
  /// sauvegarde et met à jour la caisse affichée.
  Future<CashSession?> _update(String localId, CashSession Function(CashSession) change) async {
    final s = _find(localId);
    if (s == null) return null;
    final updated = change(s);
    await _persist(updated);
    if (current.value?.localId == localId) {
      current.value = updated.isOpen && _isMine(updated) ? updated : null;
    }
    _refreshPendingCount();
    return updated;
  }

  Future<void> _enqueue(String localId, CashPendingWrite w) =>
      _update(localId, (s) => s.copyWith(pendingSync: [...s.pendingSync, w]));

  /// Envoie [w] pour la session [localId]. La réponse du serveur est
  /// renvoyée, ou null si l'envoi reste en attente (panne passagère) ou a
  /// été refusé (motif dans [serverRefusal]). Le conflit 409 remonte à
  /// l'appelant. Une session qui a déjà des envois en attente garde l'ordre :
  /// le nouvel envoi passe derrière.
  Future<dynamic> _envoyer(String localId, CashPendingWrite w) async {
    final s = _find(localId);
    if (s == null) return null;
    if (!_isMine(s) || s.hasPendingSync) {
      await _enqueue(localId, w);
      if (_isMine(s)) await syncPending();
      return null;
    }
    try {
      final res = await _send(w.endpoint, w.body);
      await _afterSuccess(localId, w, res);
      return res;
    } on CashSyncDeferred catch (e) {
      debugPrint('⚠️ Caisse : envoi ${w.endpoint} en attente ($e)');
      await _enqueue(localId, w.retried(e.message));
      return null;
    } on CashSessionRefused catch (e) {
      serverRefusal.value = e.message;
      return null;
    }
  }

  /// Taux du jour des devises étrangères de [codes] (1 devise = n CDF). Une
  /// devise sans taux exploitable est omise : le serveur prend son taux.
  Future<Map<String, double>> _ratesFor(Set<String> codes) async {
    final out = <String, double>{};
    for (final c in codes) {
      final code = c.toUpperCase();
      if (code == 'CDF') continue;
      final r = await _rate(code);
      if (r != null && r > 1) out[code] = r;
    }
    return out;
  }

  Future<void> _afterSuccess(String localId, CashPendingWrite w, dynamic res) async {
    if (w.kind == 'close') await _checkServerClosure(localId, res);
  }

  /// Rejoue, dans l'ordre, les envois en attente des sessions de
  /// l'utilisateur connecté. Appelé au retour du réseau, à l'ouverture de
  /// l'écran Caisse et au lancement. Une panne passagère arrête le passage
  /// (on retentera) ; un refus 4xx retire l'envoi et le signale.
  Future<void> syncPending() {
    final running = _syncing;
    if (running != null) return running;
    final run = _doSync();
    _syncing = run;
    return run.whenComplete(() => _syncing = null);
  }

  Future<void> _doSync() async {
    await load();
    final ids = (_all.where((s) => _isMine(s) && s.hasPendingSync).toList()
          ..sort((a, b) => a.openedAt.compareTo(b.openedAt)))
        .map((s) => s.localId)
        .toList();
    for (final localId in ids) {
      while (true) {
        final fresh = _find(localId);
        if (fresh == null || fresh.pendingSync.isEmpty) break;
        final w = fresh.pendingSync.first;
        Future<void> drop() => _update(
          localId,
          (s) => s.copyWith(pendingSync: s.pendingSync.skip(1).toList()),
        );
        try {
          dynamic res;
          if (w.kind == 'deposit') {
            await _sendDeposit(w.body);
          } else {
            res = await _send(w.endpoint, w.body);
          }
          await drop();
          await _afterSuccess(localId, w, res);
        } on CashSyncDeferred catch (e) {
          await _update(
            localId,
            (s) => s.copyWith(
              pendingSync: [
                if (s.pendingSync.isNotEmpty) s.pendingSync.first.retried(e.message),
                ...s.pendingSync.skip(1),
              ],
            ),
          );
          return;
        } on CashDepositRefused catch (e) {
          await drop();
          await _markDepositNotPosted(localId, w.ref ?? '${w.body['localId']}', e.message);
          serverRefusal.value = 'Dépôt en banque non comptabilisé : ${e.message}';
        } on CashSessionConflict catch (e) {
          await drop();
          serverRefusal.value = e.message;
        } on CashSessionRefused catch (e) {
          await drop();
          serverRefusal.value = e.message;
        } catch (e) {
          // Erreur imprévue : on garde l'envoi pour le prochain passage.
          debugPrint('⚠️ Caisse : rejeu ${w.endpoint} interrompu ($e)');
          return;
        }
      }
    }
  }

  ValueListenable<bool>? _network;

  /// Rejoue les envois en attente à chaque retour du réseau.
  void listenForReconnect(ValueListenable<bool> connected) {
    _network?.removeListener(_onNetwork);
    _network = connected;
    connected.addListener(_onNetwork);
  }

  void _onNetwork() {
    if (_network?.value == true) {
      syncPending().catchError((Object e) => debugPrint('⚠️ Caisse : rejeu impossible ($e)'));
    }
  }

  Future<void> _markDepositNotPosted(String sessionLocalId, String ref, String message) async {
    await _update(
      sessionLocalId,
      (s) => s.copyWith(
        movements: [
          for (final m in s.movements)
            m.kind == CashMovementKind.bankDeposit && m.ref == ref ? m.copyWith(syncIssue: message) : m,
        ],
      ),
    );
  }

  /// Clôture renvoyée par le serveur : si elle avait déjà été faite par
  /// quelqu'un d'autre, ou avec un autre comptage, on garde ce que le
  /// serveur a retenu et l'écart à corriger.
  Future<void> _checkServerClosure(String localId, dynamic res) async {
    final srv = _sessionIn(res);
    if (srv == null || srv['status'] != 'closed') return;
    final local = _find(localId);
    if (local == null || local.counted == null) return;
    final srvCounted = _amountsOf(srv['counted']);
    final me = _identity().userId;
    final closedBy = srv['closedBy']?.toString();
    final otherUser = closedBy != null && me != null && closedBy != me;
    final gap = CashSession.differenceOf(srvCounted, local.counted!);
    if (!otherUser && !CashSession.hasDifference(gap)) return;
    final updated = await _update(
      localId,
      (s) => s.copyWith(
        serverClosure: {
          if (srv['closedByName'] != null) 'closedByName': srv['closedByName'].toString(),
          if (srv['closedAt'] != null) 'closedAt': srv['closedAt'].toString(),
          'counted': srvCounted,
          'expected': _amountsOf(srv['expected']),
          'difference': _amountsOf(srv['difference']),
          if (srv['differenceReason'] != null) 'differenceReason': srv['differenceReason'].toString(),
          // Votre comptage moins celui retenu par le serveur, par devise.
          'countGap': gap,
        },
      ),
    );
    if (updated != null) closedElsewhere.value = updated;
  }

  Future<void> _journal(OperationJournalEntry entry) async {
    final sink = journal;
    if (sink == null) return;
    try {
      await sink(entry);
    } catch (e) {
      debugPrint('⚠️ Caisse : journal non mis à jour ($e)');
    }
  }

  OperationJournalEntry _cashEntry({
    required DateTime at,
    required String description,
    required String currency,
    required double amount,
    required String ref,
  }) => OperationJournalEntry(
    id: _uuid.v4(),
    date: at,
    description: description,
    type: amount >= 0 ? OperationType.cashIn : OperationType.cashOut,
    amount: amount,
    paymentMethod: 'cash',
    relatedDocumentId: ref,
    currencyCode: currency,
    isDebit: true,
    isCredit: false,
    balanceAfter: 0,
  );

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
    final id = _identity();
    final session = CashSession(
      localId: _uuid.v4(),
      status: 'open',
      openedAt: at ?? DateTime.now(),
      openedByName: openedByName,
      registerLabel: registerLabel,
      openingFloat: float,
      companyId: id.companyId,
      businessUnitId: id.businessUnitId,
      userId: id.userId,
    );
    await _persist(session);
    current.value = session;
    try {
      await _envoyer(
        session.localId,
        CashPendingWrite(kind: 'open', endpoint: 'cash-sessions', body: _openPayload(session)),
      );
    } on CashSessionConflict {
      // Le serveur a déjà une caisse ouverte pour ce caissier : l'ouverture
      // locale est annulée, l'écran propose de reprendre celle du serveur.
      _all = _all.where((s) => s.localId != session.localId).toList();
      await _store.delete(session.localId);
      current.value = null;
      rethrow;
    }
    for (final e in float.entries) {
      await _journal(_cashEntry(
        at: session.openedAt,
        description: 'Fonds d\'ouverture de caisse',
        currency: e.key,
        amount: e.value,
        ref: session.localId,
      ));
    }
    return session;
  }

  /// Reprend sur cet appareil la caisse ouverte renvoyée par le serveur.
  Future<CashSession> resume(Map<String, dynamic> server) async {
    await load();
    final localId = (server['localId'] ?? server['id']).toString();
    final id = _identity();
    final existing = _all.where((s) => s.localId == localId).toList();
    final session = existing.isNotEmpty && existing.first.isOpen
        ? existing.first.copyWith(
            companyId: id.companyId,
            businessUnitId: id.businessUnitId,
            userId: id.userId,
          )
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
            companyId: id.companyId,
            businessUnitId: id.businessUnitId,
            userId: id.userId,
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
    // Ouverture encore en attente d'envoi : ce n'est pas un conflit.
    if (_all.any((s) => s.localId == localId)) return null;
    return server;
  }

  /// Contre-passe les mouvements d'une vente annulée ou supprimée, dans
  /// CHAQUE session où elle a laissé un mouvement (vente, règlements, crédit
  /// accordé), ouverte ou déjà clôturée. Une session clôturée voit son
  /// théorique et son écart recalculés, et le serveur reçoit la correction.
  /// Renvoie false si la vente n'est rattachée à aucune caisse ou déjà
  /// contre-passée partout.
  Future<bool> reverseSale(Set<String> refs, {String? label}) async {
    await load();
    final keys = refs.where((r) => r.isNotEmpty).toSet();
    if (keys.isEmpty) return false;
    final companyId = _identity().companyId;
    var done = false;
    for (final s in List<CashSession>.of(_all)) {
      if (companyId != null && s.companyId != null && s.companyId != companyId) continue;
      final originals = s.movements.where(
        (m) =>
            keys.contains(m.ref) &&
            (m.kind == CashMovementKind.sale ||
                m.kind == CashMovementKind.customerPayment ||
                (m.kind == CashMovementKind.creditGranted && m.amount > 0)),
      );
      if (originals.isEmpty) continue;
      final already = s.movements.any(
        (m) =>
            keys.contains(m.ref) &&
            (m.kind == CashMovementKind.saleReversal ||
                (m.kind == CashMovementKind.creditGranted && m.amount < 0)),
      );
      if (already) continue;
      final now = DateTime.now();
      final reversals = [
        for (final m in originals)
          CashMovement(
            at: now,
            kind: m.kind == CashMovementKind.creditGranted
                ? CashMovementKind.creditGranted
                : CashMovementKind.saleReversal,
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
      done = true;
      if (updated.isOpen) {
        if (current.value?.localId == updated.localId) current.value = updated;
      } else {
        final rates = await _ratesFor(updated.expected?.keys.toSet() ?? const {});
        await _envoyer(
          s.localId,
          CashPendingWrite(
            kind: 'correction',
            endpoint: 'cash-sessions/${s.localId}/corrections',
            body: {
              'expected': updated.expected,
              'summary': updated.summaryJson(),
              'note': reversals.first.label,
              if (rates.isNotEmpty) 'exchangeRates': rates,
            },
          ),
        );
      }
    }
    return done;
  }

  /// Rattache un mouvement à la caisse ouverte DE L'UTILISATEUR CONNECTÉ.
  /// Sans caisse ouverte, ne fait rien et renvoie false (l'écran de vente
  /// invite alors à l'ouvrir).
  Future<bool> recordMovement(CashMovement movement) async {
    await load();
    final s = current.value;
    if (s == null || movement.amount == 0 || !_isMine(s)) return false;
    final updated = await _update(s.localId, (x) => x.copyWith(movements: [...x.movements, movement]));
    return updated != null;
  }

  /// Entrée ou sortie manuelle d'espèces, avec son motif.
  ///
  /// Comptabilisée par le serveur (`POST cash-sessions/:id/movements`,
  /// idempotent par localId), jointe à la clôture et écrite au journal.
  Future<void> addManual({
    required bool entry,
    required double amount,
    required String currency,
    required String reason,
    double? exchangeRate,
  }) async {
    if (amount <= 0) throw ArgumentError('Montant invalide');
    if (reason.trim().isEmpty) throw ArgumentError('Motif obligatoire');
    await load();
    final s = current.value;
    if (s == null) throw StateError('Aucune caisse ouverte');
    final code = currency.toUpperCase();
    final value = cashRound(amount);
    final rate = code == 'CDF' ? null : (exchangeRate != null && exchangeRate > 1 ? exchangeRate : await _rate(code));
    final movement = CashMovement(
      at: DateTime.now(),
      kind: entry ? CashMovementKind.manualIn : CashMovementKind.manualOut,
      method: 'cash',
      currency: code,
      amount: entry ? value : -value,
      label: reason.trim(),
      ref: _uuid.v4(),
      rate: rate != null && rate > 1 ? rate : null,
    );
    await recordMovement(movement);
    // Comptabilisé par le serveur (caisse contre entrée ou sortie, motif),
    // idempotent par localId ; hors connexion, rejoué ou joint à la clôture.
    await _envoyer(
      s.localId,
      CashPendingWrite(
        kind: 'movement',
        endpoint: 'cash-sessions/${s.localId}/movements',
        body: manualMovementBody(movement),
        ref: movement.ref,
      ),
    );
    await _journal(_cashEntry(
      at: movement.at,
      description: '${entry ? 'Entrée de caisse' : 'Sortie de caisse'} : ${movement.label}',
      currency: code,
      amount: movement.amount,
      ref: movement.ref!,
    ));
  }

  /// Dépôt des espèces en banque : sortie de caisse COMPTABILISÉE. Le serveur
  /// passe le virement interne caisse vers banque par la voie comptable de la
  /// gestion. [accountId] est un compte bancaire de l'entreprise (Réglages,
  /// comptes financiers). Hors CDF, [exchangeRate] (1 devise = x CDF) est
  /// exigé : jamais de taux 1 par défaut.
  ///
  /// Hors connexion ou serveur en panne, le dépôt est enregistré et l'envoi
  /// reste en attente avec le MÊME localId (rejoué au retour du réseau). Un
  /// refus immédiat du serveur lève [CashDepositRefused] et rien n'est
  /// enregistré ; un refus au REJEU marque le dépôt « non comptabilisé ».
  Future<CashMovement> addBankDeposit({
    required double amount,
    required String currency,
    required String accountId,
    required String accountName,
    double? exchangeRate,
    String? slipNumber,
    DateTime? at,
  }) async {
    await load();
    final s = current.value;
    if (s == null) throw StateError('Aucune caisse ouverte');
    if (amount <= 0) throw ArgumentError('Montant invalide');
    if (accountId.trim().isEmpty) throw ArgumentError('Choisissez le compte bancaire');
    final code = currency.toUpperCase();
    if (code != 'CDF' && (exchangeRate == null || exchangeRate <= 1)) {
      throw ArgumentError('Taux $code non défini : renseignez-le dans les paramètres de devise.');
    }
    final slip = slipNumber?.trim();
    final localId = _uuid.v4();
    final when = at ?? DateTime.now();
    final value = cashRound(amount);
    final body = {
      'localId': localId,
      'sessionLocalId': s.localId,
      'financialAccountId': accountId,
      'amount': value,
      'currency': code,
      if (code != 'CDF') 'exchangeRate': exchangeRate,
      if (slip != null && slip.isNotEmpty) 'slipNumber': slip,
      'depositedAt': when.toUtc().toIso8601String(),
    };
    String? deferred;
    try {
      await _sendDeposit(body);
    } on CashSyncDeferred catch (e) {
      deferred = e.message;
    }
    final movement = CashMovement(
      at: when,
      kind: CashMovementKind.bankDeposit,
      method: 'cash',
      currency: code,
      amount: -value,
      label: 'Dépôt en banque $accountName${slip != null && slip.isNotEmpty ? ' (bordereau $slip)' : ''}',
      ref: localId,
    );
    await recordMovement(movement);
    if (deferred != null) {
      await _enqueue(
        s.localId,
        CashPendingWrite(
          kind: 'deposit',
          endpoint: 'cash-sessions/bank-deposits',
          body: body,
          ref: localId,
          attempts: 1,
          lastError: deferred,
        ),
      );
    }
    await _journal(_cashEntry(
      at: when,
      description: movement.label,
      currency: code,
      amount: movement.amount,
      ref: localId,
    ));
    return movement;
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
    // Mouvements manuels : joints à la clôture (idempotents par localId),
    // leurs envois isolés en attente deviennent inutiles.
    final manual = [
      for (final m in closed.movements)
        if ((m.kind == CashMovementKind.manualIn || m.kind == CashMovementKind.manualOut) && m.ref != null)
          manualMovementBody(m),
    ];
    final rates = await _ratesFor({...expected.keys, ...countedClean.keys});
    await _persist(closed.copyWith(
      pendingSync: closed.pendingSync.where((p) => p.kind != 'movement').toList(),
    ));
    current.value = null;
    try {
      await _envoyer(
        s.localId,
        CashPendingWrite(
          kind: 'close',
          endpoint: 'cash-sessions/${s.localId}/close',
          body: {
            'closedAt': closed.closedAt!.toUtc().toIso8601String(),
            'expected': expected,
            'counted': countedClean,
            if (closed.differenceReason != null) 'differenceReason': closed.differenceReason,
            'summary': closed.summaryJson(),
            // L'ouverture voyage avec la clôture : si elle n'est jamais
            // arrivée, le serveur la crée au passage.
            'open': _openPayload(s),
            if (rates.isNotEmpty) 'exchangeRates': rates,
            if (manual.isNotEmpty) 'manualMovements': manual,
          },
        ),
      );
    } on CashSessionConflict {
      // Clôture locale acquise ; le conflit serveur est signalé par
      // [serverConflict] sur l'écran Caisse.
    }
    return _find(s.localId) ?? closed;
  }
}
