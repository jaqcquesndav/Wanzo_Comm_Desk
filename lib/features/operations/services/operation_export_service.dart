import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:wanzo/features/operations/models/operation.dart';

/// Service pour l'export des opérations en différents formats
class OperationExportService {
  /// Exporte les opérations en PDF
  Future<File?> exportToPdf(
    List<Operation> operations, {
    DateTime? startDate,
    DateTime? endDate,
    String? title,
  }) async {
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();

      final dateFormat = DateFormat('dd/MM/yyyy');
      final currencyFormat = NumberFormat.currency(
        symbol: 'FC',
        decimalDigits: 0,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(bottom: 20.0),
              child: pw.Text(
                title ?? 'Rapport des Opérations',
                style: pw.TextStyle(font: boldFont, fontSize: 18),
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10.0),
              child: pw.Text(
                'Page ${context.pageNumber} sur ${context.pagesCount}',
                style: pw.TextStyle(font: font, fontSize: 8),
              ),
            );
          },
          build:
              (pw.Context context) => [
                if (startDate != null && endDate != null)
                  pw.Text(
                    'Période: ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(font: boldFont, fontSize: 10),
                  cellStyle: pw.TextStyle(font: font, fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.grey600,
                        width: 1.5,
                      ),
                    ),
                  ),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft, // Date
                    1: pw.Alignment.centerLeft, // Type
                    2: pw.Alignment.centerLeft, // Description
                    3: pw.Alignment.centerRight, // Montant CDF
                    4: pw.Alignment.centerRight, // Montant USD
                    5: pw.Alignment.centerLeft, // Status
                  },
                  headers: [
                    'Date',
                    'Type',
                    'Description',
                    'Montant CDF',
                    'Montant USD',
                    'Statut',
                  ],
                  data:
                      operations.map((op) {
                        return [
                          dateFormat.format(op.date),
                          op.type.displayName,
                          op.description,
                          currencyFormat.format(op.amountCdf),
                          op.amountUsd != null
                              ? '\$${op.amountUsd!.toStringAsFixed(2)}'
                              : '-',
                          op.status,
                        ];
                      }).toList(),
                ),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total des opérations: ${operations.length}',
                      style: pw.TextStyle(font: boldFont, fontSize: 12),
                    ),
                    pw.Text(
                      'Total CDF: ${currencyFormat.format(operations.fold<double>(0, (sum, op) => sum + op.amountCdf))}',
                      style: pw.TextStyle(font: boldFont, fontSize: 12),
                    ),
                  ],
                ),
              ],
        ),
      );

      final outputDir = await getApplicationDocumentsDirectory();
      final downloadsDir = await getDownloadsDirectory();
      final targetDir = downloadsDir ?? outputDir;

      final String fileName =
          'operations_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final File file = File("${targetDir.path}/$fileName");
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      print('Erreur lors de la génération du PDF: $e');
      return null;
    }
  }

  /// Exporte les opérations en Excel (CSV pour simplifier)
  Future<File?> exportToExcel(
    List<Operation> operations, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
      final StringBuffer csvBuffer = StringBuffer();

      // En-têtes
      csvBuffer.writeln(
        'Date,Type,Description,Montant CDF,Montant USD,Partie liée,Statut,Méthode de paiement,Notes',
      );

      // Données
      for (final op in operations) {
        csvBuffer.writeln(
          '${dateFormat.format(op.date)},'
          '"${op.type.displayName}",'
          '"${op.description}",'
          '${op.amountCdf},'
          '${op.amountUsd ?? 0},'
          '"${op.relatedPartyName ?? ''}",'
          '"${op.status}",'
          '"${op.paymentMethod ?? ''}",'
          '"${op.categoryId ?? ''}"',
        );
      }

      final outputDir = await getApplicationDocumentsDirectory();
      final downloadsDir = await getDownloadsDirectory();
      final targetDir = downloadsDir ?? outputDir;

      final String fileName =
          'operations_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final File file = File("${targetDir.path}/$fileName");
      await file.writeAsString(csvBuffer.toString());
      return file;
    } catch (e) {
      print('Erreur lors de la génération du fichier Excel: $e');
      return null;
    }
  }

  /// Calcule les statistiques des opérations
  Map<String, dynamic> calculateStats(List<Operation> operations) {
    double totalCdf = 0;
    double totalUsd = 0;
    final Map<String, int> countByType = {};
    final Map<String, double> amountByType = {};

    for (final op in operations) {
      totalCdf += op.amountCdf;
      totalUsd += op.amountUsd ?? 0;

      final typeName = op.type.displayName;
      countByType[typeName] = (countByType[typeName] ?? 0) + 1;
      amountByType[typeName] = (amountByType[typeName] ?? 0) + op.amountCdf;
    }

    return {
      'totalOperations': operations.length,
      'totalAmountCdf': totalCdf,
      'totalAmountUsd': totalUsd,
      'countByType': countByType,
      'amountByType': amountByType,
    };
  }
}
