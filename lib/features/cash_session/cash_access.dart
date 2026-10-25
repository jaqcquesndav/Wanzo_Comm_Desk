import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/enums/business_unit_enums.dart';
import '../../core/services/business_context_service.dart';
import '../auth/bloc/auth_bloc.dart';
import '../dashboard/models/journal_filter.dart' show JournalView;

/// Valeurs de rôle (API ou jeton) qui voient la caisse, ramenées comme le
/// serveur (gestion, `mapExternalRole` puis `CASH_ACCESS_ROLES`) :
/// administrateur (owner, sme_owner, sme_admin, super_admin), comptable
/// (avec_treasurer) et caissier. Tous les autres, manager compris, reçoivent
/// 403 CASH_ACCESS_DENIED : la caisse leur est masquée partout.
const kCashSessionRoles = {
  'admin', 'superadmin', 'super_admin', 'sme_admin', 'sme_owner', 'owner',
  'accountant', 'avec_treasurer',
  'cashier',
};

/// Rôles qui voient la caisse : administrateur (propriétaire), comptable et
/// caissier. Tous les autres ne la voient nulle part (masquée, pas grisée).
bool canAccessCashSession(String? role) =>
    kCashSessionRoles.contains((role ?? '').trim().toLowerCase());

/// Rôle de l'utilisateur connecté : session d'authentification, sinon le
/// contexte gardé sur l'appareil (démarrage hors ligne).
String? currentUserRole([BuildContext? context]) {
  if (context != null) {
    try {
      final s = context.read<AuthBloc>().state;
      if (s is AuthAuthenticated) return s.user.role;
    } catch (_) {}
  }
  try {
    return BusinessContextService().userRole;
  } catch (_) {
    return null;
  }
}

/// La caisse est-elle visible pour l'utilisateur connecté ?
bool canSeeCash([BuildContext? context]) => canAccessCashSession(currentUserRole(context));

/// Périmètre d'unité de la caisse, comme le serveur (403
/// CASH_SESSION_OTHER_UNIT) : un utilisateur rattaché à une unité qui n'est
/// pas l'entreprise générale (unité racine COMPANY) ne voit et n'ouvre que
/// les sessions de SON unité, sans choix d'une autre. À la racine (aucune
/// unité, unité = entreprise, ou unité de type COMPANY), il voit toutes les
/// unités, avec un filtre.
@immutable
class CashUnitScope {
  /// Unité imposée (null : toutes les unités, filtre libre).
  final String? lockedUnitId;
  const CashUnitScope([this.lockedUnitId]);

  bool get isLocked => lockedUnitId != null;

  /// La session d'unité [unitId] est-elle visible dans ce périmètre ?
  bool allows(String? unitId) => !isLocked || unitId == lockedUnitId;
}

CashUnitScope cashUnitScopeFor({
  required String? role,
  required String? businessUnitId,
  String? companyId,
  BusinessUnitType? unitType,
}) {
  final unit = (businessUnitId ?? '').trim();
  final atRoot = unit.isEmpty || unit == companyId || unitType == BusinessUnitType.company;
  return atRoot ? const CashUnitScope() : CashUnitScope(unit);
}

/// Périmètre de l'utilisateur connecté.
CashUnitScope currentCashUnitScope([BuildContext? context]) {
  try {
    final c = BusinessContextService();
    return cashUnitScopeFor(
      role: currentUserRole(context),
      businessUnitId: c.businessUnitId,
      companyId: c.companyId,
      unitType: c.businessUnitType,
    );
  } catch (_) {
    return const CashUnitScope();
  }
}

/// Vues du journal proposées : la vue Caisse est masquée aux rôles qui ne
/// tiennent pas la caisse.
List<JournalView> visibleJournalViews(bool cashVisible) => [
  for (final v in JournalView.values)
    if (cashVisible || v != JournalView.cash) v,
];

