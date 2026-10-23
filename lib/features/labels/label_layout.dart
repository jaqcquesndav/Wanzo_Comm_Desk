import 'dart:math' as math;

import 'package:pdf/pdf.dart';

import 'label_codes.dart';
import 'label_format.dart';
import 'label_item.dart';

/// 1 point typographique en millimètres.
const double kPtToMm = 25.4 / 72;

enum LabelTextRole { company, name, price, secondary, extra, code }

/// Ligne de texte placée (millimètres depuis le coin haut gauche).
class LabelTextLine {
  final LabelTextRole role;
  final String text;
  final double fontPt;
  final bool bold;
  final double xMm;
  final double yMm;
  final double widthMm;
  final bool centered;

  /// Largeur réelle du texte (police Helvetica du PDF).
  final double textWidthMm;

  const LabelTextLine({
    required this.role,
    required this.text,
    required this.fontPt,
    required this.bold,
    required this.xMm,
    required this.yMm,
    required this.widthMm,
    required this.centered,
    required this.textWidthMm,
  });

  double get heightMm => fontPt * kLineFactor * kPtToMm;
  static const double kLineFactor = 1.18;
}

/// Zone du code (code-barres ou QR).
class LabelCodeBox {
  final LabelSymbology symbology;
  final String data;
  final double xMm;
  final double yMm;
  final double widthMm;
  final double heightMm;

  /// Largeur d'un module (barre la plus fine) en mm, pour les codes linéaires.
  final double moduleMm;

  const LabelCodeBox({
    required this.symbology,
    required this.data,
    required this.xMm,
    required this.yMm,
    required this.widthMm,
    required this.heightMm,
    required this.moduleMm,
  });
}

/// Mise en page d'une étiquette : source UNIQUE de l'aperçu, du PDF et des
/// commandes TSPL/ZPL. Le nom est coupé ou tronqué proprement, le prix n'est
/// JAMAIS tronqué (sa police réduit), rien ne déborde du cadre.
class LabelLayout {
  final double widthMm;
  final double heightMm;
  final double paddingMm;
  final List<LabelTextLine> lines;
  final LabelCodeBox code;
  final List<String> warnings;

  /// Faux si un élément obligatoire (prix, code) ne tient pas.
  final bool fits;

  const LabelLayout({
    required this.widthMm,
    required this.heightMm,
    required this.paddingMm,
    required this.lines,
    required this.code,
    required this.warnings,
    required this.fits,
  });

  LabelTextLine? line(LabelTextRole role) {
    for (final l in lines) {
      if (l.role == role) return l;
    }
    return null;
  }

  /// Densité minimale lisible par un lecteur courant (module de 0,19 mm).
  static const double minModuleMm = 0.19;

  static final PdfDocument _metricsDoc = PdfDocument();
  static final PdfFont _regular = PdfFont.helvetica(_metricsDoc);
  static final PdfFont _bold = PdfFont.helveticaBold(_metricsDoc);

  /// Largeur d'un texte en mm (Helvetica, celle du PDF).
  static double textWidthMm(String text, double pt, {bool bold = false}) {
    if (text.isEmpty) return 0;
    final f = bold ? _bold : _regular;
    return f.stringMetrics(text).advanceWidth * pt * kPtToMm;
  }

