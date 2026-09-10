/// Modèles partagés du règlement en plusieurs tranches (créances clients et
/// dettes fournisseurs).
///
/// Le backend expose deux endpoints symétriques :
///   POST sales/:id/payments    { amount, currencyCode?, exchangeRate?, method, reference?, paidAt? }
///   GET  sales/:id/payments    -> liste des tranches
///   POST expenses/:id/payments (même contrat)
///   GET  expenses/:id/payments -> liste des tranches
///
/// [PaymentDraft] porte la saisie utilisateur (dialogue de règlement) et
/// [OperationPayment] une tranche déjà enregistrée côté serveur.
library;

/// Modes de règlement proposés dans le dialogue « Enregistrer un paiement ».
///
/// Les libellés sont ceux déjà persistés par les écrans de vente et de dépense
/// (champ texte libre `paymentMethod` côté backend), ce qui garantit la
/// cohérence des journaux et des rapports.
const List<String> kPaymentMethodOptions = <String>[
  'Espèces',
  'Mobile Money',
  'Carte bancaire',
  'Virement bancaire',
  'Chèque',
];

/// Saisie d'une tranche de règlement, telle que renvoyée par le dialogue.
class PaymentDraft {
  /// Montant de la tranche, exprimé dans la devise de l'opération.
  final double amount;

  /// Devise de l'opération (CDF, USD...). Sert d'ancrage au backend.
  final String currencyCode;

  /// Taux de change vers le CDF au moment de l'opération (null si CDF).
  final double? exchangeRate;

  /// Mode de règlement (Espèces, Mobile Money...).
  final String method;

  /// Date de l'encaissement / décaissement.
  final DateTime paidAt;

  /// Référence libre (numéro de bordereau, transaction mobile money...).
  final String? reference;

  const PaymentDraft({
    required this.amount,
    required this.currencyCode,
    required this.method,
    required this.paidAt,
    this.exchangeRate,
    this.reference,
  });

  /// Montant de la tranche converti en CDF (devise d'ancrage comptable).
  double get amountInCdf {
    if (currencyCode == 'CDF') return amount;
    final rate = exchangeRate;
    if (rate == null || rate <= 0) return amount;
    return amount * rate;
  }

  /// Corps de requête attendu par `POST .../payments`.
  Map<String, dynamic> toRequestBody() => <String, dynamic>{
    'amount': amount,
    'currencyCode': currencyCode,
    if (exchangeRate != null && exchangeRate! > 0) 'exchangeRate': exchangeRate,
    'method': method,
    'paidAt': paidAt.toIso8601String(),
    if (reference != null && reference!.trim().isNotEmpty)
      'reference': reference!.trim(),
  };
}

/// Une tranche de règlement enregistrée (historique).
class OperationPayment {
  final String id;
  final double amount;
  final String currencyCode;
  final double? amountInCdf;
  final String? method;
  final String? reference;
  final DateTime? paidAt;

  /// Tranche de reprise : cumul historique matérialisé par le serveur, pas un
  /// encaissement du jour.
  final bool isOpening;

  const OperationPayment({
    required this.id,
    required this.amount,
    required this.currencyCode,
    this.amountInCdf,
    this.method,
    this.reference,
    this.paidAt,
    this.isOpening = false,
  });

  /// Lecture tolérante : le backend peut nommer les champs de plusieurs façons
  /// (`amount` / `amountInCdf`, `method` / `paymentMethod`, `paidAt` / `date`).
  /// On ne veut jamais faire échouer l'affichage de l'historique sur un alias.
  factory OperationPayment.fromJson(Map<String, dynamic> json) {
    double? readDouble(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    DateTime? readDate(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.isNotEmpty) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    String? readString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.isNotEmpty) return value;
      }
      return null;
    }

    final amount =
        readDouble('amount') ??
        readDouble('amountInTransactionCurrency') ??
        readDouble('amountCdf') ??
        readDouble('amountInCdf') ??
        0.0;

    return OperationPayment(
      id: readString(['id', 'paymentId', '_id']) ?? '',
      amount: amount,
      currencyCode: readString(['currencyCode', 'currency']) ?? 'CDF',
      amountInCdf: readDouble('amountCdf') ?? readDouble('amountInCdf'),
      method: readString(['method', 'paymentMethod', 'mode']),
      reference: readString(['reference', 'paymentReference', 'ref']),
      paidAt: readDate(['paidAt', 'date', 'paymentDate', 'createdAt']),
      isOpening: json['isOpening'] == true,
    );
  }

  /// Déballe une réponse `GET .../payments` quelle que soit son enveloppe :
  /// liste directe, `{data: [...]}`, double enveloppe `{data: {data: [...]}}`
  /// ou `{payments: [...]}`.
  static List<OperationPayment> listFrom(dynamic response) {
    dynamic payload = response;
    var depth = 0;
    while (payload is Map<String, dynamic> && depth < 3) {
      final next =
          payload['data'] ?? payload['payments'] ?? payload['items'];
      if (next == null) break;
      payload = next;
      depth++;
    }
    if (payload is! List) return const <OperationPayment>[];
    final payments = <OperationPayment>[];
    for (final entry in payload) {
      if (entry is Map<String, dynamic>) {
        payments.add(OperationPayment.fromJson(entry));
      }
    }
    payments.sort((a, b) {
      final left = a.paidAt;
      final right = b.paidAt;
      if (left == null || right == null) return 0;
      return left.compareTo(right);
    });
    return payments;
  }
}
