import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../sales/models/sale.dart';
import '../../settings/models/settings.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/enums/currency_enum.dart';

/// Service pour générer et imprimer des factures et tickets de caisse
class InvoiceService {
  /// Génère un PDF pour une vente et retourne le chemin du fichier
  Future<String> generateInvoicePdf(Sale sale, Settings settings) async {
    final pdf = pw.Document();

    final regularFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final Currency currency = settings.activeCurrency;

    pw.Widget? logoWidget;
    if (settings.companyLogo.isNotEmpty) {
      try {
        if (settings.companyLogo.startsWith('assets/')) {
          final logoData = await rootBundle.load(settings.companyLogo);
          final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
          logoWidget = pw.Image(logoImage, width: 80, height: 80);
        } else {
          final logoFile = File(settings.companyLogo);
          if (await logoFile.exists()) {
            final logoImage = pw.MemoryImage(await logoFile.readAsBytes());
            logoWidget = pw.Image(logoImage, width: 80, height: 80);
          }
        }
      } catch (e) {
        // print('Erreur lors du chargement du logo: $e');
      }
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = dateFormat.format(sale.date);

    String invoiceNumber = settings.invoiceNumberFormat;
    invoiceNumber = invoiceNumber
        .replaceAll('{YEAR}', sale.date.year.toString())
        .replaceAll('{MONTH}', sale.date.month.toString().padLeft(2, '0'))
        .replaceAll('{SEQ}', sale.id.substring(0, 8));

    final subtotal = sale.items.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.unitPrice),
    );

    double taxAmount = 0;
    if (settings.showTaxes) {
      taxAmount = subtotal * (settings.defaultTaxRate / 100.0);
    }

