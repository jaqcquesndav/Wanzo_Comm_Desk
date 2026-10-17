import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/invoice/utils/invoice_money.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/sales/models/sale_item.dart';

/// Ticket du 14 oct. (Goutte) : « 1 x 0,01 $ / 5 x 0,01 $ = 0,04 $ /
/// TOTAL 0,05 $ / Espèces 126 $ / Monnaie 125,95 $ ». Tous les chiffres d'un
/// ticket doivent venir de la base CDF au taux figé de la vente.
void main() {
  const taux = 2800.0;

  SaleItem ligne(int qte, double prixUsd) => SaleItem(
        productName: 'Rambo Maria',
        quantity: qte,
        unitPrice: prixUsd,
        totalPrice: prixUsd * qte,
        currencyCode: 'USD',
        exchangeRate: taux,
        unitPriceInCdf: prixUsd * taux,
        totalPriceInCdf: prixUsd * qte * taux,
        itemType: SaleItemType.product,
      );

  Sale vente({
    required double totalCdf,
    required double payeCdf,
    double? totalTx,
    double? payeTx,
    double remise = 0,
    double? tva,
    String mode = 'Espèces',
  }) =>
      Sale(
        id: 'ce962286',
        date: DateTime(2026, 10, 14, 18, 3),
        customerName: 'Jean',
        items: [ligne(1, 21), ligne(5, 21)],
        totalAmountInCdf: totalCdf,
        paidAmountInCdf: payeCdf,
        status: SaleStatus.completed,
        transactionCurrencyCode: 'USD',
        transactionExchangeRate: taux,
        totalAmountInTransactionCurrency: totalTx,
        paidAmountInTransactionCurrency: payeTx,
        discountPercentage: remise,
        taxAmount: tva,
        paymentMethod: mode,
      );

  test('vente USD : lignes, total, reçu et monnaie dans la même devise', () {
    final s = vente(totalCdf: 126 * taux, payeCdf: 130 * taux, totalTx: 126, payeTx: 130);
    final m = InvoiceMoney.forSale(s);
    final f = m.figures(s, showTax: false);
    expect(m.currencyCode, 'USD');
    expect(m.lineTotal(s.items[1]), closeTo(105, 1e-9));
    expect(f.total, closeTo(126, 1e-9));
    expect(f.received, closeTo(130, 1e-9));
    expect(f.change, closeTo(4, 1e-9));
    expect(f.due, 0);
  });

  test('champ « reçu en devise » vide : jamais un montant CDF sous « \$ »', () {
    // Ancien piège : paidAmountInTransactionCurrency nul -> repli sur la base
    // CDF imprimée telle quelle sous le symbole USD.
    final s = vente(totalCdf: 126 * taux, payeCdf: 126 * taux, totalTx: null, payeTx: null);
    final f = InvoiceMoney.forSale(s).figures(s, showTax: false);
    expect(f.total, closeTo(126, 1e-9));
    expect(f.received, closeTo(126, 1e-9));
    expect(f.change, 0);
  });

  test('remise et TVA : les lignes et le total se recoupent', () {
    // 10 % de remise sur 126 $ ; TVA 16 % incluse enregistrée sur la vente.
    final total = 126 * 0.9;
    final tva = total * 16 / 116;
    final s = vente(totalCdf: total * taux, payeCdf: total * taux, remise: 10, tva: tva * taux);
    final f = InvoiceMoney.forSale(s).figures(s, showTax: true);
    expect(f.lines, closeTo(126, 1e-9));
    expect(f.discount, closeTo(12.6, 1e-9));
    expect(f.total, closeTo(113.4, 1e-9));
    expect(f.tax, closeTo(tva, 1e-9));
    expect(f.totalHt + f.tax, closeTo(f.total, 1e-9));
  });

  test('prix unitaire à fraction de centime : imprimé précis', () {
    final item = SaleItem(
      productName: 'Article',
      quantity: 5,
      unitPrice: 0.0075,
      totalPrice: 0.0375,
      currencyCode: 'USD',
      exchangeRate: taux,
      unitPriceInCdf: 21,
      totalPriceInCdf: 105,
      itemType: SaleItemType.product,
    );
    final s = vente(totalCdf: 105, payeCdf: 105)..items.clear();
    final m = InvoiceMoney.forSale(s);
    expect(m.unitIsExact(item), isFalse);
    expect(m.unitIsExact(ligne(5, 21)), isTrue);
  });

  test('libellé du règlement selon le mode réel', () {
    expect(receiptPaymentLabel('Espèces'), 'Especes');
    expect(receiptPaymentLabel('Mobile Money'), 'Mobile Money');
    expect(receiptPaymentLabel('Carte bancaire'), 'Carte');
    expect(receiptPaymentLabel('Crédit'), 'Acompte');
  });
}
