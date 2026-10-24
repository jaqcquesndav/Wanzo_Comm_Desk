/// Codes canoniques des moyens de paiement, partagés avec le backend gestion.
///
/// Le serveur stocke et agrège le CODE (`cash`, `mobile_money`...), jamais le
/// libellé traduit : « Espèces », « Espèce » et « cash » étaient comptés comme
/// trois moyens différents dans les journaux et la comptabilité. Les écrans
/// affichent [paymentMethodLabel] et envoient [paymentMethodCode].
library;

class PaymentMethodCode {
  PaymentMethodCode._();

  static const cash = 'cash';
  static const card = 'card';
  static const bankTransfer = 'bank_transfer';
  static const mobileMoney = 'mobile_money';
  static const check = 'check';
  static const credit = 'credit';
  static const other = 'other';

  static const all = <String>[
    cash,
    mobileMoney,
    card,
    bankTransfer,
    check,
    credit,
    other,
  ];
}

/// Code canonique d'un moyen de paiement, à partir d'un code ou d'un ancien
/// libellé (« Espèces », « Crédit », « Mobile Money »...). Vide ou inconnu :
/// [fallback] (espèces par défaut, valeur historique des caisses).
String paymentMethodCode(
  String? raw, {
  String fallback = PaymentMethodCode.cash,
}) {
  final m = (raw ?? '').trim().toLowerCase();
  if (m.isEmpty || m == 'n/a' || m == 'na') return fallback;
  if (PaymentMethodCode.all.contains(m)) return m;
  if (m.startsWith('esp') || m.startsWith('cash') || m == 'liquide') {
    return PaymentMethodCode.cash;
  }
  if (m.contains('mobile') ||
      m.contains('momo') ||
      m == 'mobilemoney' ||
      m.contains('m-pesa') ||
      m.contains('mpesa') ||
      m.contains('airtel') ||
      m.contains('orange') ||
      m.contains('afrimoney')) {
    return PaymentMethodCode.mobileMoney;
  }
  if (m.contains('carte') || m.contains('card') || m == 'tpe') {
    return PaymentMethodCode.card;
  }
  if (m.contains('virement') || m.contains('transfer') || m == 'bank') {
    return PaymentMethodCode.bankTransfer;
  }
  if (m.startsWith('ch') && (m.contains('que') || m == 'check')) {
    return PaymentMethodCode.check;
  }
  if (m.startsWith('cr') && m.contains('dit')) return PaymentMethodCode.credit;
  if (m == 'autre' || m == 'other') return PaymentMethodCode.other;
  return fallback;
}

/// Libellé affiché pour un code (ou un ancien libellé).
String paymentMethodLabel(String? raw) {
  switch (paymentMethodCode(raw, fallback: '')) {
    case PaymentMethodCode.cash:
      return 'Espèces';
    case PaymentMethodCode.mobileMoney:
      return 'Mobile Money';
    case PaymentMethodCode.card:
      return 'Carte bancaire';
    case PaymentMethodCode.bankTransfer:
      return 'Virement bancaire';
    case PaymentMethodCode.check:
      return 'Chèque';
    case PaymentMethodCode.credit:
      return 'Crédit';
    case PaymentMethodCode.other:
      return 'Autre';
    default:
      final r = (raw ?? '').trim();
      return r.isEmpty ? 'Espèces' : r;
  }
}

bool isCreditPaymentMethod(String? raw) =>
    paymentMethodCode(raw, fallback: '') == PaymentMethodCode.credit;

bool isMobileMoneyPaymentMethod(String? raw) =>
    paymentMethodCode(raw, fallback: '') == PaymentMethodCode.mobileMoney;

/// Échéance par défaut d'une vente à crédit (J+30), modifiable dans le formulaire.
const int kDefaultCreditDays = 30;

DateTime defaultCreditDueDate([DateTime? from]) {
  final d = from ?? DateTime.now();
  // Calcul en jours calendaires (un passage à l'heure d'hiver ne décale pas
  // l'échéance d'une heure, donc d'un jour).
  return DateTime(d.year, d.month, d.day + kDefaultCreditDays);
}
