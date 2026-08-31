import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../sales/models/sale.dart';

/// Utilitaires transverses pour l'axe « créances clients / relance ».
///
/// Tout est calculé localement (offline-first) à partir des ventes déjà
/// synchronisées : aucune requête réseau n'est nécessaire.

/// Délai par défaut (en jours) accordé après la date de vente lorsqu'aucune
/// date d'échéance explicite n'est renseignée sur la vente.
const int kDefaultCreditTermDays = 30;

/// Retourne uniquement la partie « jour » d'une date (00:00), pour comparer
/// des échéances sans être perturbé par l'heure.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Date d'échéance effective d'une vente : [Sale.dueDate] si présente, sinon
/// [Sale.date] + [kDefaultCreditTermDays] jours.
DateTime effectiveDueDate(Sale sale) =>
    sale.dueDate ?? sale.date.add(const Duration(days: kDefaultCreditTermDays));

/// Vrai si la vente est une créance encore ouverte (en attente ou
/// partiellement payée, avec un solde restant strictement positif).
bool isOpenReceivable(Sale sale) {
  final isOpenStatus =
      sale.status == SaleStatus.pending ||
      sale.status == SaleStatus.partiallyPaid;
  return isOpenStatus && sale.remainingAmountInCdf > 0.0001;
}

/// Vrai si la vente est en retard : créance ouverte dont l'échéance effective
/// est antérieure à aujourd'hui.
bool isSaleOverdue(Sale sale, {DateTime? now}) {
  if (!isOpenReceivable(sale)) return false;
  final today = _dateOnly(now ?? DateTime.now());
  final due = _dateOnly(effectiveDueDate(sale));
  return due.isBefore(today);
}

/// Nombre de jours de retard (0 si pas en retard).
int overdueDays(Sale sale, {DateTime? now}) {
  if (!isSaleOverdue(sale, now: now)) return 0;
  final today = _dateOnly(now ?? DateTime.now());
  final due = _dateOnly(effectiveDueDate(sale));
  return today.difference(due).inDays;
}

/// Ancienneté d'une créance en jours, calculée depuis la date de la vente.
int ageingDays(Sale sale, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final saleDay = _dateOnly(sale.date);
  final diff = today.difference(saleDay).inDays;
  return diff < 0 ? 0 : diff;
}

/// Tranche d'ancienneté : 0 = 0-30j, 1 = 31-60j, 2 = 61-90j, 3 = 90j+.
int ageingBucketIndex(Sale sale, {DateTime? now}) {
  final days = ageingDays(sale, now: now);
  if (days <= 30) return 0;
  if (days <= 60) return 1;
  if (days <= 90) return 2;
  return 3;
}

/// Libellés des tranches d'ancienneté (ordre = index de la tranche).
const List<String> kAgeingBucketLabels = <String>[
  '0-30 j',
  '31-60 j',
  '61-90 j',
  '90 j+',
];

/// Normalise un numéro de téléphone au format international (chiffres uniquement,
/// sans « + »), utilisable dans une URL `wa.me/<num>`.
///
/// Par défaut on suppose l'indicatif RDC (243) pour les numéros locaux.
/// Retourne `null` si aucun numéro exploitable.
String? toInternationalPhone(String? raw, {String defaultCountryCode = '243'}) {
  if (raw == null) return null;
  var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.isEmpty) return null;
  // Supprimer les préfixes internationaux (« + » ou « 00 »).
  if (digits.startsWith('+')) digits = digits.substring(1);
  digits = digits.replaceAll('+', '');
  if (digits.startsWith('00')) digits = digits.substring(2);

  if (digits.isEmpty) return null;

  if (digits.startsWith(defaultCountryCode)) {
    // Déjà au format international.
    return digits;
  }
  if (digits.startsWith('0')) {
    // Numéro local avec 0 initial → indicatif pays.
    return defaultCountryCode + digits.substring(1);
  }
  // Numéro local court sans indicatif ni 0 → préfixer l'indicatif.
  if (digits.length <= 9) {
    return defaultCountryCode + digits;
  }
  return digits;
}

/// Ouvre WhatsApp (deep-link `wa.me`) avec le message [message] pré-rempli, avec
/// repli automatique sur SMS puis, en dernier recours, un SnackBar d'erreur.
///
/// Si [phone] est vide/nul, WhatsApp s'ouvre sans destinataire (l'utilisateur
/// choisit le contact) ; le repli SMS n'est alors pas tenté.
Future<bool> launchWhatsAppOrSms(
  BuildContext context, {
  required String message,
  String? phone,
}) async {
  final intlPhone = toInternationalPhone(phone);
  final encoded = Uri.encodeComponent(message);

  final waUri = Uri.parse(
    intlPhone != null
        ? 'https://wa.me/$intlPhone?text=$encoded'
        : 'https://wa.me/?text=$encoded',
  );

  try {
    if (await canLaunchUrl(waUri)) {
      final ok = await launchUrl(
        waUri,
        mode: LaunchMode.externalApplication,
      );
      if (ok) return true;
    }
  } catch (_) {
    // On tente le repli SMS ci-dessous.
  }

  // Repli SMS (uniquement si on connaît un numéro).
  if (intlPhone != null) {
    final smsUri = Uri.parse('sms:+$intlPhone?body=$encoded');
    try {
      if (await canLaunchUrl(smsUri)) {
        final ok = await launchUrl(
          smsUri,
          mode: LaunchMode.externalApplication,
        );
        if (ok) return true;
      }
    } catch (_) {
      // Ignore, on affiche l'erreur ci-dessous.
    }
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Impossible d\'ouvrir WhatsApp ou la messagerie SMS sur cet appareil.',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
  return false;
}

/// Ouvre le composeur SMS avec le message [message] pré-rempli. Si [phone] est
/// nul/vide, ouvre un SMS sans destinataire (l'utilisateur choisit le contact).
Future<bool> launchSmsMessage(
  BuildContext context, {
  required String message,
  String? phone,
}) async {
  final intlPhone = toInternationalPhone(phone);
  final encoded = Uri.encodeComponent(message);
  final smsUri = Uri.parse(
    intlPhone != null ? 'sms:+$intlPhone?body=$encoded' : 'sms:?body=$encoded',
  );
  try {
    if (await canLaunchUrl(smsUri)) {
      final ok = await launchUrl(
        smsUri,
        mode: LaunchMode.externalApplication,
      );
      if (ok) return true;
    }
  } catch (_) {
    // Erreur affichée ci-dessous.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impossible d\'ouvrir la messagerie SMS sur cet appareil.'),
        backgroundColor: Colors.red,
      ),
    );
  }
  return false;
}

/// Construit le message de relance (FR) : nom de l'entreprise + montant dû.
String buildReminderMessage({
  required String businessName,
  required String customerName,
  required String amountDueText,
}) {
  return 'Bonjour $customerName,\n\n'
      'Nous vous rappelons qu\'un solde de $amountDueText reste dû '
      'auprès de $businessName. '
      'Merci de bien vouloir procéder au règlement dès que possible.\n\n'
      'Cordialement,\n$businessName';
}

/// Construit le message d'envoi d'une pièce (facture / ticket) par messagerie.
String buildDocumentMessage({
  required String businessName,
  required String documentLabel,
  required String reference,
  required String amountText,
}) {
  return 'Bonjour,\n\n'
      '$businessName vous transmet votre $documentLabel N° $reference '
      'pour un montant de $amountText.\n\n'
      'Merci pour votre confiance.\n$businessName';
}
