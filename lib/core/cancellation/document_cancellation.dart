import 'package:intl/intl.dart';

import '../exceptions/api_exceptions.dart';

/// Annulation d'une pièce (vente, dépense) : une pièce n'est jamais effacée.
///
/// Elle passe au statut annulé, garde qui l'a annulée, quand et pourquoi, et
/// peut être rétablie. Le serveur (gestion) contre-passe le stock, les
/// règlements et l'écriture comptable ; l'app ne fait que refléter l'état.

/// Pièces annulables.
enum CancellableDocument { sale, expense }

extension CancellableDocumentX on CancellableDocument {
  /// Segment d'URL du serveur (`sales/:id/cancel`, `expenses/:id/cancel`).
  String get endpoint => this == CancellableDocument.sale ? 'sales' : 'expenses';

  /// Nom affiché (« la vente », « la dépense »).
  String get label => this == CancellableDocument.sale ? 'vente' : 'dépense';
}

/// Rôles qui annulent une pièce, comme le serveur : administrateur
/// (propriétaire compris), gérant, comptable.
const kCancelDocumentRoles = {
  'admin', 'superadmin', 'super_admin', 'sme_admin', 'sme_owner', 'owner',
  'manager',
  'accountant', 'avec_treasurer',
};

/// Rôles qui rétablissent une pièce annulée : administrateur et comptable.
const kRestoreDocumentRoles = {
  'admin', 'superadmin', 'super_admin', 'sme_admin', 'sme_owner', 'owner',
  'accountant', 'avec_treasurer',
};

String _norm(String? role) => (role ?? '').trim().toLowerCase();

/// Le rôle peut-il annuler une vente ou une dépense ?
bool canCancelDocument(String? role) => kCancelDocumentRoles.contains(_norm(role));

/// Le rôle peut-il rétablir une pièce annulée ?
bool canRestoreDocument(String? role) => kRestoreDocumentRoles.contains(_norm(role));

/// Le rôle peut-il lire le journal d'audit (« Historique ») ? Comme le
/// serveur (`GET audit-events`) : administrateur et comptable.
bool canViewAuditHistory(String? role) => canRestoreDocument(role);

/// Motif minimal exigé par le serveur.
const int kMinCancelReasonLength = 3;

/// Choix rapides du motif d'annulation d'une vente.
const kSaleCancelPresets = [
  'Doublon',
  'Erreur de saisie',
  'Client a renoncé',
  'Autre',
];

/// Choix rapides du motif d'annulation d'une dépense.
const kExpenseCancelPresets = [
  'Doublon',
  'Erreur de saisie',
  'Dépense non engagée',
  'Autre',
];

/// Choix « Autre » : le texte libre devient alors obligatoire.
const kOtherCancelPreset = 'Autre';

/// Motif final : le choix rapide, complété du texte libre s'il y en a un.
/// « Autre » seul ne suffit pas : c'est le texte qui fait le motif.
String composeCancelReason(String? preset, String details) {
  final d = details.trim();
  final p = (preset ?? '').trim();
  if (p.isEmpty || p == kOtherCancelPreset) return d;
  return d.isEmpty ? p : '$p : $d';
}

/// Message d'erreur du motif, ou null s'il est valable.
String? validateCancelReason(String? reason) {
  final r = (reason ?? '').trim();
  if (r.isEmpty) return 'Indiquez le motif de l\'annulation.';
  if (r.length < kMinCancelReasonLength) {
    return 'Le motif doit compter au moins $kMinCancelReasonLength caractères.';
  }
  return null;
}

/// Texte d'explication affiché avant de confirmer l'annulation.
String cancelExplanation(CancellableDocument doc) {
  if (doc == CancellableDocument.sale) {
    return 'La vente est conservée avec le statut annulée et pourra être '
        'rétablie. Le stock et les règlements sont rétablis, et la '
        'comptabilité en est informée.';
  }
  return 'La dépense est conservée avec le statut annulée et pourra être '
      'rétablie. Les règlements sont rétablis, et la comptabilité en est '
      'informée.';
}

