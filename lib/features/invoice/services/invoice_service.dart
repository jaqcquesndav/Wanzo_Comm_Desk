import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../sales/models/sale.dart';
import '../../proforma/models/proforma.dart';
import '../../settings/models/settings.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import '../utils/invoice_money.dart';

/// En-tête (identité émettrice) à utiliser sur les pièces commerciales.
///
/// Si l'utilisateur courant est rattaché à une BusinessUnit personne morale
/// (coopérant entreprise dans une coopérative, succursale immatriculée),
/// les pièces commerciales DOIVENT porter l'identité légale de CETTE BU.
/// Sinon on retombe sur les Settings de l'entreprise parente.
class _IssuerIdentity {
  final String name;
  final String address;
  final String phone;
  final String rccm;
  final String taxId;
  final String idNat;

  const _IssuerIdentity({
    required this.name,
    required this.address,
    required this.phone,
    required this.rccm,
    required this.taxId,
    required this.idNat,
  });

  factory _IssuerIdentity.from(Settings settings) {
    final ctx = BusinessContextService();
    final useBu = ctx.shouldUseBusinessUnitIdentity;
    // Repli entreprise : quand l'utilisateur n'a pas renseigné l'identité dans
    // les Settings locaux, on retombe sur les identifiants de l'entreprise
    // reçus via /auth/me (Company entity : RCCM/NIF/IdNat).
    String orCompany(String local, String? fromCtx) =>
        local.isNotEmpty ? local : (fromCtx ?? '');
    return _IssuerIdentity(
      name: useBu
          ? (ctx.businessUnitName ?? settings.companyName)
          : orCompany(settings.companyName, ctx.companyName),
      address: useBu
          ? (ctx.businessUnitAddress ?? settings.companyAddress)
          : settings.companyAddress,
      phone: useBu
          ? (ctx.businessUnitPhone ?? settings.companyPhone)
          : settings.companyPhone,
      rccm: useBu
          ? (ctx.businessUnitRccm ?? settings.rccmNumber)
          : orCompany(settings.rccmNumber, ctx.companyRccm),
      taxId: useBu
          ? (ctx.businessUnitTaxId ?? settings.taxIdentificationNumber)
          : orCompany(settings.taxIdentificationNumber, ctx.companyTaxId),
      idNat: useBu
          ? (ctx.businessUnitIdNat ?? settings.idNatNumber)
          : orCompany(settings.idNatNumber, ctx.companyNationalId),
    );
  }
}

/// Ligne du pied d'une pièce, montant signé dans la devise du document.
class InvoiceFooterLine {
  const InvoiceFooterLine(this.label, this.amount, {this.strong = false});

  final String label;

  /// Montant signé : une remise est négative.
  final double amount;
  final bool strong;
}

/// Pied d'une facture ou d'un reçu PDF. TOUS les montants viennent de la base
/// CDF au taux figé de la vente (InvoiceMoney.figures) : lignes, remise, TVA
/// et total s'additionnent sur le papier, et rien n'est réétiqueté.
class InvoiceFooter {
  const InvoiceFooter._(
    this.currencyCode,
    this.figures,
    this.totals,
    this.settlement,
  );

  final String currencyCode;
  final SaleFigures figures;

  /// Sous-total et remise, HT et TVA, puis total à payer.
  final List<InvoiceFooterLine> totals;

  /// Payé, monnaie rendue, solde dû.
  final List<InvoiceFooterLine> settlement;

  factory InvoiceFooter.of(Sale sale, Settings settings) {
    final money = InvoiceMoney.forSale(sale);
    // La TVA n'apparaît que si l'entreprise est assujettie (régime NORMAL) ET
    // que l'affichage des taxes est activé. En régime minimal/SMT : aucune TVA.
    final f = money.figures(
      sale,
      showTax: settings.showTaxes && settings.isTaxSubject,
    );
    // Taux arrondi au centième : « 16 % » et non « 15.999 % ».
    final taux =
        f.totalHt > 0 ? (f.tax / f.totalHt * 10000).round() / 100 : 0.0;
    final tauxLabel = taux == taux.roundToDouble()
        ? taux.toStringAsFixed(0)
        : taux.toStringAsFixed(2);
    return InvoiceFooter._(
      money.currencyCode,
      f,
      [
        if (f.discount > 0) ...[
          InvoiceFooterLine('Sous-total', f.lines),
          InvoiceFooterLine('Remise', -f.discount),
        ],
        if (f.tax > 0) ...[
          InvoiceFooterLine('Total HT', f.totalHt),
          InvoiceFooterLine('TVA ($tauxLabel%)', f.tax),
        ],
        InvoiceFooterLine('Total à payer', f.total, strong: true),
      ],
      [
        if (f.received > 0) InvoiceFooterLine('Montant payé', f.received),
        if (f.change > 0) InvoiceFooterLine('Monnaie rendue', f.change),
        if (f.due > 0) InvoiceFooterLine('Solde dû', f.due),
      ],
    );
  }