  static LabelLayout compute({
    required LabelFormat format,
    required LabelItem item,
    required LabelOptions options,
    required LabelCodeChoice choice,
  }) {
    final w = format.widthMm;
    final h = format.heightMm;
    final pad = (math.min(w, h) * 0.06).clamp(1.2, 3.0).toDouble();
    final innerW = w - 2 * pad;
    final innerH = h - 2 * pad;
    final symb = LabelCodes.symbologyFor(item.code, choice);

    final horizontalQr =
        symb == LabelSymbology.qr && innerW >= innerH * 1.25;
    final qrSide = horizontalQr ? math.min(innerH, innerW * 0.42) : 0.0;
    const colGap = 1.5;
    final textX = horizontalQr ? pad + qrSide + colGap : pad;
    final textW = horizontalQr ? innerW - qrSide - colGap : innerW;

    final content = _Content.from(item, options);

    // Passes successives : police réduite, puis éléments facultatifs retirés,
    // puis nom sur une seule ligne. On garde la première qui tient.
    _Attempt? best;
    for (final drop in _Drop.values) {
      for (var s = 1.0; s >= 0.55; s -= 0.05) {
        final a = _attempt(
          content: content.without(drop),
          textW: textW,
          innerH: innerH,
          innerW: innerW,
          scale: s,
          symb: symb,
          horizontalQr: horizontalQr,
          nameLinesMax: drop.index >= _Drop.allOptional.index
              ? 1
              : (horizontalQr ? 3 : (innerH >= 22 ? 2 : 1)),
        );
        best = a;
        if (a.ok) break;
      }
      if (best!.ok) break;
    }
    final a = best!;

    // Placement vertical : texte en haut, code dessous (code linéaire et QR
    // vertical) ; colonne de texte centrée à droite du QR (QR horizontal).
    final lines = <LabelTextLine>[];
    final warnings = <String>[];
    late LabelCodeBox codeBox;
    const gap = 0.6;

    double place(List<_Line> src, double y, double x, double width,
        {required bool centered}) {
      for (final l in src) {
        final tw = textWidthMm(l.text, l.pt, bold: l.bold);
        lines.add(LabelTextLine(
          role: l.role,
          text: l.text,
          fontPt: l.pt,
          bold: l.bold,
          xMm: x,
          yMm: y,
          widthMm: width,
          centered: centered,
          textWidthMm: tw,
        ));
        y += l.pt * LabelTextLine.kLineFactor * kPtToMm;
      }
      return y;
    }

    if (horizontalQr) {
      final colH = a.textHeight;
      final y0 = pad + math.max(0, (innerH - colH) / 2);
      place(a.top, y0, textX, textW, centered: false);
      codeBox = LabelCodeBox(
        symbology: symb,
        data: item.code,
        xMm: pad,
        yMm: pad + (innerH - qrSide) / 2,
        widthMm: qrSide,
        heightMm: qrSide,
        moduleMm: 0,
      );
    } else {
      final topH = _height(a.top);
      final bottomH = _height(a.bottom);
      final codeH = a.codeHeight;
      final used = topH + gap + codeH + (bottomH > 0 ? gap + bottomH : 0);
      var y = pad + math.max(0, (innerH - used) / 2);
      y = place(a.top, y, pad, innerW, centered: true);
      y += gap;
      final codeW = symb == LabelSymbology.qr ? codeH : innerW;
      codeBox = LabelCodeBox(
        symbology: symb,
        data: item.code,
        xMm: pad + (innerW - codeW) / 2,
        yMm: y,
        widthMm: codeW,
        heightMm: codeH,
        moduleMm: _moduleMm(symb, item.code, innerW),
      );
      y += codeH + gap;
      place(a.bottom, y, pad, innerW, centered: true);
    }

    if (codeBox.symbology != LabelSymbology.qr &&
        codeBox.moduleMm < minModuleMm) {
      warnings.add('Code trop long pour cette largeur : choisissez le QR code '
          'ou un format plus large.');
    }
    if (!a.ok) {
      warnings.add('Étiquette trop petite pour tout afficher : '
          'choisissez un format plus grand.');
    }
    if (a.droppedOptional) {
      warnings.add('Certaines mentions facultatives ne tiennent pas sur ce '
          'format.');
    }

    return LabelLayout(
      widthMm: w,
      heightMm: h,
      paddingMm: pad,
      lines: lines,
      code: codeBox,
      warnings: warnings,
      fits: a.ok,
    );
  }

  static double _moduleMm(LabelSymbology s, String code, double width) {
    switch (s) {
      case LabelSymbology.ean13:
        return width / (LabelCodes.ean13Modules + 14); // zones calmes
      case LabelSymbology.code128:
        return width / (LabelCodes.code128Modules(code) + 10);
      case LabelSymbology.qr:
        return 0;
    }
  }

  static double _height(List<_Line> l) => l.fold(
      0.0, (s, e) => s + e.pt * LabelTextLine.kLineFactor * kPtToMm);

  static _Attempt _attempt({
    required _Content content,
    required double textW,
    required double innerH,
    required double innerW,
    required double scale,
    required LabelSymbology symb,
    required bool horizontalQr,
    required int nameLinesMax,
  }) {
    final hPt = innerH / kPtToMm;
    final namePt = (hPt * 0.12 * scale).clamp(4.5, 13.0).toDouble();
    var pricePt = (hPt * 0.16 * scale).clamp(5.5, 18.0).toDouble();
    final smallPt = (hPt * 0.075 * scale).clamp(4.0, 8.0).toDouble();
    var ok = true;

    final top = <_Line>[];
    if (content.company != null) {
      top.add(_Line(LabelTextRole.company,
          _ellipsize(content.company!, smallPt, false, textW), smallPt, false));
    }
    for (final l in _wrap(content.name, namePt, true, textW, nameLinesMax)) {
      top.add(_Line(LabelTextRole.name, l, namePt, true));
    }
    if (content.price != null) {
      var p = content.price!;
      // Le prix n'est jamais coupé : sa police réduit jusqu'à tenir.
      while (textWidthMm(p, pricePt, bold: true) > textW && pricePt > 5) {
        pricePt -= 0.5;
      }
      if (textWidthMm(p, pricePt, bold: true) > textW) {
        ok = false;
        // Dernier recours (format minuscule) : sans l'unité accolée.
        p = content.priceBare ?? p;
      }
      top.add(_Line(LabelTextRole.price, p, pricePt, true));
    }
    if (content.secondary != null) {
      final s = content.secondary!;
      if (textWidthMm(s, smallPt) <= textW) {
        top.add(_Line(LabelTextRole.secondary, s, smallPt, false));
      }
    }
    final bottom = <_Line>[];
    final codeText = _ellipsize(content.code, smallPt, false, textW);
    final extra = content.extra == null
        ? null
        : _Line(LabelTextRole.extra,
            _ellipsize(content.extra!, smallPt, false, textW), smallPt, false);

    if (horizontalQr) {
      if (extra != null) top.add(extra);
      top.add(_Line(LabelTextRole.code, codeText, smallPt, false));
      final th = _height(top);
      return _Attempt(
        top: top,
        bottom: const [],
        codeHeight: 0,
        textHeight: th,
        ok: ok && th <= innerH,
        droppedOptional: content.dropped,
      );
    }

    bottom.add(_Line(LabelTextRole.code, codeText, smallPt, false));
    if (extra != null) bottom.add(extra);
    const gaps = 1.2;
    final remaining = innerH - _height(top) - _height(bottom) - gaps;
    final double minCode;
    final double maxCode;
    if (symb == LabelSymbology.qr) {
      minCode = 8;
      maxCode = innerW;
    } else {
      minCode = math.max(4.0, innerH * 0.22);
      maxCode = 15;
    }
    final codeH = math.min(remaining, maxCode);
    return _Attempt(
      top: top,
      bottom: bottom,
      codeHeight: math.max(codeH, 0),
      textHeight: 0,
      ok: ok && codeH >= minCode,
      droppedOptional: content.dropped,
    );
  }

