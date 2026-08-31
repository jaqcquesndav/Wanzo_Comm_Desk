import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/features/atelier/models/atelier_order.dart';
import 'package:wanzo/features/settings/models/settings.dart';

/// Génère la FICHE (état de sortie) imprimable d'une commande d'atelier.
///
/// C'est le document que l'atelier remet au client au retrait :
/// - métier **maintenance** → « Fiche de réception et de réparation »
///   (appareil, panne, diagnostic, réparation, état de sortie, test, garantie) ;
/// - métier **couture / cordonnerie** → « Fiche de commande / bon de livraison »
///   (désignation, renvoi vers la fiche mesures, montants).
///
/// Réutilise EXACTEMENT les mêmes dépendances (`pdf` + `printing` + `share_plus`)
/// et le même point d'entrée d'impression (`Printing.layoutPdf`) que les factures
/// (`InvoiceService`) — aucune nouvelle dépendance.
class AtelierSheetPdf {
  /// En-tête émetteur : identité de la BusinessUnit si l'utilisateur y est
  /// rattaché (même règle que les pièces commerciales), sinon les Settings.
  static ({
    String name,
    String address,
    String phone,
    String rccm,
    String taxId,
    String idNat,
  }) _issuer(
    Settings? settings,
  ) {
    final ctx = BusinessContextService();
    final useBu = ctx.shouldUseBusinessUnitIdentity;
    String pick(String? bu, String? fallback) {
      final v = useBu ? (bu ?? fallback) : fallback;
      return v ?? '';
    }

    return (
      name: pick(ctx.businessUnitName, settings?.companyName).isNotEmpty
          ? pick(ctx.businessUnitName, settings?.companyName)
          : 'Atelier',
      address: pick(ctx.businessUnitAddress, settings?.companyAddress),
      phone: pick(ctx.businessUnitPhone, settings?.companyPhone),
      rccm: pick(ctx.businessUnitRccm, settings?.rccmNumber),
      taxId: pick(ctx.businessUnitTaxId, settings?.taxIdentificationNumber),
      idNat: pick(ctx.businessUnitIdNat, settings?.idNatNumber),
    );
  }

