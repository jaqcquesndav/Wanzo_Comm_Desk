import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/units/measurement_units.dart';
import 'package:wanzo/features/inventory/models/product.dart';
import 'package:wanzo/features/sales/models/sale_item.dart';
import 'package:wanzo/features/sales/services/sale_dto.dart';
import 'package:wanzo/features/sales/models/sale.dart';

/// Produit vendu au carton (24), au demi-carton (12) et à la bouteille.
Map<String, dynamic> primusJson({Object? unit = 'piece', Object? unitCode = 'bottle', Object? packagings}) => {
      'id': 'p-primus',
      'name': 'Primus 72 cl',
      'category': 'drink',
      'costPriceInCdf': 2000,
      'sellingPriceInCdf': 2600,
      'stockQuantity': 77,
      'inputCurrencyCode': 'CDF',
      'inputExchangeRate': 1,
      'costPriceInInputCurrency': 2000,
      'sellingPriceInInputCurrency': 2600,
      if (unit != null) 'unit': unit,
      if (unitCode != null) 'unitCode': unitCode,
      'createdAt': '2026-10-30T10:00:00.000Z',
      'updatedAt': '2026-10-30T10:00:00.000Z',
      'packagings': packagings ??
          [
            {'unitCode': 'carton', 'contains': '24.000', 'sellingPriceInCdf': 60000},
            {'unitCode': 'half_carton', 'contains': 12},
          ],
    };

SaleItem ligne(int qte, {String? unitCode, double? factor, double prix = 60000}) => SaleItem(
      productId: 'p-primus',
      productName: 'Primus 72 cl',
      quantity: qte,
      unitPrice: prix,
      totalPrice: prix * qte,
      unitPriceInCdf: prix,
      totalPriceInCdf: prix * qte,
      unitCode: unitCode,
      unitFactor: factor,
    );

void main() {
  group('Fiche produit lue du serveur', () {
    test('unité réelle, conditionnements et stock lisible', () {
      final p = Product.fromJson(primusJson());
      expect(p.unit, ProductUnit.piece);
      expect(p.unitCode, 'bottle');
      expect(p.baseUnitCode, 'bottle');
      expect(p.packagings.map((e) => e.contains), [24, 12]);
      expect(p.stockLabel, '3 cartons et 5 bouteilles');
      expect(p.sellableUnits.map((u) => u.code), ['bottle', 'half_carton', 'carton']);
      expect(p.sellableUnits.last.sellingPriceInCdf, 60000);
      expect(p.sellableUnits[1].sellingPriceInCdf, 31200);
    });

    test('ancienne fiche sans unitCode ni conditionnements : rien ne change', () {
      final p = Product.fromJson(primusJson(unit: 'kg', unitCode: null, packagings: const []));
      expect(p.unit, ProductUnit.kg);
      expect(p.unitCode, isNull);
      expect(p.baseUnitCode, 'kg');
      expect(p.packagings, isEmpty);
      expect(p.stockLabel, '77 kg');
    });

    test('code inconnu dans unit (serveur plus récent) : pas de plantage, code gardé', () {
      final p = Product.fromJson(primusJson(unit: 'calebasse', unitCode: null, packagings: const []));
      expect(p.unit, ProductUnit.piece);
      expect(p.unitCode, 'calebasse');
      expect(MeasurementUnits.label(p.baseUnitCode), 'calebasse');
      final carton = Product.fromJson(primusJson(unit: 'carton', unitCode: null, packagings: const []));
      expect(carton.unit, ProductUnit.box);
      expect(carton.unitCode, 'carton');
    });

    test('renvoyé au serveur : unit historique, unitCode et conditionnements', () {
      final json = Product.fromJson(primusJson()).toJson();
      expect(json['unit'], 'piece');
      expect(json['unitCode'], 'bottle');
      expect(json['packagings'], [
        {'unitCode': 'carton', 'contains': 24.0, 'sellingPriceInCdf': 60000.0},
        {'unitCode': 'half_carton', 'contains': 12.0},
      ]);
      // Conditionnements inconnus (fiche d'une version antérieure) : jamais
      // renvoyés, pour ne pas effacer ceux d'un autre appareil.
      final sansPack = Map<String, dynamic>.from(primusJson())..remove('packagings');
      expect(Product.fromJson(sansPack).toJson().containsKey('packagings'), isFalse);
    });

    test('hors ligne : unitCode et conditionnements survivent à Hive', () async {
      final dir = await Directory.systemTemp.createTemp('units');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(20)) Hive.registerAdapter(ProductCategoryAdapter());
      if (!Hive.isAdapterRegistered(21)) Hive.registerAdapter(ProductUnitAdapter());
      if (!Hive.isAdapterRegistered(22)) Hive.registerAdapter(ProductAdapter());
      final box = await Hive.openBox<Product>('units_test');
      await box.put('p', Product.fromJson(primusJson()));
      await box.close();
      final again = await Hive.openBox<Product>('units_test');
      final p = again.get('p')!;
      expect(p.unitCode, 'bottle');
      expect(p.packagings.length, 2);
      expect(p.stockLabel, '3 cartons et 5 bouteilles');
      await Hive.close();
      await dir.delete(recursive: true);
    });
  });

  group('Vente et stock en unités de base', () {
    test('2 cartons = 48, 1 demi-carton = 12, 3 bouteilles = 3', () {
      expect(ligne(2, unitCode: 'carton', factor: 24).baseQuantity, 48);
      expect(ligne(1, unitCode: 'half_carton', factor: 12).baseQuantity, 12);
      expect(ligne(3, unitCode: 'bottle', factor: 1).baseQuantity, 3);
      // Ligne enregistrée par une version antérieure : 1 pour 1.
      expect(ligne(3).baseQuantity, 3);
    });

    test('le corps envoyé porte unitCode et unitFactor', () {
      final sale = Sale(
        id: 'local-1',
        date: DateTime(2026, 10, 30, 10),
        customerName: 'Client',
        items: [ligne(2, unitCode: 'carton', factor: 24), ligne(3, prix: 2600)],
        totalAmountInCdf: 127800,
        paidAmountInCdf: 127800,
        status: SaleStatus.completed,
        paymentMethod: 'cash',
      );
      final items = saleToApiDto(sale, sourceMode: 'retail')['items'] as List;
      expect(items[0]['unitCode'], 'carton');
      expect(items[0]['unitFactor'], 24);
      expect(items[0]['quantity'], 2);
      expect(items[1].containsKey('unitCode'), isFalse);
    });

    test('ligne relue du serveur (facteur en chaîne)', () {
      final item = SaleItem.fromJson({
        'productName': 'Primus',
        'quantity': '2',
        'unitPrice': '60000.00',
        'totalPrice': '120000.00',
        'unitCode': 'carton',
        'unitFactor': '24.000',
      });
      expect(item.baseQuantity, 48);
    });
  });

  group('Impression', () {
    test('quantité et unité imprimées, entières pour les unités de comptage', () {
      expect(lineQuantityLabel(2, 'carton'), '2 cartons');
      expect(lineQuantityLabel(1, 'half_carton'), '1 demi-carton');
      expect(lineQuantityLabel(3, 'bottle'), '3 bouteilles');
      expect(lineQuantityLabel(2.5, 'kg'), '2,5 kg');
      expect(lineQuantityLabel(3, null), '3');
      expect(lineQuantityLabel(3, 'calebasse'), '3 calebasse');
    });
  });
}