    final total = subtotal + taxAmount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête avec logo et informations de l'entreprise
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Logo et informations de l'entreprise à gauche
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoWidget != null) logoWidget,
                        if (logoWidget != null) pw.SizedBox(height: 5),
                        if (settings.companyName.isNotEmpty)
                          pw.Text(
                            settings.companyName,
                            style: pw.TextStyle(font: boldFont, fontSize: 12),
                          ),
                        if (settings.companyAddress.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            settings.companyAddress,
                            style: pw.TextStyle(font: regularFont, fontSize: 9),
                          ),
                        ],
                        if (settings.companyPhone.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Tél: ${settings.companyPhone}',
                            style: pw.TextStyle(font: regularFont, fontSize: 9),
                          ),
                        ],
                        if (settings.taxIdentificationNumber.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'NIF: ${settings.taxIdentificationNumber}',
                            style: pw.TextStyle(font: regularFont, fontSize: 9),
                          ),
                        ],
                        if (settings.rccmNumber.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'RCCM: ${settings.rccmNumber}',
                            style: pw.TextStyle(font: regularFont, fontSize: 9),
                          ),
                        ],
                        if (settings.idNatNumber.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'ID NAT: ${settings.idNatNumber}',
                            style: pw.TextStyle(font: regularFont, fontSize: 9),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  // Informations de la facture à droite
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'FACTURE',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 18,
                            color: PdfColors.blueGrey700,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'N°: $invoiceNumber',
                          style: pw.TextStyle(font: regularFont, fontSize: 10),
                        ),
                        pw.Text(
                          'Date: $formattedDate',
                          style: pw.TextStyle(font: regularFont, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  children: [
                    pw.Text('CLIENT:', style: pw.TextStyle(font: boldFont)),
                    pw.SizedBox(width: 10),
                    pw.Text(sale.customerName),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Désignation',
                          style: pw.TextStyle(font: boldFont),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Qté',
                          style: pw.TextStyle(font: boldFont),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'P.U.',
                          style: pw.TextStyle(font: boldFont),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Total',
                          style: pw.TextStyle(font: boldFont),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),

                  ...sale.items.map((item) {
                    final itemTotal = item.quantity * item.unitPrice;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(item.productName),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            '${item.quantity}',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            formatCurrency(item.unitPrice, currency.code),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            formatCurrency(itemTotal, currency.code),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 10),

              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          width: 150,
                          child: pw.Text(
                            'Sous-total:',
                            style: pw.TextStyle(font: boldFont),
                          ),
                        ),
                        pw.Container(
                          width: 120,
                          child: pw.Text(
                            formatCurrency(subtotal, currency.code),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    if (settings.showTaxes) ...[
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Container(
                            width: 150,
                            child: pw.Text(
                              'TVA (${settings.defaultTaxRate}%):',
                              style: pw.TextStyle(font: boldFont),
                            ),
                          ),
                          pw.Container(
                            width: 120,
                            child: pw.Text(
                              formatCurrency(taxAmount, currency.code),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ],
                    pw.SizedBox(height: 5),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(5),
                      color: PdfColors.grey300,
                      child: pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Container(
                            width: 150,
                            child: pw.Text(
                              'Total à payer:',
                              style: pw.TextStyle(font: boldFont, fontSize: 12),
                            ),
                          ),
                          pw.Container(
                            width: 120,
                            child: pw.Text(
                              formatCurrency(total, currency.code),
                              style: pw.TextStyle(font: boldFont, fontSize: 12),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Display payment status if applicable
              if (sale.paidAmountInCdf > 0) ...[
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  mainAxisAlignment:
                      pw
                          .MainAxisAlignment
                          .end, // Align to the right with other totals
                  children: [
                    pw.Container(
                      width: 150,
                      child: pw.Text(
                        'Montant Payé:',
                        style: pw.TextStyle(font: regularFont, fontSize: 10),
                      ),
                    ),
                    pw.Container(
                      width: 120,
                      child: pw.Text(
                        formatCurrency(sale.paidAmountInCdf, currency.code),
                        style: pw.TextStyle(font: regularFont, fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                if (sale.remainingAmountInCdf > 0) ...[
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    mainAxisAlignment:
                        pw.MainAxisAlignment.end, // Align to the right
                    children: [
                      pw.Container(
                        width: 150,
                        child: pw.Text(
                          'Solde Dû:',
                          style: pw.TextStyle(font: regularFont, fontSize: 10),
                        ),
                      ),
                      pw.Container(
                        width: 120,
                        child: pw.Text(
                          formatCurrency(
                            sale.remainingAmountInCdf,
                            currency.code,
                          ),
                          style: pw.TextStyle(font: regularFont, fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ],

              pw.SizedBox(height: 30),

              if (settings.defaultPaymentTerms.isNotEmpty) ...[
                pw.Text(
                  'Conditions de paiement:',
                  style: pw.TextStyle(font: boldFont),
                ),
                pw.SizedBox(height: 5),
                pw.Text(settings.defaultPaymentTerms),
                pw.SizedBox(height: 10),
              ],

              pw.Spacer(),

              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Merci pour votre confiance, merci pour votre achat!',
                      style: pw.TextStyle(font: boldFont, fontSize: 12),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Facture générée par Wanzo, conçu par i-kiotahub Goma.',
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/invoice_${sale.id}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  /// Partage la facture PDF générée
  Future<void> shareInvoice(
    Sale sale,
    Settings settings, {
    String? customerPhoneNumber,
    String? customerEmail,
  }) async {
    try {
      final pdfPath = await generateInvoicePdf(sale, settings);
      final xFile = XFile(pdfPath);

      String shareText =
          'Voici votre facture N° ${sale.id.substring(0, 8)} concernant ${sale.items.first.productName}.';
      if (customerPhoneNumber != null) {
        shareText += '\nPartage via WhatsApp: wa.me/$customerPhoneNumber';
      }

      await Share.shareXFiles(
        [xFile],
        text: shareText,
        subject: 'Facture N° ${sale.id.substring(0, 8)}',
      );
    } catch (e) {
      // print('Erreur lors du partage de la facture: $e');
      throw Exception(
        'Impossible de partager la facture: $e',
      ); // Escaped apostrophe
    }
  }

  /// Génère un ticket de caisse pour une vente et retourne le chemin du fichier
  Future<String> generateReceiptPdf(Sale sale, Settings settings) async {
    final pdf = pw.Document();

    final regularFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final Currency currency = settings.activeCurrency;

    pw.Widget? logoWidget;
    if (settings.companyLogo.isNotEmpty) {
      try {
        if (settings.companyLogo.startsWith('assets/')) {
          final logoData = await rootBundle.load(settings.companyLogo);
          final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
          logoWidget = pw.Image(logoImage, width: 60, height: 60);
        } else {
          final logoFile = File(settings.companyLogo);
          if (await logoFile.exists()) {
            final logoImage = pw.MemoryImage(await logoFile.readAsBytes());
            logoWidget = pw.Image(logoImage, width: 60, height: 60);
          }
        }
      } catch (e) {
        // print('Erreur lors du chargement du logo: $e');
      }
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = dateFormat.format(sale.date);

    final subtotal = sale.items.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.unitPrice),
    );

    double taxAmount = 0;
    if (settings.showTaxes) {
      taxAmount = subtotal * (settings.defaultTaxRate / 100.0);
    }

    final total = subtotal + taxAmount;
    final ticketWidth = PdfPageFormat(
      80 * PdfPageFormat.mm,
      500 * PdfPageFormat.mm, // Increased height for potentially long receipts
      marginAll: 5 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: ticketWidth,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoWidget != null) ...[
                pw.Center(child: logoWidget),
                pw.SizedBox(height: 5),
              ],

              pw.Text(
                settings.companyName,
                style: pw.TextStyle(font: boldFont, fontSize: 12),
                textAlign: pw.TextAlign.center,
              ),

              if (settings.companyAddress.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  settings.companyAddress,
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],

              if (settings.companyPhone.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'Tél: ${settings.companyPhone}',
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              if (settings.taxIdentificationNumber.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'NIF: ${settings.taxIdentificationNumber}',
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],

              if (settings.rccmNumber.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'RCCM: ${settings.rccmNumber}',
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],

              if (settings.idNatNumber.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'ID NAT: ${settings.idNatNumber}',
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],

              pw.SizedBox(height: 5),
              pw.Text(
                // MODIFIED: Make substring safe
                'Ticket N°: ${sale.id.length >= 8 ? sale.id.substring(0, 8) : sale.id}',
                style: pw.TextStyle(font: regularFont, fontSize: 8),
              ),
              pw.Text(
                'Date: $formattedDate',
                style: pw.TextStyle(font: regularFont, fontSize: 8),
              ),
              pw.SizedBox(height: 5),

              pw.Divider(color: PdfColors.black, height: 1),
              pw.SizedBox(height: 3),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      'Article',
                      style: pw.TextStyle(font: boldFont, fontSize: 8),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Qté',
                      style: pw.TextStyle(font: boldFont, fontSize: 8),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'P.U.',
                      style: pw.TextStyle(font: boldFont, fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Total',
                      style: pw.TextStyle(font: boldFont, fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Divider(
                color: PdfColors.black,
                height: 1,
              ), // Garder ce Divider
              pw.SizedBox(height: 3),

              ...sale.items.map((item) {
                final itemTotal = item.quantity * item.unitPrice;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          item.productName,
                          style: pw.TextStyle(font: regularFont, fontSize: 8),
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          '${item.quantity}',
                          style: pw.TextStyle(font: regularFont, fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          formatCurrency(item.unitPrice, currency.code),
                          style: pw.TextStyle(font: regularFont, fontSize: 8),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          formatCurrency(itemTotal, currency.code),
                          style: pw.TextStyle(font: regularFont, fontSize: 8),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 5),
              pw.Divider(
                color: PdfColors.black,
                height: 1,
              ), // Garder ce Divider
              pw.SizedBox(height: 3),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Sous-total: ',
                    style: pw.TextStyle(font: regularFont, fontSize: 8),
                  ),
                  pw.SizedBox(
                    width: 60, // Adjust width as needed
                    child: pw.Text(
                      formatCurrency(subtotal, currency.code),
                      style: pw.TextStyle(font: regularFont, fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),

              if (settings.showTaxes) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      'TVA (${settings.defaultTaxRate}%): ',
                      style: pw.TextStyle(font: regularFont, fontSize: 8),
                    ),
                    pw.SizedBox(
                      width: 60, // Adjust width as needed
                      child: pw.Text(
                        formatCurrency(taxAmount, currency.code),
                        style: pw.TextStyle(font: regularFont, fontSize: 8),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],

              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'TOTAL: ',
                    style: pw.TextStyle(font: boldFont, fontSize: 10),
                  ),
                  pw.SizedBox(
                    width: 60, // Adjust width as needed
                    child: pw.Text(
                      formatCurrency(total, currency.code),
                      style: pw.TextStyle(font: boldFont, fontSize: 10),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // Montant Reçu
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Montant Reçu: ',
                    style: pw.TextStyle(font: boldFont, fontSize: 10),
                  ),
                  pw.SizedBox(
                    width: 80, // Adjusted width
                    child: pw.Text(
                      formatCurrency(sale.paidAmountInCdf, currency.code),
                      style: pw.TextStyle(font: boldFont, fontSize: 10),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 3),
              // Total Vente (for context)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total Vente: ',
                    style: pw.TextStyle(font: regularFont, fontSize: 8),
                  ),
                  pw.SizedBox(
                    width: 80, // Adjusted width
                    child: pw.Text(
                      formatCurrency(
                        total,
                        currency.code,
                      ), // 'total' is the full sale amount calculated in this function
                      style: pw.TextStyle(font: regularFont, fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),

              // Solde Restant (if any)
              if (sale.remainingAmountInCdf > 0) ...[
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Solde Restant: ',
                      style: pw.TextStyle(font: regularFont, fontSize: 8),
                    ),
                    pw.SizedBox(
                      width: 80, // Adjusted width
                      child: pw.Text(
                        formatCurrency(
                          sale.remainingAmountInCdf,
                          currency.code,
                        ),
                        style: pw.TextStyle(font: regularFont, fontSize: 8),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],

              pw.SizedBox(height: 10),

              pw.Text(
                'Merci pour votre confiance, merci pour votre achat!',
                style: pw.TextStyle(font: boldFont, fontSize: 9),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Wanzo by i-kiotahub Goma',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/receipt_${sale.id}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  /// Imprime directement une facture ou un ticket (nécessite une imprimante configurée)
  Future<void> printDocument(String filePath, {bool isReceipt = false}) async {
    try {
      // Pour l'impression directe, on peut utiliser printing.layoutPdf
      // ou pour une impression plus contrôlée, on peut utiliser platform-specific code.
      // Ici, on utilise une méthode simple qui pourrait ouvrir le dialogue d'impression.
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          final file = File(filePath);
          return file.readAsBytes();
        },
        name:
            isReceipt
                ? 'Receipt_${DateTime.now().millisecondsSinceEpoch}'
                : 'Invoice_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      // print('Erreur lors de l'impression du document: $e');
      throw Exception(
        'Impossible d\'imprimer le document: $e',
      ); // Escaped apostrophe
    }
  }
}

// Helper function to load font (if needed for custom fonts, not used with Helvetica)
// Future<pw.Font> loadFont(String path) async {
//   final fontData = await rootBundle.load(path);
//   return pw.Font.ttf(fontData);
// }

// Example of how to get a default font if a custom one fails (not directly used here)
// pw.Font getFallbackFont() {
//   return pw.Font.helvetica();
// }
