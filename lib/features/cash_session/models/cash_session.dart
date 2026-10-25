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

  /// Sortie manuelle (retrait), simple trace.
  manualOut,

  /// Contre-passation d'une vente annulée ou supprimée.
  saleReversal,

  /// Dépôt des espèces en banque : sortie de caisse COMPTABILISÉE (virement
  /// interne caisse vers banque envoyé au serveur, `cash-sessions/bank-deposits`).
  bankDeposit,

  /// Crédit accordé : part d'une vente NON encaissée (vente à crédit, reste
  /// à payer). Simple information du rapport : n'entre JAMAIS dans les
  /// espèces attendues.
  creditGranted,
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
      case CashMovementKind.bankDeposit:
        return 'Dépôt en banque';
      case CashMovementKind.creditGranted:
        return 'Crédit accordé';
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

  /// Motif d'un refus du serveur au rejeu (dépôt en banque « non
  /// comptabilisé »). Null quand rien n'est à signaler.
  final String? syncIssue;

  /// Taux du jour retenu à la saisie (1 devise = n CDF), hors CDF.
  final double? rate;

  const CashMovement({
    required this.at,
    required this.kind,
    required this.currency,
    required this.amount,
    required this.label,
    this.method,
    this.ref,
    this.syncIssue,
    this.rate,
  });

  /// Mouvement d'ESPÈCES (seuls ceux-là entrent dans le tiroir). Le crédit
  /// accordé n'y entre jamais : rien n'a été encaissé.
  bool get isCash =>
      kind != CashMovementKind.creditGranted &&
      (kind == CashMovementKind.manualIn ||
          kind == CashMovementKind.manualOut ||
          kind == CashMovementKind.bankDeposit ||
          cashMethodGroupOf(method) == CashMethodGroup.cash);

  /// Dépôt en banque refusé par le serveur : la sortie physique reste, mais
  /// elle n'est pas passée en comptabilité.
  bool get isNotPosted => kind == CashMovementKind.bankDeposit && syncIssue != null;

  CashMovement copyWith({String? syncIssue}) => CashMovement(
    at: at,
    kind: kind,
    method: method,
    currency: currency,
    amount: amount,
    label: label,
    ref: ref,
    syncIssue: syncIssue ?? this.syncIssue,
    rate: rate,
  );

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'kind': kind.name,
    if (method != null) 'method': method,
    'currency': currency,
    'amount': amount,
    'label': label,
    if (ref != null) 'ref': ref,
    if (syncIssue != null) 'syncIssue': syncIssue,
    if (rate != null) 'rate': rate,
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
    syncIssue: j['syncIssue'] as String?,
    rate: (j['rate'] as num?)?.toDouble(),
  );
}

/// Envoi au serveur en attente (5xx, délai dépassé, hors connexion) : rejoué
/// tel quel, dans l'ordre, au retour du réseau. Le corps garde ses
/// identifiants (même `localId` pour un dépôt rejoué).
@immutable
class CashPendingWrite {
  /// open | close | correction | deposit | movement
  final String kind;
  final String endpoint;
  final Map<String, dynamic> body;

  /// Référence du mouvement concerné (dépôt : son localId).
  final String? ref;
  final int attempts;
  final String? lastError;

  const CashPendingWrite({
    required this.kind,
    required this.endpoint,
    required this.body,
    this.ref,
    this.attempts = 0,
    this.lastError,
  });

  CashPendingWrite retried(String error) => CashPendingWrite(
    kind: kind,
    endpoint: endpoint,
    body: body,
    ref: ref,
    attempts: attempts + 1,
    lastError: error,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'endpoint': endpoint,
    'body': body,
    if (ref != null) 'ref': ref,
    'attempts': attempts,
    if (lastError != null) 'lastError': lastError,
  };

  factory CashPendingWrite.fromJson(Map<String, dynamic> j) => CashPendingWrite(
    kind: (j['kind'] as String?) ?? 'open',
    endpoint: j['endpoint'] as String,
    body: Map<String, dynamic>.from(j['body'] as Map),
    ref: j['ref'] as String?,
    attempts: (j['attempts'] as num?)?.toInt() ?? 0,
    lastError: j['lastError'] as String?,
  );
}

