import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/inventory/models/product.dart';
import 'package:wanzo/features/inventory/models/stock_transaction.dart';
import 'package:wanzo/features/inventory/repositories/inventory_repository.dart';
import 'package:wanzo/features/inventory/stock_count/stock_count.dart';

Product product(String id, double stock, {String barcode = '', String? sku, double cost = 1000}) => Product(
  id: id,
  name: 'Article $id',
  description: '',
  barcode: barcode,
  sku: sku,
  category: ProductCategory.values.first,
  costPriceInCdf: cost,
  sellingPriceInCdf: cost * 2,
  stockQuantity: stock,
  unit: ProductUnit.values.first,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  inputCurrencyCode: 'CDF',
  inputExchangeRate: 1,
  costPriceInInputCurrency: cost,
  sellingPriceInInputCurrency: cost * 2,
);

class _Repo extends Fake implements InventoryRepository {
  final sent = <StockTransaction>[];
  @override
  Future<StockTransaction> addStockTransaction(
    StockTransaction transaction, {
    String? awaitingExpenseId,
  }) async {
    if (transaction.productId == 'refuse') {
      throw const StockRefusedException('Stock insuffisant sur le serveur pour cet article.');
    }
    sent.add(transaction);
    return transaction;
  }
}

void main() {
  final products = [
    product('a', 10, barcode: '6001234'),
    product('b', 5, sku: 'SAV-01'),
    product('c', 3),
    product('refuse', 2),
  ];

  test('lecture par code-barres puis SKU, +1 par lecture', () {
    expect(findProductByCode(products, '6001234')!.id, 'a');
    expect(findProductByCode(products, 'sav-01')!.id, 'b');
    expect(findProductByCode(products, 'inconnu'), isNull);
    var d = StockCountDraft.start(DateTime(2026, 10, 24, 9));
    d = d.increment('a').increment('a');
    expect(d.counts['a'], 2);
    expect(d.reference, 'INV-20261024-0900');
  });

  test('écarts : seuls les articles comptés et différents du théorique', () {
    final d = StockCountDraft.start()
        .withCount('a', 8)
        .withCount('b', 5)
        .withCount('c', 4);
    final gaps = stockCountGaps(products, d);
    expect({for (final g in gaps) g.product.id: g.difference}, {'a': -2.0, 'c': 1.0});
    expect(gaps.first.valueInCdf, -2000);
  });

  test('validation : ajustements SIGNÉS avec référence et trace, refus isolé', () async {
    final d = StockCountDraft.start(DateTime(2026, 10, 24, 9))
        .withCount('a', 8)
        .withCount('c', 4)
        .withCount('refuse', 0);
    final repo = _Repo();
    final result = await StockCountService.apply(repo, d, stockCountGaps(products, d));
    expect(result.applied, 2);
    expect(result.refused.keys, ['refuse']);
    final a = repo.sent.firstWhere((t) => t.productId == 'a');
    expect(a.type, StockTransactionType.adjustment);
    expect(a.quantity, -2);
    expect(a.referenceId, 'INV-20261024-0900');
    expect(a.notes, contains('compté 8, théorique 10'));
    expect(repo.sent.firstWhere((t) => t.productId == 'c').quantity, 1);
  });

  test('brouillon sérialisé (reprise hors ligne)', () {
    final d = StockCountDraft.start().withCount('a', 3.5);
    final back = StockCountDraft.fromJson(d.toJson());
    expect(back.counts, {'a': 3.5});
    expect(back.reference, d.reference);
  });

  group('inventaire par emplacement', () {
    test('« Tous » par défaut : théorique = stock de l’article, sans locationId', () async {
      final d = StockCountDraft.start().withCount('a', 8);
      expect(d.locationId, isNull);
      expect(d.theoreticalOf(products.first), 10);
      final repo = _Repo();
      await StockCountService.apply(repo, d, stockCountGaps(products, d));
      expect(repo.sent.single.locationId, isNull);
      expect(repo.sent.single.toApiPayload().containsKey('locationId'), isFalse);
    });

    test('théorique = stock DE l’emplacement (absent = 0)', () {
      final stock = parseLocationStock({
        'success': true,
        'data': {
          'businessUnitId': 'goma',
          'name': 'Magasin Goma',
          'items': [
            {'productId': 'a', 'quantity': '4.00'},
            {'productId': 'b', 'quantity': 5},
          ],
        },
      });
      expect(stock, {'a': 4.0, 'b': 5.0});
      final d = StockCountDraft.start()
          .forLocation('goma', 'Magasin Goma', stock)
          .withCount('a', 3)
          .withCount('b', 5)
          .withCount('c', 1);
      expect(d.theoreticalOf(products[2]), 0);
      final gaps = stockCountGaps(products, d);
      expect({for (final g in gaps) g.product.id: g.difference}, {'a': -1.0, 'c': 1.0});
    });

    test('ajustements validés avec le locationId de l’emplacement, brouillon conservé', () async {
      final d = StockCountDraft.start(DateTime(2026, 10, 24, 9))
          .forLocation('goma', 'Magasin Goma', {'a': 4})
          .withCount('a', 3);
      final back = StockCountDraft.fromJson(d.toJson());
      expect(back.locationId, 'goma');
      expect(back.locationStock, {'a': 4.0});
      final repo = _Repo();
      await StockCountService.apply(repo, back, stockCountGaps(products, back));
      final t = repo.sent.single;
      expect(t.quantity, -1);
      expect(t.locationId, 'goma');
      expect(t.toApiPayload()['locationId'], 'goma');
      expect(t.notes, contains('Magasin Goma'));
      expect(t.notes, contains('compté 3, théorique 4'));
    });

    test('changer d’emplacement repart d’un comptage vide, revenir à Tous efface le stock d’emplacement', () {
      final d = StockCountDraft.start().withCount('a', 2).forLocation('goma', 'Goma', {'a': 1});
      expect(d.counts, isEmpty);
      final all = d.forLocation(null, null, {'a': 9});
      expect(all.locationId, isNull);
      expect(all.locationStock, isEmpty);
    });
  });
}
