import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/features/atelier/models/atelier_order.dart';
import 'package:wanzo/features/atelier/models/customer_vehicle.dart';
import 'package:wanzo/features/settings/models/settings.dart';

/// Fiche de suivi d'un véhicule client (mode garage) : identité du véhicule
/// puis historique des interventions (commandes atelier rattachées). Elle
/// évolue automatiquement : chaque nouvelle intervention y figure à la
/// prochaine génération. Mêmes dépendances que les factures et la fiche atelier.
class VehicleSheetPdf {
  static String _fmtDate(DateTime? d) => d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);

  static ({String name, String address, String phone}) _issuer(Settings? settings) {
    final ctx = BusinessContextService();
    final useBu = ctx.shouldUseBusinessUnitIdentity;
    String pick(String? bu, String? fallback) => (useBu ? (bu ?? fallback) : fallback) ?? '';
    final name = pick(ctx.businessUnitName, settings?.companyName);
    return (
      name: name.isNotEmpty ? name : 'Garage',
      address: pick(ctx.businessUnitAddress, settings?.companyAddress),
      phone: pick(ctx.businessUnitPhone, settings?.companyPhone),
    );
  }

  static Future<pw.Document> build(
    CustomerVehicle vehicle,
    List<AtelierOrder> orders, {
    String? customerName,
    Settings? settings,
  }) async {
    final doc = pw.Document();
    final regular = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final issuer = _issuer(settings);
    final sorted = [...orders]..sort((a, b) => (a.entryDate ?? a.createdAt ?? DateTime(2000))
        .compareTo(b.entryDate ?? b.createdAt ?? DateTime(2000)));
    final totalCdf = sorted.fold<double>(0, (s, o) => s + o.totalAmount * o.exchangeRate);

    pw.Widget field(String label, String? value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(children: [
            pw.SizedBox(width: 88, child: pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700))),
            pw.Expanded(child: pw.Text((value ?? '').isEmpty ? '—' : value!, style: pw.TextStyle(font: bold, fontSize: 9))),
          ]),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Fiche générée par Wanzo, conçu par i-kiotahub Goma.',
                style: pw.TextStyle(font: regular, fontSize: 7, color: PdfColors.grey600)),
            pw.Text('Page ${ctx.pageNumber}/${ctx.pagesCount}',
                style: pw.TextStyle(font: regular, fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(issuer.name, style: pw.TextStyle(font: bold, fontSize: 13)),
                if (issuer.address.isNotEmpty) pw.Text(issuer.address, style: pw.TextStyle(font: regular, fontSize: 8)),
                if (issuer.phone.isNotEmpty) pw.Text(issuer.phone, style: pw.TextStyle(font: regular, fontSize: 8)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('FICHE DE SUIVI VÉHICULE', style: pw.TextStyle(font: bold, fontSize: 14)),
                pw.Text('Éditée le ${_fmtDate(DateTime.now())}', style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey700)),
              ]),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('VÉHICULE', style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  field('Fabricant', vehicle.brand),
                  field('Modèle', vehicle.model),
                  field('Année', vehicle.year?.toString()),
                  field('Carrosserie', vehicle.bodyType),
                  field('Boîte', vehicle.transmission),
                ]),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('VÉHICULE SPÉCIFIQUE', style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  field('Immatriculation', vehicle.plate),
                  field('Châssis (VIN)', vehicle.vin),
                  field('Couleur', vehicle.color),
                  field('Carburant', vehicle.fuel),
                  field('Kilométrage', vehicle.mileage == null ? null : '${NumberFormat.decimalPattern('fr').format(vehicle.mileage)} km'),
                ]),
              ),
            ]),
          ),
          pw.SizedBox(height: 8),
          field('Propriétaire', customerName),
          if ((vehicle.notes ?? '').isNotEmpty) field('Remarques', vehicle.notes),
          pw.SizedBox(height: 12),
          pw.Text('HISTORIQUE DES INTERVENTIONS (${sorted.length})', style: pw.TextStyle(font: bold, fontSize: 10)),
          pw.SizedBox(height: 6),
          if (sorted.isEmpty)
            pw.Text('Aucune intervention enregistrée pour ce véhicule.',
                style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700))
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(font: bold, fontSize: 8),
              cellStyle: pw.TextStyle(font: regular, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerLeft,
              },
              columnWidths: {
                0: const pw.FixedColumnWidth(52),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FixedColumnWidth(46),
                3: const pw.FlexColumnWidth(2.2),
                4: const pw.FlexColumnWidth(2.2),
                5: const pw.FixedColumnWidth(62),
                6: const pw.FixedColumnWidth(50),
              },
              headers: ['Date', 'Intervention', 'Km', 'Panne signalée', 'Travaux réalisés', 'Montant', 'Statut'],
              data: [
                for (final o in sorted)
                  [
                    _fmtDate(o.entryDate ?? o.createdAt),
                    o.label,
                    o.maintenanceDetails?.mileage ?? '',
                    o.maintenanceDetails?.reportedFault ?? '',
                    o.maintenanceDetails?.repairDone ?? o.maintenanceDetails?.diagnostic ?? '',
                    formatCurrency(o.totalAmount, o.currencyCode),
                    o.status.labelFor(o.metier),
                  ],
              ],
            ),
          pw.SizedBox(height: 8),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Total des interventions : ${formatCurrency(totalCdf, 'CDF')}',
                style: pw.TextStyle(font: bold, fontSize: 9)),
          ),
        ],
      ),
    );
    return doc;
  }

  static String _fileStem(CustomerVehicle v) =>
      'Fiche_vehicule_${(v.plate ?? v.id.substring(0, 8)).replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}';

  /// Impression ou export PDF via le dialogue système.
  static Future<void> printSheet(CustomerVehicle vehicle, List<AtelierOrder> orders,
      {String? customerName, Settings? settings}) async {
    final doc = await build(vehicle, orders, customerName: customerName, settings: settings);
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: _fileStem(vehicle));
  }

  /// Partage (WhatsApp, e-mail...) : la fiche téléchargeable remise au client.
  static Future<void> shareSheet(CustomerVehicle vehicle, List<AtelierOrder> orders,
      {String? customerName, Settings? settings}) async {
    final doc = await build(vehicle, orders, customerName: customerName, settings: settings);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_fileStem(vehicle)}.pdf');
    await file.writeAsBytes(await doc.save());
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Fiche de suivi ${vehicle.displayLabel}',
        text: 'Fiche de suivi du véhicule ${vehicle.displayLabel}',
      ),
    );
  }
}
