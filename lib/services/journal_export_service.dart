import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import '../core/enums/currency_enum.dart';
import '../core/services/currency_service.dart';
import '../features/dashboard/models/journal_filter.dart';
import '../features/dashboard/models/operation_journal_entry.dart';
import '../features/auth/models/user.dart';

/// Service pour l'exportation du journal des opérations
///
/// Architecture: UN tableau principal unique chronologique avec soldes cohérents
/// par catégorie comptable OHADA (pas de mélange de classes).
///
/// La colonne CATÉGORIE identifie chaque opération (TRÉSO, VENTES, STOCK, AUTRE)
/// et la colonne SOLDE affiche le solde courant de SA propre catégorie:
///   - TRÉSO  → Solde de caisse (Classe 5)
///   - VENTES → Cumul CA (Classe 7)
///   - STOCK  → Valeur stock (Classe 3)
///   - AUTRE  → Cumul autres
///
/// Quand un filtre spécifique est appliqué (ex: Trésorerie uniquement),
/// le tableau ne contient naturellement que cette catégorie = rapport spécifique.
class JournalExportService {
  // Constantes de mise en page
  static const double _fontSize = 8.0;
  static const double _fontSizeSmall = 7.0;
  static const double _fontSizeTitle = 10.0;
  static const double _cellPadding = 4.0;
  static const double _qrSize = 60.0;

  // ==========================================================================
  // POINT D'ENTRÉE PRINCIPAL
  // ==========================================================================