  /// Découpe le nom en [maxLines] lignes au plus ; la dernière est tronquée
  /// par « ... » si le nom ne tient pas.
  static List<String> _wrap(
      String text, double pt, bool bold, double width, int maxLines) {
    bool fits(String t) => textWidthMm(t, pt, bold: bold) <= width;
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    final out = <String>[];
    var idx = 0;
    var current = '';
    while (idx < words.length && out.length < maxLines) {
      final word = words[idx];
      final candidate = current.isEmpty ? word : '$current $word';
      if (fits(candidate)) {
        current = candidate;
        idx++;
        continue;
      }
      if (current.isEmpty) {
        // Mot plus long que la ligne : coupé au caractère.
        var cut = word.length - 1;
        while (cut > 1 && !fits(word.substring(0, cut))) {
          cut--;
        }
        out.add(word.substring(0, cut));
        words[idx] = word.substring(cut);
        continue;
      }
      out.add(current);
      current = '';
    }
    if (current.isNotEmpty) out.add(current);
    if (idx < words.length) {
      final last = out.removeLast();
      out.add(
          _ellipsize([last, ...words.sublist(idx)].join(' '), pt, bold, width));
    }
    return out;
  }

  static String _ellipsize(String text, double pt, bool bold, double width) {
    if (textWidthMm(text, pt, bold: bold) <= width) return text;
    var t = text;
    while (t.isNotEmpty &&
        textWidthMm('${t.trimRight()}...', pt, bold: bold) > width) {
      t = t.substring(0, t.length - 1);
    }
    return t.isEmpty ? '' : '${t.trimRight()}...';
  }
}

enum _Drop { none, extra, secondary, company, allOptional }

class _Content {
  final String name;
  final String? price;
  final String? priceBare;
  final String? secondary;
  final String? company;
  final String? extra;
  final String code;
  final bool dropped;

  const _Content({
    required this.name,
    required this.price,
    required this.priceBare,
    required this.secondary,
    required this.company,
    required this.extra,
    required this.code,
    this.dropped = false,
  });

  factory _Content.from(LabelItem item, LabelOptions o) {
    String? opt(String? v) {
      final t = labelSafeText(v ?? '');
      return t.isEmpty ? null : t;
    }

    final price = opt(item.price);
    final unit = o.showUnit ? opt(item.unit) : null;
    return _Content(
      name: labelSafeText(item.name).isEmpty ? 'Article' : labelSafeText(item.name),
      price: price == null ? null : (unit == null ? price : '$price / $unit'),
      priceBare: price,
      secondary: o.showSecondaryPrice ? opt(item.secondaryPrice) : null,
      company: o.showCompany ? opt(o.companyName) : null,
      extra: o.showExtra ? opt(item.extra) : null,
      code: labelSafeText(item.code),
    );
  }

  _Content without(_Drop d) {
    if (d == _Drop.none) return this;
    final i = d.index;
    return _Content(
      name: name,
      price: i >= _Drop.allOptional.index ? priceBare : price,
      priceBare: priceBare,
      secondary: i >= _Drop.secondary.index ? null : secondary,
      company: i >= _Drop.company.index ? null : company,
      extra: i >= _Drop.extra.index ? null : extra,
      code: code,
      dropped: (i >= _Drop.extra.index && extra != null) ||
          (i >= _Drop.secondary.index && secondary != null) ||
          (i >= _Drop.company.index && company != null) ||
          (i >= _Drop.allOptional.index && price != priceBare),
    );
  }
}

class _Line {
  final LabelTextRole role;
  final String text;
  final double pt;
  final bool bold;
  const _Line(this.role, this.text, this.pt, this.bold);
}

class _Attempt {
  final List<_Line> top;
  final List<_Line> bottom;
  final double codeHeight;
  final double textHeight;
  final bool ok;
  final bool droppedOptional;
  const _Attempt({
    required this.top,
    required this.bottom,
    required this.codeHeight,
    required this.textHeight,
    required this.ok,
    required this.droppedOptional,
  });
}
