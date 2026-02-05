import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Types d'export supportés
enum ExportFormat { pdf, csv, xlsx }

/// Configuration pour l'export de table
class TableExportConfig {
  /// Titre du document/fichier
  final String title;

  /// Sous-titre optionnel
  final String? subtitle;

  /// En-têtes des colonnes
  final List<String> headers;

  /// Données sous forme de liste de lignes (chaque ligne = liste de cellules)
  final List<List<dynamic>> rows;

  /// Nom du fichier (sans extension)
  final String fileName;

  /// Nom de l'entreprise (pour PDF)
  final String? companyName;

  /// Date de génération
  final DateTime? generatedAt;

  /// Orientation du PDF
  final PdfPageFormat pageFormat;

  const TableExportConfig({
    required this.title,
    this.subtitle,
    required this.headers,
    required this.rows,
    required this.fileName,
    this.companyName,
    this.generatedAt,
    this.pageFormat = PdfPageFormat.a4,
  });
}

/// Service d'export de tables vers différents formats
class TableExportService {
  static final TableExportService _instance = TableExportService._internal();
  factory TableExportService() => _instance;
  TableExportService._internal();

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
  final DateFormat _fileNameDateFormat = DateFormat('yyyyMMdd_HHmmss');

  /// Exporte les données selon le format choisi
  Future<bool> export({
    required BuildContext context,
    required TableExportConfig config,
    required ExportFormat format,
    bool showSaveDialog = true,
  }) async {
    try {
      switch (format) {
        case ExportFormat.pdf:
          return await _exportToPdf(context, config, showSaveDialog);
        case ExportFormat.csv:
          return await _exportToCsv(context, config, showSaveDialog);
        case ExportFormat.xlsx:
          return await _exportToExcel(context, config, showSaveDialog);
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'export: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Export vers PDF
  Future<bool> _exportToPdf(
    BuildContext context,
    TableExportConfig config,
    bool showSaveDialog,
  ) async {
    final pdf = pw.Document();
    final now = config.generatedAt ?? DateTime.now();

    // Calculer les largeurs des colonnes
    final columnWidths = _calculateColumnWidths(config.headers.length);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: config.pageFormat,
        orientation:
            config.pageFormat == PdfPageFormat.a4
                ? pw.PageOrientation.landscape
                : pw.PageOrientation.portrait,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context ctx) => _buildPdfHeader(config, now),
        footer: (pw.Context ctx) => _buildPdfFooter(ctx, config),
        build:
            (pw.Context ctx) => [
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: columnWidths,
                children: [
                  // En-têtes
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue100,
                    ),
                    children:
                        config.headers
                            .map(
                              (header) => pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  header,
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  // Données
                  ...config.rows.map(
                    (row) => pw.TableRow(
                      children:
                          row
                              .map(
                                (cell) => pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(
                                    _formatCellValue(cell),
                                    style: const pw.TextStyle(fontSize: 9),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ),
            ],
      ),
    );

    final bytes = await pdf.save();

    if (showSaveDialog) {
      // Afficher le dialogue d'impression/sauvegarde
      await Printing.layoutPdf(
        onLayout: (_) => bytes,
        name: '${config.fileName}_${_fileNameDateFormat.format(now)}.pdf',
      );
      return true;
    } else {
      // Sauvegarder directement
      return await _saveFile(
        context: context,
        bytes: bytes,
        fileName: '${config.fileName}_${_fileNameDateFormat.format(now)}.pdf',
        mimeType: 'application/pdf',
      );
    }
  }

  pw.Widget _buildPdfHeader(TableExportConfig config, DateTime now) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (config.companyName != null)
                  pw.Text(
                    config.companyName!,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                pw.SizedBox(height: 4),
                pw.Text(
                  config.title,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (config.subtitle != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    config.subtitle!,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Généré le: ${_dateFormat.format(now)}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  '${config.rows.length} enregistrement(s)',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildPdfFooter(pw.Context ctx, TableExportConfig config) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    );
  }

  Map<int, pw.TableColumnWidth> _calculateColumnWidths(int columnCount) {
    // Distribution égale des colonnes
    final width = 1.0 / columnCount;
    return {for (int i = 0; i < columnCount; i++) i: pw.FlexColumnWidth(width)};
  }

  /// Export vers CSV
  Future<bool> _exportToCsv(
    BuildContext context,
    TableExportConfig config,
    bool showSaveDialog,
  ) async {
    final now = config.generatedAt ?? DateTime.now();

    // Construire les données CSV
    final List<List<dynamic>> csvData = [
      config.headers,
      ...config.rows.map((row) => row.map(_formatCellValue).toList()),
    ];

    final csvString = const ListToCsvConverter().convert(csvData);
    final bytes = Uint8List.fromList(csvString.codeUnits);
    final fileName =
        '${config.fileName}_${_fileNameDateFormat.format(now)}.csv';

    return await _saveFile(
      context: context,
      bytes: bytes,
      fileName: fileName,
      mimeType: 'text/csv',
    );
  }

  /// Export vers Excel (XLSX)
  Future<bool> _exportToExcel(
    BuildContext context,
    TableExportConfig config,
    bool showSaveDialog,
  ) async {
    final now = config.generatedAt ?? DateTime.now();
    final excel = Excel.createExcel();

    // Renommer la feuille par défaut
    final sheetName =
        config.title.length > 31 ? config.title.substring(0, 31) : config.title;
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    // Style pour les en-têtes
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue100,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Ajouter les en-têtes
    for (var i = 0; i < config.headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(config.headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Ajouter les données
    for (var rowIndex = 0; rowIndex < config.rows.length; rowIndex++) {
      final row = config.rows[rowIndex];
      for (var colIndex = 0; colIndex < row.length; colIndex++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: colIndex,
            rowIndex: rowIndex + 1,
          ),
        );
        cell.value = _getCellValue(row[colIndex]);
      }
    }

    // Ajuster les largeurs de colonnes (approximatif)
    for (var i = 0; i < config.headers.length; i++) {
      sheet.setColumnWidth(i, 20);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Échec de l\'encodage Excel');
    }

    final fileName =
        '${config.fileName}_${_fileNameDateFormat.format(now)}.xlsx';

    return await _saveFile(
      context: context,
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  CellValue _getCellValue(dynamic value) {
    if (value == null) return TextCellValue('');
    if (value is num) return DoubleCellValue(value.toDouble());
    if (value is DateTime)
      return DateCellValue(
        year: value.year,
        month: value.month,
        day: value.day,
      );
    if (value is bool) return TextCellValue(value ? 'Oui' : 'Non');
    return TextCellValue(value.toString());
  }

  String _formatCellValue(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) return _dateFormat.format(value);
    if (value is double) return value.toStringAsFixed(2);
    if (value is bool) return value ? 'Oui' : 'Non';
    return value.toString();
  }

  /// Sauvegarder un fichier
  Future<bool> _saveFile({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      if (kIsWeb) {
        // Pour le web, on utilise share_plus
        await Share.shareXFiles([
          XFile.fromData(bytes, name: fileName, mimeType: mimeType),
        ], subject: fileName);
        return true;
      }

      // Desktop/Mobile: Afficher le dialogue de sauvegarde
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le fichier',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [fileName.split('.').last],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsBytes(bytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fichier sauvegardé: ${file.path}'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Ouvrir',
                textColor: Colors.white,
                onPressed: () => _openFile(file.path),
              ),
            ),
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Erreur sauvegarde fichier: $e');

      // Fallback: sauvegarder dans le dossier temporaire
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fichier sauvegardé: ${file.path}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return true;
      } catch (e2) {
        debugPrint('Erreur fallback sauvegarde: $e2');
        return false;
      }
    }
  }

  /// Ouvrir un fichier avec l'application par défaut
  Future<void> _openFile(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (e) {
      debugPrint('Erreur ouverture fichier: $e');
    }
  }
}
