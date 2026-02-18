import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/features/dashboard/models/operation_journal_entry.dart';
import 'package:wanzo/features/settings/models/settings.dart';

/// Service pour la génération du journal des opérations en PDF
///
/// Architecture: UN tableau principal unique chronologique avec soldes cohérents
/// par catégorie comptable OHADA (pas de mélange de classes).
///
/// La colonne CATÉGORIE identifie chaque opération et la colonne SOLDE
/// affiche le solde courant de SA propre catégorie comptable.
class JournalService {
  /// Génère un PDF du journal avec UN tableau principal unique
  /// et des soldes cohérents par catégorie comptable
  Future<File?> generateJournalPdf(
    List<OperationJournalEntry> entries,
    DateTime startDate,
    DateTime endDate,
    double openingBalance, // Solde d'ouverture de TRÉSORERIE
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

    // Trier chronologiquement
    final sortedEntries = List<OperationJournalEntry>.from(entries);
    sortedEntries.sort((a, b) => a.date.compareTo(b.date));

    // Catégoriser pour les totaux
    final cashOperations = entries.where((e) => e.type.impactsCash).toList();
    final salesOperations =
        entries.where((e) => e.type.isSalesOperation).toList();
    final stockOperations = entries.where((e) => e.type.impactsStock).toList();

    // Calculer les totaux PAR CATÉGORIE
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
              // En-tête avec période
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

              // Résumé par catégorie
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

              // ═══════════════════════════════════════════
              // TABLEAU PRINCIPAL UNIQUE – Chronologique
              // ═══════════════════════════════════════════
              _buildUnifiedTable(
                sortedEntries,
                openingBalance,
                font,
                boldFont,
                currencyFormat,
                dateFormat,
                timeFormat,
                l10n,
                settings,
              ),

              // Pied de page
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

  // ==========================================================================
  // TABLEAU PRINCIPAL UNIQUE
  // ==========================================================================

  /// Construit UN seul tableau chronologique avec toutes les opérations
  /// et des soldes cohérents par catégorie comptable
  pw.Widget _buildUnifiedTable(
    List<OperationJournalEntry> operations,
    double openingCashBalance,
    pw.Font font,
    pw.Font boldFont,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
    DateFormat timeFormat,
    AppLocalizations l10n,
    Settings settings,
  ) {
    // Soldes courants par catégorie
    double runningCashBalance = openingCashBalance;
    double runningSalesTotal = 0.0;
    double runningStockValue = 0.0;

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(font: boldFont, fontSize: 8),
      cellStyle: pw.TextStyle(font: font, fontSize: 7),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey700, width: 1),
        ),
      ),
      cellAlignments: {
        0: pw.Alignment.center, // N°
        1: pw.Alignment.centerLeft, // Date
        2: pw.Alignment.center, // Catégorie
        3: pw.Alignment.centerLeft, // Description
        4: pw.Alignment.centerRight, // Débit
        5: pw.Alignment.centerRight, // Crédit
        6: pw.Alignment.centerRight, // Solde
      },
      headers: [
        'N°',
        'Date / Heure',
        'Catégorie',
        'Description',
        'Débit',
        'Crédit',
        'Solde',
      ],
      data: <List<String>>[
        // Ligne d'ouverture
        [
          '',
          '',
          'OUVERTURE',
          'Solde d\'ouverture en caisse',
          '',
          '',
          currencyFormat.format(openingCashBalance),
        ],
        // Lignes de données chronologiques
        ...operations.asMap().entries.map((e) {
          final index = e.key;
          final entry = e.value;
          final entryCurrencyFormat = NumberFormat.currency(
            locale: l10n.localeName,
            name: entry.currencyCode ?? settings.activeCurrency.code,
          );

          // Catégorie comptable
          final category = _getCategory(entry.type);

          // Calculer le solde courant de la catégorie
          String soldeText;
          if (entry.type.impactsCash) {
            runningCashBalance += entry.amount;
            soldeText = entryCurrencyFormat.format(
              entry.cashBalance ?? runningCashBalance,
            );
          } else if (entry.type.isSalesOperation) {
            runningSalesTotal += entry.amount.abs();
            soldeText = entryCurrencyFormat.format(
              entry.salesBalance ?? runningSalesTotal,
            );
          } else if (entry.type.impactsStock) {
            if (entry.type == OperationType.stockIn) {
              runningStockValue += entry.amount.abs();
            } else {
              runningStockValue -= entry.amount.abs();
            }
            soldeText = entryCurrencyFormat.format(
              entry.stockValue ?? runningStockValue,
            );
          } else {
            soldeText = entryCurrencyFormat.format(entry.amount);
          }

          // Débit / Crédit
          final isDebit = entry.amount < 0 || entry.isDebit;
          final debitText =
              isDebit ? entryCurrencyFormat.format(entry.amount.abs()) : '';
          final creditText =
              !isDebit ? entryCurrencyFormat.format(entry.amount.abs()) : '';

          return [
            '${index + 1}',
            '${dateFormat.format(entry.date)} ${timeFormat.format(entry.date)}',
            category,
            entry.description,
            debitText,
            creditText,
            soldeText,
          ];
        }),
        // Ligne de soldes finaux par catégorie
        if (operations.where((e) => e.type.impactsCash).isNotEmpty)
          [
            '',
            '',
            '',
            'Solde Caisse (Classe 5)',
            '',
            '',
            currencyFormat.format(runningCashBalance),
          ],
        if (operations.where((e) => e.type.isSalesOperation).isNotEmpty)
          [
            '',
            '',
            '',
            'Cumul CA / Ventes (Classe 7)',
            '',
            '',
            currencyFormat.format(runningSalesTotal),
          ],
        if (operations.where((e) => e.type.impactsStock).isNotEmpty)
          [
            '',
            '',
            '',
            'Valeur Stock (Classe 3)',
            '',
            '',
            currencyFormat.format(runningStockValue),
          ],
      ],
    );
  }

  /// Retourne le label de catégorie comptable
  String _getCategory(OperationType type) {
    if (type.impactsCash) return 'TRÉSO';
    if (type.isSalesOperation) return 'VENTES';
    if (type.impactsStock) return 'STOCK';
    return 'AUTRE';
  }

  // ==========================================================================
  // RÉSUMÉ PAR CATÉGORIE
  // ==========================================================================

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
            'RÉSUMÉ PAR CATÉGORIE COMPTABLE',
            style: pw.TextStyle(font: boldFont, fontSize: 12),
          ),
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 8),

          // Trésorerie (Classe 5)
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

          // Ventes (Classe 7)
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

          // Stock (Classe 3)
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

  // Placeholder for printJournalPdf
  Future<void> printJournalPdf(File pdfFile) async {
    // ignore: avoid_print
    debugPrint("Printing PDF: ${pdfFile.path}");
  }
}