Map<String, double> _amounts(dynamic raw) {
  if (raw is! Map) return {};
  final out = <String, double>{};
  raw.forEach((k, v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v');
    if (n != null) out[k.toString()] = n;
  });
  return out;
}

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// Session de caisse tenue sur l'appareil (hors ligne d'abord), envoyée au
/// serveur (`cash-sessions`).
///
/// Une session appartient à UNE entreprise, UNE unité et UN utilisateur : sur
/// un poste partagé, la caisse de A ne reçoit jamais les ventes de B.
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

  /// Propriétaire de la session (entreprise, unité, caissier).
  final String? companyId;
  final String? businessUnitId;
  final String? userId;

  /// Envois au serveur pas encore aboutis, dans l'ordre.
  final List<CashPendingWrite> pendingSync;

  /// Clôture déjà enregistrée sur le serveur par quelqu'un d'autre (ou avec
  /// un autre comptage) : ce que le serveur a retenu.
  final Map<String, dynamic>? serverClosure;

  /// Résumé de la journée tel que le serveur le garde (sessions relues du
  /// serveur, sans détail des mouvements sur cet appareil).
  final Map<String, dynamic>? summary;

  /// Session connue seulement par le serveur (historique relu).
  final bool fromServer;

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
    this.companyId,
    this.businessUnitId,
    this.userId,
    this.pendingSync = const [],
    this.serverClosure,
    this.summary,
    this.fromServer = false,
  });

  bool get isOpen => status == 'open';

  /// Vrai si un envoi au serveur attend le retour du réseau.
  bool get hasPendingSync => pendingSync.isNotEmpty;

  /// Session sans propriétaire (enregistrée avant l'isolation par
  /// utilisateur).
  bool get isLegacy => companyId == null && userId == null && businessUnitId == null;

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
    if (movements.isEmpty && summary != null) return _summaryReceipts();
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

  Map<CashMethodGroup, Map<String, double>> _summaryReceipts() {
    final raw = summary?['receiptsByMethod'];
    if (raw is! Map) return {};
    final out = <CashMethodGroup, Map<String, double>>{};
    raw.forEach((k, v) {
      final g = CashMethodGroup.values.where((x) => x.name == k.toString()).firstOrNull;
      if (g == null) return;
      final amounts = _amounts(v);
      if (amounts.isNotEmpty) out[g] = amounts;
    });
    return out;
  }

  static const _summaryKeys = {
    CashMovementKind.expense: 'expensesCash',
    CashMovementKind.manualIn: 'manualIn',
    CashMovementKind.manualOut: 'manualOut',
    CashMovementKind.bankDeposit: 'bankDeposits',
    CashMovementKind.creditGranted: 'creditGranted',
  };

  /// Somme signée des mouvements d'une nature, par devise.
  Map<String, double> totalOf(CashMovementKind kind, {bool cashOnly = false}) {
    if (movements.isEmpty && summary != null) {
      final key = _summaryKeys[kind];
      return key == null ? {} : _amounts(summary![key]);
    }
    final out = <String, double>{};
    for (final m in movements) {
      if (m.kind != kind) continue;
      if (cashOnly && !m.isCash) continue;
      out[m.currency] = cashRound((out[m.currency] ?? 0) + m.amount);
    }
    return out;
  }

  /// Crédit accordé (ventes non encaissées), par devise, annulations
  /// déduites ; les devises à zéro sont omises.
  Map<String, double> creditGranted() {
    final all = totalOf(CashMovementKind.creditGranted);
    return {
      for (final e in all.entries)
        if (e.value.abs() >= 0.01) e.key: e.value,
    };
  }

  /// Dépôts en banque refusés par le serveur (non comptabilisés).
  List<CashMovement> get notPostedDeposits => movements.where((m) => m.isNotPosted).toList();

  /// Ventes de la session, ventes annulées déduites. Une vente à crédit
  /// sans encaissement compte aussi.
  int get salesCount {
    if (movements.isEmpty && summary != null) {
      final n = summary!['salesCount'];
      return n is num ? n.toInt() : 0;
    }
    final saleRefs = movements
        .where((m) => m.kind == CashMovementKind.sale && m.ref != null)
        .map((m) => m.ref)
        .toSet();
    final sales = movements.where((m) => m.kind == CashMovementKind.sale).length;
    final creditOnly = movements
        .where(
          (m) =>
              m.kind == CashMovementKind.creditGranted &&
              m.amount > 0 &&
              !saleRefs.contains(m.ref),
        )
        .length;
    final reversed = movements
        .where(
          (m) =>
              m.kind == CashMovementKind.saleReversal ||
              (m.kind == CashMovementKind.creditGranted && m.amount < 0),
        )
        .map((m) => m.ref)
        .toSet()
        .length;
    return sales + creditOnly - reversed;
  }

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
    'bankDeposits': totalOf(CashMovementKind.bankDeposit),
    'creditGranted': creditGranted(),
    if (notPostedDeposits.isNotEmpty)
      'bankDepositsNotPosted': {
        for (final m in notPostedDeposits) m.ref ?? m.label: {'currency': m.currency, 'amount': m.amount},
      },
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
    String? companyId,
    String? businessUnitId,
    String? userId,
    List<CashPendingWrite>? pendingSync,
    Map<String, dynamic>? serverClosure,
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
    companyId: companyId ?? this.companyId,
    businessUnitId: businessUnitId ?? this.businessUnitId,
    userId: userId ?? this.userId,
    pendingSync: pendingSync ?? this.pendingSync,
    serverClosure: serverClosure ?? this.serverClosure,
    summary: summary,
    fromServer: fromServer,
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
    if (companyId != null) 'companyId': companyId,
    if (businessUnitId != null) 'businessUnitId': businessUnitId,
    if (userId != null) 'userId': userId,
    if (pendingSync.isNotEmpty) 'pendingSync': pendingSync.map((p) => p.toJson()).toList(),
    if (serverClosure != null) 'serverClosure': serverClosure,
    if (summary != null) 'summary': summary,
    if (fromServer) 'fromServer': true,
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
    companyId: j['companyId'] as String?,
    businessUnitId: j['businessUnitId'] as String?,
    userId: j['userId'] as String?,
    pendingSync: [
      for (final p in (j['pendingSync'] as List? ?? const []))
        CashPendingWrite.fromJson(Map<String, dynamic>.from(p as Map)),
    ],
    serverClosure: j['serverClosure'] is Map ? Map<String, dynamic>.from(j['serverClosure'] as Map) : null,
    summary: j['summary'] is Map ? Map<String, dynamic>.from(j['summary'] as Map) : null,
    fromServer: j['fromServer'] == true,
  );

  /// Session telle que le serveur la renvoie (`GET cash-sessions`) : sans
  /// détail des mouvements, avec son résumé.
  factory CashSession.fromServer(Map<String, dynamic> j) => CashSession(
    localId: (j['localId'] ?? j['id']).toString(),
    status: (j['status'] as String?) ?? 'closed',
    openedAt: _date(j['openedAt']) ?? DateTime.now(),
    openedByName: j['openedByName'] as String?,
    registerLabel: j['registerLabel'] as String?,
    openingFloat: _amounts(j['openingFloat']),
    closedAt: _date(j['closedAt']),
    closedByName: j['closedByName'] as String?,
    expected: j['expected'] == null ? null : _amounts(j['expected']),
    counted: j['counted'] == null ? null : _amounts(j['counted']),
    difference: j['difference'] == null ? null : _amounts(j['difference']),
    differenceReason: j['differenceReason'] as String?,
    companyId: j['companyId']?.toString(),
    businessUnitId: j['businessUnitId']?.toString(),
    userId: j['openedBy']?.toString(),
    summary: j['summary'] is Map ? Map<String, dynamic>.from(j['summary'] as Map) : const {},
    fromServer: true,
  );
}
