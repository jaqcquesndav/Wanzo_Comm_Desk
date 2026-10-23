import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'label_codes.dart';
import 'label_format.dart';
import 'label_item.dart';
import 'label_layout.dart';

/// Barcode du paquet `barcode` (réexporté par `pdf`) pour une symbologie.
pw.Barcode labelBarcodeFor(LabelSymbology s) => switch (s) {
      LabelSymbology.code128 => pw.Barcode.code128(),
      LabelSymbology.ean13 => pw.Barcode.ean13(),
      LabelSymbology.qr => pw.Barcode.qrCode(),
    };

/// Toutes les étiquettes d'une impression, exemplaires compris, dans l'ordre.
List<LabelItem> expandJobs(List<LabelJob> jobs) => [
      for (final j in jobs)
        for (var i = 0; i < j.copies; i++) j.item,
    ];

// ═══════════════════════════════════════════════════════════════════════════
// PDF : impression système (pilote), planches A4, partage
// ═══════════════════════════════════════════════════════════════════════════

/// Format de page PDF d'une étiquette seule (rouleau ou adhésive).
PdfPageFormat labelPageFormat(LabelFormat f) => f.isSheet
    ? PdfPageFormat(f.pageWidthMm * PdfPageFormat.mm,
        f.pageHeightMm * PdfPageFormat.mm)
    : PdfPageFormat(
        f.widthMm * PdfPageFormat.mm, f.heightMm * PdfPageFormat.mm);

Future<Uint8List> buildLabelsPdf({
  required List<LabelJob> jobs,
  required LabelFormat format,
  required LabelOptions options,
  required LabelCodeChoice choice,
}) async {
  final doc = pw.Document(title: 'Etiquettes', creator: 'Wanzo');
  final regular = pw.Font.helvetica();
  final bold = pw.Font.helveticaBold();
  final labels = expandJobs(jobs);
  final cache = <String, LabelLayout>{};
  LabelLayout layoutOf(LabelItem it) => cache.putIfAbsent(
        '${it.id}|${it.code}',
        () => LabelLayout.compute(
            format: format, item: it, options: options, choice: choice),
      );

  const mm = PdfPageFormat.mm;
  if (format.isSheet) {
    final per = format.perPage;
    for (var start = 0; start < labels.length; start += per) {
      final slice = labels.sublist(start, math.min(start + per, labels.length));
      doc.addPage(pw.Page(
        pageFormat: labelPageFormat(format),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(children: [
          for (var i = 0; i < slice.length; i++)
            pw.Positioned(
              left: (format.marginLeftMm +
                      (i % format.columns) * format.widthMm) *
                  mm,
              top: (format.marginTopMm + (i ~/ format.columns) * format.heightMm) *
                  mm,
              child: _pdfLabel(layoutOf(slice[i]), regular, bold),
            ),
        ]),
      ));
    }
  } else {
    for (final it in labels) {
      doc.addPage(pw.Page(
        pageFormat: labelPageFormat(format),
        margin: pw.EdgeInsets.zero,
        build: (_) => _pdfLabel(layoutOf(it), regular, bold),
      ));
    }
  }
  return doc.save();
}