  /// Exporte le journal des opérations filtré en PDF
  /// Produit UN tableau principal unique chronologique avec soldes cohérents.
  ///
  /// Les totaux sont convertis en CDF avec les taux de [currencyService]
  /// (sinon les taux enregistrés localement).
  static Future<File> exportToPdf({
    required List<OperationJournalEntry> operations,
    required JournalFilter filter,
    required User? currentUser,
    String? companyName,
    String? companyAddress,
    CurrencyService? currencyService,
  }) async {
    final settings = await _getBusinessSettings();
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoMonoRegular();
    final fontBold = await PdfGoogleFonts.robotoMonoBold();
    final rates = await _loadRates(currencyService);

    // Générer les données d'authentification pour le QR code
    final exportId = _generateExportId();
    final qrData = _generateQrData(
      exportId: exportId,
      operations: operations,
      rates: rates,
      filter: filter,
      currentUser: currentUser,
      settings: settings,
    );

    // Trier les opérations chronologiquement
    final sortedOperations = List<OperationJournalEntry>.from(operations);
    sortedOperations.sort((a, b) => a.date.compareTo(b.date));

    // Catégoriser pour les totaux de synthèse (ordre chronologique)
    final cashOperations =
        sortedOperations.where((e) => e.type.impactsCash).toList();
    final salesOperations =
        sortedOperations.where((e) => e.type.isSalesOperation).toList();
    final stockOperations =
        sortedOperations.where((e) => e.type.impactsStock).toList();
    final otherOperations =
        sortedOperations
            .where(
              (e) =>
                  !e.type.impactsCash &&
                  !e.type.isSalesOperation &&
                  !e.type.impactsStock,
            )
            .toList();

    // Calculer les totaux PAR CATÉGORIE (contre-valeur CDF)
    final categoryTotals = _calculateCategoryTotals(
      cashOperations: cashOperations,
      salesOperations: salesOperations,
      stockOperations: stockOperations,
      rates: rates,
    );

    final cashIn = (categoryTotals['cashIn'] as double?) ?? 0.0;
    final cashOut = (categoryTotals['cashOut'] as double?) ?? 0.0;
    final cashNet = cashIn - cashOut;
    final salesTotal = (categoryTotals['salesTotal'] as double?) ?? 0.0;
    final stockIn = (categoryTotals['stockIn'] as double?) ?? 0.0;
    final stockOut = (categoryTotals['stockOut'] as double?) ?? 0.0;
    final otherTotal = otherOperations.fold<double>(
      0.0,
      (sum, e) => sum + _entryToCdf(rates, e, e.amount),
    );

    // Solde d'ouverture caisse consolidé : soldes de chaque devise avant la
    // première opération de trésorerie, convertis un à un
    final openingBalance = _openingCashByCurrency(cashOperations).entries
        .fold<double>(0.0, (sum, e) => sum + _toCdf(rates, e.key, e.value));

    // Titre dynamique selon le filtre
    final reportTitle = _getReportTitle(filter);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header:
            (context) => _buildSimpleHeader(
              context,
              settings,
              font,
              fontBold,
              filter,
              exportId,
              reportTitle,
            ),
        footer: (context) => _buildSimpleFooter(context, font, exportId),
        build:
            (context) => [
              // Métadonnées du rapport
              _buildMetadataSection(
                font,
                fontBold,
                filter,
                currentUser,
                operations.length,
                qrData,
              ),
              pw.SizedBox(height: 10),

              // Résumé financier par catégorie
              _buildCategorizedSummary(categoryTotals, font, fontBold),
              pw.SizedBox(height: 15),

              // ═══════════════════════════════════════════════
              // TABLEAU PRINCIPAL UNIQUE – Journal chronologique
              // ═══════════════════════════════════════════════
              ..._buildUnifiedJournalTable(
                operations: sortedOperations,
                font: font,
                fontBold: fontBold,
              ),

              // ═══════════════════════════════════════════════
              // SYNTHÈSE DE CLÔTURE PAR CLASSE COMPTABLE
              // ═══════════════════════════════════════════════
              pw.SizedBox(height: 15),
              _buildClosingSynthesis(
                font: font,
                fontBold: fontBold,
                rates: rates,
                openingBalance: openingBalance,
                cashIn: cashIn,
                cashOut: cashOut,
                cashNet: cashNet,
                salesTotal: salesTotal,
                stockIn: stockIn,
                stockOut: stockOut,
                otherTotal: otherTotal,
                cashOperations: cashOperations,
                stockOperations: stockOperations,
              ),
            ],
      ),
    );

    // Fichier de travail : dossier temporaire sur desktop (le dossier
    // Documents de Windows est celui de l'utilisateur, on ne l'encombre pas ;
    // « Enregistrer sous » laisse choisir l'emplacement final).
    final directory =
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            ? await getTemporaryDirectory()
            : await getApplicationDocumentsDirectory();
    final fileName = 'journal_$exportId.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ==========================================================================
  // TABLEAU PRINCIPAL UNIQUE
  // ==========================================================================

  /// Construit UN seul tableau chronologique avec toutes les opérations.
  ///
  /// Chaque ligne affiche sa catégorie comptable via un badge coloré,
  /// et la colonne SOLDE montre le solde courant de CETTE catégorie.
  ///
  /// En bas du tableau: lignes de clôture par catégorie.
  static List<pw.Widget> _buildUnifiedJournalTable({
    required List<OperationJournalEntry> operations,
    required pw.Font font,
    required pw.Font fontBold,
  }) {
    if (operations.isEmpty) {
      return [
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Aucune opération pour la période sélectionnée.',
            style: pw.TextStyle(
              font: font,
              fontSize: _fontSize,
              color: PdfColors.grey600,
            ),
          ),
        ),
      ];
    }

    final List<pw.Widget> widgets = [];

    // Grouper par devise pour traitement multi-devises
    final grouped = _groupOperationsByCurrency(operations);

    for (final entry in grouped.entries) {
      final currency = entry.key;
      final ops = entry.value;
      if (ops.isEmpty) continue;

      // Indicateur de devise : les montants du tableau sont en $currency
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 10, bottom: 5),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Text(
            'DEVISE: $currency',
            style: pw.TextStyle(font: fontBold, fontSize: _fontSize),
          ),
        ),
      );

      // Soldes courants par catégorie pour cette devise : l'ouverture ne
      // vient que des opérations de trésorerie en $currency
      final openingCashBalance =
          _openingCashByCurrency(ops)[currency] ?? 0.0;
      double runningCashBalance = openingCashBalance;
      double runningSalesTotal = 0.0;
      double runningStockValue = 0.0;
      double runningOtherTotal = 0.0;

      // ── En-tête du tableau ──
      final List<pw.TableRow> rows = [];

      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey800),
          children: [
            _buildHeaderCell('N°', fontBold, color: PdfColors.white),
            _buildHeaderCell('DATE', fontBold, color: PdfColors.white),
            _buildHeaderCell('CATÉGORIE', fontBold, color: PdfColors.white),
            _buildHeaderCell('DESCRIPTION', fontBold, color: PdfColors.white),
            _buildHeaderCell(
              'DÉBIT',
              fontBold,
              align: pw.TextAlign.right,
              color: PdfColors.white,
            ),
            _buildHeaderCell(
              'CRÉDIT',
              fontBold,
              align: pw.TextAlign.right,
              color: PdfColors.white,
            ),
            _buildHeaderCell(
              'SOLDE',
              fontBold,
              align: pw.TextAlign.right,
              color: PdfColors.white,
            ),
          ],
        ),
      );

      // ── Ligne de solde d'ouverture caisse ──
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            _buildDataCell('', font),
            _buildDataCell('', font),
            _buildCategoryBadge('OUVERTURE', font, PdfColors.blue800),
            _buildDataCell(
              'Solde d\'ouverture en caisse ($currency)',
              font,
              color: PdfColors.blue800,
            ),
            _buildDataCell('', font),
            _buildDataCell('', font),
            _buildDataCell(
              _formatNumber(openingCashBalance),
              font,
              align: pw.TextAlign.right,
              color: PdfColors.blue800,
            ),
          ],
        ),
      );

      // ── Lignes de données (chronologiques) ──
      for (var i = 0; i < ops.length; i++) {
        final op = ops[i];
        final isAlternate = i % 2 == 1;
        final category = _getCategoryInfo(op.type);

        // Calculer le solde courant de la catégorie de cette opération
        String soldeText;
        PdfColor soldeColor;

        if (op.type.impactsCash) {
          runningCashBalance += op.amount;
          final displayBalance = op.cashBalance ?? runningCashBalance;
          soldeText = _formatNumber(displayBalance);
          soldeColor =
              displayBalance >= 0 ? PdfColors.blue800 : PdfColors.red800;
        } else if (op.type.isSalesOperation) {
          runningSalesTotal += op.amount.abs();
          final displayBalance = op.salesBalance ?? runningSalesTotal;
          soldeText = _formatNumber(displayBalance);
          soldeColor = PdfColors.green800;
        } else if (op.type.impactsStock) {
          if (op.type == OperationType.stockIn) {
            runningStockValue += op.amount.abs();
          } else {
            runningStockValue -= op.amount.abs();
          }
          final displayBalance = op.stockValue ?? runningStockValue;
          soldeText = _formatNumber(displayBalance);
          soldeColor = PdfColors.orange800;
        } else {
          runningOtherTotal += op.amount;
          soldeText = _formatNumber(runningOtherTotal);
          soldeColor = PdfColors.grey700;
        }

        // Déterminer débit / crédit
        final isDebit = op.amount < 0 || op.isDebit;
        final debitAmount = isDebit ? op.amount.abs() : 0.0;
        final creditAmount = !isDebit ? op.amount.abs() : 0.0;

        rows.add(
          pw.TableRow(
            decoration:
                isAlternate
                    ? const pw.BoxDecoration(color: PdfColors.grey50)
                    : null,
            children: [
              _buildDataCell('${i + 1}', font, align: pw.TextAlign.center),
              _buildDataCell(DateFormat('dd/MM/yy').format(op.date), font),
              _buildCategoryBadge(
                category['label'] as String,
                font,
                category['color'] as PdfColor,
              ),
              _buildDataCell(_truncateText(op.description, 35), font),
              _buildDataCell(
                debitAmount > 0 ? _formatNumber(debitAmount) : '',
                font,
                align: pw.TextAlign.right,
                color: PdfColors.red700,
              ),
              _buildDataCell(
                creditAmount > 0 ? _formatNumber(creditAmount) : '',
                font,
                align: pw.TextAlign.right,
                color: PdfColors.green700,
              ),
              _buildDataCell(
                soldeText,
                font,
                align: pw.TextAlign.right,
                color: soldeColor,
              ),
            ],
          ),
        );
      }

      // ── Ligne de totaux Débit/Crédit ──
      final totalDebit = ops
          .where((o) => o.amount < 0 || o.isDebit)
          .fold<double>(0.0, (s, o) => s + o.amount.abs());
      final totalCredit = ops
          .where((o) => o.amount >= 0 && !o.isDebit)
          .fold<double>(0.0, (s, o) => s + o.amount.abs());

      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildDataCell('', fontBold),
            _buildDataCell('', fontBold),
            _buildDataCell('TOTAUX', fontBold),
            _buildDataCell('${ops.length} opérations', fontBold),
            _buildDataCell(
              _formatNumber(totalDebit),
              fontBold,
              align: pw.TextAlign.right,
              color: PdfColors.red800,
            ),
            _buildDataCell(
              _formatNumber(totalCredit),
              fontBold,
              align: pw.TextAlign.right,
              color: PdfColors.green800,
            ),
            _buildDataCell('', fontBold),
          ],
        ),
      );

      // ── Soldes finaux par catégorie (en bas du tableau) ──
      final cashOps = ops.where((o) => o.type.impactsCash);
      final salesOps = ops.where((o) => o.type.isSalesOperation);
      final stockOps = ops.where((o) => o.type.impactsStock);
      final otherOps = ops.where(
        (o) =>
            !o.type.impactsCash &&
            !o.type.isSalesOperation &&
            !o.type.impactsStock,
      );

      if (cashOps.isNotEmpty) {
        rows.add(
          _buildBalanceFooterRow(
            'Solde caisse $currency (Classe 5)',
            runningCashBalance,
            fontBold,
            PdfColors.blue800,
            PdfColors.blue50,
          ),
        );
      }
      if (salesOps.isNotEmpty) {
        rows.add(
          _buildBalanceFooterRow(
            'Cumul CA / Ventes $currency (Classe 7)',
            runningSalesTotal,
            fontBold,
            PdfColors.green800,
            PdfColors.green50,
          ),
        );
      }
      if (stockOps.isNotEmpty) {
        rows.add(
          _buildBalanceFooterRow(
            'Valeur stock $currency (Classe 3)',
            runningStockValue,
            fontBold,
            PdfColors.orange800,
            PdfColors.orange50,
          ),
        );
      }
      if (otherOps.isNotEmpty) {
        rows.add(
          _buildBalanceFooterRow(
            'Autres opérations $currency',
            runningOtherTotal,
            fontBold,
            PdfColors.grey700,
            PdfColors.grey100,
          ),
        );
      }

      // ── Construction du tableau ──
      widgets.add(
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
          columnWidths: const {
            0: pw.FixedColumnWidth(25), // N°
            1: pw.FixedColumnWidth(50), // Date
            2: pw.FixedColumnWidth(55), // Catégorie
            3: pw.FlexColumnWidth(2.5), // Description
            4: pw.FixedColumnWidth(70), // Débit
            5: pw.FixedColumnWidth(70), // Crédit
            6: pw.FixedColumnWidth(75), // Solde
          },
          children: rows,
        ),
      );

      // Légende des catégories
      widgets.add(pw.SizedBox(height: 5));
      widgets.add(_buildCategoryLegend(font, fontBold));
    }

    return widgets;
  }

  // ==========================================================================
  // ÉLÉMENTS DU TABLEAU PRINCIPAL
  // ==========================================================================

  /// Ligne de solde final par catégorie en bas du tableau
  static pw.TableRow _buildBalanceFooterRow(
    String label,
    double balance,
    pw.Font fontBold,
    PdfColor textColor,
    PdfColor bgColor,
  ) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bgColor),
      children: [
        _buildDataCell('', fontBold),
        _buildDataCell('', fontBold),
        _buildDataCell('', fontBold),
        pw.Padding(
          padding: const pw.EdgeInsets.all(_cellPadding),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: _fontSizeSmall,
              color: textColor,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
        _buildDataCell('', fontBold),
        _buildDataCell('', fontBold),
        pw.Padding(
          padding: const pw.EdgeInsets.all(_cellPadding),
          child: pw.Text(
            _formatNumber(balance),
            style: pw.TextStyle(
              font: fontBold,
              fontSize: _fontSizeSmall,
              color: textColor,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// Badge coloré pour identifier la catégorie comptable dans le tableau
  static pw.Widget _buildCategoryBadge(
    String label,
    pw.Font font,
    PdfColor color,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 3,
        vertical: _cellPadding,
      ),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
        ),
        child: pw.Text(
          label,
          style: pw.TextStyle(font: font, fontSize: 6, color: PdfColors.white),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  /// Légende des catégories comptables
  static pw.Widget _buildCategoryLegend(pw.Font font, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.3, color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Text(
            'Légende catégories / soldes:',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 6,
              color: PdfColors.grey600,
            ),
          ),
          _legendItem('TRÉSO', 'Solde Caisse', PdfColors.blue800, font),
          _legendItem('VENTES', 'Cumul CA', PdfColors.green800, font),
          _legendItem('STOCK', 'Val. Stock', PdfColors.orange800, font),
          _legendItem('AUTRE', 'Cumul', PdfColors.grey700, font),
        ],
      ),
    );
  }

  static pw.Widget _legendItem(
    String badge,
    String meaning,
    PdfColor color,
    pw.Font font,
  ) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
          child: pw.Text(
            badge,
            style: pw.TextStyle(
              font: font,
              fontSize: 5,
              color: PdfColors.white,
            ),
          ),
        ),
        pw.SizedBox(width: 2),
        pw.Text('= $meaning', style: pw.TextStyle(font: font, fontSize: 6)),
      ],
    );
  }

  /// Détermine la catégorie comptable d'une opération
  static Map<String, dynamic> _getCategoryInfo(OperationType type) {
    if (type.impactsCash) {
      return {'label': 'TRÉSO', 'color': PdfColors.blue800};
    } else if (type.isSalesOperation) {
      return {'label': 'VENTES', 'color': PdfColors.green800};
    } else if (type.impactsStock) {
      return {'label': 'STOCK', 'color': PdfColors.orange800};
    }
    return {'label': 'AUTRE', 'color': PdfColors.grey700};
  }

  // ==========================================================================
  // TITRE DYNAMIQUE SELON FILTRE
  // ==========================================================================

  /// Détermine le titre du rapport selon le filtre actif
  /// Produit un rapport spécifique quand un filtre de catégorie est appliqué
  static String _getReportTitle(JournalFilter filter) {
    if (filter.selectedTypes.isEmpty ||
        filter.selectedTypes.length == OperationType.values.length) {
      return 'JOURNAL DES OPERATIONS';
    }

    final allCash = filter.selectedTypes.every((t) => t.impactsCash);
    final allSales = filter.selectedTypes.every((t) => t.isSalesOperation);
    final allStock = filter.selectedTypes.every((t) => t.impactsStock);

    if (allCash) return 'JOURNAL DE TRESORERIE';
    if (allSales) return 'JOURNAL DES VENTES';
    if (allStock) return 'JOURNAL DES STOCKS';

    return 'JOURNAL DES OPERATIONS';
  }

  // ==========================================================================
  // EN-TÊTE, PIED DE PAGE, MÉTADONNÉES
  // ==========================================================================

  static String _generateExportId() {
    final now = DateTime.now();
    return '${DateFormat('yyyyMMddHHmmss').format(now)}-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
  }

  static String _generateQrData({
    required String exportId,
    required List<OperationJournalEntry> operations,
    required CurrencyService rates,
    required JournalFilter filter,
    required User? currentUser,
    required dynamic settings,
  }) {
    final totals = _calculateTotals(operations, rates);
    final dataToHash =
        '$exportId|${operations.length}|${totals['totalInflow']}|${totals['totalOutflow']}';
    final hash = sha256
        .convert(utf8.encode(dataToHash))
        .toString()
        .substring(0, 12);

    final qrContent = {
      'id': exportId,
      'company': settings.companyName ?? 'WANZO',
      'date': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      'user': currentUser?.email ?? 'N/A',
      'ops': operations.length,
      'in': totals['totalInflow'],
      'out': totals['totalOutflow'],
      'hash': hash,
    };
    return jsonEncode(qrContent);
  }

  /// En-tête professionnel (chaque page)
  static pw.Widget _buildSimpleHeader(
    pw.Context context,
    dynamic settings,
    pw.Font font,
    pw.Font fontBold,
    JournalFilter filter,
    String exportId,
    String reportTitle,
  ) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    String periodText = 'Toutes périodes';

    if (filter.startDate != null && filter.endDate != null) {
      periodText =
          '${dateFormat.format(filter.startDate!)} - ${dateFormat.format(filter.endDate!)}';
    } else if (filter.startDate != null) {
      periodText = 'Depuis ${dateFormat.format(filter.startDate!)}';
    } else if (filter.endDate != null) {
      periodText = 'Jusqu\'au ${dateFormat.format(filter.endDate!)}';
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    settings.companyName ?? 'WANZO',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: _fontSizeTitle,
                    ),
                  ),
                  pw.Text(
                    settings.companyAddress ?? 'Kinshasa, RDC',
                    style: pw.TextStyle(font: font, fontSize: _fontSizeSmall),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    reportTitle,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: _fontSizeTitle,
                    ),
                  ),
                  pw.Text(
                    'Période: $periodText',
                    style: pw.TextStyle(font: font, fontSize: _fontSizeSmall),
                  ),
                  pw.Text(
                    'Réf: $exportId',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: _fontSizeSmall,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
        ],
      ),
    );
  }

  /// Pied de page (chaque page)
  static pw.Widget _buildSimpleFooter(
    pw.Context context,
    pw.Font font,
    String exportId,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 5),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 0.5, color: PdfColors.grey400),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Export: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())} | Réf: $exportId',
            style: pw.TextStyle(
              font: font,
              fontSize: 6,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber}/${context.pagesCount}',
            style: pw.TextStyle(
              font: font,
              fontSize: 6,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  /// Section métadonnées avec QR code de vérification
  static pw.Widget _buildMetadataSection(
    pw.Font font,
    pw.Font fontBold,
    JournalFilter filter,
    User? currentUser,
    int operationCount,
    String qrData,
  ) {
    final List<String> activeFilters = [];

    if (filter.selectedTypes.isNotEmpty &&
        filter.selectedTypes.length < OperationType.values.length) {
      activeFilters.add(
        'Types: ${filter.selectedTypes.map((t) => t.displayName).join(", ")}',
      );
    }

    if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      activeFilters.add('Recherche: "${filter.searchQuery}"');
    }

    if (filter.minAmount != null || filter.maxAmount != null) {
      String amountFilter = 'Montant: ';
      if (filter.minAmount != null && filter.maxAmount != null) {
        amountFilter +=
            '${_formatNumber(filter.minAmount!)} - ${_formatNumber(filter.maxAmount!)}';
      } else if (filter.minAmount != null) {
        amountFilter += '>= ${_formatNumber(filter.minAmount!)}';
      } else {
        amountFilter += '<= ${_formatNumber(filter.maxAmount!)}';
      }
      activeFilters.add(amountFilter);
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PARAMETRES DU RAPPORT',
                style: pw.TextStyle(font: fontBold, fontSize: _fontSize),
              ),
              pw.SizedBox(height: 5),
              _buildInfoRow(
                'Exporté par',
                currentUser?.name ?? currentUser?.email ?? 'N/A',
                font,
              ),
              _buildInfoRow(
                'Date export',
                DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now()),
                font,
              ),
              _buildInfoRow('Nb opérations', operationCount.toString(), font),
              _buildInfoRow(
                'Tri',
                '${filter.sortBy.displayName} (${filter.sortAscending ? "ASC" : "DESC"})',
                font,
              ),
              if (activeFilters.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  'Filtres actifs:',
                  style: pw.TextStyle(font: fontBold, fontSize: _fontSizeSmall),
                ),
                ...activeFilters.map(
                  (f) => pw.Text(
                    '  • $f',
                    style: pw.TextStyle(font: font, fontSize: _fontSizeSmall),
                  ),
                ),
              ],
              if (activeFilters.isEmpty)
                _buildInfoRow('Filtres', 'Aucun (toutes les opérations)', font),
            ],
          ),
        ),
        pw.Container(
          width: _qrSize,
          height: _qrSize,
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: qrData,
            width: _qrSize,
            height: _qrSize,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildInfoRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(font: font, fontSize: _fontSizeSmall),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: _fontSizeSmall),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // RÉSUMÉ FINANCIER PAR CATÉGORIE
  // ==========================================================================

  static pw.Widget _buildCategorizedSummary(
    Map<String, dynamic> categoryTotals,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final cashIn = categoryTotals['cashIn'] as double;
    final cashOut = categoryTotals['cashOut'] as double;
    final netCash = cashIn - cashOut;
    final salesTotal = categoryTotals['salesTotal'] as double;
    final stockIn = categoryTotals['stockIn'] as double;
    final stockOut = categoryTotals['stockOut'] as double;

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RESUME FINANCIER PAR CATEGORIE COMPTABLE (CONTRE-VALEUR CDF)',
            style: pw.TextStyle(font: fontBold, fontSize: _fontSize),
          ),
          pw.SizedBox(height: 6),

          // Trésorerie (Classe 5)
          pw.Row(
            children: [
              pw.Container(
                width: 8,
                height: 8,
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.Text(
                  'Trésorerie (Classe 5)',
                  style: pw.TextStyle(font: fontBold, fontSize: _fontSizeSmall),
                ),
              ),
              pw.Text(
                '+${_formatNumber(cashIn)}',
                style: pw.TextStyle(
                  fontSize: _fontSizeSmall,
                  color: PdfColors.green800,
                ),
              ),
              pw.Text(
                ' / -${_formatNumber(cashOut)}',
                style: pw.TextStyle(
                  fontSize: _fontSizeSmall,
                  color: PdfColors.red800,
                ),
              ),
              pw.Text(
                ' = ${netCash >= 0 ? '+' : ''}${_formatNumber(netCash)} CDF',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: _fontSizeSmall,
                  color: netCash >= 0 ? PdfColors.green800 : PdfColors.red800,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),

          // Ventes / CA (Classe 7)
          pw.Row(
            children: [
              pw.Container(
                width: 8,
                height: 8,
                decoration: const pw.BoxDecoration(color: PdfColors.green800),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.Text(
                  'Chiffre d\'affaires (Classe 7)',
                  style: pw.TextStyle(font: fontBold, fontSize: _fontSizeSmall),
                ),
              ),
              pw.Text(
                '${_formatNumber(salesTotal)} CDF',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: _fontSizeSmall,
                  color: PdfColors.blue800,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),

          // Stock (Classe 3)
          pw.Row(
            children: [
              pw.Container(
                width: 8,
                height: 8,
                decoration: const pw.BoxDecoration(color: PdfColors.orange800),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.Text(
                  'Stock (Classe 3)',
                  style: pw.TextStyle(font: fontBold, fontSize: _fontSizeSmall),
                ),
              ),
              pw.Text(
                'Entrées: ${_formatNumber(stockIn)} / Sorties: ${_formatNumber(stockOut)} CDF',
                style: pw.TextStyle(fontSize: _fontSizeSmall),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SYNTHÈSE DE CLÔTURE PAR CLASSE COMPTABLE
  // ==========================================================================

  static pw.Widget _buildClosingSynthesis({
    required pw.Font font,
    required pw.Font fontBold,
    required CurrencyService rates,
    required double openingBalance,
    required double cashIn,
    required double cashOut,
    required double cashNet,
    required double salesTotal,
    required double stockIn,
    required double stockOut,
    required double otherTotal,
    required List<OperationJournalEntry> cashOperations,
    required List<OperationJournalEntry> stockOperations,
  }) {
    final cashClosing = openingBalance + cashNet;

    // Valeur de stock consolidée : valeurs par devise de la dernière
    // opération, converties une à une (sinon le delta de la période)
    final lastStockValues =
        stockOperations.isNotEmpty
            ? stockOperations.last.stockValuesByCurrency
            : null;
    final stockClosing =
        lastStockValues != null && lastStockValues.isNotEmpty
            ? lastStockValues.entries.fold<double>(
              0.0,
              (sum, e) => sum + _toCdf(rates, e.key, e.value),
            )
            : (stockIn - stockOut);

    pw.Widget cell(
      String text, {
      bool bold = false,
      pw.Alignment align = pw.Alignment.centerRight,
      PdfColor? bg,
    }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        color: bg,
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: bold ? fontBold : font,
            fontSize: _fontSizeSmall,
          ),
        ),
      );
    }

    final rows = <pw.TableRow>[
      // En-tête
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          cell('Classe Comptable', bold: true, align: pw.Alignment.centerLeft),
          cell('Ouverture', bold: true),
          cell('Entrées (+)', bold: true),
          cell('Sorties (-)', bold: true),
          cell('Clôture', bold: true),
        ],
      ),

      // Trésorerie (Classe 5)
      pw.TableRow(
        children: [
          cell(
            'Classe 5 – Trésorerie',
            bold: true,
            align: pw.Alignment.centerLeft,
            bg: PdfColors.blue50,
          ),
          cell(_formatNumber(openingBalance), bg: PdfColors.blue50),
          cell(_formatNumber(cashIn), bg: PdfColors.blue50),
          cell(_formatNumber(cashOut), bg: PdfColors.blue50),
          cell(_formatNumber(cashClosing), bold: true, bg: PdfColors.blue50),
        ],
      ),

      // CA / Ventes (Classe 7)
      pw.TableRow(
        children: [
          cell(
            'Classe 7 – CA / Ventes',
            bold: true,
            align: pw.Alignment.centerLeft,
          ),
          cell('–'),
          cell(_formatNumber(salesTotal)),
          cell('–'),
          cell(_formatNumber(salesTotal), bold: true),
        ],
      ),

      // Stocks (Classe 3)
      pw.TableRow(
        children: [
          cell(
            'Classe 3 – Stocks',
            bold: true,
            align: pw.Alignment.centerLeft,
            bg: PdfColors.orange50,
          ),
          cell('–', bg: PdfColors.orange50),
          cell(_formatNumber(stockIn), bg: PdfColors.orange50),
          cell(_formatNumber(stockOut), bg: PdfColors.orange50),
          cell(_formatNumber(stockClosing), bold: true, bg: PdfColors.orange50),
        ],
      ),
    ];

    // Autres opérations (conditionnelle)
    if (otherTotal.abs() > 0) {
      rows.add(
        pw.TableRow(
          children: [
            cell(
              'Autres opérations',
              bold: true,
              align: pw.Alignment.centerLeft,
              bg: PdfColors.grey100,
            ),
            cell('–', bg: PdfColors.grey100),
            cell(
              otherTotal > 0 ? _formatNumber(otherTotal) : '–',
              bg: PdfColors.grey100,
            ),
            cell(
              otherTotal < 0 ? _formatNumber(otherTotal.abs()) : '–',
              bg: PdfColors.grey100,
            ),
            cell(_formatNumber(otherTotal), bold: true, bg: PdfColors.grey100),
          ],
        ),
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Titre
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Text(
              'SYNTHESE DE CLOTURE PAR CLASSE COMPTABLE (CDF)',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: _fontSize,
                color: PdfColors.grey800,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),

          // Tableau
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.5),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.5),
              4: pw.FlexColumnWidth(1.5),
            },
            children: rows,
          ),

          // Bandeau bleu – Solde de clôture en caisse
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: const pw.BoxDecoration(
              color: PdfColors.blue800,
              borderRadius: pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(4),
                bottomRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SOLDE DE CLOTURE EN CAISSE',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: _fontSize,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  '${_formatNumber(cashClosing)} CDF',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: _fontSize + 1,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // UTILITAIRES
  // ==========================================================================

  static pw.Widget _buildHeaderCell(
    String text,
    pw.Font fontBold, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(_cellPadding),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: fontBold,
          fontSize: _fontSizeSmall,
          color: color,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildDataCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(_cellPadding),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: _fontSizeSmall, color: color),
        textAlign: align,
      ),
    );
  }

  static String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 2)}..';
  }

  static String _formatNumber(double value) {
    return NumberFormat('#,##0.00', 'fr_FR').format(value);
  }

  static double _getRelevantBalance(OperationJournalEntry operation) {
    if (operation.type.impactsCash) {
      // ignore: deprecated_member_use_from_same_package
      return operation.cashBalance ?? operation.balanceAfter;
    } else if (operation.type.isSalesOperation) {
      // ignore: deprecated_member_use_from_same_package
      return operation.salesBalance ?? operation.balanceAfter;
    } else if (operation.type.impactsStock) {
      // ignore: deprecated_member_use_from_same_package
      return operation.stockValue ?? operation.balanceAfter;
    }
    // ignore: deprecated_member_use_from_same_package
    return operation.balanceAfter;
  }

  /// Totaux par catégorie consolidés en CDF : chaque montant est converti
  /// avec SA devise avant d'être additionné.
  static Map<String, dynamic> _calculateCategoryTotals({
    required List<OperationJournalEntry> cashOperations,
    required List<OperationJournalEntry> salesOperations,
    required List<OperationJournalEntry> stockOperations,
    required CurrencyService rates,
  }) {
    double cashIn = 0.0;
    double cashOut = 0.0;
    for (final op in cashOperations) {
      if (op.amount > 0) {
        cashIn += _entryToCdf(rates, op, op.amount);
      } else {
        cashOut += _entryToCdf(rates, op, op.amount.abs());
      }
    }

    double salesTotal = 0.0;
    for (final op in salesOperations) {
      salesTotal += _entryToCdf(rates, op, op.amount.abs());
    }

    double stockIn = 0.0;
    double stockOut = 0.0;
    for (final op in stockOperations) {
      if (op.type == OperationType.stockIn) {
        stockIn += _entryToCdf(rates, op, op.amount.abs());
      } else {
        stockOut += _entryToCdf(rates, op, op.amount.abs());
      }
    }

    return {
      'cashIn': cashIn,
      'cashOut': cashOut,
      'salesTotal': salesTotal,
      'stockIn': stockIn,
      'stockOut': stockOut,
    };
  }

  /// Flux entrants et sortants consolidés en CDF (QR d'authentification).
  static Map<String, dynamic> _calculateTotals(
    List<OperationJournalEntry> operations,
    CurrencyService rates,
  ) {
    double totalInflow = 0;
    double totalOutflow = 0;
    double? lastBalance;

    for (final operation in operations) {
      if (operation.amount >= 0) {
        totalInflow += _entryToCdf(rates, operation, operation.amount);
      } else {
        totalOutflow += _entryToCdf(rates, operation, operation.amount.abs());
      }
      lastBalance = _getRelevantBalance(operation);
    }

    return {
      'count': operations.length,
      'totalInflow': totalInflow,
      'totalOutflow': totalOutflow,
      'netBalance': totalInflow - totalOutflow,
      'lastBalance': lastBalance ?? 0.0,
    };
  }

  // ==========================================================================
  // DEVISES : les totaux du résumé sont consolidés en CDF (chaque montant
  // converti avec SA devise) ; chaque section de devise garde ses propres
  // soldes, calculés uniquement sur les opérations de cette devise.
  // ==========================================================================

  /// Taux à utiliser : service fourni, sinon taux enregistrés localement.
  static Future<CurrencyService> _loadRates(CurrencyService? provided) async {
    if (provided != null) return provided;
    final local = CurrencyService();
    await local.loadSettings();
    return local;
  }

  /// Montant ramené en CDF avec le taux de SA devise ; devise inconnue exclue.
  static double _toCdf(CurrencyService rates, String? code, double amount) {
    final currency = _currencyOfCode(code);
    if (currency == null) return 0.0;
    return rates.convertToCdf(amount, currency);
  }

  /// Montant d'une opération ramené en CDF avec SA devise.
  static double _entryToCdf(
    CurrencyService rates,
    OperationJournalEntry op,
    double amount,
  ) => _toCdf(rates, op.currencyCode, amount);

  /// Soldes de caisse par devise juste avant la première opération de
  /// trésorerie de [operations] (instantané après l'opération moins son
  /// montant, sinon solde de la première opération de chaque devise).
  static Map<String, double> _openingCashByCurrency(
    List<OperationJournalEntry> operations,
  ) {
    final cashOps =
        operations.where((o) => o.type.impactsCash).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final result = <String, double>{};
    if (cashOps.isEmpty) return result;

    final first = cashOps.first;
    final snapshot = first.cashBalancesByCurrency;
    if (snapshot != null && snapshot.isNotEmpty) {
      result.addAll(snapshot);
      final code = first.currencyCode ?? 'CDF';
      result[code] = (result[code] ?? 0.0) - first.amount;
      return result;
    }
    for (final op in cashOps) {
      final code = op.currencyCode ?? 'CDF';
      if (result.containsKey(code) || op.cashBalance == null) continue;
      result[code] = op.cashBalance! - op.amount;
    }
    return result;
  }

  static Map<String, List<OperationJournalEntry>> _groupOperationsByCurrency(
    List<OperationJournalEntry> operations,
  ) {
    final Map<String, List<OperationJournalEntry>> result = {};
    for (final entry in operations) {
      final currencyCode = entry.currencyCode ?? 'CDF';
      result.putIfAbsent(currencyCode, () => []).add(entry);
    }
    if (result.isEmpty) {
      result['CDF'] = operations;
    }
    return result;
  }

  // ==========================================================================
  // EXPORT & PARTAGE
  // ==========================================================================

  /// Exporte et partage le PDF via le dialogue système
  static Future<void> exportAndShare({
    required List<OperationJournalEntry> operations,
    required JournalFilter filter,
    required User? currentUser,
    String? companyName,
    String? companyAddress,
    CurrencyService? currencyService,
  }) async {
    try {
      final file = await exportToPdf(
        operations: operations,
        filter: filter,
        currentUser: currentUser,
        companyName: companyName,
        companyAddress: companyAddress,
        currencyService: currencyService,
      );

      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename: fileBaseName(file.path),
      );
    } catch (e) {
      debugPrint('[JournalExportService] Error during PDF share: $e');
      rethrow;
    }
  }

  /// Ouvre l'aperçu avant impression du PDF (imprimer ou « Microsoft Print
  /// to PDF » depuis la boîte de dialogue système) : usage courant sur
  /// desktop, là où le partage mobile n'a pas d'équivalent naturel.
  static Future<void> exportAndPrint({
    required List<OperationJournalEntry> operations,
    required JournalFilter filter,
    required User? currentUser,
    CurrencyService? currencyService,
  }) async {
    final file = await exportToPdf(
      operations: operations,
      filter: filter,
      currentUser: currentUser,
      currencyService: currencyService,
    );
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: fileBaseName(file.path),
    );
  }

  /// Génère le PDF puis demande où l'enregistrer. Renvoie le chemin choisi,
  /// ou null si l'utilisateur a annulé.
  static Future<String?> exportAndSave({
    required List<OperationJournalEntry> operations,
    required JournalFilter filter,
    required User? currentUser,
    CurrencyService? currencyService,
  }) async {
    final file = await exportToPdf(
      operations: operations,
      filter: filter,
      currentUser: currentUser,
      currencyService: currencyService,
    );
    final target = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer le journal des opérations',
      fileName: fileBaseName(file.path),
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (target == null) return null;
    final path = target.toLowerCase().endsWith('.pdf') ? target : '$target.pdf';
    await File(path).writeAsBytes(await file.readAsBytes());
    return path;
  }

  /// Nom du fichier sans le dossier, quel que soit le séparateur (Windows
  /// sépare les dossiers par une barre oblique inverse : couper sur « / »
  /// seulement renvoyait le chemin complet).
  @visibleForTesting
  static String fileBaseName(String path) => path.split(RegExp(r'[\\/]')).last;

  static Future<dynamic> _getBusinessSettings() async {
    try {
      final settingsBox = await Hive.openBox('settings');
      final settings = settingsBox.get('settings');
      if (settings != null) return settings;
      return _DefaultSettings();
    } catch (e) {
      return _DefaultSettings();
    }
  }
}

