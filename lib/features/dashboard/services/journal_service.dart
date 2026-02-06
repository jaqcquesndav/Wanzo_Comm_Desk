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

/// Service pour la génération du journal des opérations en PDF
///
/// IMPORTANT: Le journal est maintenant séparé par catégorie comptable:
/// - Trésorerie (Classe 5 OHADA): Encaissements et Décaissements
/// - Ventes/Revenus (Classe 7 OHADA): Chiffre d'affaires
/// - Stock (Classe 3 OHADA): Mouvements d'inventaire
class JournalService {
  /// Génère un PDF du journal avec les opérations SÉPARÉES PAR CATÉGORIE
  /// pour éviter les incohérences comptables
  Future<File?> generateJournalPdf(
    List<OperationJournalEntry> entries,
    DateTime startDate,
    DateTime endDate,
    double openingBalance, // Utilisé comme solde d'ouverture de TRÉSORERIE
    AppLocalizations l10n,
    Settings settings,
  ) async {
    pw.RichText.debug = true;

    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final currencyFormat = NumberFormat.currency(
      locale: l10n.localeName,
      name: settings.activeCurrency.code,
    );

    final dateFormat = DateFormat.yMMMd(l10n.localeName);
    final timeFormat = DateFormat.Hm(l10n.localeName);

    // === SÉPARER LES OPÉRATIONS PAR CATÉGORIE COMPTABLE ===
    final cashOperations = entries.where((e) => e.type.impactsCash).toList();
    final salesOperations =
        entries.where((e) => e.type.isSalesOperation).toList();
    final stockOperations = entries.where((e) => e.type.impactsStock).toList();
    final otherOperations =
        entries
            .where(
              (e) =>
                  !e.type.impactsCash &&
                  !e.type.isSalesOperation &&
                  !e.type.impactsStock,
            )
            .toList();

    // === CALCULER LES TOTAUX PAR CATÉGORIE ===
    double totalCashIn = 0.0;
    double totalCashOut = 0.0;
    double totalSales = 0.0;
    double totalStockIn = 0.0;
    double totalStockOut = 0.0;

    for (final op in cashOperations) {
      if (op.amount > 0) {
        totalCashIn += op.amount;
      } else {
        totalCashOut += op.amount.abs();
      }
    }

    for (final op in salesOperations) {
      totalSales += op.amount.abs();
    }

    for (final op in stockOperations) {
      if (op.type == OperationType.stockIn) {
        totalStockIn += op.amount.abs();
      } else {
        totalStockOut += op.amount.abs();
      }
    }

    // Solde final de trésorerie
    final closingCashBalance = openingBalance + totalCashIn - totalCashOut;

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
              l10n.journalPdf_footer_pageInfo(
                pdfContext.pageNumber,
                pdfContext.pagesCount,
              ),
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
          );
        },
        build:
            (pw.Context pdfContext) => [
              // === EN-TÊTE AVEC PÉRIODE ===
              pw.Header(
                level: 1,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      l10n.journalPdf_period(
                        dateFormat.format(startDate),
                        dateFormat.format(endDate),
                      ),
                      style: pw.TextStyle(font: font, fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // === RÉSUMÉ PAR CATÉGORIE ===
              _buildSummarySection(
                font: font,
                boldFont: boldFont,
                currencyFormat: currencyFormat,
                openingBalance: openingBalance,
                closingCashBalance: closingCashBalance,
                totalCashIn: totalCashIn,
                totalCashOut: totalCashOut,
                totalSales: totalSales,
                totalStockIn: totalStockIn,
                totalStockOut: totalStockOut,
              ),
              pw.SizedBox(height: 20),

              // === SECTION 1: JOURNAL DE TRÉSORERIE ===
              if (cashOperations.isNotEmpty) ...[
                _buildSectionHeader(
                  '📊 JOURNAL DE TRÉSORERIE',
                  boldFont,
                  PdfColors.blue700,
                ),
                pw.SizedBox(height: 5),
                _buildCashTable(
                  cashOperations,
                  openingBalance,
                  font,
                  boldFont,
                  currencyFormat,
                  dateFormat,
                  timeFormat,
                  l10n,
                  settings,
                ),
                pw.SizedBox(height: 20),
              ],

              // === SECTION 2: JOURNAL DES VENTES ===
              if (salesOperations.isNotEmpty) ...[
                _buildSectionHeader(
                  '💰 JOURNAL DES VENTES',
                  boldFont,
                  PdfColors.green700,
                ),
                pw.SizedBox(height: 5),
                _buildSalesTable(
                  salesOperations,
                  font,
                  boldFont,
                  currencyFormat,
                  dateFormat,
                  timeFormat,
                  l10n,
                  settings,
                ),
                pw.SizedBox(height: 20),
              ],

              // === SECTION 3: JOURNAL DES STOCKS ===
              if (stockOperations.isNotEmpty) ...[
                _buildSectionHeader(
                  '📦 JOURNAL DES STOCKS',
                  boldFont,
                  PdfColors.orange700,
                ),
                pw.SizedBox(height: 5),
                _buildStockTable(
                  stockOperations,
                  font,
                  boldFont,
                  currencyFormat,
                  dateFormat,
                  timeFormat,
                  l10n,
                  settings,
                ),
                pw.SizedBox(height: 20),
              ],

              // === SECTION 4: AUTRES OPÉRATIONS ===
              if (otherOperations.isNotEmpty) ...[
                _buildSectionHeader(
                  '📋 AUTRES OPÉRATIONS',
                  boldFont,
                  PdfColors.grey700,
                ),
                pw.SizedBox(height: 5),
                _buildOtherTable(
                  otherOperations,
                  font,
                  boldFont,
                  currencyFormat,
                  dateFormat,
                  timeFormat,
                  l10n,
                  settings,
                ),
                pw.SizedBox(height: 20),
              ],

              // === PIED DE PAGE ===
              pw.SizedBox(height: 30),
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  l10n.journalPdf_footer_generatedBy,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 9,
                    color: PdfColors.grey,
                  ),
                ),
              ),
            ],
      ),
    );

    try {
      final outputDir = await getApplicationDocumentsDirectory();
      final downloadsDir = await getDownloadsDirectory();
      final targetDir = downloadsDir ?? outputDir;

      final String fileName =
          'operation_journal_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final File file = File("${targetDir.path}/$fileName");
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      rethrow;
    }
  }

  /// Section résumé avec les totaux par catégorie
  pw.Widget _buildSummarySection({
    required pw.Font font,
    required pw.Font boldFont,
    required NumberFormat currencyFormat,
    required double openingBalance,
    required double closingCashBalance,
    required double totalCashIn,
    required double totalCashOut,
    required double totalSales,
    required double totalStockIn,
    required double totalStockOut,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RÉSUMÉ DES OPÉRATIONS',
            style: pw.TextStyle(font: boldFont, fontSize: 12),
          ),
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 8),

          // Trésorerie
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Solde de trésorerie initial:',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.Text(
                currencyFormat.format(openingBalance),
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '  + Encaissements:',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: PdfColors.green700,
                ),
              ),
              pw.Text(
                currencyFormat.format(totalCashIn),
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: PdfColors.green700,
                ),
              ),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '  - Décaissements:',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: PdfColors.red700,
                ),
              ),
              pw.Text(
                currencyFormat.format(totalCashOut),
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: PdfColors.red700,
                ),
              ),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '= Solde de trésorerie final:',
                style: pw.TextStyle(font: boldFont, fontSize: 10),
              ),
              pw.Text(
                currencyFormat.format(closingCashBalance),
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                  color:
                      closingCashBalance >= 0
                          ? PdfColors.green700
                          : PdfColors.red700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 0.5, color: PdfColors.grey300),
          pw.SizedBox(height: 8),

          // Ventes
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Chiffre d\'affaires (Ventes):',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.Text(
                currencyFormat.format(totalSales),
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                  color: PdfColors.blue700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),

          // Stock
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Mouvements de stock:',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.Text(
                'Entrées: ${currencyFormat.format(totalStockIn)} | Sorties: ${currencyFormat.format(totalStockOut)}',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construit un en-tête de section coloré
  pw.Widget _buildSectionHeader(
    String title,
    pw.Font boldFont,
    PdfColor color,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: boldFont,
          fontSize: 11,
          color: PdfColors.white,
        ),
      ),
    );
  }

  /// Table de trésorerie avec solde courant
  pw.Widget _buildCashTable(
    List<OperationJournalEntry> operations,
    double openingBalance,
    pw.Font font,
    pw.Font boldFont,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
    DateFormat timeFormat,
    AppLocalizations l10n,
    Settings settings,
  ) {
    double runningBalance = openingBalance;

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(font: boldFont, fontSize: 9),
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blue700, width: 1),
        ),
      ),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headers: [
        'Date',
        'Description',
        'Encaissement',
        'Décaissement',
        'Solde Caisse',
      ],
      data: <List<String>>[
        [
          '',
          'Solde d\'ouverture',
          '',
          '',
          currencyFormat.format(openingBalance),
        ],
        ...operations.map((entry) {
          final entryCurrencyFormat = NumberFormat.currency(
            locale: l10n.localeName,
            name: entry.currencyCode ?? settings.activeCurrency.code,
          );

          final isIn = entry.amount > 0;
          runningBalance += entry.amount;

          return [
            '${dateFormat.format(entry.date)} ${timeFormat.format(entry.date)}',
            entry.description,
            isIn ? entryCurrencyFormat.format(entry.amount) : '',
            !isIn ? entryCurrencyFormat.format(entry.amount.abs()) : '',
            entryCurrencyFormat.format(runningBalance),
          ];
        }),
        ['', 'Solde de clôture', '', '', currencyFormat.format(runningBalance)],
      ],
    );
  }

  /// Table des ventes avec cumul
  pw.Widget _buildSalesTable(
    List<OperationJournalEntry> operations,
    pw.Font font,
    pw.Font boldFont,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
    DateFormat timeFormat,
    AppLocalizations l10n,
    Settings settings,
  ) {
    double runningTotal = 0.0;

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(font: boldFont, fontSize: 9),
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.green700, width: 1),
        ),
      ),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headers: ['Date', 'Client', 'Type de vente', 'Montant', 'Cumul CA'],
      data: <List<String>>[
        ...operations.map((entry) {
          final entryCurrencyFormat = NumberFormat.currency(
            locale: l10n.localeName,
            name: entry.currencyCode ?? settings.activeCurrency.code,
          );

          runningTotal += entry.amount.abs();

          return [
            '${dateFormat.format(entry.date)} ${timeFormat.format(entry.date)}',
            entry.customerName ?? '-',
            entry.type.displayName,
            entryCurrencyFormat.format(entry.amount.abs()),
            entryCurrencyFormat.format(runningTotal),
          ];
        }),
        [
          '',
          '',
          'TOTAL CHIFFRE D\'AFFAIRES',
          '',
          currencyFormat.format(runningTotal),
        ],
      ],
    );
  }

  /// Table des stocks avec valeur
  pw.Widget _buildStockTable(
    List<OperationJournalEntry> operations,
    pw.Font font,
    pw.Font boldFont,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
    DateFormat timeFormat,
    AppLocalizations l10n,
    Settings settings,
  ) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(font: boldFont, fontSize: 9),
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.orange50,
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.orange700, width: 1),
        ),
      ),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headers: ['Date', 'Produit', 'Mouvement', 'Quantité', 'Valeur'],
      data: <List<String>>[
        ...operations.map((entry) {
          final entryCurrencyFormat = NumberFormat.currency(
            locale: l10n.localeName,
            name: entry.currencyCode ?? settings.activeCurrency.code,
          );

          final isIn = entry.type == OperationType.stockIn;

          return [
            '${dateFormat.format(entry.date)} ${timeFormat.format(entry.date)}',
            entry.productName ?? entry.description,
            isIn ? '↑ Entrée' : '↓ Sortie',
            entry.quantity?.toStringAsFixed(0) ?? '-',
            entryCurrencyFormat.format(entry.amount.abs()),
          ];
        }),
      ],
    );
  }

  /// Table des autres opérations
  pw.Widget _buildOtherTable(
    List<OperationJournalEntry> operations,
    pw.Font font,
    pw.Font boldFont,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
    DateFormat timeFormat,
    AppLocalizations l10n,
    Settings settings,
  ) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(font: boldFont, fontSize: 9),
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey700, width: 1),
        ),
      ),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
      },
      headers: ['Date', 'Type', 'Description', 'Montant'],
      data: <List<String>>[
        ...operations.map((entry) {
          final entryCurrencyFormat = NumberFormat.currency(
            locale: l10n.localeName,
            name: entry.currencyCode ?? settings.activeCurrency.code,
          );

          return [
            '${dateFormat.format(entry.date)} ${timeFormat.format(entry.date)}',
            entry.type.displayName,
            entry.description,
            entryCurrencyFormat.format(entry.amount),
          ];
        }),
      ],
    );
  }

  // Placeholder for printJournalPdf
  Future<void> printJournalPdf(File pdfFile) async {
    print("Printing PDF: ${pdfFile.path}");
  }
}