  /// Montant signé formaté (« -1 500 FC » pour une remise).
  String format(double amount) => amount < 0
      ? '-${formatCurrency(-amount, currencyCode)}'
      : formatCurrency(amount, currencyCode);
}


/// Contenu du QR imprimé sur la facture et le reçu PDF : identité émettrice
/// (NIF, RCCM) et montants issus du MÊME pied de pièce (base CDF au taux de la
/// vente), donc cohérents avec ce qui est imprimé au-dessus.
String _documentQrData({
  required _IssuerIdentity issuer,
  required Sale sale,
  required InvoiceFooter footer,
  required String formattedDate,
  String? invoiceNumber,
}) {
  final fig = footer.figures;
  final code = footer.currencyCode;
  return <String>[
    if (issuer.name.isNotEmpty) issuer.name,
    if (issuer.taxId.isNotEmpty) 'NIF: ${issuer.taxId}',
    if (issuer.rccm.isNotEmpty) 'RCCM: ${issuer.rccm}',
    'ID: ${sale.id}',
    if (invoiceNumber != null && invoiceNumber.isNotEmpty)
      'FAC: $invoiceNumber',
    'Date: $formattedDate',
    if (sale.customerName.isNotEmpty) 'Client: ${sale.customerName}',
    'Total: ${formatCurrency(fig.total, code)}',
    if (fig.received > 0) 'Paye: ${formatCurrency(fig.received, code)}',
    if (fig.due > 0) 'Solde du: ${formatCurrency(fig.due, code)}',
    if (sale.paymentMethod != null && sale.paymentMethod!.isNotEmpty)
      'Mode: ${sale.paymentMethod}',
    'wanzzo.com',
  ].join('\n');
}

