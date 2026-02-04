import 'dart:convert';
import 'dart:io';
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

    // Calculer les totaux globaux
    final totals = _calculateTotals(operations);

    // Grouper par devise pour un meilleur rendu
    final groupedByDevise = _groupOperationsByCurrency(operations);

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

              // Résumé financier compact
              _buildCompactSummary(totals, font, fontBold),
              pw.SizedBox(height: 20),

              // Tableau des opérations
              ..._buildDataTable(groupedByDevise, font, fontBold),
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

  /// Résumé financier compact
  static pw.Widget _buildCompactSummary(
    Map<String, dynamic> totals,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final netBalance =
        (totals['totalInflow'] as double) - (totals['totalOutflow'] as double);
    final isPositive = netBalance >= 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            'ENTREES',
            totals['totalInflow'],
            PdfColors.green800,
            fontBold,
          ),
          pw.Container(width: 1, height: 25, color: PdfColors.grey400),
          _buildSummaryItem(
            'SORTIES',
            totals['totalOutflow'],
            PdfColors.red800,
            fontBold,
          ),
          pw.Container(width: 1, height: 25, color: PdfColors.grey400),
          _buildSummaryItem(
            'SOLDE NET',
            netBalance,
            isPositive ? PdfColors.green800 : PdfColors.red800,
            fontBold,
          ),
        ],
      ),
    );
  }

  /// Élément du résumé
  static pw.Widget _buildSummaryItem(
    String label,
    double value,
    PdfColor color,
    pw.Font fontBold,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          _formatCurrency(value),
          style: pw.TextStyle(font: fontBold, fontSize: 9, color: color),
        ),
      ],
    );
  }

  /// Construit le tableau de données optimisé pour plusieurs pages
  static List<pw.Widget> _buildDataTable(
    Map<String, List<OperationJournalEntry>> groupedOperations,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final List<pw.Widget> widgets = [];

    for (final entry in groupedOperations.entries) {
      final currency = entry.key;
      final operations = entry.value;

      if (operations.isEmpty) continue;

      // Titre de la section devise (si plusieurs devises)
      if (groupedOperations.length > 1) {
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 10, bottom: 5),
            child: pw.Text(
              '--- $currency ---',
              style: pw.TextStyle(font: fontBold, fontSize: _fontSize),
            ),
          ),
        );
      }

      // Utiliser pw.Table pour un meilleur rendu multi-pages
      widgets.add(
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
          columnWidths: const {
            0: pw.FixedColumnWidth(55), // Date
            1: pw.FlexColumnWidth(2.5), // Description
            2: pw.FixedColumnWidth(55), // Type
            3: pw.FixedColumnWidth(70), // Débit
            4: pw.FixedColumnWidth(70), // Crédit
            5: pw.FixedColumnWidth(75), // Solde
          },
          children: [
            // En-tête
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildHeaderCell('DATE', fontBold),
                _buildHeaderCell('DESCRIPTION', fontBold),
                _buildHeaderCell('TYPE', fontBold),
                _buildHeaderCell('DEBIT', fontBold, align: pw.TextAlign.right),
                _buildHeaderCell('CREDIT', fontBold, align: pw.TextAlign.right),
                _buildHeaderCell('SOLDE', fontBold, align: pw.TextAlign.right),
              ],
            ),
            // Lignes de données
            ...operations.asMap().entries.map((e) {
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
                  _buildDataCell(_truncateText(op.description, 45), font),
                  _buildDataCell(op.type.shortName, font),
                  _buildDataCell(
                    op.amount < 0 ? _formatNumber(op.amount.abs()) : '',
                    font,
                    align: pw.TextAlign.right,
                    color: PdfColors.red800,
                  ),
                  _buildDataCell(
                    op.amount >= 0 ? _formatNumber(op.amount) : '',
                    font,
                    align: pw.TextAlign.right,
                    color: PdfColors.green800,
                  ),
                  _buildDataCell(
                    _formatNumber(_getRelevantBalance(op)),
                    font,
                    align: pw.TextAlign.right,
                  ),
                ],
              );
            }),
          ],
        ),
      );

      // Sous-total par devise
      final currencyTotals = _calculateTotals(operations);
      widgets.add(
        pw.Container(
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
                'Total $currency: ',
                style: pw.TextStyle(font: fontBold, fontSize: _fontSizeSmall),
              ),
              pw.Text(
                'Entrées: ${_formatNumber(currencyTotals['totalInflow'])} | ',
                style: pw.TextStyle(
                  fontSize: _fontSizeSmall,
                  color: PdfColors.green800,
                ),
              ),
              pw.Text(
                'Sorties: ${_formatNumber(currencyTotals['totalOutflow'])}',
                style: pw.TextStyle(
                  fontSize: _fontSizeSmall,
                  color: PdfColors.red800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
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

  /// Formate un nombre
  static String _formatNumber(double value) {
    return NumberFormat('#,##0.00', 'fr_FR').format(value);
  }

  /// Formate en devise
  static String _formatCurrency(double value) {
    return '${_formatNumber(value)} CDF';
  }

  /// Récupère le solde approprié selon le type d'opération
  static double _getRelevantBalance(OperationJournalEntry operation) {
    if (operation.type.impactsCash) {
      return operation.cashBalance ?? operation.balanceAfter;
    } else if (operation.type.isSalesOperation) {
      return operation.salesBalance ?? operation.balanceAfter;
    } else if (operation.type.impactsStock) {
      return operation.stockValue ?? operation.balanceAfter;
    }
    return operation.balanceAfter;
  }

  /// Calcule les totaux des opérations
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
  static Future<void> exportAndShare({
    required List<OperationJournalEntry> operations,
    required JournalFilter filter,
    required User? currentUser,
    String? companyName,
    String? companyAddress,
  }) async {
    final file = await exportToPdf(
      operations: operations,
      filter: filter,
      currentUser: currentUser,
      companyName: companyName,
      companyAddress: companyAddress,
    );

    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: file.path.split('/').last,
    );
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
