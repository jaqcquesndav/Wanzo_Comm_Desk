import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/labels/label_codes.dart';
import 'package:wanzo/features/labels/label_format.dart';
import 'package:wanzo/features/labels/label_item.dart';
import 'package:wanzo/features/labels/label_layout.dart';

const _eps = 0.01;

final _formats = [
  ...LabelFormat.presets,
  LabelFormat.custom(30, 20),
  LabelFormat.custom(100, 50),
];

const _items = [
  LabelItem(
    id: '1',
    name: 'Huile végétale raffinée Bonne Santé bidon de cinq litres édition '
        'spéciale familiale',
    code: 'WZ23ABCDEF',
    price: '1 250 000 CDF',
    secondaryPrice: '446,43 \$',
    unit: 'bidon',
    extra: 'Lot L2026-10-23-0001',
  ),
  LabelItem(
    id: '2',
    name: 'Sucre',
    code: '5901234123457',
    price: '\$1,234.56',
    unit: 'kg',
  ),
  LabelItem(
    id: '3',
    name: 'Supercalifragilisticexpialidocious-sans-espace-aucun',
    code: 'ARTICLE-2026-000123',
    price: '2 500 CDF',
  ),
];

void _expectInside(LabelLayout l, String ctx) {
  for (final t in l.lines) {
    expect(t.xMm, greaterThanOrEqualTo(-_eps), reason: '$ctx ${t.role} x');
    expect(t.textWidthMm, lessThanOrEqualTo(t.widthMm + _eps),
        reason: '$ctx ${t.role} « ${t.text} » déborde en largeur');
    expect(t.xMm + t.widthMm, lessThanOrEqualTo(l.widthMm + _eps),
        reason: '$ctx ${t.role} boîte hors étiquette');
    expect(t.yMm + t.heightMm, lessThanOrEqualTo(l.heightMm + _eps),
        reason: '$ctx ${t.role} déborde en hauteur');
  }
  final c = l.code;
  expect(c.xMm, greaterThanOrEqualTo(-_eps), reason: '$ctx code x');
  expect(c.yMm, greaterThanOrEqualTo(-_eps), reason: '$ctx code y');
  expect(c.xMm + c.widthMm, lessThanOrEqualTo(l.widthMm + _eps),
      reason: '$ctx code largeur');
  expect(c.yMm + c.heightMm, lessThanOrEqualTo(l.heightMm + _eps),
      reason: '$ctx code hauteur');
  // Aucun texte ne chevauche le code.
  for (final t in l.lines) {
    final overlapX = t.xMm < c.xMm + c.widthMm && c.xMm < t.xMm + t.widthMm;
    final overlapY =
        t.yMm < c.yMm + c.heightMm - _eps && c.yMm < t.yMm + t.heightMm - _eps;
    expect(overlapX && overlapY, isFalse,
        reason: '$ctx ${t.role} chevauche le code');
  }
}

void main() {
  for (final f in _formats) {
    for (final choice in LabelCodeChoice.values) {
      for (final item in _items) {
        for (final full in [false, true]) {
          final ctx = '${f.id} ${f.widthMm}x${f.heightMm} ${choice.name} '
              '#${item.id} ${full ? 'options' : 'simple'}';
          test(ctx, () {
            final l = LabelLayout.compute(
              format: f,
              item: item,
              choice: choice,
              options: LabelOptions(
                showCompany: full,
                showUnit: full,
                showExtra: full,
                showSecondaryPrice: full,
                companyName: 'Établissements Kabila et Fils SARL de Lubumbashi',
              ),
            );
            _expectInside(l, ctx);
            expect(l.fits, isTrue, reason: '$ctx ne tient pas');
            // Le prix est toujours imprimé en entier.
            final price = l.line(LabelTextRole.price);
            expect(price, isNotNull, reason: ctx);
            expect(price!.text, startsWith(labelSafeText(item.price!)));
            expect(l.line(LabelTextRole.name), isNotNull);
            expect(l.code.heightMm, greaterThan(3.5), reason: '$ctx code');
          });
        }
      }
    }
  }

  test('nom long tronqué proprement par « ... »', () {
    final l = LabelLayout.compute(
      format: LabelFormat.byId('l40x30'),
      item: _items[0],
      options: const LabelOptions(),
      choice: LabelCodeChoice.barcode,
    );
    final names = l.lines.where((t) => t.role == LabelTextRole.name).toList();
    expect(names, isNotEmpty);
    expect(names.last.text, endsWith('...'));
    expect(names.length, lessThanOrEqualTo(2));
  });

  test('nom court non tronqué', () {
    final l = LabelLayout.compute(
      format: LabelFormat.byId('l50x30'),
      item: _items[1],
      options: const LabelOptions(),
      choice: LabelCodeChoice.barcode,
    );
    expect(l.line(LabelTextRole.name)!.text, 'Sucre');
    expect(l.code.symbology, LabelSymbology.ean13);
  });

  test('code trop long pour une petite étiquette : avertissement', () {
    final l = LabelLayout.compute(
      format: LabelFormat.custom(25, 20),
      item: const LabelItem(
          id: 'x',
          name: 'Article',
          code: 'CODE-ARTICLE-TRES-LONG-0000000001',
          price: '100 CDF'),
      options: const LabelOptions(),
      choice: LabelCodeChoice.barcode,
    );
    expect(l.warnings.any((w) => w.contains('QR')), isTrue);
  });

  test('QR à côté du texte sur une étiquette large', () {
    final l = LabelLayout.compute(
      format: LabelFormat.byId('l60x40'),
      item: _items[0],
      options: const LabelOptions(),
      choice: LabelCodeChoice.qr,
    );
    expect(l.code.widthMm, l.code.heightMm);
    final name = l.line(LabelTextRole.name)!;
    expect(name.xMm, greaterThanOrEqualTo(l.code.xMm + l.code.widthMm));
  });

  test('texte sûr pour les polices standard', () {
    expect(labelSafeText('1 250 CDF'), '1 250 CDF');
    expect(labelSafeText('Prix…'), 'Prix...');
    expect(labelAsciiText('Café crème "bio"'), "Cafe creme 'bio'");
  });

  test('quantité par défaut : le stock, sinon 1', () {
    expect(const LabelItem(id: 'a', name: 'a', code: 'a', stockQuantity: 12.2)
        .defaultCopies, 13);
    expect(const LabelItem(id: 'a', name: 'a', code: 'a').defaultCopies, 1);
  });

  test('réglages mémorisés : aller-retour JSON', () {
    const s = LabelSettings(
      formatId: LabelFormat.customId,
      customWidthMm: 45,
      customHeightMm: 22,
      codeChoice: LabelCodeChoice.qr,
      showCompany: true,
      language: LabelPrinterLanguage.tspl,
    );
    final back = LabelSettings.fromJson(s.toJson());
    expect(back.format.widthMm, 45);
    expect(back.format.heightMm, 22);
    expect(back.codeChoice, LabelCodeChoice.qr);
    expect(back.language, LabelPrinterLanguage.tspl);
    expect(LabelFormat.validateSide('10'), isNotNull);
    expect(LabelFormat.validateSide('40,5'), isNull);
    expect(LabelFormat.validateSide('abc'), isNotNull);
  });
}
