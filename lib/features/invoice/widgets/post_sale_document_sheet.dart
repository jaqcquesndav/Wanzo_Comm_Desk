import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/services/platform_share_service.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/widgets/desktop/adaptive_modal.dart';
import 'package:wanzo/features/invoice/services/invoice_service.dart';
import 'package:wanzo/features/invoice/utils/invoice_money.dart';
import 'package:wanzo/features/receivables/utils/receivables_utils.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/settings/models/settings.dart';
import 'package:wanzo/services/receipt_printer_service.dart';

/// Pièce post-vente générée (chemin PDF + libellé du type).
class PostSaleDocument {
  final String pdfPath;
  final String documentType;
  const PostSaleDocument(this.pdfPath, this.documentType);
}

/// Génère la pièce commerciale d'une vente (reçu ou facture) et retourne son
/// chemin PDF + son type.
///
/// [isReceipt] force le type : `true` = reçu (paiement encaissé), `false` =
/// facture (vente à crédit / solde dû). S'il est nul, on déduit du solde restant
/// (reçu si tout est payé, sinon facture). Utilisé par la boutique ET le salon
/// pour partager EXACTEMENT le même service de génération.
Future<PostSaleDocument?> generatePostSaleDocument(
  Sale sale,
  Settings settings, {
  bool? isReceipt,
}) async {
  final invoiceService = InvoiceService();
  final receipt = isReceipt ?? (sale.remainingAmountInCdf <= 0.0001);
  final documentType = receipt ? 'Reçu' : 'Facture';
  final pdfPath = receipt
      ? await invoiceService.generateReceiptPdf(sale, settings)
      : await invoiceService.generateInvoicePdf(sale, settings);
  if (pdfPath.isEmpty) return null;
  return PostSaleDocument(pdfPath, documentType);
}

