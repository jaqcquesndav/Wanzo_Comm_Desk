import 'package:flutter/foundation.dart';

import '../../dashboard/models/journal_filter.dart' show isCashPaymentMethod;

/// Arrondi monétaire (2 décimales).
double cashRound(double v) => (v * 100).roundToDouble() / 100;

/// Nature d'un mouvement rattaché à une session de caisse.
enum CashMovementKind {
  /// Vente (montant payé à la vente).
  sale,

  /// Règlement d'une vente à crédit.
  customerPayment,

  /// Dépense ou règlement fournisseur payé.
  expense,

  /// Entrée manuelle (apport, fonds complémentaire).
  manualIn,

  /// Sortie manuelle (retrait, dépôt en banque).
  manualOut,

  /// Contre-passation d'une vente annulée ou supprimée.
  saleReversal,
}

extension CashMovementKindLabel on CashMovementKind {
  String get label {
    switch (this) {
      case CashMovementKind.sale:
        return 'Vente';
      case CashMovementKind.customerPayment:
        return 'Règlement client';
      case CashMovementKind.expense:
        return 'Dépense';
      case CashMovementKind.manualIn:
        return 'Entrée de caisse';
      case CashMovementKind.manualOut:
        return 'Sortie de caisse';
      case CashMovementKind.saleReversal:
        return 'Vente annulée';
    }
  }
}

/// Moyens de paiement regroupés pour le rapport de clôture.
enum CashMethodGroup { cash, mobileMoney, card, credit, other }

extension CashMethodGroupLabel on CashMethodGroup {
  String get label {
    switch (this) {
      case CashMethodGroup.cash:
        return 'Espèces';
      case CashMethodGroup.mobileMoney:
        return 'Mobile Money';
      case CashMethodGroup.card:
        return 'Carte';
      case CashMethodGroup.credit:
        return 'Crédit';
      case CashMethodGroup.other:
        return 'Autres (virement, chèque)';
    }
  }
}

CashMethodGroup cashMethodGroupOf(String? method) {
  if (isCashPaymentMethod(method)) return CashMethodGroup.cash;
  final m = method!.toLowerCase();
  if (m.contains('mobile') || m.contains('momo') || m.contains('m-pesa') || m.contains('airtel') || m.contains('orange')) {
    return CashMethodGroup.mobileMoney;
  }
  if (m.contains('carte') || m.contains('card') || m.contains('tpe')) return CashMethodGroup.card;
  if (m.contains('crédit') || m.contains('credit') || m.contains('échel') || m.contains('echel')) {
    return CashMethodGroup.credit;
  }
  return CashMethodGroup.other;
}

/// Un mouvement de la journée. [amount] est SIGNÉ (+ entrée, - sortie) et
/// exprimé dans [currency] (devise réellement remise ou payée).
@immutable
class CashMovement {
  final DateTime at;
  final CashMovementKind kind;
  final String? method;
  final String currency;
  final double amount;
  final String label;
  final String? ref;

  const CashMovement({
    required this.at,
    required this.kind,
    required this.currency,
    required this.amount,
    required this.label,
    this.method,
    this.ref,
  });

  /// Mouvement d'ESPÈCES (seuls ceux-là entrent dans le tiroir).
  bool get isCash =>
      kind == CashMovementKind.manualIn ||
      kind == CashMovementKind.manualOut ||
      cashMethodGroupOf(method) == CashMethodGroup.cash;

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'kind': kind.name,
    if (method != null) 'method': method,
    'currency': currency,
    'amount': amount,
    'label': label,
    if (ref != null) 'ref': ref,
  };

  factory CashMovement.fromJson(Map<String, dynamic> j) => CashMovement(
    at: DateTime.parse(j['at'] as String).toLocal(),
    kind: CashMovementKind.values.firstWhere(
      (k) => k.name == j['kind'],
      orElse: () => CashMovementKind.manualIn,
    ),
    method: j['method'] as String?,
    currency: (j['currency'] as String?) ?? 'CDF',
    amount: (j['amount'] as num).toDouble(),
    label: (j['label'] as String?) ?? '',
    ref: j['ref'] as String?,
  );
}

Map<String, double> _amounts(dynamic raw) {
  if (raw is! Map) return {};
  return raw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
}

/// Session de caisse tenue sur l'appareil (hors ligne d'abord), envoyée au
/// serveur par la file d'écritures (`cash-sessions`).
@immutable
class CashSession {
  final String localId;
  final String status; // open | closed
  final DateTime openedAt;
  final String? openedByName;
  final String? registerLabel;
  final Map<String, double> openingFloat;
  final List<CashMovement> movements;
  final DateTime? closedAt;
  final String? closedByName;
  final Map<String, double>? expected;
  final Map<String, double>? counted;
  final Map<String, double>? difference;
  final String? differenceReason;

  const CashSession({
    required this.localId,
    required this.status,
    required this.openedAt,
    required this.openingFloat,
    this.openedByName,
    this.registerLabel,
    this.movements = const [],
    this.closedAt,
    this.closedByName,
    this.expected,
    this.counted,
    this.difference,
    this.differenceReason,
  });

  bool get isOpen => status == 'open';

  /// Devises suivies : fonds, mouvements et comptage.
  Set<String> get currencies => {
    'CDF',
    ...openingFloat.keys,
    ...movements.map((m) => m.currency),
    ...?counted?.keys,
  };

