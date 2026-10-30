import 'package:flutter/widgets.dart';

import '../enums/user_role.dart';
import '../services/business_context_service.dart';

/// Droits de l'utilisateur connecté, lus en UN seul endroit : le contexte
/// métier ([BusinessContextService]), réécrit à chaque lecture de /auth/me
/// et gardé sur l'appareil. Le choix du mode, l'en-tête et les réglages
/// passent tous par ici (jamais l'état d'AuthBloc à un endroit et le
/// contexte à un autre).
enum AdminRightsStatus { admin, notAdmin, unknown }

class UserRights {
  UserRights._();

  /// Valeur API du rôle connu (null si aucun rôle n'est connu).
  static String? roleValue([BusinessContextService? ctx]) {
    final v = (ctx ?? BusinessContextService()).userRole;
    return UserRoleExtension.isKnownApiValue(v) ? v : null;
  }

  /// Rôle connu, null s'il ne l'est pas encore.
  static UserRole? role([BusinessContextService? ctx]) {
    final v = roleValue(ctx);
    return v == null ? null : UserRoleExtension.fromApiValue(v);
  }

  /// Administrateur si le rôle frais de /auth/me l'est, ou si le serveur le
  /// dit propriétaire de l'entreprise ; inconnu tant qu'aucun rôle n'est lu.
  static AdminRightsStatus adminStatus([BusinessContextService? ctx]) {
    final c = ctx ?? BusinessContextService();
    if (c.isCompanyOwner) return AdminRightsStatus.admin;
    final r = role(c);
    if (r == null) return AdminRightsStatus.unknown;
    return r.isAdmin ? AdminRightsStatus.admin : AdminRightsStatus.notAdmin;
  }

  static bool isAdmin([BusinessContextService? ctx]) =>
      adminStatus(ctx) == AdminRightsStatus.admin;
}

/// Rôle lu dans un claim du jeton : jamais « staff » ni « user » supposé
/// quand le claim est absent. Dernier rôle connu du serveur, sinon inconnu.
String roleFromTokenClaim(dynamic claim, {String? lastKnownServerRole}) {
  String? fromClaim;
  if (claim is List && claim.isNotEmpty && claim.first is String) {
    fromClaim = claim.first as String;
  } else if (claim is String) {
    fromClaim = claim;
  }
  if (UserRoleExtension.isKnownApiValue(fromClaim)) return fromClaim!;
  if (UserRoleExtension.isKnownApiValue(lastKnownServerRole)) {
    return lastKnownServerRole!;
  }
  return UserRoleExtension.unknownApiValue;
}

/// Relecture du rôle sans redémarrage : au retour au premier plan (au plus
/// une fois toutes les 5 minutes), quand un écran a besoin d'un rôle encore
/// inconnu, et après un refus 403 lié aux droits. Le lanceur (relecture de
/// /auth/me, mise à jour du cache) est branché au démarrage de l'app.
class RoleRefresh {
  RoleRefresh._();
  static final RoleRefresh instance = RoleRefresh._();

  static const Duration resumeInterval = Duration(minutes: 5);
  static const Duration forbiddenInterval = Duration(seconds: 30);

  /// Relit /auth/me et met à jour le cache (AuthBloc, Hive, contexte).
  Future<void> Function(String reason)? runner;

  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  DateTime? _lastRun;
  Future<void>? _inFlight;

  @visibleForTesting
  void reset() {
    _lastRun = null;
    _inFlight = null;
  }

  /// Relit tout de suite (partage une relecture en cours).
  Future<void> refreshNow(String reason) {
    final running = _inFlight;
    if (running != null) return running;
    final run = runner;
    if (run == null) return Future.value();
    _lastRun = clock();
    final future = run(reason).catchError((Object e) {
      debugPrint('RoleRefresh: relecture du rôle impossible ($reason) : $e');
    }).whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  /// Relit si la dernière relecture date d'au moins [interval].
  Future<void> refreshIfStale(String reason, {Duration interval = resumeInterval}) {
    final last = _lastRun;
    if (last != null && clock().difference(last) < interval) {
      return Future.value();
    }
    return refreshNow(reason);
  }

  /// Retour au premier plan.
  Future<void> onResumed() => refreshIfStale('premier plan');

  /// Refus 403 lié aux droits (le rôle a pu changer sur le serveur).
  Future<void> onRoleForbidden() =>
      refreshIfStale('refus 403', interval: forbiddenInterval);
}

/// Un 403 porte-t-il sur les DROITS (rôle) ? Les refus de compte suspendu,
/// d'abonnement ou de quota ont leurs propres écrans : ils n'appellent pas de
/// relecture du rôle.
bool isRoleForbidden(int? statusCode, dynamic body, {String? endpoint}) {
  if (statusCode != 403) return false;
  if ((endpoint ?? '').contains('auth/me')) return false;
  String code = '';
  if (body is Map) {
    final error = body['error'];
    code = '${body['code'] ?? (error is Map ? error['code'] : '') ?? ''}';
  }
  final upper = code.toUpperCase();
  const others = ['SUSPENDED', 'SUBSCRIPTION', 'PLAN', 'QUOTA', 'LIMIT', 'MACHINE', 'TOKEN', 'FEATURE'];
  return !others.any(upper.contains);
}

/// Retour au premier plan : relecture du rôle (au plus toutes les 5 min).
class RoleRefreshLifecycleObserver with WidgetsBindingObserver {
  RoleRefreshLifecycleObserver._();
  static final RoleRefreshLifecycleObserver instance = RoleRefreshLifecycleObserver._();
  bool _attached = false;

  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) RoleRefresh.instance.onResumed();
  }
}
