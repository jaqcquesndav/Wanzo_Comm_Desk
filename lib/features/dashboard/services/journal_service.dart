import 'dart:io';

import 'package:wanzo/l10n/app_localizations.dart'; // Corrigé
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; // Pour PdfGoogleFonts
import 'package:wanzo/core/enums/currency_enum.dart'; // Import Currency enum
import 'package:wanzo/features/dashboard/models/operation_journal_entry.dart';
import 'package:wanzo/features/settings/models/settings.dart';

class JournalService {
  Future<File?> generateJournalPdf(
    List<OperationJournalEntry> entries,
    DateTime startDate,
    DateTime endDate,
    double openingBalance,
    AppLocalizations l10n,
    Settings settings,
  ) async {
    // final font = await PdfGoogleFonts.nunitoExtraLight();
    pw.RichText.debug = true;
    // print('Generating PDF with ${entries.length} entries.');
    // print('Selected currency: ${settings.mainCurrency}');

    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    // Use currency code from settings and locale from l10n
    final currencyFormat = NumberFormat.currency(
      locale: l10n.localeName, // Use locale from AppLocalizations
      name: settings.activeCurrency.code, // Use currency code from Settings
      // decimalDigits can be inferred by NumberFormat based on currency code and locale,
      // or you can define it explicitly if needed, e.g., for specific currencies.
      // decimalDigits: settings.activeCurrency.decimalDigits, // Assuming Currency enum has decimalDigits
    );

    final dateFormat = DateFormat.yMMMd(l10n.localeName);
    final timeFormat = DateFormat.Hm(l10n.localeName);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context pdfContext) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(bottom: 20.0),
            child: pw.Text(
              l10n.journalPdf_title,
              style: pw.TextStyle(font: boldFont, fontSize: 18),
            ),
          );
        },
        footer: (pw.Context pdfContext) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10.0),
            child: pw.Text(
              l10n.journalPdf_footer_pageInfo(pdfContext.pageNumber, pdfContext.pagesCount),
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
          );
        },
        build: (pw.Context pdfContext) => [
          pw.Header(
            level: 1,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  l10n.journalPdf_period(dateFormat.format(startDate), dateFormat.format(endDate)),
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            // context: pdfContext, // context est implicite pour TableHelper
            headerStyle: pw.TextStyle(font: boldFont, fontSize: 10),
            cellStyle: pw.TextStyle(font: font, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey600, width: 1.5),
              ),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.centerLeft, // Date
              1: pw.Alignment.centerLeft, // Heure
              2: pw.Alignment.centerLeft, // Description
              3: pw.Alignment.centerRight, // Débit
              4: pw.Alignment.centerRight, // Crédit
              5: pw.Alignment.centerRight, // Solde
            },
            headers: [
              l10n.journalPdf_tableHeader_date,
              l10n.journalPdf_tableHeader_time,
              l10n.journalPdf_tableHeader_description,
              l10n.journalPdf_tableHeader_debit,
              l10n.journalPdf_tableHeader_credit,
              l10n.journalPdf_tableHeader_balance,
            ],
            data: <List<String>>[
              [
                '',
                '',
                l10n.journalPdf_openingBalance, 
                '',
                '',
                // Ensure openingBalance is formatted using the entry's currency if available,
                // otherwise use the active currency. For simplicity, using active currency here.
                currencyFormat.format(openingBalance),
              ],
              ...entries.map(
                (entry) {
                  // Determine the currency format for this specific entry
                  final entryCurrencyFormat = NumberFormat.currency(
                    locale: l10n.localeName,
                    name: entry.currencyCode ?? settings.activeCurrency.code,
                  );
                  return [
                    dateFormat.format(entry.date),
                    timeFormat.format(entry.date),
                    entry.description,
                    entry.isDebit ? entryCurrencyFormat.format(entry.amount.abs()) : '', // Use .abs() for debit/credit amounts
                    entry.isCredit ? entryCurrencyFormat.format(entry.amount.abs()) : '', // Use .abs()
                    entryCurrencyFormat.format(entry.balanceAfter),
                  ];
                },
              ),
              [
                '',
                '',
                l10n.journalPdf_closingBalance,
                '',
                '',
                // Format closing balance with the currency of the last entry or active currency
                currencyFormat.format(entries.isNotEmpty ? entries.last.balanceAfter : openingBalance),
              ],
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Text(
              l10n.journalPdf_footer_generatedBy,
              style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey),
            ),
          )
        ],
      ),
    );

    try {
      final outputDir = await getApplicationDocumentsDirectory();
      final downloadsDir = await getDownloadsDirectory();
      final targetDir = downloadsDir ?? outputDir; // Préfère Téléchargements

      final String fileName = 'operation_journal_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final File file = File("${targetDir.path}/$fileName");
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      // print('Error generating PDF: $e');
      rethrow;
    }
  }

  // Placeholder for printJournalPdf
  Future<void> printJournalPdf(File pdfFile) async {
    // This is a placeholder. Implementation would depend on the desired printing mechanism.
    // For example, using the 'printing' package:
    // await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfFile.readAsBytes());
    // Or, if you want to share/open the PDF:
    // await Printing.sharePdf(bytes: await pdfFile.readAsBytes(), filename: pdfFile.path.split('/').last);
    print("Printing PDF: ${pdfFile.path}"); // Placeholder action
    // Depending on the app's requirements, you might use a package like `open_file` to open the PDF
    // or `printing` to send it to a printer.
    // For now, this method is a stub.
  }
}
