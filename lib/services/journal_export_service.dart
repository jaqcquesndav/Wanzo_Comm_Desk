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
import '../features/dashboard/models/journal_filter.dart';
import '../features/dashboard/models/operation_journal_entry.dart';
import '../features/auth/models/user.dart';

/// Service pour l'exportation du journal des opérations
/// Format professionnel et simplifié similaire aux exports de systèmes informatiques
class JournalExportService {
  // Constantes de mise en page
  static const double _fontSize = 8.0;
  static const double _fontSizeSmall = 7.0;
  static const double _fontSizeTitle = 10.0;
  static const double _cellPadding = 4.0;
  static const double _qrSize = 60.0;

  /// Exporte le journal des opérations filtré en PDF
  static Future<File> exportToPdf({
    required List<OperationJournalEntry> operations,
    required JournalFilter filter,
    required User? currentUser,
    String? companyName,
    String? companyAddress,
  }) async {
    final settings = await _getBusinessSettings();
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoMonoRegular();
    final fontBold = await PdfGoogleFonts.robotoMonoBold();

    // Générer les données d'authentification pour le QR code
    final exportId = _generateExportId();
    final qrData = _generateQrData(
      exportId: exportId,
      operations: operations,
      filter: filter,
      currentUser: currentUser,
      settings: settings,
    );

    // === SÉPARER LES OPÉRATIONS PAR CATÉGORIE COMPTABLE (OHADA) ===
    final cashOperations = operations.where((e) => e.type.impactsCash).toList();
    final salesOperations =
        operations.where((e) => e.type.isSalesOperation).toList();
    final stockOperations =
        operations.where((e) => e.type.impactsStock).toList();
    final otherOperations =
        operations
            .where(
              (e) =>
                  !e.type.impactsCash &&
                  !e.type.isSalesOperation &&
                  !e.type.impactsStock,
            )
            .toList();

    // Calculer les totaux PAR CATÉGORIE
    final categoryTotals = _calculateCategoryTotals(
      cashOperations: cashOperations,
      salesOperations: salesOperations,
      stockOperations: stockOperations,
    );

    // Extraire les totaux pour la synthèse de clôture
    final cashIn = (categoryTotals['cashIn'] as double?) ?? 0.0;
    final cashOut = (categoryTotals['cashOut'] as double?) ?? 0.0;
    final cashNet = cashIn - cashOut;
    final salesTotal = (categoryTotals['salesTotal'] as double?) ?? 0.0;
    final stockIn = (categoryTotals['stockIn'] as double?) ?? 0.0;
    final stockOut = (categoryTotals['stockOut'] as double?) ?? 0.0;
    final otherTotal = otherOperations.fold<double>(
      0.0,
      (sum, e) => sum + e.amount,
    );

    // Solde d'ouverture = cashBalance de la 1ère opération de trésorerie - son montant
    final openingBalance =
        cashOperations.isNotEmpty && cashOperations.first.cashBalance != null
            ? cashOperations.first.cashBalance! - cashOperations.first.amount
            : 0.0;

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
              pw.SizedBox(height: 15),

              // Résumé PAR CATÉGORIE COMPTABLE (pas de mélange!)
              _buildCategorizedSummary(categoryTotals, font, fontBold),
              pw.SizedBox(height: 20),

              // === SECTION 1: TRÉSORERIE (Classe 5 OHADA) ===
              if (cashOperations.isNotEmpty) ...[
                _buildCategoryHeader(
                  'TRESORERIE',
                  'Encaissements et décaissements (Classe 5)',
                  fontBold,
                  PdfColors.blue800,
                ),
                pw.SizedBox(height: 5),
                ..._buildCashCategoryTable(cashOperations, font, fontBold),
                pw.SizedBox(height: 15),
              ],

              // === SECTION 2: VENTES / CA (Classe 7 OHADA) ===
              if (salesOperations.isNotEmpty) ...[
                _buildCategoryHeader(
                  'CHIFFRE D\'AFFAIRES',
                  'Ventes et revenus (Classe 7)',
                  fontBold,
                  PdfColors.green800,
                ),
                pw.SizedBox(height: 5),
                ..._buildSalesCategoryTable(salesOperations, font, fontBold),
                pw.SizedBox(height: 15),
              ],

              // === SECTION 3: STOCK (Classe 3 OHADA) ===
              if (stockOperations.isNotEmpty) ...[
                _buildCategoryHeader(
                  'MOUVEMENTS DE STOCK',
                  'Entrées et sorties d\'inventaire (Classe 3)',
                  fontBold,
                  PdfColors.orange800,
                ),
                pw.SizedBox(height: 5),
                ..._buildStockCategoryTable(stockOperations, font, fontBold),
                pw.SizedBox(height: 15),
              ],

              // === SECTION 4: AUTRES OPÉRATIONS ===
              if (otherOperations.isNotEmpty) ...[
                _buildCategoryHeader(
                  'AUTRES OPERATIONS',
                  'Financement et autres',
                  fontBold,
                  PdfColors.grey700,
                ),
                pw.SizedBox(height: 5),
                ..._buildOtherCategoryTable(otherOperations, font, fontBold),
                pw.SizedBox(height: 15),
              ],

              // === SYNTHÈSE DE CLÔTURE PAR CLASSE COMPTABLE ===
              pw.SizedBox(height: 10),
              _buildClosingSynthesis(
                font: font,
                fontBold: fontBold,
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

    // Sauvegarde du fichier
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'journal_$exportId.pdf';
    final file = File('${directory.path}/$fileName');

    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Génère un ID unique pour l'export
  static String _generateExportId() {
    final now = DateTime.now();
    return '${DateFormat('yyyyMMddHHmmss').format(now)}-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
  }

  /// Génère les données pour le QR code d'authentification
  static String _generateQrData({
    required String exportId,
    required List<OperationJournalEntry> operations,
    required JournalFilter filter,
    required User? currentUser,
    required dynamic settings,
  }) {
    final totals = _calculateTotals(operations);

    // Hash de vérification des données
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

  /// En-tête simple et professionnel
  static pw.Widget _buildSimpleHeader(
    pw.Context context,
    dynamic settings,
    pw.Font font,
    pw.Font fontBold,
    JournalFilter filter,
    String exportId,
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
                    'JOURNAL DES OPERATIONS',
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

  /// Pied de page simple
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

  /// Section métadonnées avec QR code
  static pw.Widget _buildMetadataSection(
    pw.Font font,
    pw.Font fontBold,
    JournalFilter filter,
    User? currentUser,
    int operationCount,
    String qrData,
  ) {
    // Construire la liste des filtres actifs
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
        // Informations à gauche
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
        // QR Code à droite
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

  /// Ligne d'information simple
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

  /// Résumé financier PAR CATÉGORIE COMPTABLE (pas de mélange!)
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
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RESUME PAR CATEGORIE COMPTABLE',
            style: pw.TextStyle(font: fontBold, fontSize: _fontSize),
          ),
          pw.SizedBox(height: 6),

          // Trésorerie
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

          // Ventes / CA
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

          // Stock
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

  /// En-tête de section catégorie
  static pw.Widget _buildCategoryHeader(
    String title,
    String subtitle,
    pw.Font fontBold,
    PdfColor color,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: _fontSize,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            subtitle,
            style: pw.TextStyle(
              fontSize: _fontSizeSmall,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Table de TRÉSORERIE avec solde courant propre
  static List<pw.Widget> _buildCashCategoryTable(
    List<OperationJournalEntry> operations,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final List<pw.Widget> widgets = [];
    final grouped = _groupOperationsByCurrency(operations);

    for (final entry in grouped.entries) {
      final currency = entry.key;
      final ops = entry.value;
      if (ops.isEmpty) continue;

      double runningBalance = 0.0;
      // Try to get opening balance from first operation's cashBalance
      if (ops.first.cashBalance != null) {
        runningBalance = ops.first.cashBalance! - ops.first.amount;
      }

      if (grouped.length > 1) {
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 5, bottom: 3),
            child: pw.Text(
              '--- $currency ---',
              style: pw.TextStyle(font: fontBold, fontSize: _fontSizeSmall),
            ),
          ),
        );
      }

      widgets.add(
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
          columnWidths: const {
            0: pw.FixedColumnWidth(55),
            1: pw.FlexColumnWidth(2.5),
            2: pw.FixedColumnWidth(70),
            3: pw.FixedColumnWidth(70),
            4: pw.FixedColumnWidth(75),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blue50),
              children: [
                _buildHeaderCell('DATE', fontBold),
                _buildHeaderCell('DESCRIPTION', fontBold),
                _buildHeaderCell(
                  'ENCAISSEMENT',
                  fontBold,
                  align: pw.TextAlign.right,
                ),
                _buildHeaderCell(
                  'DECAISSEMENT',
                  fontBold,
                  align: pw.TextAlign.right,
                ),
                _buildHeaderCell(
                  'SOLDE CAISSE',
                  fontBold,
                  align: pw.TextAlign.right,
                ),
              ],
            ),
            ...ops.asMap().entries.map((e) {
              final index = e.key;
              final op = e.value;
              final isAlternate = index % 2 == 1;
              runningBalance += op.amount;

              return pw.TableRow(
                decoration:
                    isAlternate
                        ? const pw.BoxDecoration(color: PdfColors.grey50)
                        : null,
                children: [
                  _buildDataCell(DateFormat('dd/MM/yy').format(op.date), font),
                  _buildDataCell(_truncateText(op.description, 40), font),
                  _buildDataCell(
                    op.amount > 0 ? _formatNumber(op.amount) : '',
                    font,
                    align: pw.TextAlign.right,
                    color: PdfColors.green800,
                  ),
                  _buildDataCell(
                    op.amount < 0 ? _formatNumber(op.amount.abs()) : '',
                    font,
                    align: pw.TextAlign.right,
                    color: PdfColors.red800,
                  ),
                  _buildDataCell(
                    _formatNumber(op.cashBalance ?? runningBalance),
                    font,
                    align: pw.TextAlign.right,
                  ),
                ],
              );
            }),
          ],
        ),
      );

      // Sous-total
      final cashIn = ops
          .where((o) => o.amount > 0)
          .fold<double>(0.0, (s, o) => s + o.amount);
      final cashOut = ops
          .where((o) => o.amount < 0)
          .fold<double>(0.0, (s, o) => s + o.amount.abs());
      widgets.add(
        _buildSubtotalRow(
          'Total $currency: +${_formatNumber(cashIn)} / -${_formatNumber(cashOut)} = ${_formatNumber(cashIn - cashOut)}',
          fontBold,
        ),
      );
    }
    return widgets;
  }

