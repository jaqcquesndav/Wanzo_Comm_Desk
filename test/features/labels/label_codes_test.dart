import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw show Barcode;
import 'package:wanzo/features/labels/label_codes.dart';

void main() {
  group('EAN-13', () {
    test('clé de contrôle calculée', () {
      expect(LabelCodes.ean13CheckDigit('400638133393'), 1); // 4006381333931
      expect(LabelCodes.ean13CheckDigit('590123412345'), 7); // 5901234123457
      expect(LabelCodes.ean13CheckDigit('000000000000'), 0);
    });

    test('validation : longueur, chiffres et clé', () {
      expect(LabelCodes.isValidEan13('4006381333931'), isTrue);
      expect(LabelCodes.isValidEan13('5901234123457'), isTrue);
      expect(LabelCodes.isValidEan13('5901234123458'), isFalse); // mauvaise clé
      expect(LabelCodes.isValidEan13('590123412345'), isFalse); // 12 chiffres
      expect(LabelCodes.isValidEan13('59012341234A7'), isFalse);
    });

    test('le paquet barcode accepte nos EAN-13 valides', () {
      expect(pw.Barcode.ean13().isValid('5901234123457'), isTrue);
    });
  });

  group('Code 128', () {
    test('ASCII imprimable uniquement', () {
      expect(LabelCodes.isCode128Encodable('SKU-001/A'), isTrue);
      expect(LabelCodes.isCode128Encodable('café'), isFalse);
      expect(LabelCodes.isCode128Encodable(''), isFalse);
    });

    test('jeu C pour les chiffres en nombre pair', () {
      expect(LabelCodes.usesCode128C('12345678'), isTrue);
      expect(LabelCodes.usesCode128C('1234567'), isFalse);
      expect(LabelCodes.escPosCode128Payload('1234'), [0x7B, 0x43, 12, 34]);
      expect(LabelCodes.escPosCode128Payload('AB'), [0x7B, 0x42, 65, 66]);
    });

    test('nombre de modules', () {
      // départ + 3 symboles + clé = 5 x 11, arrêt = 13
      expect(LabelCodes.code128Modules('ABC'), 5 * 11 + 13);
      expect(LabelCodes.code128Modules('1234'), 4 * 11 + 13);
    });
  });

  group('symbologie', () {
    test('EAN-13 valide imprimé en EAN-13, le reste en Code 128', () {
      expect(LabelCodes.symbologyFor('5901234123457', LabelCodeChoice.barcode),
          LabelSymbology.ean13);
      expect(LabelCodes.symbologyFor('5901234123458', LabelCodeChoice.barcode),
          LabelSymbology.code128);
      expect(LabelCodes.symbologyFor('WZ23ABCDEF', LabelCodeChoice.barcode),
          LabelSymbology.code128);
      expect(LabelCodes.symbologyFor('5901234123457', LabelCodeChoice.qr),
          LabelSymbology.qr);
    });
  });

  group('code généré', () {
    test('stable, court, sans caractère ambigu, encodable', () {
      final a = LabelCodes.generateSku('a1b2c3-uuid');
      expect(a, LabelCodes.generateSku('a1b2c3-uuid'));
      expect(a, matches(RegExp(r'^WZ[2-9A-HJ-NP-Z]{8}$')));
      expect(LabelCodes.isCode128Encodable(a), isTrue);
      expect(pw.Barcode.code128().isValid(a), isTrue);
      expect(pw.Barcode.qrCode().isValid(a), isTrue);
    });

    test('identifiants différents, codes différents', () {
      final codes = {
        for (var i = 0; i < 2000; i++) LabelCodes.generateSku('produit-$i'),
      };
      expect(codes.length, 2000);
    });

    test('code existant préféré : code-barres puis SKU', () {
      expect(LabelCodes.pickExistingCode(barcode: ' 123 ', sku: 'S'), '123');
      expect(LabelCodes.pickExistingCode(barcode: '', sku: 'SKU1'), 'SKU1');
      expect(LabelCodes.pickExistingCode(barcode: '', sku: null), isNull);
    });
  });
}