  /// Espèces théoriques par devise : fonds + entrées - sorties d'espèces.
  Map<String, double> expectedCash() {
    final out = <String, double>{for (final c in currencies) c: 0};
    openingFloat.forEach((c, v) => out[c] = (out[c] ?? 0) + v);
    for (final m in movements) {
      if (!m.isCash) continue;
      out[m.currency] = (out[m.currency] ?? 0) + m.amount;
    }
    return out.map((k, v) => MapEntry(k, cashRound(v)));
  }

  /// Totaux encaissés (ventes et règlements) par moyen puis devise.
  Map<CashMethodGroup, Map<String, double>> receiptsByMethod() {
    final out = <CashMethodGroup, Map<String, double>>{};
    for (final m in movements) {
      if (m.kind != CashMovementKind.sale &&
          m.kind != CashMovementKind.customerPayment &&
          m.kind != CashMovementKind.saleReversal) {
        continue;
      }
      final g = cashMethodGroupOf(m.method);
      final byCur = out.putIfAbsent(g, () => {});
      byCur[m.currency] = cashRound((byCur[m.currency] ?? 0) + m.amount);
    }
    return out;
  }

  /// Somme signée des mouvements d'une nature, par devise.
  Map<String, double> totalOf(CashMovementKind kind, {bool cashOnly = false}) {
    final out = <String, double>{};
    for (final m in movements) {
      if (m.kind != kind) continue;
      if (cashOnly && !m.isCash) continue;
      out[m.currency] = cashRound((out[m.currency] ?? 0) + m.amount);
    }
    return out;
  }

  /// Ventes de la session, ventes annulées déduites.
  int get salesCount =>
      movements.where((m) => m.kind == CashMovementKind.sale).length -
      movements.where((m) => m.kind == CashMovementKind.saleReversal).map((m) => m.ref).toSet().length;

  /// Écart = compté - théorique, par devise.
  static Map<String, double> differenceOf(
    Map<String, double> expected,
    Map<String, double> counted,
  ) {
    final codes = {...expected.keys, ...counted.keys};
    return {
      for (final c in codes) c: cashRound((counted[c] ?? 0) - (expected[c] ?? 0)),
    };
  }

  static bool hasDifference(Map<String, double> diff) =>
      diff.values.any((v) => v.abs() >= 0.01);

  /// Résumé envoyé au serveur avec la clôture.
  Map<String, dynamic> summaryJson() => {
    'salesCount': salesCount,
    'receiptsByMethod': {
      for (final e in receiptsByMethod().entries) e.key.name: e.value,
    },
    'expensesCash': totalOf(CashMovementKind.expense, cashOnly: true),
    'manualIn': totalOf(CashMovementKind.manualIn),
    'manualOut': totalOf(CashMovementKind.manualOut),
    'movementsCount': movements.length,
  };

  CashSession copyWith({
    String? status,
    List<CashMovement>? movements,
    DateTime? closedAt,
    String? closedByName,
    Map<String, double>? expected,
    Map<String, double>? counted,
    Map<String, double>? difference,
    String? differenceReason,
  }) => CashSession(
    localId: localId,
    status: status ?? this.status,
    openedAt: openedAt,
    openedByName: openedByName,
    registerLabel: registerLabel,
    openingFloat: openingFloat,
    movements: movements ?? this.movements,
    closedAt: closedAt ?? this.closedAt,
    closedByName: closedByName ?? this.closedByName,
    expected: expected ?? this.expected,
    counted: counted ?? this.counted,
    difference: difference ?? this.difference,
    differenceReason: differenceReason ?? this.differenceReason,
  );

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'status': status,
    'openedAt': openedAt.toIso8601String(),
    if (openedByName != null) 'openedByName': openedByName,
    if (registerLabel != null) 'registerLabel': registerLabel,
    'openingFloat': openingFloat,
    'movements': movements.map((m) => m.toJson()).toList(),
    if (closedAt != null) 'closedAt': closedAt!.toIso8601String(),
    if (closedByName != null) 'closedByName': closedByName,
    if (expected != null) 'expected': expected,
    if (counted != null) 'counted': counted,
    if (difference != null) 'difference': difference,
    if (differenceReason != null) 'differenceReason': differenceReason,
  };

  factory CashSession.fromJson(Map<String, dynamic> j) => CashSession(
    localId: j['localId'] as String,
    status: (j['status'] as String?) ?? 'open',
    openedAt: DateTime.parse(j['openedAt'] as String).toLocal(),
    openedByName: j['openedByName'] as String?,
    registerLabel: j['registerLabel'] as String?,
    openingFloat: _amounts(j['openingFloat']),
    movements: [
      for (final m in (j['movements'] as List? ?? const []))
        CashMovement.fromJson(Map<String, dynamic>.from(m as Map)),
    ],
    closedAt: j['closedAt'] == null ? null : DateTime.parse(j['closedAt'] as String).toLocal(),
    closedByName: j['closedByName'] as String?,
    expected: j['expected'] == null ? null : _amounts(j['expected']),
    counted: j['counted'] == null ? null : _amounts(j['counted']),
    difference: j['difference'] == null ? null : _amounts(j['difference']),
    differenceReason: j['differenceReason'] as String?,
  );
}
