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
}
