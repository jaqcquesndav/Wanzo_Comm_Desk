import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/units/measurement_units.dart';
import 'package:wanzo/features/inventory/models/product.dart';
import 'package:wanzo/features/sales/models/sale_item.dart';

/// Primus : stock en CARTONS, demi admis (prix du demi 31 000), 24
/// bouteilles par carton vendables à 2 600.
Map<String, dynamic> primusJson({
  Object? unit = 'box',
  Object? unitCode = 'carton',
  Object? stock = 3,
  Object? unitOptions = const {
    'fractions': [0.5],
    'halfPriceInCdf': 31000,
    'pieceUnitCode': 'bottle',
    'piecesPerUnit': 24,
    'piecePriceInCdf': 2600,
  },
}) =>
    {
      'id': 'p-primus',
      'name': 'Primus 72 cl',
      'category': 'drink',
      'costPriceInCdf': 48000,
      'sellingPriceInCdf': 60000,
      'stockQuantity': stock,
      'inputCurrencyCode': 'CDF',
      'inputExchangeRate': 1,
      'costPriceInInputCurrency': 48000,
      'sellingPriceInInputCurrency': 60000,
      if (unit != null) 'unit': unit,
      if (unitCode != null) 'unitCode': unitCode,
      'createdAt': '2026-10-31T10:00:00.000Z',
      'updatedAt': '2026-10-31T10:00:00.000Z',
      if (unitOptions != null) 'unitOptions': unitOptions,
    };

SaleItem ligne(int qte, double prix, {String? unitCode, double? factor}) => SaleItem(
      productId: 'p-primus',
      productName: 'Primus 72 cl',
      quantity: qte,
      unitPrice: prix,
      totalPrice: prix * qte,
      currencyCode: 'CDF',
      exchangeRate: 1,
      unitPriceInCdf: prix,
      totalPriceInCdf: prix * qte,
      itemType: SaleItemType.product,
      unitCode: unitCode,
      unitFactor: factor,
    );