pw.Widget _pdfLabel(LabelLayout l, pw.Font regular, pw.Font bold) {
  const mm = PdfPageFormat.mm;
  final c = l.code;
  return pw.SizedBox(
    width: l.widthMm * mm,
    height: l.heightMm * mm,
    child: pw.Stack(children: [
      for (final t in l.lines)
        pw.Positioned(
          left: t.xMm * mm,
          top: t.yMm * mm,
          child: pw.SizedBox(
            width: t.widthMm * mm,
            child: pw.Text(
              t.text,
              maxLines: 1,
              softWrap: false,
              textAlign: t.centered ? pw.TextAlign.center : pw.TextAlign.left,
              style: pw.TextStyle(
                font: t.bold ? bold : regular,
                fontSize: t.fontPt,
                lineSpacing: 0,
              ),
            ),
          ),
        ),
      if (c.heightMm > 0)
        pw.Positioned(
          left: c.xMm * mm,
          top: c.yMm * mm,
          child: pw.BarcodeWidget(
            barcode: labelBarcodeFor(c.symbology),
            data: c.data,
            width: c.widthMm * mm,
            height: c.heightMm * mm,
            drawText: false,
          ),
        ),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// ESC/POS : imprimantes de caisse (Bluetooth, réseau, intégrée)
// ═══════════════════════════════════════════════════════════════════════════

/// Points imprimables d'une imprimante de caisse selon la largeur du papier.
int escPosDots(LabelFormat f) {
  final paper = f.paperWidthMm;
  if (paper >= 76) return 576; // 80 mm
  if (paper >= 56) return 384; // 58 mm
  return (f.widthMm * 8).round().clamp(160, 576);
}

/// Commandes ESC/POS natives : texte, code-barres (GS k) et QR (GS ( k).
List<int> buildEscPosLabels({
  required List<LabelJob> jobs,
  required LabelFormat format,
  required LabelOptions options,
  required LabelCodeChoice choice,
}) {
  final dots = escPosDots(format);
  final cols = dots ~/ 12; // police A : 12 points par caractère
  final out = <int>[0x1B, 0x40, 0x1B, 0x74, 0x10]; // init + WPC1252
  // Hauteur visée en lignes de 24 points (~3 mm) pour respecter le format.
  final targetDots = (format.heightMm * 8).round();

  for (final it in expandJobs(jobs)) {
    final symb = LabelCodes.symbologyFor(it.code, choice);
    final block = <int>[];
    void line(String s) => block
      ..addAll(_wpc1252(s))
      ..add(0x0A);

    block.addAll([0x1B, 0x61, 0x01]); // centré
    if (options.showCompany && (options.companyName ?? '').trim().isNotEmpty) {
      line(_cut(labelSafeText(options.companyName!), cols));
    }
    block.addAll([0x1B, 0x45, 0x01]);
    for (final l in _wrapChars(labelSafeText(it.name), cols, 2)) {
      line(l);
    }
    block.addAll([0x1B, 0x45, 0x00]);
    final price = _priceText(it, options);
    if (price != null) {
      final big = price.length * 2 <= cols;
      block.addAll([0x1B, 0x45, 0x01, 0x1D, 0x21, big ? 0x11 : 0x01]);
      line(price);
      block.addAll([0x1D, 0x21, 0x00, 0x1B, 0x45, 0x00]);
    }
    if (options.showSecondaryPrice && (it.secondaryPrice ?? '').isNotEmpty) {
      line(labelSafeText(it.secondaryPrice!));
    }

    if (symb == LabelSymbology.qr) {
      final module = (format.heightMm >= 35 ? 5 : 4);
      block.addAll(_escQr(it.code, module));
      block.add(0x0A);
      line(_cut(labelSafeText(it.code), cols));
    } else {
      final modules = symb == LabelSymbology.ean13
          ? LabelCodes.ean13Modules + 14
          : LabelCodes.code128Modules(it.code) + 10;
      final w = (dots ~/ modules).clamp(1, 4);
      final h = (format.heightMm * 8 * 0.35).round().clamp(40, 120);
      block.addAll([0x1D, 0x68, h]); // hauteur
      block.addAll([0x1D, 0x77, w < 2 ? 2 : w]); // largeur du module
      block.addAll([0x1D, 0x48, 0x02]); // texte lisible dessous
      block.addAll([0x1D, 0x66, 0x01]); // police B du texte lisible
      if (symb == LabelSymbology.ean13) {
        final d = it.code.substring(0, 12).codeUnits;
        block.addAll([0x1D, 0x6B, 0x43, 12, ...d]);
      } else {
        final payload = LabelCodes.escPosCode128Payload(it.code);
        block.addAll([0x1D, 0x6B, 0x49, payload.length, ...payload]);
      }
      block.add(0x0A);
    }
    if (options.showExtra && (it.extra ?? '').trim().isNotEmpty) {
      line(_cut(labelSafeText(it.extra!), cols));
    }
    // Compléter jusqu'à la hauteur du format (approximatif : 24 points par
    // ligne de texte, la hauteur du code en plus), puis séparer.
    final approx = _approxDots(block, symb, format);
    final pad = ((targetDots - approx) / 24).ceil().clamp(1, 8);
    block.addAll(List.filled(pad, 0x0A));
    out.addAll(block);
  }
  out.addAll([0x0A, 0x0A, 0x1D, 0x56, 0x41, 0x03]); // avance + coupe
  return out;
}

int _approxDots(List<int> block, LabelSymbology s, LabelFormat f) {
  final lf = block.where((b) => b == 0x0A).length;
  final code = s == LabelSymbology.qr
      ? 120
      : (f.heightMm * 8 * 0.35).round().clamp(40, 120) + 24;
  return lf * 24 + code;
}

String? _priceText(LabelItem it, LabelOptions o) {
  final p = labelSafeText(it.price ?? '');
  if (p.isEmpty) return null;
  final u = labelSafeText(it.unit ?? '');
  return o.showUnit && u.isNotEmpty ? '$p / $u' : p;
}

List<int> _escQr(String data, int module) {
  final bytes = utf8.encode(data);
  final len = bytes.length + 3;
  return [
    0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00, // modèle 2
    0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, module, // taille module
    0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31, // correction M
    0x1D, 0x28, 0x6B, len & 0xFF, (len >> 8) & 0xFF, 0x31, 0x50, 0x30,
    ...bytes,
    0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30, // impression
  ];
}

List<int> _wpc1252(String s) =>
    [for (final r in s.runes) r < 0x100 ? r : 0x3F];

String _cut(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, math.max(0, max - 3)).trimRight()}...';

List<String> _wrapChars(String text, int cols, int maxLines) {
  final words = text.split(' ').where((w) => w.isNotEmpty).toList();
  final out = <String>[];
  var cur = '';
  var i = 0;
  while (i < words.length && out.length < maxLines) {
    final cand = cur.isEmpty ? words[i] : '$cur ${words[i]}';
    if (cand.length <= cols) {
      cur = cand;
      i++;
    } else if (cur.isEmpty) {
      out.add(words[i].substring(0, cols));
      words[i] = words[i].substring(cols);
    } else {
      out.add(cur);
      cur = '';
    }
  }
  if (cur.isNotEmpty && out.length < maxLines) out.add(cur);
  if (i < words.length && out.isNotEmpty) {
    out[out.length - 1] =
        _cut([out.last, ...words.sublist(i)].join(' '), cols);
  }
  return out;
}

// ═══════════════════════════════════════════════════════════════════════════
// TSPL et ZPL : imprimantes d'étiquettes (taille et espacement exacts)
// ═══════════════════════════════════════════════════════════════════════════

const double _dotsPerMm = 8; // 203 dpi

/// Police interne TSPL la plus grande dont la hauteur tient dans [pt].
({String font, int h, int w}) _tsplFont(double pt) {
  final dots = pt * kPtToMm * _dotsPerMm;
  const fonts = [
    ('5', 48, 32),
    ('4', 32, 24),
    ('3', 24, 16),
    ('2', 20, 12),
    ('1', 12, 8),
  ];
  for (final f in fonts) {
    if (f.$2 <= dots * 1.05) return (font: f.$1, h: f.$2, w: f.$3);
  }
  return (font: '1', h: 12, w: 8);
}

String buildTsplLabels({
  required List<LabelJob> jobs,
  required LabelFormat format,
  required LabelOptions options,
  required LabelCodeChoice choice,
}) {
  final b = StringBuffer();
  String n(double v) => v.toStringAsFixed(1);
  int d(double mm) => (mm * _dotsPerMm).round();
  b.writeln('SIZE ${n(format.widthMm)} mm,${n(format.heightMm)} mm');
  b.writeln(format.media == LabelMedia.roll ? 'GAP 0 mm,0 mm' : 'GAP 2 mm,0 mm');
  b.writeln('DIRECTION 1');
  b.writeln('CODEPAGE 1252');
  for (final j in jobs) {
    final l = LabelLayout.compute(
        format: format, item: j.item, options: options, choice: choice);
    b.writeln('CLS');
    for (final t in l.lines) {
      final f = _tsplFont(t.fontPt);
      final txt = labelAsciiText(t.text);
      final maxChars = math.max(1, d(t.widthMm) ~/ f.w);
      final shown = _cut(txt, maxChars);
      final tw = shown.length * f.w;
      final x = t.centered ? d(t.xMm) + math.max(0, (d(t.widthMm) - tw) ~/ 2) : d(t.xMm);
      b.writeln('TEXT $x,${d(t.yMm)},"${f.font}",0,1,1,"$shown"');
    }
    final c = l.code;
    if (c.symbology == LabelSymbology.qr) {
      final cell = math.max(2, d(c.widthMm) ~/ 29).clamp(2, 10);
      b.writeln('QRCODE ${d(c.xMm)},${d(c.yMm)},M,$cell,A,0,"${c.data}"');
    } else {
      final type = c.symbology == LabelSymbology.ean13 ? 'EAN13' : '128';
      final data =
          c.symbology == LabelSymbology.ean13 ? c.data.substring(0, 12) : c.data;
      final modules = c.symbology == LabelSymbology.ean13
          ? LabelCodes.ean13Modules
          : LabelCodes.code128Modules(c.data);
      final narrow = (d(c.widthMm) ~/ modules).clamp(1, 4);
      final x = d(c.xMm) + math.max(0, (d(c.widthMm) - narrow * modules) ~/ 2);
      b.writeln(
          'BARCODE $x,${d(c.yMm)},"$type",${d(c.heightMm)},0,0,$narrow,$narrow,"$data"');
    }
    b.writeln('PRINT 1,${j.copies}');
  }
  return b.toString();
}

String buildZplLabels({
  required List<LabelJob> jobs,
  required LabelFormat format,
  required LabelOptions options,
  required LabelCodeChoice choice,
}) {
  final b = StringBuffer();
  int d(double mm) => (mm * _dotsPerMm).round();
  String esc(String s) =>
      s.replaceAll('^', ' ').replaceAll('~', ' ').replaceAll('\\', '/');
  for (final j in jobs) {
    final l = LabelLayout.compute(
        format: format, item: j.item, options: options, choice: choice);
    b.write('^XA^CI28^PW${d(format.widthMm)}^LL${d(format.heightMm)}');
    for (final t in l.lines) {
      final h = math.max(10, (t.fontPt * kPtToMm * _dotsPerMm).round());
      b.write('^FO${d(t.xMm)},${d(t.yMm)}'
          '^A0N,$h,$h'
          '^FB${d(t.widthMm)},1,0,${t.centered ? 'C' : 'L'},0'
          '^FD${esc(t.text)}^FS');
    }
    final c = l.code;
    if (c.symbology == LabelSymbology.qr) {
      final mag = (d(c.widthMm) ~/ 29).clamp(1, 10);
      b.write('^FO${d(c.xMm)},${d(c.yMm)}^BQN,2,$mag^FDMA,${esc(c.data)}^FS');
    } else {
      final modules = c.symbology == LabelSymbology.ean13
          ? LabelCodes.ean13Modules
          : LabelCodes.code128Modules(c.data);
      final narrow = (d(c.widthMm) ~/ modules).clamp(1, 4);
      final x = d(c.xMm) + math.max(0, (d(c.widthMm) - narrow * modules) ~/ 2);
      if (c.symbology == LabelSymbology.ean13) {
        b.write('^FO$x,${d(c.yMm)}^BY$narrow^BEN,${d(c.heightMm)},N,N'
            '^FD${c.data.substring(0, 12)}^FS');
      } else {
        b.write('^FO$x,${d(c.yMm)}^BY$narrow^BCN,${d(c.heightMm)},N,N,N'
            '^FD${esc(c.data)}^FS');
      }
    }
    b.write('^PQ${j.copies}^XZ\n');
  }
  return b.toString();
}

// ═══════════════════════════════════════════════════════════════════════════
// Epson ePOS-Print (XML sur HTTP)
// ═══════════════════════════════════════════════════════════════════════════

String buildEposLabels({
  required List<LabelJob> jobs,
  required LabelFormat format,
  required LabelOptions options,
  required LabelCodeChoice choice,
}) {
  String x(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  final cols = escPosDots(format) ~/ 12;
  final b = StringBuffer();
  void line(String s) => b.write('<text>${x(s)}&#10;</text>');
  for (final it in expandJobs(jobs)) {
    final symb = LabelCodes.symbologyFor(it.code, choice);
    b.write('<text align="center"/>');
    if (options.showCompany && (options.companyName ?? '').trim().isNotEmpty) {
      line(_cut(labelSafeText(options.companyName!), cols));
    }
    b.write('<text em="true"/>');
    for (final l in _wrapChars(labelSafeText(it.name), cols, 2)) {
      line(l);
    }
    final price = _priceText(it, options);
    if (price != null) {
      b.write('<text dw="${price.length * 2 <= cols}" dh="true"/>');
      line(price);
      b.write('<text dw="false" dh="false"/>');
    }
    b.write('<text em="false"/>');
    if (options.showSecondaryPrice && (it.secondaryPrice ?? '').isNotEmpty) {
      line(labelSafeText(it.secondaryPrice!));
    }
    if (symb == LabelSymbology.qr) {
      b.write('<symbol type="qrcode_model_2" level="level_m" width="5">'
          '${x(it.code)}</symbol>');
      line(it.code);
    } else if (symb == LabelSymbology.ean13) {
      b.write('<barcode type="ean13" hri="below" width="2" height="60">'
          '${it.code.substring(0, 12)}</barcode>');
    } else {
      b.write('<barcode type="code128" hri="below" width="2" height="60">'
          '{B${x(it.code)}</barcode>');
    }
    if (options.showExtra && (it.extra ?? '').trim().isNotEmpty) {
      line(_cut(labelSafeText(it.extra!), cols));
    }
    b.write('<feed line="2"/>');
  }
  b.write('<cut type="feed"/>');
  return '<?xml version="1.0" encoding="utf-8"?>'
      '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>'
      '<epos-print xmlns="http://www.epson-pos.com/schemas/2011/03/epos-print">'
      '$b'
      '</epos-print></s:Body></s:Envelope>';
}
