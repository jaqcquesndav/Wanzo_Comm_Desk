import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/invoice/utils/invoice_money.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/sales/models/sale_item.dart';

SaleItem item({
  required double unitPrice,
  required double unitPriceInCdf,
  required String currencyCode,
  required double exchangeRate,
}) => SaleItem(
  productName: 'Article',
  quantity: 1,
  unitPrice: unitPrice,
  totalPrice: unitPrice,
  currencyCode: currencyCode,
  exchangeRate: exchangeRate,
  unitPriceInCdf: unitPriceInCdf,
  totalPriceInCdf: unitPriceInCdf,
  itemType: SaleItemType.product,
);

Sale sale({
  required double totalCdf,
  String? currency,
  double? rate,
  double? totalTx,
  List<SaleItem> items = const [],
}) => Sale(
  id: 'sale-1',
  date: DateTime(2026, 9, 9),
  customerName: 'Client',
  items: items,
  totalAmountInCdf: totalCdf,
  paidAmountInCdf: 0,
  transactionCurrencyCode: currency,
  transactionExchangeRate: rate,
  totalAmountInTransactionCurrency: totalTx,
  status: SaleStatus.completed,
);

void main() {
  group('InvoiceMoney', () {
    test('ligne en CDF sur une facture en USD est convertie, jamais reetiquetee', () {
      final line = item(
        unitPrice: 28000,
        unitPriceInCdf: 28000,
        currencyCode: 'CDF',
        exchangeRate: 1,
      );
      final money = InvoiceMoney.forSale(
        sale(totalCdf: 28000, currency: 'USD', rate: 2800, totalTx: 10, items: [line]),
      );
      expect(money.currencyCode, 'USD');
      expect(money.lineUnit(line), closeTo(10, 0.001));
      expect(money.lineTotal(line), closeTo(10, 0.001));
    });

    test('ligne deja en USD reste identique', () {
      final line = item(
        unitPrice: 10,
        unitPriceInCdf: 28000,
        currencyCode: 'USD',
        exchangeRate: 2800,
      );
      final money = InvoiceMoney.forSale(
        sale(totalCdf: 28000, currency: 'USD', rate: 2800, totalTx: 10, items: [line]),
      );
      expect(money.lineUnit(line), closeTo(10, 0.001));
    });

    test('taux absent : deduit du couple de totaux', () {
      final line = item(
        unitPrice: 28000,
        unitPriceInCdf: 28000,
        currencyCode: 'CDF',
        exchangeRate: 1,
      );
      final money = InvoiceMoney.forSale(
        sale(totalCdf: 28000, currency: 'USD', rate: null, totalTx: 10, items: [line]),
      );
      expect(money.currencyCode, 'USD');
      expect(money.rateToBase, closeTo(2800, 0.001));
      expect(money.lineUnit(line), closeTo(10, 0.001));
    });

    test('aucun taux exploitable : document presente en CDF, pas de symbole USD sur des CDF', () {
      final line = item(
        unitPrice: 28000,
        unitPriceInCdf: 28000,
        currencyCode: 'CDF',
        exchangeRate: 1,
      );
      final money = InvoiceMoney.forSale(
        sale(totalCdf: 28000, currency: 'USD', rate: null, totalTx: null, items: [line]),
      );
      expect(money.currencyCode, 'CDF');
      expect(money.lineUnit(line), closeTo(28000, 0.001));
    });

    test('enregistrement ancien sans base CDF : reconstituee via le taux de la ligne', () {
      final line = item(
        unitPrice: 10,
        unitPriceInCdf: 0,
        currencyCode: 'USD',
        exchangeRate: 2800,
      );
      final money = InvoiceMoney.forSale(
        sale(totalCdf: 28000, currency: 'USD', rate: 2800, totalTx: 10, items: [line]),
      );
      expect(money.lineUnit(line), closeTo(10, 0.001));
    });

    test('somme des lignes coherente avec le total du document', () {
      final lines = [
        item(unitPrice: 28000, unitPriceInCdf: 28000, currencyCode: 'CDF', exchangeRate: 1),
        item(unitPrice: 14000, unitPriceInCdf: 14000, currencyCode: 'CDF', exchangeRate: 1),
      ];
      final money = InvoiceMoney.forSale(
        sale(totalCdf: 42000, currency: 'USD', rate: 2800, totalTx: 15, items: lines),
      );
      expect(money.linesTotal(lines), closeTo(15, 0.001));
    });
  });
}