void main() {
  group('Fiche produit lue du serveur', () {
    test('stock en cartons, demi et bouteille vendables', () {
      final p = Product.fromJson(primusJson(stock: 2.5));
      expect(p.unit, ProductUnit.box);
      expect(p.unitCode, 'carton');
      expect(p.baseUnitCode, 'carton');
      expect(p.stockLabel, '2 cartons et demi');
      expect(p.sellableUnits.map((u) => u.label), ['Carton', 'Demi-carton', 'Bouteille']);
      expect(p.sellableUnits[1].sellingPriceInCdf, 31000);
      expect(p.sellableUnits[2].sellingPriceInCdf, 2600);
    });

    test('carton entamé : 3 cartons moins 5 bouteilles', () {
      final p = Product.fromJson(primusJson(stock: 3 - 5 / 24));
      expect(p.stockLabel, '2 cartons et 19 bouteilles');
    });

    test('ancienne fiche sans unitCode ni options : rien ne change', () {
      final p = Product.fromJson(primusJson(unit: 'kg', unitCode: null, unitOptions: null, stock: 77));
      expect(p.unit, ProductUnit.kg);
      expect(p.unitCode, isNull);
      expect(p.unitOptions, isNull);
      expect(p.stockLabel, '77 kg');
      expect(p.sellableUnits.length, 1);
    });

    test('carton sans options : demi proposé d\'office, au demi-prix', () {
      final p = Product.fromJson(primusJson(unitOptions: null));
      expect(p.sellableUnits.map((u) => u.label), ['Carton', 'Demi-carton']);
      expect(p.sellableUnits[1].sellingPriceInCdf, 30000);
    });

    test('code inconnu dans unit (serveur plus récent) : pas de plantage, code gardé', () {
      final p = Product.fromJson(primusJson(unit: 'calebasse', unitCode: null, unitOptions: null));
      expect(p.unit, ProductUnit.piece);
      expect(p.unitCode, 'calebasse');
      expect(MeasurementUnits.label(p.baseUnitCode), 'calebasse');
      final carton = Product.fromJson(primusJson(unit: 'carton', unitCode: null, unitOptions: null));
      expect(carton.unit, ProductUnit.box);
      expect(carton.unitCode, 'carton');
    });

    test('renvoyé au serveur : unit historique, unitCode et options', () {
      final json = Product.fromJson(primusJson()).toJson();
      expect(json['unit'], 'box');
      expect(json['unitCode'], 'carton');
      expect(json['unitOptions'], {
        'fractions': [0.5],
        'halfPriceInCdf': 31000.0,
        'pieceUnitCode': 'bottle',
        'piecesPerUnit': 24.0,
        'piecePriceInCdf': 2600.0,
      });
      // Options inconnues (fiche d'une version antérieure) : jamais renvoyées.
      final sans = Product.fromJson(primusJson(unitOptions: null)).toJson();
      expect(sans.containsKey('unitOptions'), isFalse);
    });

    test('hors ligne : unitCode, options et demis survivent à Hive', () async {
      final dir = await Directory.systemTemp.createTemp('units');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(20)) Hive.registerAdapter(ProductCategoryAdapter());
      if (!Hive.isAdapterRegistered(21)) Hive.registerAdapter(ProductUnitAdapter());
      if (!Hive.isAdapterRegistered(22)) Hive.registerAdapter(ProductAdapter());
      final box = await Hive.openBox<Product>('units_test');
      await box.put('p', Product.fromJson(primusJson(stock: 2.5)));
      await box.close();
      final again = await Hive.openBox<Product>('units_test');
      final p = again.get('p')!;
      expect(p.unitCode, 'carton');
      expect(p.unitOptions?.piecesPerUnit, 24);
      expect(p.stockQuantity, 2.5);
      expect(p.stockLabel, '2 cartons et demi');
      await Hive.close();
      await dir.delete(recursive: true);
    });
  });

  group('Vente : diviser un carton, vendre des bouteilles', () {
    test('1 demi = 0,5 carton au prix du demi ; 5 bouteilles = 5/24 ; carton = 1', () {
      final demi = ligne(1, 31000, unitCode: 'carton', factor: 0.5);
      expect(demi.baseQuantity, 0.5);
      expect(demi.totalPrice, 31000);
      expect(ligne(5, 2600, unitCode: 'bottle', factor: 1 / 24).baseQuantity, closeTo(5 / 24, 1e-9));
      expect(ligne(2, 60000, unitCode: 'carton', factor: 1).baseQuantity, 2);
      // Ligne enregistrée par une version antérieure : 1 pour 1.
      expect(ligne(3, 60000).baseQuantity, 3);
    });

    test('stock après la vente d\'un demi puis de 5 bouteilles', () {
      var stock = 3.0;
      stock -= ligne(1, 31000, unitCode: 'carton', factor: 0.5).baseQuantity;
      expect(Product.fromJson(primusJson(stock: stock)).stockLabel, '2 cartons et demi');
      stock -= ligne(5, 2600, unitCode: 'bottle', factor: 1 / 24).baseQuantity;
      expect(Product.fromJson(primusJson(stock: stock)).stockLabel, '2 cartons et 7 bouteilles');
    });

    test('la ligne enregistrée et envoyée porte unitCode et unitFactor', () {
      final json = ligne(1, 31000, unitCode: 'carton', factor: 0.5).toJson();
      expect(json['unitCode'], 'carton');
      expect(json['unitFactor'], 0.5);
      expect(ligne(3, 60000).toJson().containsKey('unitCode'), isFalse);
    });

    test('ligne relue du serveur (facteur numérique)', () {
      final item = SaleItem.fromJson({
        'productName': 'Primus',
        'quantity': 5,
        'unitPrice': 2600,
        'totalPrice': 13000,
        'unitCode': 'bottle',
        'unitFactor': 0.041667,
        'currencyCode': 'CDF',
        'exchangeRate': 1,
        'unitPriceInCdf': 2600,
        'totalPriceInCdf': 13000,
        'itemType': 'product',
      });
      expect(item.baseQuantity, closeTo(5 / 24, 1e-5));
    });
  });

  group('Impression', () {
    test('1/2 carton, 1 carton et demi, 5 bouteilles ; entier pour le comptage', () {
      final demi = ligne(1, 31000, unitCode: 'carton', factor: 0.5);
      expect(lineQuantityLabel(demi.quantity, demi.unitCode, demi.unitFactor), '1/2 carton');
      expect(lineQuantityLabel(3, 'carton', 0.5), '1 carton et demi');
      expect(lineQuantityLabel(5, 'bottle', 1 / 24), '5 bouteilles');
      expect(lineQuantityLabel(2, 'carton', 1), '2 cartons');
      expect(lineQuantityLabel(3, null), '3');
      expect(lineQuantityLabel(3, 'calebasse'), '3 calebasse');
    });
  });
}
