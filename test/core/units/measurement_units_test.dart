import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/units/measurement_units.dart';
import 'package:wanzo/core/units/measurement_units_data.dart';

/// La copie embarquée du catalogue doit rester IDENTIQUE à celle du serveur
/// (packages/shared/src/standards/measurement-units.json). L'instantané du
/// serveur est copié dans test/fixtures ; si le dépôt serveur est à côté, il
/// est lu directement.
void main() {
  const options = ProductUnitOptions(
    fractions: [0.5],
    halfPriceInCdf: 31000,
    pieceUnitCode: 'bottle',
    piecesPerUnit: 24,
    piecePriceInCdf: 2600,
  );

  group('Catalogue des unités : copie du serveur', () {
    test('la copie embarquée égale l\'instantané du serveur', () {
      final fixture = jsonDecode(
        File('test/fixtures/measurement_units.json').readAsStringSync(),
      );
      expect(jsonDecode(jsonEncode(kMeasurementUnitsSnapshot)), fixture);

      final server = File(
        '../Wanzo_Backend/packages/shared/src/standards/measurement-units.json',
      );
      if (server.existsSync()) {
        expect(fixture, jsonDecode(server.readAsStringSync()),
            reason: 'Copier le nouvel instantané du serveur dans les apps');
      }
    });

    test('garde les 8 unités historiques et les unités RDC demandées', () {
      for (final c in MeasurementUnits.legacyCodes) {
        expect(MeasurementUnits.isKnown(c), isTrue, reason: c);
      }
      for (final c in [
        'carton', 'sachet', 'bottle', 'bidon', 'jerrican_20l', 'drum',
        'crate', 'tray', 'banana_bunch', 'bag_25kg', 'bag_50kg', 'bucket',
        'basin', 'heap', 'glass', 'cup', 'plate', 'measure', 'bunch', 'head',
        'dozen', 'wrapper', 'm', 'yard', 'roll', 'unit', 'pair',
      ]) {
        expect(MeasurementUnits.isKnown(c), isTrue, reason: c);
      }
    });

    test('demi-carton, demi-sac, demi-pièce : des fractions, pas des unités', () {
      for (final c in ['half_carton', 'half_bag', 'half_piece', 'half_dozen']) {
        expect(MeasurementUnits.isKnown(c), isFalse, reason: c);
      }
      expect(MeasurementUnits.isDivisible('carton'), isTrue);
      expect(MeasurementUnits.halfLabel('carton'), 'Demi-carton');
      expect(MeasurementUnits.halfLabel('wrapper'), 'Demi-pièce (3 yards)');
      expect(MeasurementUnits.fractionsOf('carton', null), [0.5]);
      expect(MeasurementUnits.fractionsOf('carton', const ProductUnitOptions(fractions: [0.5, 0.25])), [0.5, 0.25]);
      expect(MeasurementUnits.fractionsOf('carton', const ProductUnitOptions(fractions: [])), isEmpty);
      expect(MeasurementUnits.fractionsOf('bottle', null), isEmpty);
    });
  });

  group('Lecture et affichage', () {
    test('graphies libres ramenées au code', () {
      expect(MeasurementUnits.normalize('Kg'), 'kg');
      expect(MeasurementUnits.normalize('pièce'), 'piece');
      expect(MeasurementUnits.normalize('m²'), 'm2');
      expect(MeasurementUnits.normalize('Carton'), 'carton');
      expect(MeasurementUnits.normalize('brouette'), isNull);
    });

    test('un code inconnu (version plus récente du serveur) s\'affiche tel quel', () {
      expect(MeasurementUnits.label('code_futur'), 'code_futur');
      expect(MeasurementUnits.formatUnitQuantity(3, 'code_futur'), '3 code_futur');
      expect(MeasurementUnits.legacyOf('code_futur'), 'piece');
    });

    test('libellés par langue', () {
      expect(MeasurementUnits.label('carton', 'fr'), 'Carton');
      expect(MeasurementUnits.label('bucket', 'sw'), 'Ndoo');
      expect(MeasurementUnits.label('bucket', 'xx'), 'Seau');
    });

    test('stock en cartons et demis, le reste en pièces', () {
      expect(MeasurementUnits.formatStockBreakdown(2.5, 'carton', options), '2 cartons et demi');
      expect(MeasurementUnits.formatStockBreakdown(3 - 5 / 24, 'carton', options),
          '2 cartons et 19 bouteilles');
      expect(MeasurementUnits.formatStockBreakdown(0.5, 'carton', options), '1/2 carton');
      expect(MeasurementUnits.formatStockBreakdown(5 / 24, 'carton', options), '5 bouteilles');
      expect(MeasurementUnits.formatStockBreakdown(3, 'carton', options), '3 cartons');
      expect(MeasurementUnits.formatStockBreakdown(2.75, 'carton'), '2 cartons et trois quarts');
      expect(MeasurementUnits.formatUnitQuantity(2.5, 'kg'), '2,5 kg');
    });

    test('ticket : 1/2 carton, 1 carton et demi, 5 bouteilles', () {
      expect(lineQuantityLabel(1, 'carton', 0.5), '1/2 carton');
      expect(lineQuantityLabel(3, 'carton', 0.5), '1 carton et demi');
      expect(lineQuantityLabel(5, 'bottle', 1 / 24), '5 bouteilles');
      expect(lineQuantityLabel(2, 'carton', 1), '2 cartons');
      expect(lineQuantityLabel(3, null), '3');
      expect(lineQuantityLabel(2.5, 'kg'), '2,5 kg');
    });
  });

  group('Fractions et pièces', () {
    test('nombre de pièces proposé', () {
      expect(MeasurementUnits.suggestedContains('dozen', 'piece'), 12);
      expect(MeasurementUnits.suggestedContains('tray', 'piece'), 30);
      expect(MeasurementUnits.suggestedContains('bag_50kg', 'kg'), 50);
      expect(MeasurementUnits.suggestedContains('jerrican_20l', 'l'), 20);
      expect(MeasurementUnits.suggestedContains('wrapper', 'yard'), 6);
      expect(MeasurementUnits.suggestedContains('carton', 'bottle'), isNull);
    });

    test('unités vendables : carton, demi-carton, bouteille, avec leurs prix', () {
      final units = MeasurementUnits.sellableUnits('carton', options,
          baseSellingPriceInCdf: 60000, baseCostPriceInCdf: 48000);
      expect(units.map((u) => u.label), ['Carton', 'Demi-carton', 'Bouteille']);
      expect(units.map((u) => u.factor), [1, 0.5, 1 / 24]);
      expect(units[1].code, 'carton');
      expect(units[1].sellingPriceInCdf, 31000);
      expect(units[1].costPriceInCdf, 24000);
      expect(units[2].sellingPriceInCdf, 2600);
      // Sans prix du demi saisi : la moitié du carton.
      final def = MeasurementUnits.sellableUnits('carton', null, baseSellingPriceInCdf: 60000);
      expect(def.map((u) => u.sellingPriceInCdf), [60000, 30000]);
      expect(MeasurementUnits.sellableUnits('bottle', null).length, 1);
    });

    test('quantités en cartons : demi, pièces', () {
      expect(MeasurementUnits.toBase(1, 0.5), 0.5);
      expect(MeasurementUnits.toBase(3, 0.5), 1.5);
      expect(MeasurementUnits.toBase(5, 1 / 24), closeTo(5 / 24, 1e-6));
      expect(MeasurementUnits.toBase(3, null), 3);
    });

    test('lecture tolérante des options (chaîne, nombres en chaîne, fraction inconnue)', () {
      final o = ProductUnitOptions.fromJson(
          '{"fractions":[0.5,0.3],"halfPriceInCdf":"31000","pieceUnitCode":"Bouteille","piecesPerUnit":"24"}')!;
      expect(o.fractions, [0.5]);
      expect(o.halfPriceInCdf, 31000);
      expect(o.pieceUnitCode, 'bottle');
      expect(o.piecesPerUnit, 24);
      expect(ProductUnitOptions.fromJson(null), isNull);
      expect(ProductUnitOptions.fromJson('pas du json'), isNull);
      expect(ProductUnitOptions.fromJson(o.encode()), o);
    });

    test('liste triée par usage puis par fréquence du catalogue', () {
      final sorted = MeasurementUnits.sortedCodes(usage: {'bag_50kg': 5, 'carton': 2});
      expect(sorted.take(3), ['bag_50kg', 'carton', 'piece']);
      expect(sorted.length, MeasurementUnits.all.length);
    });
  });
}
