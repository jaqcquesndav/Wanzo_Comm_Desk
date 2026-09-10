import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/widgets/desktop/adaptive_modal.dart';
import 'package:wanzo/features/invoice/services/invoice_service.dart';
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
/// `AdaptiveModal` sur desktop (>= 900 px), `BottomSheet` sur mobile. Propose
/// aperçu, impression système, ticket thermique (si espèces) et partage du PDF.
///
/// - [customerPhone] : numéro du client lié, joint au partage du PDF.
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
  final screenWidth = MediaQuery.of(context).size.width;
  final isDesktop = screenWidth >= 900;
  final isCash = ReceiptPrinterService.isCashPayment(sale.paymentMethod);

  if (isDesktop) {
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
                icon: Icons.share,
                iconColor: Colors.orange,
                title: 'Partager $documentType',
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await invoiceService.shareInvoice(
                    sale,
                    settings,
                    customerPhoneNumber: customerPhone,
                  );
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
    return;
  }

  // Mobile : BottomSheet.
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext bc) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // En-tête avec message de succès
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 48.0,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Vente enregistrée avec succès',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        'Montant total: ${_formatSaleAmount(sale)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Divider(),
                  ],
                ),
              ),
              if (onNewSale != null)
                ListTile(
                  leading: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.green,
                  ),
                  title: const Text('Enregistrer une autre vente'),
                  subtitle: const Text('Réinitialiser le formulaire'),
                  onTap: () {
                    Navigator.pop(bc);
                    onNewSale();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.blue),
                title: Text('Prévisualiser $documentType'),
                onTap: () async {
                  Navigator.pop(bc);
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
              ListTile(
                leading: const Icon(Icons.print, color: Colors.blue),
                title: Text('Imprimer $documentType'),
                onTap: () async {
                  Navigator.pop(bc);
                  await invoiceService.printDocument(pdfPath);
                  onClose?.call();
                },
              ),
              if (isCash)
                ListTile(
                  leading: const Icon(Icons.receipt, color: Colors.teal),
                  title: const Text('Ticket thermique'),
                  subtitle: const Text('Imprimante ESC/POS'),
                  onTap: () async {
                    Navigator.pop(bc);
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
              ListTile(
                leading: const Icon(Icons.share, color: Colors.orange),
                title: Text('Partager $documentType'),
                onTap: () async {
                  Navigator.pop(bc);
                  await invoiceService.shareInvoice(
                    sale,
                    settings,
                    customerPhoneNumber: customerPhone,
                  );
                  onClose?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.grey),
                title: const Text('Fermer et continuer'),
                onTap: () {
                  Navigator.pop(bc);
                  onClose?.call();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Formate le montant de la vente pour l'en-tête de la feuille.
String _formatSaleAmount(Sale sale) {
  if (sale.transactionCurrencyCode != null &&
      sale.totalAmountInTransactionCurrency != null) {
    return formatCurrency(
      sale.totalAmountInTransactionCurrency!,
      sale.transactionCurrencyCode!,
    );
  }
  return formatCurrency(sale.totalAmountInCdf, 'CDF');
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