  static String _shortId(String id) =>
      id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  static String _fmtDate(DateTime? d) =>
      d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);

  static const Map<String, String> _exitStates = {
    'repaired': 'Réparé',
    'partial': 'Partiel',
    'not_repaired': 'Non réparé',
    'irreparable': 'Irréparable',
  };

  static const Map<String, String> _testResults = {
    'conform': 'Conforme',
    'to_review': 'À revoir',
    'not_tested': 'Non testé',
  };

  /// Construit le document PDF (A4) selon le métier de la commande.
  static Future<pw.Document> build(
    AtelierOrder order, {
    Settings? settings,
  }) async {
    final doc = pw.Document();
    final regular = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final italic = pw.Font.helveticaOblique();
    final issuer = _issuer(settings);

    pw.Widget? logo;
    final logoPath = settings?.companyLogo ?? '';
    if (logoPath.isNotEmpty) {
      try {
        if (logoPath.startsWith('assets/')) {
          final data = await rootBundle.load(logoPath);
          logo = pw.Image(pw.MemoryImage(data.buffer.asUint8List()),
              width: 64, height: 64);
        } else if (logoPath.startsWith('http')) {
          logo = pw.Image(await networkImage(logoPath), width: 64, height: 64);
        } else {
          final f = File(logoPath);
          if (await f.exists()) {
            logo = pw.Image(pw.MemoryImage(await f.readAsBytes()),
                width: 64, height: 64);
          }
        }
      } catch (_) {
        // Logo optionnel : on ignore toute erreur de chargement.
      }
    }

    final isMaintenance = order.metier == AtelierMetier.maintenance;
    final title = isMaintenance
        ? 'FICHE DE RÉCEPTION ET DE RÉPARATION'
        : 'FICHE DE COMMANDE / BON DE LIVRAISON';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(issuer, title, logo, regular, bold),
              pw.SizedBox(height: 10),
              _metaBar(order, regular, bold, isMaintenance),
              pw.SizedBox(height: 12),
              _clientBox(order, regular, bold),
              pw.SizedBox(height: 12),
              if (isMaintenance)
                ..._maintenanceBody(order, regular, bold, italic)
              else
                ..._confectionBody(order, regular, bold, italic),
              pw.SizedBox(height: 12),
              _amountsTable(order, regular, bold),
              pw.SizedBox(height: 12),
              if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
                _sectionTitle('OBSERVATIONS', bold),
                _paragraph(order.notes!, regular),
                pw.SizedBox(height: 12),
              ],
              pw.Spacer(),
              _signatures(regular, bold, isMaintenance),
              pw.SizedBox(height: 6),
              pw.Text(
                'Fiche générée par Wanzo, conçu par i-kiotahub Goma.',
                style: pw.TextStyle(
                    font: regular, fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          );
        },
      ),
    );
    return doc;
  }

  // ── En-tête ─────────────────────────────────────────────────────────────
  static pw.Widget _header(
    ({
      String name,
      String address,
      String phone,
      String rccm,
      String taxId,
      String idNat,
    }) issuer,
    String title,
    pw.Widget? logo,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logo != null) ...[
                    logo,
                    pw.SizedBox(width: 10),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(issuer.name,
                            style: pw.TextStyle(font: bold, fontSize: 14)),
                        if (issuer.address.isNotEmpty)
                          pw.Text(issuer.address,
                              style: pw.TextStyle(font: regular, fontSize: 9)),
                        if (issuer.phone.isNotEmpty)
                          pw.Text('Tél: ${issuer.phone}',
                              style: pw.TextStyle(font: regular, fontSize: 9)),
                        if (issuer.taxId.isNotEmpty)
                          pw.Text('NIF: ${issuer.taxId}',
                              style: pw.TextStyle(font: regular, fontSize: 9)),
                        if (issuer.rccm.isNotEmpty)
                          pw.Text('RCCM: ${issuer.rccm}',
                              style: pw.TextStyle(font: regular, fontSize: 9)),
                        if (issuer.idNat.isNotEmpty)
                          pw.Text('ID NAT: ${issuer.idNat}',
                              style: pw.TextStyle(font: regular, fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          color: PdfColors.blueGrey800,
          child: pw.Text(
            title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                font: bold, fontSize: 13, color: PdfColors.white),
          ),
        ),
      ],
    );
  }

  // ── Bandeau n° de fiche + dates ─────────────────────────────────────────
  static pw.Widget _metaBar(
    AtelierOrder order,
    pw.Font regular,
    pw.Font bold,
    bool isMaintenance,
  ) {
    pw.Widget cell(String label, String value) => pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      font: bold, fontSize: 8, color: PdfColors.grey700)),
              pw.Text(value, style: pw.TextStyle(font: regular, fontSize: 10)),
            ],
          ),
        );

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          cell('FICHE N°', _shortId(order.id)),
          cell(isMaintenance ? 'RÉCEPTION' : 'ENREGISTREMENT',
              _fmtDate(order.entryDate)),
          cell(isMaintenance ? 'RETRAIT PRÉVU' : 'LIVRAISON PRÉVUE',
              _fmtDate(order.exitDate)),
          cell('STATUT', order.status.labelFor(order.metier)),
        ],
      ),
    );
  }

  // ── Client ──────────────────────────────────────────────────────────────
  static pw.Widget _clientBox(
    AtelierOrder order,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Text('CLIENT : ', style: pw.TextStyle(font: bold, fontSize: 10)),
          pw.Expanded(
            child: pw.Text(order.customerName ?? '—',
                style: pw.TextStyle(font: regular, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  // ── Corps MAINTENANCE ───────────────────────────────────────────────────
  static List<pw.Widget> _maintenanceBody(
    AtelierOrder order,
    pw.Font regular,
    pw.Font bold,
    pw.Font italic,
  ) {
    final d = order.maintenanceDetails;
    final rows = <List<String>>[
      ['Type d\'appareil', d?.deviceType ?? '—'],
      ['Marque', d?.brand ?? '—'],
      ['Modèle', d?.model ?? '—'],
      ['N° de série / IMEI', d?.serialNumber ?? '—'],
      ['Couleur', d?.color ?? '—'],
      ['État extérieur', d?.exteriorState ?? '—'],
      ['Accessoires reçus', d?.accessories ?? '—'],
    ];

    return [
      _sectionTitle('APPAREIL', bold),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: const {
          0: pw.FlexColumnWidth(2),
          1: pw.FlexColumnWidth(3),
        },
        children: [
          for (final r in rows)
            pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(r[0],
                    style: pw.TextStyle(font: bold, fontSize: 9)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(r[1],
                    style: pw.TextStyle(font: regular, fontSize: 9)),
              ),
            ]),
        ],
      ),
      pw.SizedBox(height: 10),
      _sectionTitle('PANNE SIGNALÉE', bold),
      _paragraph(d?.reportedFault ?? '—', regular),
      pw.SizedBox(height: 8),
      _sectionTitle('DIAGNOSTIC TECHNIQUE', bold),
      _paragraph(d?.diagnostic ?? '—', regular),
      pw.SizedBox(height: 8),
      _sectionTitle('RÉPARATION EFFECTUÉE', bold),
      _paragraph(d?.repairDone ?? '—', regular),
      pw.SizedBox(height: 10),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _checklist(
                'ÉTAT DE SORTIE', _exitStates, d?.exitState, regular, bold),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: _checklist(
                'TEST FINAL', _testResults, d?.testResult, regular, bold),
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Row(
        children: [
          pw.Expanded(
            child: _inlineField(
                'Garantie',
                d?.warrantyDays != null ? '${d!.warrantyDays} jours' : '—',
                regular,
                bold),
          ),
          pw.Expanded(
            child: _inlineField(
                'Technicien', d?.technicianName ?? '—', regular, bold),
          ),
          pw.Expanded(
            child: _inlineField(
                'Date de sortie', _fmtDate(order.exitDate), regular, bold),
          ),
        ],
      ),
    ];
  }

  // ── Corps COUTURE / CORDONNERIE ─────────────────────────────────────────
  static List<pw.Widget> _confectionBody(
    AtelierOrder order,
    pw.Font regular,
    pw.Font bold,
    pw.Font italic,
  ) {
    final designation = [
      order.label,
      if (order.modelDetails != null && order.modelDetails!.trim().isNotEmpty)
        order.modelDetails!,
    ].join(' — ');

    return [
      _sectionTitle('DÉSIGNATION', bold),
      _paragraph(designation.isEmpty ? '—' : designation, regular),
      pw.SizedBox(height: 8),
      _sectionTitle('MESURES', bold),
      pw.Text(
        'Voir fiche mesures du client.',
        style: pw.TextStyle(font: italic, fontSize: 9, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 8),
      if (order.fabricProvidedBy != null)
        _inlineField('Tissu fourni par', order.fabricProvidedBy!.label,
            regular, bold),
    ];
  }

  // ── Tableau des montants ────────────────────────────────────────────────
  static pw.Widget _amountsTable(
    AtelierOrder order,
    pw.Font regular,
    pw.Font bold,
  ) {
    pw.TableRow row(String label, String value, {bool strong = false}) {
      final f = strong ? bold : regular;
      return pw.TableRow(children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(label, style: pw.TextStyle(font: f, fontSize: 10)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: f, fontSize: 10)),
        ),
      ]);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('MONTANTS',
                  style: pw.TextStyle(font: bold, fontSize: 10)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Devise : ${order.currencyCode}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: bold, fontSize: 9)),
            ),
          ],
        ),
        row('Total à payer',
            formatCurrency(order.totalAmount, order.currencyCode)),
        row('Avance reçue',
            formatCurrency(order.advanceAmount, order.currencyCode)),
        row('Solde',
            formatCurrency(order.remainingAmount, order.currencyCode),
            strong: true),
      ],
    );
  }

  // ── Signatures ──────────────────────────────────────────────────────────
  static pw.Widget _signatures(
    pw.Font regular,
    pw.Font bold,
    bool isMaintenance,
  ) {
    pw.Widget line(String caption) => pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 24),
              pw.Container(height: 1, color: PdfColors.grey600),
              pw.SizedBox(height: 3),
              pw.Text(caption,
                  style: pw.TextStyle(font: regular, fontSize: 8)),
            ],
          ),
        );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        line(isMaintenance ? 'Technicien' : 'Atelier'),
        pw.SizedBox(width: 16),
        line('Client (« reçu conforme »)'),
        pw.SizedBox(width: 16),
        line('Responsable atelier'),
      ],
    );
  }

  // ── Helpers de mise en forme ────────────────────────────────────────────
  static pw.Widget _sectionTitle(String text, pw.Font bold) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(text,
            style: pw.TextStyle(
                font: bold, fontSize: 10, color: PdfColors.blueGrey800)),
      );

  static pw.Widget _paragraph(String text, pw.Font regular) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Text(text.trim().isEmpty ? '—' : text.trim(),
            style: pw.TextStyle(font: regular, fontSize: 9)),
      );

  static pw.Widget _inlineField(
    String label,
    String value,
    pw.Font regular,
    pw.Font bold,
  ) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(right: 8),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                  text: '$label : ',
                  style: pw.TextStyle(font: bold, fontSize: 9)),
              pw.TextSpan(
                  text: value,
                  style: pw.TextStyle(font: regular, fontSize: 9)),
            ],
          ),
        ),
      );

  static pw.Widget _checklist(
    String title,
    Map<String, String> options,
    String? selected,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 9)),
          pw.SizedBox(height: 3),
          for (final entry in options.entries)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 9,
                  height: 9,
                  margin: const pw.EdgeInsets.only(right: 4, top: 1),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey700),
                    color: entry.key == selected
                        ? PdfColors.blueGrey800
                        : PdfColors.white,
                  ),
                  child: entry.key == selected
                      ? pw.Center(
                          child: pw.Text('X',
                              style: pw.TextStyle(
                                  font: bold,
                                  fontSize: 7,
                                  color: PdfColors.white)),
                        )
                      : null,
                ),
                pw.Text(entry.value,
                    style: pw.TextStyle(font: regular, fontSize: 9)),
              ],
            ),
        ],
      ),
    );
  }

  /// Ouvre le dialogue d'impression système (impression, PDF ou partage),
  /// exactement comme `InvoiceService.printDocument`.
  static Future<void> printSheet(
    AtelierOrder order, {
    Settings? settings,
  }) async {
    final doc = await build(order, settings: settings);
    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Fiche_atelier_${_shortId(order.id)}',
    );
  }

  /// Enregistre le PDF puis le partage (WhatsApp, e-mail…), comme
  /// `InvoiceService.shareInvoice`.
  static Future<void> shareSheet(
    AtelierOrder order, {
    Settings? settings,
  }) async {
    final doc = await build(order, settings: settings);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/fiche_atelier_${order.id}.pdf');
    await file.writeAsBytes(await doc.save());
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Fiche atelier ${_shortId(order.id)}',
        text: 'Fiche atelier — ${order.label}',
      ),
    );
  }
}