  /// Table des VENTES avec cumul CA
  static List<pw.Widget> _buildSalesCategoryTable(
    List<OperationJournalEntry> operations,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final List<pw.Widget> widgets = [];
    final grouped = _groupOperationsByCurrency(operations);

    for (final entry in grouped.entries) {
      final currency = entry.key;
      final ops = entry.value;
      if (ops.isEmpty) continue;

      double runningTotal = 0.0;

      if (grouped.length > 1) {
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 5, bottom: 3),
            child: pw.Text(
              '--- $currency ---',
              style: pw.TextStyle(font: fontBold, fontSize: _fontSizeSmall),
            ),
          ),
        );
      }

      widgets.add(
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
          columnWidths: const {
            0: pw.FixedColumnWidth(55),
            1: pw.FlexColumnWidth(2),
            2: pw.FixedColumnWidth(55),
            3: pw.FixedColumnWidth(70),
            4: pw.FixedColumnWidth(75),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green50),
              children: [
                _buildHeaderCell('DATE', fontBold),
                _buildHeaderCell('CLIENT / DESCRIPTION', fontBold),
                _buildHeaderCell('TYPE', fontBold),
                _buildHeaderCell(
                  'MONTANT',
                  fontBold,
                  align: pw.TextAlign.right,
                ),
                _buildHeaderCell(
                  'CUMUL CA',
                  fontBold,
                  align: pw.TextAlign.right,
                ),
              ],
            ),
            ...ops.asMap().entries.map((e) {
              final index = e.key;
              final op = e.value;
              final isAlternate = index % 2 == 1;
              runningTotal += op.amount.abs();

              return pw.TableRow(
                decoration:
                    isAlternate
                        ? const pw.BoxDecoration(color: PdfColors.grey50)
                        : null,
                children: [
                  _buildDataCell(DateFormat('dd/MM/yy').format(op.date), font),
                  _buildDataCell(
                    _truncateText(op.customerName ?? op.description, 35),
                    font,
                  ),
                  _buildDataCell(op.type.shortName, font),
                  _buildDataCell(
                    _formatNumber(op.amount.abs()),
                    font,
                    align: pw.TextAlign.right,
                    color: PdfColors.green800,
                  ),
                  _buildDataCell(
                    _formatNumber(op.salesBalance ?? runningTotal),
                    font,
                    align: pw.TextAlign.right,
                  ),
                ],
              );
            }),
          ],
        ),
      );

      // Sous-total
      final total = ops.fold<double>(0.0, (s, o) => s + o.amount.abs());
      widgets.add(
        _buildSubtotalRow(
          'Total CA $currency: ${_formatNumber(total)}',
          fontBold,
        ),
      );
    }
    return widgets;
  }

  /// Table de STOCK avec entrées/sorties
  static List<pw.Widget> _buildStockCategoryTable(
    List<OperationJournalEntry> operations,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final List<pw.Widget> widgets = [];
    final grouped = _groupOperationsByCurrency(operations);

    for (final entry in grouped.entries) {
      final currency = entry.key;
      final ops = entry.value;
      if (ops.isEmpty) continue;

      if (grouped.length > 1) {
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 5, bottom: 3),
            child: pw.Text(
              '--- $currency ---',
              style: pw.TextStyle(font: fontBold, fontSize: _fontSizeSmall),
            ),
          ),
        );
      }

      widgets.add(
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
          columnWidths: const {
            0: pw.FixedColumnWidth(55),
            1: pw.FlexColumnWidth(2),
            2: pw.FixedColumnWidth(55),
            3: pw.FixedColumnWidth(50),
            4: pw.FixedColumnWidth(70),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.orange50),
              children: [
                _buildHeaderCell('DATE', fontBold),
                _buildHeaderCell('PRODUIT', fontBold),
                _buildHeaderCell('MOUVEMENT', fontBold),
                _buildHeaderCell('QTE', fontBold, align: pw.TextAlign.right),
                _buildHeaderCell('VALEUR', fontBold, align: pw.TextAlign.right),
              ],
            ),
            ...ops.asMap().entries.map((e) {
              final index = e.key;
              final op = e.value;
              final isAlternate = index % 2 == 1;
              final isIn = op.type == OperationType.stockIn;

              return pw.TableRow(
                decoration:
                    isAlternate
                        ? const pw.BoxDecoration(color: PdfColors.grey50)
                        : null,
                children: [
                  _buildDataCell(DateFormat('dd/MM/yy').format(op.date), font),
                  _buildDataCell(
                    _truncateText(op.productName ?? op.description, 35),
                    font,
                  ),
                  _buildDataCell(
                    isIn ? 'ENTREE' : 'SORTIE',
                    font,
                    color: isIn ? PdfColors.green800 : PdfColors.red800,
                  ),
                  _buildDataCell(
                    op.quantity?.toStringAsFixed(0) ?? '-',
                    font,
                    align: pw.TextAlign.right,
                  ),
                  _buildDataCell(
                    _formatNumber(op.amount.abs()),
                    font,
                    align: pw.TextAlign.right,
                    color: isIn ? PdfColors.green800 : PdfColors.red800,
                  ),
                ],
              );
            }),
          ],
        ),
      );

      // Sous-total
      final stockIn = ops
          .where((o) => o.type == OperationType.stockIn)
          .fold<double>(0.0, (s, o) => s + o.amount.abs());
      final stockOut = ops
          .where((o) => o.type == OperationType.stockOut)
          .fold<double>(0.0, (s, o) => s + o.amount.abs());
      widgets.add(
        _buildSubtotalRow(
          'Stock $currency: Entrées ${_formatNumber(stockIn)} / Sorties ${_formatNumber(stockOut)}',
          fontBold,
        ),
      );
    }
    return widgets;
  }

  /// Table des AUTRES opérations
  static List<pw.Widget> _buildOtherCategoryTable(
    List<OperationJournalEntry> operations,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final List<pw.Widget> widgets = [];
    final grouped = _groupOperationsByCurrency(operations);

    for (final entry in grouped.entries) {
      final currency = entry.key;
      final ops = entry.value;
      if (ops.isEmpty) continue;

      if (grouped.length > 1) {
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 5, bottom: 3),
            child: pw.Text(
              '--- $currency ---',
              style: pw.TextStyle(font: fontBold, fontSize: _fontSizeSmall),
            ),
          ),
        );
      }

      widgets.add(
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
          columnWidths: const {
            0: pw.FixedColumnWidth(55),
            1: pw.FixedColumnWidth(55),
            2: pw.FlexColumnWidth(2.5),
            3: pw.FixedColumnWidth(75),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildHeaderCell('DATE', fontBold),
                _buildHeaderCell('TYPE', fontBold),
                _buildHeaderCell('DESCRIPTION', fontBold),
                _buildHeaderCell(
                  'MONTANT',
                  fontBold,
                  align: pw.TextAlign.right,
                ),
              ],
            ),
            ...ops.asMap().entries.map((e) {
              final index = e.key;
              final op = e.value;
              final isAlternate = index % 2 == 1;

              return pw.TableRow(
                decoration:
                    isAlternate
                        ? const pw.BoxDecoration(color: PdfColors.grey50)
                        : null,
                children: [
                  _buildDataCell(DateFormat('dd/MM/yy').format(op.date), font),
                  _buildDataCell(op.type.shortName, font),
                  _buildDataCell(_truncateText(op.description, 45), font),
                  _buildDataCell(
                    _formatNumber(op.amount),
                    font,
                    align: pw.TextAlign.right,
                    color:
                        op.amount >= 0 ? PdfColors.green800 : PdfColors.red800,
                  ),
                ],
              );
            }),
          ],
        ),
      );
    }
    return widgets;
  }

  /// Ligne de sous-total
  static pw.Widget _buildSubtotalRow(String text, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(width: 0.5, color: PdfColors.grey400),
          right: pw.BorderSide(width: 0.5, color: PdfColors.grey400),
          bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey400),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            text,
            style: pw.TextStyle(font: fontBold, fontSize: _fontSizeSmall),
          ),
        ],
      ),
    );
  }

  /// Cellule d'en-tête
  static pw.Widget _buildHeaderCell(
    String text,
    pw.Font fontBold, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(_cellPadding),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: fontBold, fontSize: _fontSizeSmall),
        textAlign: align,
      ),
    );
  }

  /// Cellule de données
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

  /// Tronque le texte si nécessaire
  static String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 2)}..';
  }

  /// Construit la SYNTHÈSE DE CLÔTURE PAR CLASSE COMPTABLE
  /// Tableau récapitulatif : Ouverture | Entrées | Sorties | Clôture par classe
  static pw.Widget _buildClosingSynthesis({
    required pw.Font font,
    required pw.Font fontBold,
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
    // Calcul du solde de clôture trésorerie
    final cashClosing = openingBalance + cashNet;

    // Dernière valeur de stock connue via stockValue, sinon calcul
    final stockClosing =
        stockOperations.isNotEmpty && stockOperations.last.stockValue != null
            ? stockOperations.last.stockValue!
            : (stockIn - stockOut);

    // Style commun pour les cellules
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

    // Construction des lignes du tableau
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

      // Ligne Trésorerie (Classe 5)
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

      // Ligne CA / Ventes (Classe 7)
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

      // Ligne Stocks (Classe 3)
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

    // Ligne Autres opérations (conditionnelle)
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
              'SYNTHÈSE DE CLÔTURE PAR CLASSE COMPTABLE',
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
                  'SOLDE DE CLÔTURE EN CAISSE',
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

  /// Formate un nombre
  static String _formatNumber(double value) {
    return NumberFormat('#,##0.00', 'fr_FR').format(value);
  }

  /// Récupère le solde approprié selon le type d'opération
  /// Utilise les soldes typés en priorité, fallback sur balanceAfter pour rétrocompatibilité
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

  /// Calcule les totaux PAR CATÉGORIE COMPTABLE
  /// Évite le mélange de classes comptables incompatibles (OHADA SYSCOHADA)
  static Map<String, dynamic> _calculateCategoryTotals({
    required List<OperationJournalEntry> cashOperations,
    required List<OperationJournalEntry> salesOperations,
    required List<OperationJournalEntry> stockOperations,
  }) {
    double cashIn = 0.0;
    double cashOut = 0.0;
    for (final op in cashOperations) {
      if (op.amount > 0) {
        cashIn += op.amount;
      } else {
        cashOut += op.amount.abs();
      }
    }

    double salesTotal = 0.0;
    for (final op in salesOperations) {
      salesTotal += op.amount.abs();
    }

    double stockIn = 0.0;
    double stockOut = 0.0;
    for (final op in stockOperations) {
      if (op.type == OperationType.stockIn) {
        stockIn += op.amount.abs();
      } else {
        stockOut += op.amount.abs();
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

  /// Calcule les totaux des opérations (conservé pour QR code et usage interne)
  static Map<String, dynamic> _calculateTotals(
    List<OperationJournalEntry> operations,
  ) {
    double totalInflow = 0;
    double totalOutflow = 0;
    double? lastBalance;

    for (final operation in operations) {
      if (operation.amount >= 0) {
        totalInflow += operation.amount;
      } else {
        totalOutflow += operation.amount.abs();
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

  /// Groupe les opérations par devise
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

  /// Exporte et partage le PDF
  /// Utilise Printing.sharePdf qui est supporté sur toutes les plateformes desktop
  static Future<void> exportAndShare({
    required List<OperationJournalEntry> operations,
    required JournalFilter filter,
    required User? currentUser,
    String? companyName,
    String? companyAddress,
  }) async {
    try {
      final file = await exportToPdf(
        operations: operations,
        filter: filter,
        currentUser: currentUser,
        companyName: companyName,
        companyAddress: companyAddress,
      );

      // Printing.sharePdf fonctionne sur toutes les plateformes
      // C'est la méthode recommandée pour partager des PDFs sur desktop
      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename: file.path.split('/').last,
      );
    } catch (e) {
      debugPrint('[JournalExportService] Error during PDF share: $e');
      rethrow;
    }
  }

  /// Récupère les paramètres de l'entreprise
  static Future<dynamic> _getBusinessSettings() async {
    try {
      final settingsBox = await Hive.openBox('settings');
      final settings = settingsBox.get('settings');
      if (settings != null) {
        return settings;
      }
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

/// Classe par défaut pour les paramètres
class _DefaultSettings {
  String get companyName => 'WANZO';
  String get companyAddress => 'Kinshasa, République Démocratique du Congo';
  String get companyPhone => '+243 XXX XXX XXX';
  String get companyEmail => 'contact@wanzo.cd';
  String get rccmNumber => '';
  String get idNatNumber => '';
  String get taxIdentificationNumber => '';
}