/// Qui a annulé, quand et pourquoi.
class CancellationInfo {
  final DateTime? at;
  final String? byId;
  final String? byName;
  final String? reason;

  const CancellationInfo({this.at, this.byId, this.byName, this.reason});

  bool get isEmpty => at == null && byName == null && reason == null;

  /// Lit les champs du serveur : `cancelledAt`, `cancelledBy` (`{ id, email,
  /// name }` ou simple texte), `cancelReason` (ou `cancellationReason`).
  static CancellationInfo fromJson(Map<String, dynamic> json) {
    DateTime? at;
    final rawAt = json['cancelledAt'];
    if (rawAt is String) {
      final parsed = DateTime.tryParse(rawAt);
      at = parsed == null ? null : (parsed.isUtc ? parsed.toLocal() : parsed);
    }
    String? byId;
    String? byName;
    final by = json['cancelledBy'];
    if (by is Map) {
      byId = _text(by['id']);
      byName = _text(by['name']) ?? _text(by['email']);
    } else if (by is String) {
      byName = _text(by);
    }
    final reason =
        _text(json['cancelReason']) ?? _text(json['cancellationReason']);
    return CancellationInfo(at: at, byId: byId, byName: byName, reason: reason);
  }

  static String? _text(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}

/// Bandeau de la fiche : « Annulée le 12/10/2026 à 14:05 par Marie : Doublon ».
String cancellationBanner(CancellationInfo info) {
  final buffer = StringBuffer('Annulée');
  if (info.at != null) {
    buffer.write(' le ${DateFormat('dd/MM/yyyy à HH:mm').format(info.at!)}');
  }
  if (info.byName != null) buffer.write(' par ${info.byName}');
  if (info.reason != null) buffer.write(' : ${info.reason}');
  return buffer.toString();
}

/// Lit `possibleDuplicateOf` dans une réponse de création (à la racine ou
/// dans `data`).
String? possibleDuplicateIn(Object? response) {
  if (response is! Map) return null;
  final direct = response['possibleDuplicateOf'];
  if (direct is String && direct.trim().isNotEmpty) return direct.trim();
  final data = response['data'];
  if (data is Map) {
    final nested = data['possibleDuplicateOf'];
    if (nested is String && nested.trim().isNotEmpty) return nested.trim();
  }
  return null;
}

/// Le serveur a-t-il REFUSÉ l'action (droits, motif, état) ? Une coupure,
/// un délai, une session expirée ou une panne serveur ne sont pas des refus :
/// l'action reste en file et repart plus tard.
bool isServerRefusal(Object error) {
  if (error is OfflineQueuedException || error is NetworkException) return false;
  if (error is AuthenticationException) return false;
  if (error is ApiException) {
    final code = error.statusCode;
    if (code == null) return false;
    if (code == 401 || code == 408 || code == 429) return false;
    return code >= 400 && code < 500;
  }
  return false;
}

/// Route absente sur un serveur pas encore à jour (`Cannot POST ...`).
bool isMissingRoute(Object error) {
  if (error is! ApiException) return false;
  final code = error.statusCode;
  if (code != 404 && code != 405) return false;
  final text = '${error.message} ${error.responseBody}'.toLowerCase();
  return code == 405 || text.contains('cannot post');
}

/// Message lisible d'un refus du serveur.
String refusalMessage(Object error, {required String fallback}) {
  if (error is ApiException) {
    if (error.statusCode == 403) {
      return 'Vous n\'avez pas le droit de faire cette action.';
    }
    final m = error.message.trim();
    if (m.isNotEmpty) return m;
  }
  return fallback;
}

/// Résultat d'une annulation ou d'un rétablissement.
class CancellationOutcome<T> {
  /// Pièce à jour (version serveur si envoyée, sinon version locale).
  final T document;

  /// Vrai si le serveur a confirmé ; faux si l'action attend en file.
  final bool synced;

  final String message;

  const CancellationOutcome({
    required this.document,
    required this.synced,
    required this.message,
  });
}
