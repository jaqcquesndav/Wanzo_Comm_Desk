import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/labels/label_codes.dart';
import 'package:wanzo/features/labels/label_format.dart';
import 'package:wanzo/features/labels/label_item.dart';
import 'package:wanzo/features/labels/label_renderers.dart';

const _item = LabelItem(
  id: 'p1',
  name: 'Savon de ménage',
  code: 'WZ23ABCDEF',
  price: '2 500 CDF',
);
const _ean = LabelItem(
  id: 'p2',
  name: 'Lait',
  code: '5901234123457',
  price: '\$3.50',
);

bool _contains(List<int> hay, List<int> needle) {
  for (var i = 0; i + needle.length <= hay.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

void main() {
  final f = LabelFormat.byId('l40x30');
  const o = LabelOptions();

  test('ESC/POS : Code 128 natif avec le code produit', () {
    final b = buildEscPosLabels(
        jobs: const [LabelJob(_item, 2)],
        format: f,
        options: o,
        choice: LabelCodeChoice.barcode);
    final payload = LabelCodes.escPosCode128Payload(_item.code);
    expect(_contains(b, [0x1D, 0x6B, 0x49, payload.length, ...payload]), isTrue);
    expect(latin1.decode(b, allowInvalid: true), contains('2 500 CDF'));
    // deux exemplaires
    final count = latin1.decode(b, allowInvalid: true).split('Savon').length - 1;
    expect(count, 2);
  });

  test('ESC/POS : EAN-13 natif (12 chiffres, clé calculée par l\'imprimante)',
      () {
    final b = buildEscPosLabels(
        jobs: const [LabelJob(_ean, 1)],
        format: f,
        options: o,
        choice: LabelCodeChoice.barcode);
    expect(_contains(b, [0x1D, 0x6B, 0x43, 12, ...'590123412345'.codeUnits]),
        isTrue);
  });

  test('ESC/POS : QR natif', () {
    final b = buildEscPosLabels(
        jobs: const [LabelJob(_item, 1)],
        format: f,
        options: o,
        choice: LabelCodeChoice.qr);
    expect(_contains(b, [0x1D, 0x28, 0x6B]), isTrue);
    expect(_contains(b, utf8.encode(_item.code)), isTrue);
  });

  test('TSPL : taille exacte, espacement, code et exemplaires', () {
    final s = buildTsplLabels(
        jobs: const [LabelJob(_item, 3)],
        format: f,
        options: o,
        choice: LabelCodeChoice.barcode);
    expect(s, contains('SIZE 40.0 mm,30.0 mm'));
    expect(s, contains('GAP 2 mm,0 mm'));
    expect(s, contains('"128"'));
    expect(s, contains('"WZ23ABCDEF"'));
    expect(s, contains('PRINT 1,3'));
    expect(s, contains('Savon de menage')); // accents retirés
  });

  test('ZPL : largeur, longueur, code et exemplaires', () {
    final s = buildZplLabels(
        jobs: const [LabelJob(_ean, 4)],
        format: f,
        options: o,
        choice: LabelCodeChoice.barcode);
    expect(s, contains('^PW320^LL240'));
    expect(s, contains('^BEN'));
    expect(s, contains('^FD590123412345^FS'));
    expect(s, contains('^PQ4^XZ'));
  });

  test('ePOS : code-barres Code 128 avec jeu B', () {
    final s = buildEposLabels(
        jobs: const [LabelJob(_item, 1)],
        format: f,
        options: o,
        choice: LabelCodeChoice.barcode);
    expect(s, contains('<barcode type="code128"'));
    expect(s, contains('{BWZ23ABCDEF'));
  });

  test('PDF : une page par étiquette, planche A4 par 24', () async {
    final single = await buildLabelsPdf(
        jobs: const [LabelJob(_item, 3)],
        format: f,
        options: o,
        choice: LabelCodeChoice.barcode);
    expect(latin1.decode(single.sublist(0, 4)), '%PDF');
    expect(_pages(single), 3);

    final sheet = await buildLabelsPdf(
        jobs: const [LabelJob(_item, 30), LabelJob(_ean, 1)],
        format: LabelFormat.byId('a4_3x8'),
        options: o,
        choice: LabelCodeChoice.qr);
    expect(_pages(sheet), 2); // 31 étiquettes, 24 par page
  });

  test('expansion des exemplaires dans l\'ordre', () {
    final all = expandJobs(const [LabelJob(_item, 2), LabelJob(_ean, 1)]);
    expect(all.map((e) => e.id), ['p1', 'p1', 'p2']);
  });
}

int _pages(List<int> pdf) {
  final s = latin1.decode(pdf, allowInvalid: true);
  return RegExp(r'/Type\s*/Page[^s]').allMatches(s).length;
}
