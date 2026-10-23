import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw show Barcode, BarcodeBar;

import 'label_codes.dart';
import 'label_layout.dart';
import 'label_renderers.dart';

/// Aperçu à l'échelle d'une étiquette, dessiné depuis la MÊME mise en page
/// que le PDF et les commandes d'imprimante ([LabelLayout]). C'est une image
/// du papier : la taille de police du système ne s'y applique pas.
class LabelPreview extends StatelessWidget {
  final LabelLayout layout;

  /// Largeur maximale de l'aperçu à l'écran.
  final double maxWidth;
  final double maxHeight;

  const LabelPreview({
    super.key,
    required this.layout,
    this.maxWidth = 320,
    this.maxHeight = 220,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final availW = c.maxWidth.isFinite ? c.maxWidth : maxWidth;
      final w = availW < maxWidth ? availW : maxWidth;
      var pxPerMm = w / layout.widthMm;
      if (layout.heightMm * pxPerMm > maxHeight) {
        pxPerMm = maxHeight / layout.heightMm;
      }
      final width = layout.widthMm * pxPerMm;
      final height = layout.heightMm * pxPerMm;
      return Center(
        child: MediaQuery.withNoTextScaling(
          child: Semantics(
            label: 'Aperçu de l\'étiquette',
            child: Container(
              key: const ValueKey('label-preview'),
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black26),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(children: [
                for (final t in layout.lines)
                  Positioned(
                    left: t.xMm * pxPerMm,
                    top: t.yMm * pxPerMm,
                    width: t.widthMm * pxPerMm,
                    height: t.heightMm * pxPerMm,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment:
                          t.centered ? Alignment.center : Alignment.centerLeft,
                      child: Text(
                        t.text,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: t.fontPt * kPtToMm * pxPerMm,
                          fontWeight:
                              t.bold ? FontWeight.w700 : FontWeight.w400,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                if (layout.code.heightMm > 0)
                  Positioned(
                    left: layout.code.xMm * pxPerMm,
                    top: layout.code.yMm * pxPerMm,
                    width: layout.code.widthMm * pxPerMm,
                    height: layout.code.heightMm * pxPerMm,
                    child: CustomPaint(
                      painter: _CodePainter(
                          layout.code.symbology, layout.code.data),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
    });
  }
}

class _CodePainter extends CustomPainter {
  final LabelSymbology symbology;
  final String data;
  _CodePainter(this.symbology, this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final pw.Barcode bc = labelBarcodeFor(symbology);
    final paint = Paint()..color = Colors.black;
    try {
      for (final e in bc.make(data,
          width: size.width, height: size.height, drawText: false)) {
        if (e is pw.BarcodeBar && e.black) {
          canvas.drawRect(
              Rect.fromLTWH(e.left, e.top, e.width, e.height), paint);
        }
      }
    } catch (_) {
      // Donnée non encodable : cadre barré, l'écran affiche l'avertissement.
      final p = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke;
      canvas.drawRect(Offset.zero & size, p);
      canvas.drawLine(Offset.zero, Offset(size.width, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_CodePainter old) =>
      old.data != data || old.symbology != symbology;
}
