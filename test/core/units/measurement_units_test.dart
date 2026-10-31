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
        'carton', 'half_carton', 'sachet', 'bottle', 'bidon', 'jerrican_20l',
        'drum', 'crate', 'tray', 'banana_bunch', 'bag_25kg', 'bag_50kg',
        'half_bag', 'bucket', 'basin', 'heap', 'glass', 'cup', 'plate',
        'measure', 'bunch', 'head', 'dozen', 'half_dozen', 'wrapper',
        'half_piece', 'm', 'yard', 'roll', 'unit', 'pair',
      ]) {
        expect(MeasurementUnits.isKnown(c), isTrue, reason: c);
      }
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
      expect(MeasurementUnits.shortLabel('code_futur'), 'code_futur');
      expect(MeasurementUnits.formatUnitQuantity(3, 'code_futur'), '3 code_futur');
      expect(MeasurementUnits.legacyOf('code_futur'), 'piece');
    });

    test('libellés par langue', () {
      expect(MeasurementUnits.label('carton', 'fr'), 'Carton');
      expect(MeasurementUnits.label('bucket', 'sw'), 'Ndoo');
      expect(MeasurementUnits.label('bucket', 'xx'), 'Seau');
    });

    test('stock lisible : 3 cartons et 5 bouteilles', () {
      const packs = [
        ProductPackaging(unitCode: 'carton', contains: 24),
        ProductPackaging(unitCode: 'half_carton', contains: 12),
      ];
      expect(MeasurementUnits.formatStockBreakdown(77, 'bottle', packs),
          '3 cartons et 5 bouteilles');
      expect(MeasurementUnits.formatStockBreakdown(48, 'bottle', packs), '2 cartons');
      expect(MeasurementUnits.formatStockBreakdown(5, 'bottle', packs), '5 bouteilles');
      expect(MeasurementUnits.formatUnitQuantity(2.5, 'kg'), '2,5 kg');
    });

    test('quantité imprimée entière pour les unités de comptage', () {
      expect(MeasurementUnits.formatQuantity(3.0, 'carton'), '3');
      expect(MeasurementUnits.formatQuantity(2.6, 'piece'), '3');
      expect(MeasurementUnits.formatQuantity(2.5, 'kg'), '2,5');
    });
  });

  group('Conditionnements', () {
    test('contenu proposé automatiquement', () {
      expect(MeasurementUnits.suggestedContains('dozen', 'piece'), 12);
      expect(MeasurementUnits.suggestedContains('tray', 'piece'), 30);
      expect(MeasurementUnits.suggestedContains('bag_50kg', 'kg'), 50);
      expect(MeasurementUnits.suggestedContains('jerrican_20l', 'l'), 20);
      expect(MeasurementUnits.suggestedContains('wrapper', 'yard'), 6);
      expect(
          MeasurementUnits.suggestedContains('half_carton', 'bottle',
              known: {'carton': 24}),
          12);
      expect(MeasurementUnits.suggestedContains('carton', 'bottle'), isNull);
    });

    test('carton, demi-carton et unité en unités de base', () {
      expect(MeasurementUnits.toBase(2, 24), 48);
      expect(MeasurementUnits.toBase(1, 12), 12);
      expect(MeasurementUnits.toBase(3, 1), 3);
      expect(MeasurementUnits.toBase(3, null), 3);
    });

    test('unités vendables : base puis conditionnements, prix au carton ou calculé', () {
      final units = MeasurementUnits.sellableUnits(
        'bottle',
        const [
          ProductPackaging(unitCode: 'carton', contains: 24, sellingPriceInCdf: 60000),
          ProductPackaging(unitCode: 'half_carton', contains: 12),
        ],
        baseSellingPriceInCdf: 2600,
      );
      expect(units.map((u) => u.code), ['bottle', 'half_carton', 'carton']);
      expect(units[1].sellingPriceInCdf, 31200);
      expect(units[2].sellingPriceInCdf, 60000);
    });

    test('lecture tolérante des conditionnements (chaîne, entrées invalides)', () {
      final list = ProductPackaging.listFromJson(
          '[{"unitCode":"Carton","contains":"24"},{"unitCode":"x","contains":0},{"contains":3}]');
      expect(list, [const ProductPackaging(unitCode: 'carton', contains: 24)]);
      expect(ProductPackaging.listFromJson(null), isEmpty);
      expect(ProductPackaging.listFromJson('pas du json'), isEmpty);
    });

    test('liste triée par usage puis par fréquence du catalogue', () {
      final sorted = MeasurementUnits.sortedCodes(usage: {'bag_50kg': 5, 'carton': 2});
      expect(sorted.take(3), ['bag_50kg', 'carton', 'piece']);
      expect(sorted.length, MeasurementUnits.all.length);
    });
  });
}