/// Service pour générer et imprimer des factures et tickets de caisse
class InvoiceService {
  /// Ligne du pied de facture A4.
  pw.Widget _invoiceFooterRow(
    InvoiceFooter footer,
    InvoiceFooterLine l,
    pw.Font regularFont,
    pw.Font boldFont, {
    bool settlement = false,
  }) {
    final style = settlement
        ? pw.TextStyle(font: regularFont, fontSize: 10)
        : pw.TextStyle(font: boldFont, fontSize: l.strong ? 12 : null);
    final row = pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 150,
          child: pw.Text('${l.label}:', style: style),
        ),
        pw.Container(
          width: 120,
          child: pw.Text(
            footer.format(l.amount),
            style: settlement || l.strong ? style : null,
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 5),
      child: l.strong
          ? pw.Container(
              padding: const pw.EdgeInsets.all(5),
              color: PdfColors.grey300,
              child: row,
            )
          : row,
    );
  }

  /// Ligne du pied de reçu (ticket PDF 80 mm).
  pw.Widget _receiptFooterRow(
    InvoiceFooter footer,
    InvoiceFooterLine l,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    final style = pw.TextStyle(
      font: l.strong ? boldFont : regularFont,
      fontSize: l.strong ? 10 : 8,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text('${l.label}: ', style: style),
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              footer.format(l.amount),
              style: style,
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// Génère un PDF pour une vente et retourne le chemin du fichier
  /// [proforma] : la même pièce rendue en FACTURE PROFORMA (titre, numéro
  /// PF, numéro provisoire hors ligne, validité, aucune ligne de règlement,
  /// mention « ce n'est pas une facture »). Aucun moteur dupliqué.
  Future<String> generateInvoicePdf(
    Sale sale,
    Settings settings, {
    ProformaMention? proforma,
  }) async {
    final pdf = pw.Document();

    final regularFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final issuer = _IssuerIdentity.from(settings);

    // Devise de présentation du document + conversion de TOUS les montants
    // depuis leur base CDF (voir InvoiceMoney) : une ligne ne peut plus
    // s'imprimer sous le symbole d'une autre devise que la sienne.
    final money = InvoiceMoney.forSale(sale);
    final currencyCode = money.currencyCode;

    pw.Widget? logoWidget;
    if (settings.companyLogo.isNotEmpty) {
      try {
        if (settings.companyLogo.startsWith('assets/')) {
          final logoData = await rootBundle.load(settings.companyLogo);
          final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
          logoWidget = pw.Image(logoImage, width: 80, height: 80);
        } else if (settings.companyLogo.startsWith('http')) {
          final logoImage = await networkImage(settings.companyLogo);
          logoWidget = pw.Image(logoImage, width: 80, height: 80);
        } else {
          final logoFile = File(settings.companyLogo);
          if (await logoFile.exists()) {
            final logoImage = pw.MemoryImage(await logoFile.readAsBytes());
            logoWidget = pw.Image(logoImage, width: 80, height: 80);
          }
        }
      } catch (e) {
        // print('Erreur lors du chargement du logo: $e');
      }
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = dateFormat.format(sale.date);

    String invoiceNumber = settings.invoiceNumberFormat;
    invoiceNumber = invoiceNumber
        .replaceAll('{YEAR}', sale.date.year.toString())
        .replaceAll('{MONTH}', sale.date.month.toString().padLeft(2, '0'))
        .replaceAll('{SEQ}', sale.id.substring(0, 8));
    if (proforma != null) invoiceNumber = proforma.number;

    // Pied de pièce depuis la base CDF au taux figé de la vente : lignes,
    // remise, TVA et totaux s'additionnent (voir InvoiceFooter).
    final footer = InvoiceFooter.of(sale, settings);
    final invoiceQrDataBrut = _documentQrData(
      issuer: issuer,
      sale: sale,
      footer: footer,
      formattedDate: formattedDate,
      invoiceNumber: invoiceNumber,
    );
    // Proforma : ni règlement, ni solde dû, ni mode (ce n'est pas une facture).
    final invoiceQrData = proforma == null
        ? invoiceQrDataBrut
        : invoiceQrDataBrut
            .split('\n')
            .where((l) =>
                !l.startsWith('Paye:') &&
                !l.startsWith('Solde du:') &&
                !l.startsWith('Mode:') &&
                !l.startsWith('FAC:'))
            .join('\n');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête avec logo et informations de l'entreprise
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Logo et informations de l'entreprise à gauche
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoWidget != null) logoWidget,
                        if (logoWidget != null) pw.SizedBox(height: 5),
                        if (issuer.name.isNotEmpty)
                          pw.Text(
                            issuer.name,
                            style: pw.TextStyle(font: boldFont, fontSize: 12),
                          ),
                        if (issuer.address.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            issuer.address,
                            style: pw.TextStyle(font: regularFont, fontSize: 9),
                          ),
                        ],
                        if (issuer.phone.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Tél: ${issuer.phone}',
                            style: pw.TextStyle(font: regularFont, fontSize: 9),
                          ),
                        ],
                        if (issuer.taxId.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'NIF: ${issuer.taxId}',
                            style: pw.TextStyle(font: regularFont, fontSize: 9),
                          ),
                        ],
                        if (issuer.rccm.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'RCCM: ${issuer.rccm}',
                            style: pw.TextStyle(font: regularFont, fontSize: 9),
                          ),
                        ],
                        if (issuer.idNat.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'ID NAT: ${issuer.idNat}',
                            style: pw.TextStyle(font: regularFont, fontSize: 9),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  // Informations de la facture à droite
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          proforma != null ? 'FACTURE PROFORMA' : 'FACTURE',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 18,
                            color: PdfColors.blueGrey700,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'N°: $invoiceNumber',
                          style: pw.TextStyle(font: regularFont, fontSize: 10),
                        ),
                        if (proforma != null && proforma.provisional)
                          pw.Text(
                            'Numéro provisoire',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 9,
                              color: PdfColors.orange800,
                            ),
                          ),
                        if (proforma?.validUntil != null)
                          pw.Text(
                            "Valable jusqu'au ${DateFormat('dd/MM/yyyy').format(proforma!.validUntil!)}",
                            style: pw.TextStyle(font: regularFont, fontSize: 10),
                          ),
                        pw.Text(
                          'Date: $formattedDate',
                          style: pw.TextStyle(font: regularFont, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  children: [
                    pw.Text('CLIENT:', style: pw.TextStyle(font: boldFont)),
                    pw.SizedBox(width: 10),
                    pw.Text(sale.customerName),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Désignation',
                          style: pw.TextStyle(font: boldFont),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Qté',
                          style: pw.TextStyle(font: boldFont),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'P.U.',
                          style: pw.TextStyle(font: boldFont),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Total',
                          style: pw.TextStyle(font: boldFont),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),

                  ...sale.items.map((item) {
                    // Montants ramenés dans la devise du document depuis leur
                    // base CDF : la ligne peut avoir sa propre devise.
                    final itemUnit = money.lineUnit(item);
                    final itemTotal = money.lineTotal(item);
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(item.productName),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            '${item.quantity}',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            formatCurrency(itemUnit, currencyCode),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            formatCurrency(itemTotal, currencyCode),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 10),

              // Pied de facture : chaque montant vient de la base CDF.
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    for (final l in footer.totals)
                      _invoiceFooterRow(footer, l, regularFont, boldFont),
                    for (final l in proforma != null
                        ? const <InvoiceFooterLine>[]
                        : footer.settlement)
                      _invoiceFooterRow(
                        footer,
                        l,
                        regularFont,
                        boldFont,
                        settlement: true,
                      ),
                  ],
                ),
              ),

              if (proforma != null) ...[
                pw.SizedBox(height: 12),
                if ((proforma.attention ?? '').isNotEmpty)
                  pw.Text("À l'attention de ${proforma.attention}",
                      style: pw.TextStyle(font: regularFont, fontSize: 10)),
                pw.Text(
                  "Facture proforma : document sans valeur comptable, ce n'est pas une facture.",
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 10,
                    color: PdfColors.blueGrey700,
                  ),
                ),
              ],
              pw.SizedBox(height: 30),

              if (settings.defaultPaymentTerms.isNotEmpty) ...[
                pw.Text(
                  'Conditions de paiement:',
                  style: pw.TextStyle(font: boldFont),
                ),
                pw.SizedBox(height: 5),
                pw.Text(settings.defaultPaymentTerms),
                pw.SizedBox(height: 10),
              ],

              pw.Spacer(),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          proforma != null
                              ? 'Merci pour votre confiance.'
                              : 'Merci pour votre confiance, merci pour votre achat!',
                          style: pw.TextStyle(font: boldFont, fontSize: 12),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Facture générée par Wanzo, conçu par i-kiotahub Goma.',
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  // QR de la pièce (données de la vente, sans appel réseau).
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: invoiceQrData,
                    width: 80,
                    height: 80,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/${proforma != null ? 'proforma' : 'invoice'}_${sale.id}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  /// Partage la facture PDF générée
  /// Note: Cette méthode est dépréciée. Utilisez PlatformShareService.instance.sharePdfFile()
  /// pour un partage cross-platform robuste.
  @Deprecated('Use PlatformShareService.instance.sharePdfFile() instead')
  Future<void> shareInvoice(
    Sale sale,
    Settings settings, {
    String? customerPhoneNumber,
    String? customerEmail,
  }) async {
    try {
      final pdfPath = await generateInvoicePdf(sale, settings);
      final xFile = XFile(pdfPath);

      String shareText =
          'Voici votre facture N° ${sale.id.substring(0, 8)} concernant ${sale.items.first.productName}.';
      if (customerPhoneNumber != null) {
        shareText += '\nPartage via WhatsApp: wa.me/$customerPhoneNumber';
      }

      // Utilisation de la nouvelle API SharePlus
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: shareText,
          subject: 'Facture N° ${sale.id.substring(0, 8)}',
        ),
      );
    } catch (e) {
      debugPrint('Erreur lors du partage de la facture: $e');
      throw Exception('Impossible de partager la facture: $e');
    }
  }

  /// Génère un ticket de caisse pour une vente et retourne le chemin du fichier
  Future<String> generateReceiptPdf(Sale sale, Settings settings) async {
    final pdf = pw.Document();

    final regularFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final issuer = _IssuerIdentity.from(settings);

    // Devise de présentation du document + conversion de TOUS les montants
    // depuis leur base CDF (voir InvoiceMoney) : une ligne ne peut plus
    // s'imprimer sous le symbole d'une autre devise que la sienne.
    final money = InvoiceMoney.forSale(sale);
    final currencyCode = money.currencyCode;

    pw.Widget? logoWidget;
    if (settings.companyLogo.isNotEmpty) {
      try {
        if (settings.companyLogo.startsWith('assets/')) {
          final logoData = await rootBundle.load(settings.companyLogo);
          final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
          logoWidget = pw.Image(logoImage, width: 60, height: 60);
        } else if (settings.companyLogo.startsWith('http')) {
          final logoImage = await networkImage(settings.companyLogo);
          logoWidget = pw.Image(logoImage, width: 60, height: 60);
        } else {
          final logoFile = File(settings.companyLogo);
          if (await logoFile.exists()) {
            final logoImage = pw.MemoryImage(await logoFile.readAsBytes());
            logoWidget = pw.Image(logoImage, width: 60, height: 60);
          }
        }
      } catch (e) {
        // print('Erreur lors du chargement du logo: $e');
      }
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = dateFormat.format(sale.date);

    // Pied de pièce depuis la base CDF au taux figé de la vente : lignes,
    // remise, TVA et totaux s'additionnent (voir InvoiceFooter).
    final footer = InvoiceFooter.of(sale, settings);
    final receiptQrData = _documentQrData(
      issuer: issuer,
      sale: sale,
      footer: footer,
      formattedDate: formattedDate,
      invoiceNumber: sale.invoiceNumber,
    );
    final ticketWidth = PdfPageFormat(
      80 * PdfPageFormat.mm,
      500 * PdfPageFormat.mm, // Increased height for potentially long receipts
      marginAll: 5 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: ticketWidth,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoWidget != null) ...[
                pw.Center(child: logoWidget),
                pw.SizedBox(height: 5),
              ],

              pw.Text(
                issuer.name,
                style: pw.TextStyle(font: boldFont, fontSize: 12),
                textAlign: pw.TextAlign.center,
              ),

              if (issuer.address.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  issuer.address,
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],

              if (issuer.phone.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'Tél: ${issuer.phone}',
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              if (issuer.taxId.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'NIF: ${issuer.taxId}',
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],

              if (issuer.rccm.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'RCCM: ${issuer.rccm}',
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],

              if (issuer.idNat.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'ID NAT: ${issuer.idNat}',
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],

              pw.SizedBox(height: 5),
              pw.Text(
                // MODIFIED: Make substring safe
                'Ticket N°: ${sale.id.length >= 8 ? sale.id.substring(0, 8) : sale.id}',
                style: pw.TextStyle(font: regularFont, fontSize: 8),
              ),
              pw.Text(
                'Date: $formattedDate',
                style: pw.TextStyle(font: regularFont, fontSize: 8),
              ),
              pw.SizedBox(height: 5),

              pw.Divider(color: PdfColors.black, height: 1),
              pw.SizedBox(height: 3),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      'Article',
                      style: pw.TextStyle(font: boldFont, fontSize: 8),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Qté',
                      style: pw.TextStyle(font: boldFont, fontSize: 8),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'P.U.',
                      style: pw.TextStyle(font: boldFont, fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Total',
                      style: pw.TextStyle(font: boldFont, fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Divider(
                color: PdfColors.black,
                height: 1,
              ), // Garder ce Divider
              pw.SizedBox(height: 3),

              ...sale.items.map((item) {
                // Montants ramenés dans la devise du document depuis leur
                // base CDF : la ligne peut avoir sa propre devise.
                final itemUnit = money.lineUnit(item);
                final itemTotal = money.lineTotal(item);
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          item.productName,
                          style: pw.TextStyle(font: regularFont, fontSize: 8),
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          '${item.quantity}',
                          style: pw.TextStyle(font: regularFont, fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          formatCurrency(itemUnit, currencyCode),
                          style: pw.TextStyle(font: regularFont, fontSize: 8),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          formatCurrency(itemTotal, currencyCode),
                          style: pw.TextStyle(font: regularFont, fontSize: 8),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 5),
              pw.Divider(
                color: PdfColors.black,
                height: 1,
              ), // Garder ce Divider
              pw.SizedBox(height: 3),

              // Pied de reçu : chaque montant vient de la base CDF.
              for (final l in footer.totals)
                _receiptFooterRow(footer, l, regularFont, boldFont),
              pw.SizedBox(height: 8),
              for (final l in footer.settlement)
                _receiptFooterRow(footer, l, regularFont, boldFont),

              pw.SizedBox(height: 10),

              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: receiptQrData,
                  width: 80,
                  height: 80,
                ),
              ),
              pw.SizedBox(height: 5),

              pw.Text(
                'Merci pour votre confiance, merci pour votre achat!',
                style: pw.TextStyle(font: boldFont, fontSize: 9),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Wanzo by i-kiotahub Goma',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/receipt_${sale.id}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  /// Bon de SORTIE DE CAISSE, au format ticket 80 mm.
  ///
  /// Toute somme qui quitte la caisse sans être une vente (avance à un
  /// prestataire, achat au comptant, remboursement) laisse une pièce que le
  /// bénéficiaire signe. On reprend l'entête légal des autres pièces, donc la
  /// même identité émettrice, et la même largeur : la même imprimante sort le
  /// reçu de vente et ce bon.
  Future<String> generateCashOutVoucherPdf({
    required Settings settings,
    required String reference,
    required DateTime date,
    required String beneficiary,
    required String motif,
    required double amount,
    required String currencyCode,
    String? paymentMethod,
    String? note,
  }) async {
    final pdf = pw.Document();
    final regularFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();
    final issuer = _IssuerIdentity.from(settings);
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);
    final montant = formatCurrency(amount, currencyCode);

    final qrData = <String>[
      if (issuer.name.isNotEmpty) issuer.name,
      'BON DE SORTIE DE CAISSE',
      'Ref: $reference',
      'Date: $formattedDate',
      'Beneficiaire: $beneficiary',
      'Montant: $montant',
      'wanzzo.com',
    ].join('\n');

    pw.Widget ligne(String libelle, String valeur, {bool gras = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                libelle,
                style: pw.TextStyle(font: regularFont, fontSize: 8),
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                valeur,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  font: gras ? boldFont : regularFont,
                  fontSize: gras ? 10 : 8,
                ),
              ),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          300 * PdfPageFormat.mm,
          marginAll: 5 * PdfPageFormat.mm,
        ),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                issuer.name,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: boldFont, fontSize: 12),
              ),
            ),
            if (issuer.address.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  issuer.address,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                ),
              ),
            if (issuer.phone.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  'Tél: ${issuer.phone}',
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                ),
              ),
            if (issuer.rccm.isNotEmpty || issuer.taxId.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  [
                    if (issuer.rccm.isNotEmpty) 'RCCM: ${issuer.rccm}',
                    if (issuer.taxId.isNotEmpty) 'NIF: ${issuer.taxId}',
                  ].join('  '),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: regularFont, fontSize: 7),
                ),
              ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 0.5),
            pw.Center(
              child: pw.Text(
                'BON DE SORTIE DE CAISSE',
                style: pw.TextStyle(font: boldFont, fontSize: 11),
              ),
            ),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 6),
            ligne('N°', reference),
            ligne('Date', formattedDate),
            ligne('Bénéficiaire', beneficiary),
            ligne('Motif', motif),
            if (paymentMethod != null && paymentMethod.isNotEmpty)
              ligne('Règlement', paymentMethod),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 0.5),
            ligne('MONTANT VERSÉ', montant, gras: true),
            pw.Divider(thickness: 0.5),
            if (note != null && note.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                note,
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
            ],
            pw.SizedBox(height: 18),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Le caissier',
                          style: pw.TextStyle(font: regularFont, fontSize: 8)),
                      pw.SizedBox(height: 20),
                      pw.Text('..............',
                          style: pw.TextStyle(font: regularFont, fontSize: 8)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Le bénéficiaire',
                          style: pw.TextStyle(font: regularFont, fontSize: 8)),
                      pw.SizedBox(height: 20),
                      pw.Text('..............',
                          style: pw.TextStyle(font: regularFont, fontSize: 8)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrData,
                width: 70,
                height: 70,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                'Wanzo by i-kiotahub Goma',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/bon_sortie_$reference.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  /// Imprime directement une facture ou un ticket (nécessite une imprimante configurée)
  Future<void> printDocument(String filePath, {bool isReceipt = false}) async {
    try {
      // Pour l'impression directe, on peut utiliser printing.layoutPdf
      // ou pour une impression plus contrôlée, on peut utiliser platform-specific code.
      // Ici, on utilise une méthode simple qui pourrait ouvrir le dialogue d'impression.
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          final file = File(filePath);
          return file.readAsBytes();
        },
        name:
            isReceipt
                ? 'Receipt_${DateTime.now().millisecondsSinceEpoch}'
                : 'Invoice_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      // print('Erreur lors de l'impression du document: $e');
      throw Exception(
        'Impossible d\'imprimer le document: $e',
      ); // Escaped apostrophe
    }
  }
}

// Helper function to load font (if needed for custom fonts, not used with Helvetica)
// Future<pw.Font> loadFont(String path) async {
//   final fontData = await rootBundle.load(path);
//   return pw.Font.ttf(fontData);
// }

// Example of how to get a default font if a custom one fails (not directly used here)
// pw.Font getFallbackFont() {
//   return pw.Font.helvetica();
// }
