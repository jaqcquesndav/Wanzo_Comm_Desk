import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/constants/spacing.dart';
import 'package:wanzo/features/sales/bloc/sales_bloc.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/settings/bloc/settings_bloc.dart' as old_settings_bloc;
import 'package:wanzo/features/settings/bloc/settings_state.dart' as old_settings_state;
import 'package:wanzo/features/settings/models/settings.dart' as old_settings_model;
import 'package:wanzo/features/settings/presentation/cubit/currency_settings_cubit.dart';
import 'package:wanzo/features/invoice/services/invoice_service.dart';
import 'package:pdf/pdf.dart'; // Added import
import 'package:printing/printing.dart'; // Added import for Printing
import 'package:share_plus/share_plus.dart'; // Added for Share.shareXFiles
// Added for XFile

/// Écran de détails d'une vente
class SaleDetailsScreen extends StatelessWidget {
  final Sale sale;

  const SaleDetailsScreen({
    super.key,
    required this.sale,
  });

  @override
  Widget build(BuildContext context) {
    // Access currency settings
    final currencySettingsState = context.watch<CurrencySettingsCubit>().state;
    final Currency appDefaultCurrency = currencySettingsState.settings.activeCurrency; // Corrected: activeCurrency is the app's default/active
    final String transactionCurrencyCode = sale.transactionCurrencyCode ?? appDefaultCurrency.code; // Provide a default value

    Color statusColor;
    String statusText;
    IconData statusIcon;

    // Déterminer la couleur et le texte en fonction du statut
    switch (sale.status) {
      case SaleStatus.pending:
        statusColor = Colors.amber;
        statusText = "En attente";
        statusIcon = Icons.pending;
        break;
      case SaleStatus.completed:
        statusColor = Colors.green;
        statusText = "Terminée";
        statusIcon = Icons.check_circle;
        break;
      case SaleStatus.partiallyPaid: 
        statusColor = Colors.blue; 
        statusText = "Partiellement payée";
        statusIcon = Icons.hourglass_bottom; 
        break;
      case SaleStatus.cancelled:
        statusColor = Colors.red;
        statusText = "Annulée";
        statusIcon = Icons.cancel;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Détails de la vente"),
        actions: [
          // Menu d'options
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == "edit") {
                // Naviguer vers l'écran d'édition
                context.push(
                  '/sales/edit', 
                  extra: {'sale': sale, 'currencySettings': context.read<CurrencySettingsCubit>().state.settings}
                );
              } else if (value == "delete") {
                _showDeleteConfirmation(context);
              } else if (value == "print") {
                // _printOrShareInvoice(context, print: true);
                _showDocumentTypeSelectionDialog(context, isPrintAction: true);
              } else if (value == "share") {
                // _printOrShareInvoice(context, print: false);
                _showDocumentTypeSelectionDialog(context, isPrintAction: false);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: "edit",
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text("Modifier"),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: "print",
                child: Row(
                  children: [
                    Icon(Icons.print),
                    SizedBox(width: 8),
                    Text("Imprimer"),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: "share",
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text("Partager"),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: "delete",
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text("Supprimer", style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(WanzoSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec information générale
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(WanzoSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status de la vente
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Vente #${sale.id.substring(0, 8)}",
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Chip(
                          label: Text(
                            statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: statusColor,
                          avatar: Icon(
                            statusIcon,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: WanzoSpacing.sm),
                    // Information sur la date et le client
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: WanzoSpacing.xs),
                        Text(
                          DateFormat("dd/MM/yyyy HH:mm").format(sale.date),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: WanzoSpacing.xs),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16),
                        const SizedBox(width: WanzoSpacing.xs),
                        Text(
                          "Client: ${sale.customerName}",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: WanzoSpacing.sm),
                    // Information sur le paiement
                    Row(
                      children: [
                        const Icon(Icons.payment, size: 16),
                        const SizedBox(width: WanzoSpacing.xs),
                        Text(
                          "Mode de paiement: ${sale.paymentMethod}",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const Divider(),
                    // Résumé des montants
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          formatCurrency(sale.totalAmountInTransactionCurrency ?? 0.0, transactionCurrencyCode),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    if (transactionCurrencyCode != appDefaultCurrency.code)
                      Padding(
                        padding: const EdgeInsets.only(top: WanzoSpacing.xxs, bottom: WanzoSpacing.xs),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              "(${formatCurrency(sale.totalAmountInCdf, appDefaultCurrency.code)})", // Display in app's active currency
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: WanzoSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Payé"),
                        Text(formatCurrency(sale.paidAmountInTransactionCurrency ?? 0.0, transactionCurrencyCode)),
                      ],
                    ),
                     if (transactionCurrencyCode != appDefaultCurrency.code)
                      Padding(
                        padding: const EdgeInsets.only(top: WanzoSpacing.xxs),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              "(${formatCurrency(sale.paidAmountInCdf, appDefaultCurrency.code)})", // Display in app's active currency
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: WanzoSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Reste à payer",
                          style: TextStyle(
                            color: ((sale.totalAmountInTransactionCurrency ?? 0.0) - (sale.paidAmountInTransactionCurrency ?? 0.0)).abs() < 0.001 || (sale.paidAmountInTransactionCurrency ?? 0.0) >= (sale.totalAmountInTransactionCurrency ?? 0.0)
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          formatCurrency((sale.totalAmountInTransactionCurrency ?? 0.0) - (sale.paidAmountInTransactionCurrency ?? 0.0), transactionCurrencyCode),
                          style: TextStyle(
                           color: ((sale.totalAmountInTransactionCurrency ?? 0.0) - (sale.paidAmountInTransactionCurrency ?? 0.0)).abs() < 0.001 || (sale.paidAmountInTransactionCurrency ?? 0.0) >= (sale.totalAmountInTransactionCurrency ?? 0.0)
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: WanzoSpacing.base),
            // Liste des articles vendus
            Text(
              "Articles vendus",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: WanzoSpacing.sm),
            Card(
              margin: EdgeInsets.zero,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sale.items.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final item = sale.items[index];
                  return ListTile(
                    title: Text(item.productName),
                    subtitle: Text(
                      "${item.quantity.toInt()} × ${formatCurrency(item.unitPrice, item.currencyCode)}", // item.currencyCode is transaction currency
                    ),
                    trailing: Text(
                      formatCurrency(item.totalPrice, item.currencyCode), // item.currencyCode is transaction currency
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WanzoSpacing.base,
            vertical: WanzoSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  // onPressed: () => _printOrShareInvoice(context, print: true),
                  onPressed: () => _showDocumentTypeSelectionDialog(context, isPrintAction: true),
                  icon: const Icon(Icons.print),
                  label: const Text("Imprimer"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: WanzoSpacing.sm), // Add some spacing between buttons
              Expanded(
                child: ElevatedButton.icon(
                  // onPressed: () => _printOrShareInvoice(context, print: false),
                  onPressed: () => _showDocumentTypeSelectionDialog(context, isPrintAction: false),
                  icon: const Icon(Icons.share),
                  label: const Text("Partager"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              if (sale.status == SaleStatus.pending || sale.status == SaleStatus.partiallyPaid) ...[
                const SizedBox(width: WanzoSpacing.sm), // Add some spacing between buttons
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Marquer la vente comme terminée
                      // All amounts are already correctly stored in the sale object.
                      // We just need to update the status.
                      final Sale updatedSale = sale.copyWith(
                        status: SaleStatus.completed,
                        // Ensure paid amount covers the total if marking completed this way
                        // This might need more sophisticated logic if partial payments can lead to completion
                        paidAmountInTransactionCurrency: sale.totalAmountInTransactionCurrency,
                        paidAmountInCdf: sale.totalAmountInCdf,
                      );
                      context.read<SalesBloc>().add(UpdateSale(updatedSale));
                      GoRouter.of(context).pop();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text("Terminer"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  /// Affiche une boîte de dialogue de confirmation pour supprimer la vente
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: const Text(
            "Êtes-vous sûr de vouloir supprimer cette vente ? Cette action est irréversible."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<SalesBloc>().add(DeleteSale(sale.id));
              GoRouter.of(context).pop();
            },
            child: const Text(
              "Supprimer",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog to select document type (Invoice or Receipt)
  void _showDocumentTypeSelectionDialog(BuildContext context, {required bool isPrintAction}) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isPrintAction ? "Imprimer le document" : "Partager le document"),
        content: const Text("Quel type de document souhaitez-vous générer ?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _printOrShareInvoice(context, print: isPrintAction, documentType: 'invoice');
            },
            child: const Text("Facture"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _printOrShareInvoice(context, print: isPrintAction, documentType: 'receipt');
            },
            child: const Text("Ticket de caisse"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Annuler"),
          ),
        ],
      ),
    );
  }

  /// Imprime la facture ou la partage
  void _printOrShareInvoice(BuildContext context, {required bool print, required String documentType}) async {
    final invoiceService = InvoiceService();
    // The sale object already contains all necessary currency information.
    // The InvoiceService is expected to use sale.transactionCurrencyCode, 
    // sale.totalAmountInTransactionCurrency, etc., for display,
    // and potentially sale.totalAmountInCdf for records if needed.

    // Retrieve old settings for invoice template compatibility
    final settingsBloc = context.read<old_settings_bloc.SettingsBloc>();
    final settingsState = settingsBloc.state;
    old_settings_model.Settings? legacySettings;

    if (settingsState is old_settings_state.SettingsLoaded) {
      legacySettings = settingsState.settings;
    } else if (settingsState is old_settings_state.SettingsUpdated) {
      legacySettings = settingsState.settings;
    }

    if (legacySettings == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de générer le document : anciens paramètres non chargés.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    try {
      String? pdfPath;
      // The Sale object now contains all necessary currency information.
      // InvoiceService's generateInvoicePdf and generateReceiptPdf methods
      // should be updated to use these fields (e.g., sale.transactionCurrencyCode,
      // sale.totalAmountInTransactionCurrency, sale.items[n].currencyCode, etc.)
      // The legacySettings are passed for template formatting (prefix, notes etc.)

      if (documentType == 'invoice') {
        pdfPath = await invoiceService.generateInvoicePdf(sale, legacySettings);
      } else if (documentType == 'receipt') {
        pdfPath = await invoiceService.generateReceiptPdf(sale, legacySettings);
      } else {
        // Should not happen with the dialog, but good to have a fallback or error
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Type de document non valide.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Corrected condition: Removed pdfPath != null as it was deemed redundant by the analyzer
      if (pdfPath.isNotEmpty && context.mounted) { 
        if (print) {
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => File(pdfPath!).readAsBytes(), // pdfPath is not null here due to isNotEmpty check
            name: documentType == 'invoice' ? 'Invoice_${sale.id.substring(0,8)}' : 'Receipt_${sale.id.substring(0,8)}',
          );
        } else {
          // Share the PDF that was actually generated by the logic above (invoice or receipt)
          final xFile = XFile(pdfPath); // pdfPath is not null here due to isNotEmpty check
          String subjectText = documentType == 'invoice' 
              ? 'Facture N° ${sale.id.substring(0,8)}' 
              : 'Ticket N° ${sale.id.substring(0,8)}';
          String bodyText = documentType == 'invoice' 
              ? 'Voici votre facture N° ${sale.id.substring(0,8)} concernant ${sale.items.first.productName}.'
              : 'Voici votre ticket de caisse N° ${sale.id.substring(0,8)} concernant ${sale.items.first.productName}.';

          await Share.shareXFiles(
            [xFile],
            text: bodyText,
            subject: subjectText,
          );
        }
      } else if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de générer le document. Chemin non valide.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de la génération/partage du document: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
}
