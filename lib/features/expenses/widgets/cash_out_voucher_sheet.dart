import 'package:flutter/material.dart';
import 'package:wanzo/core/services/platform_share_service.dart';

import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/features/invoice/services/invoice_service.dart';
import 'package:wanzo/features/settings/models/settings.dart';

/// Pièce de caisse d'une sortie d'argent.
///
/// Sert à toute somme qui quitte la caisse sans être une vente : avance à un
/// prestataire, achat au comptant, remboursement. Le PDF est produit au format
/// ticket 80 mm, donc l'imprimante du comptoir le sort comme un reçu de vente.
class CashOutVoucher {
  const CashOutVoucher({
    required this.reference,
    required this.date,
    required this.beneficiary,
    required this.motif,
    required this.amount,
    required this.currencyCode,
    this.paymentMethod,
    this.note,
  });

  final String reference;
  final DateTime date;
  final String beneficiary;
  final String motif;
  final double amount;
  final String currencyCode;
  final String? paymentMethod;

  /// Mention de bas de pièce, par exemple ce que l'avance vient déduire.
  final String? note;
}

/// Produit le bon puis l'affiche. Retourne false si le PDF n'a pas pu être
/// écrit : l'appelant garde la main pour le dire sans prétendre l'inverse.
Future<bool> showCashOutVoucher(
  BuildContext context,
  CashOutVoucher bon,
  Settings settings,
) async {
  String pdfPath;
  try {
    pdfPath = await InvoiceService().generateCashOutVoucherPdf(
      settings: settings,
      reference: bon.reference,
      date: bon.date,
      beneficiary: bon.beneficiary,
      motif: bon.motif,
      amount: bon.amount,
      currencyCode: bon.currencyCode,
      paymentMethod: bon.paymentMethod,
      note: bon.note,
    );
  } catch (_) {
    return false;
  }

  if (!context.mounted) return false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _VoucherSheet(bon: bon, pdfPath: pdfPath),
  );
  return true;
}

class _VoucherSheet extends StatelessWidget {
  const _VoucherSheet({required this.bon, required this.pdfPath});

  final CashOutVoucher bon;
  final String pdfPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bon de sortie de caisse',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'N° ${bon.reference}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _Ligne(libelle: 'Bénéficiaire', valeur: bon.beneficiary),
                  _Ligne(libelle: 'Motif', valeur: bon.motif),
                  _Ligne(
                    libelle: 'Montant',
                    valeur: formatCurrency(bon.amount, bon.currencyCode),
                    gras: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _partager(context),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Partager'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _imprimer(context),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Imprimer'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _imprimer(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await InvoiceService().printDocument(pdfPath, isReceipt: true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Impression impossible : $e')),
      );
    }
  }

  Future<void> _partager(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Sur Windows et Linux, share_plus ne sait pas ouvrir de feuille de
      // partage : ce service choisit le bon chemin par plateforme.
      await PlatformShareService.instance.sharePdfFile(
        filePath: pdfPath,
        subject: 'Bon de sortie de caisse N° ${bon.reference}',
        text: 'Bon de sortie de caisse N° ${bon.reference} — '
            '${bon.beneficiary} — '
            '${formatCurrency(bon.amount, bon.currencyCode)}',
        context: context,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Partage impossible : $e')),
      );
    }
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.libelle, required this.valeur, this.gras = false});

  final String libelle;
  final String valeur;
  final bool gras;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              libelle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              valeur,
              textAlign: TextAlign.right,
              style: gras
                  ? theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)
                  : theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