/// Extension pour ajouter un nom court aux types d'opération
extension OperationTypeShortName on OperationType {
  String get shortName {
    switch (this) {
      case OperationType.saleCash:
        return 'V.CASH';
      case OperationType.saleCredit:
        return 'V.CRED';
      case OperationType.saleInstallment:
        return 'V.ECH';
      case OperationType.stockIn:
        return 'E.STK';
      case OperationType.stockOut:
        return 'S.STK';
      case OperationType.cashIn:
        return 'ENCAIS';
      case OperationType.cashOut:
        return 'DECAIS';
      case OperationType.customerPayment:
        return 'P.CLI';
      case OperationType.supplierPayment:
        return 'P.FRN';
      case OperationType.financingRequest:
        return 'D.FIN';
      case OperationType.financingApproved:
        return 'A.FIN';
      case OperationType.financingRepayment:
        return 'R.FIN';
      case OperationType.other:
        return 'AUTRE';
    }
  }
}

/// Classe par défaut pour les paramètres entreprise
class _DefaultSettings {
  String get companyName => 'WANZO';
  String get companyAddress => 'Kinshasa, République Démocratique du Congo';
  String get companyPhone => '+243 XXX XXX XXX';
  String get companyEmail => 'contact@wanzo.cd';
  String get rccmNumber => '';
  String get idNatNumber => '';
  String get taxIdentificationNumber => '';
}

/// Devise d'un code (absent = CDF), null si inconnue.
Currency? _currencyOfCode(String? code) {
  switch ((code ?? 'CDF').trim().toUpperCase()) {
    case '':
    case 'CDF':
    case 'FC':
      return Currency.CDF;
    case 'USD':
    case r'$':
      return Currency.USD;
    case 'FCFA':
    case 'XAF':
      return Currency.FCFA;
    default:
      return null;
  }
}