/// Feuille d'options post-vente PARTAGÉE (boutique + salon), adaptative :
/// toujours en `AdaptiveModal` dans l'app desktop. Propose
/// aperçu, impression système, ticket thermique (si espèces), envoi WhatsApp
/// au client (repli SMS) et partage du PDF généré (PlatformShareService).
///
/// - [customerPhone] : numéro du client lié, pré-ciblé pour WhatsApp.
/// - [onNewSale] : si non nul, affiche « Enregistrer une autre vente »
///   (spécifique à la boutique) ; le salon ne la fournit pas.
/// - [onClose] : appelé après toute action terminale ou l'option « Fermer »
///   (la boutique referme l'écran de vente, le salon revient en arrière).
void showPostSaleDocumentSheet({
  required BuildContext context,
  required String pdfPath,
  required String documentType,
  required Sale sale,
  required Settings settings,
  String? customerPhone,
  VoidCallback? onNewSale,
  VoidCallback? onClose,
}) {
  final invoiceService = InvoiceService();
  final isCash = ReceiptPrinterService.isCashPayment(sale.paymentMethod);

  // App desktop : toujours la modale centrée (plus de feuille du bas).
  {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AdaptiveModal(
          title: 'Vente enregistrée avec succès',
          subtitle: 'Montant total: ${_formatSaleAmount(sale)}',
          size: ModalSize.small,
          headerIcon: Icons.check_circle,
          headerIconColor: Colors.green,
          showCloseButton: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onNewSale != null)
                _DocumentOptionTile(
                  icon: Icons.add_circle_outline,
                  iconColor: Colors.green,
                  title: 'Enregistrer une autre vente',
                  subtitle: 'Réinitialiser le formulaire',
                  onTap: () {
                    Navigator.pop(dialogContext);
                    onNewSale();
                  },
                ),
              _DocumentOptionTile(
                icon: Icons.visibility,
                iconColor: Colors.blue,
                title: 'Prévisualiser $documentType',
                onTap: () async {
                  Navigator.pop(dialogContext);
                  try {
                    final file = File(pdfPath);
                    if (await file.exists()) {
                      final uri = Uri.file(pdfPath);
                      await launchUrl(uri);
                    }
                  } catch (e) {
                    debugPrint('Erreur lors de l\'ouverture du document: $e');
                  }
                  onClose?.call();
                },
              ),
              _DocumentOptionTile(
                icon: Icons.print,
                iconColor: Colors.blue,
                title: 'Imprimer $documentType',
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await invoiceService.printDocument(pdfPath);
                  onClose?.call();
                },
              ),
              if (isCash)
                _DocumentOptionTile(
                  icon: Icons.receipt,
                  iconColor: Colors.teal,
                  title: 'Ticket thermique',
                  subtitle: 'Imprimante ESC/POS',
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    final printerService = ReceiptPrinterService();
                    final success = await printerService.printCashReceipt(
                      sale,
                      settings,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Ticket thermique imprimé'
                                : 'Échec impression thermique',
                          ),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                    onClose?.call();
                  },
                ),
              _DocumentOptionTile(
                icon: Icons.chat,
                iconColor: Colors.green,
                title: 'Envoyer par WhatsApp',
                subtitle: 'Résumé au client, avec repli SMS',
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await launchWhatsAppOrSms(
                    context,
                    message: buildPostSaleDocumentMessage(sale, documentType),
                    phone: customerPhone,
                  );
                  onClose?.call();
                },
              ),
              _DocumentOptionTile(
                icon: Icons.share,
                iconColor: Colors.orange,
                title: 'Partager $documentType',
                subtitle: 'E-mail, applications installées (PDF joint)',
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await _sharePdf(context, pdfPath, documentType, sale);
                  onClose?.call();
                },
              ),
              _DocumentOptionTile(
                icon: Icons.close,
                iconColor: Colors.grey,
                title: 'Fermer et continuer',
                onTap: () {
                  Navigator.pop(dialogContext);
                  onClose?.call();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Partage le PDF DÉJÀ généré (la pièce réellement présentée, reçu ou
/// facture) via [PlatformShareService], qui gère les replis desktop
/// (enregistrer, imprimer, copier le chemin). L'ancien
/// `InvoiceService.shareInvoice` régénérait toujours une FACTURE, même quand
/// la pièce était un reçu.
Future<void> _sharePdf(
  BuildContext context,
  String pdfPath,
  String documentType,
  Sale sale,
) async {
  try {
    await PlatformShareService.instance.sharePdfFile(
      filePath: pdfPath,
      subject: '$documentType ${_documentReference(sale)}',
      text: buildPostSaleDocumentMessage(sale, documentType),
      context: context,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de partager la pièce : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

String _documentReference(Sale sale) =>
    (sale.invoiceNumber != null && sale.invoiceNumber!.isNotEmpty)
        ? sale.invoiceNumber!
        : (sale.id.length >= 8 ? sale.id.substring(0, 8) : sale.id);

/// Résumé texte de la pièce (facture / reçu) pour un envoi WhatsApp / SMS.
/// Total et solde dans la MÊME devise, celle de la pièce, depuis la base CDF.
String buildPostSaleDocumentMessage(Sale sale, String documentType) {
  final money = InvoiceMoney.forSale(sale);
  final total = formatCurrency(
    money.fromCdf(sale.totalAmountInCdf),
    money.currencyCode,
  );
  final ctx = BusinessContextService();
  final business =
      ctx.currentContext?.companyName ?? ctx.businessUnitName ?? 'Wanzo';
  final base = buildDocumentMessage(
    businessName: business,
    documentLabel: documentType.toLowerCase(),
    reference: _documentReference(sale),
    amountText: total,
  );
  if (sale.remainingAmountInCdf <= 0.0001) return base;
  final due = formatCurrency(
    money.fromCdf(sale.remainingAmountInCdf),
    money.currencyCode,
  );
  return '$base\n\nSolde restant dû : $due';
}

/// Formate le montant de la vente pour l'en-tête de la feuille.
String _formatSaleAmount(Sale sale) {
  // Devise de la pièce, montant depuis la base CDF (voir InvoiceMoney).
  final money = InvoiceMoney.forSale(sale);
  return formatCurrency(
    money.fromCdf(sale.totalAmountInCdf),
    money.currencyCode,
  );
}

/// Option de document (rendu desktop) : icône colorée, titre, sous-titre.
class _DocumentOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _DocumentOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
