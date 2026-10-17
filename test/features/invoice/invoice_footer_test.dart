import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/invoice/services/invoice_service.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/sales/models/sale_item.dart';
import 'package:wanzo/features/settings/models/settings.dart';

/// Pied de facture / reçu PDF : tous les montants viennent de la base CDF au
/// taux figé de la vente, et lignes, remise, TVA et total s'additionnent.
void main() {
  const taux = 2800.0;

  SaleItem ligne(int qte, double prixUsd) => SaleItem(
        productName: 'Article',
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
    String? devise = 'USD',
    double? tauxVente = taux,
    double? totalTx,
    double? tva,
  }) =>
      Sale(
        id: 'facture01',
        date: DateTime(2026, 10, 14),
        customerName: 'Jean',
        items: [ligne(2, 10), ligne(1, 20)],
        totalAmountInCdf: totalCdf,
        paidAmountInCdf: payeCdf,
        status: SaleStatus.completed,
        transactionCurrencyCode: devise,
        transactionExchangeRate: tauxVente,
        totalAmountInTransactionCurrency: totalTx,
        taxAmount: tva,
      );

  double montant(InvoiceFooter f, String label) => [
        ...f.totals,
        ...f.settlement,
      ].firstWhere((l) => l.label.startsWith(label)).amount;

  bool aLigne(InvoiceFooter f, String label) =>
      [...f.totals, ...f.settlement].any((l) => l.label.startsWith(label));

  test('vente USD sans remise : total seul, en USD, depuis la base CDF', () {
    // Total en devise absent (vente ancienne) : on ne retombe PAS sur le
    // nombre CDF, on convertit la base.
    final f = InvoiceFooter.of(
      vente(totalCdf: 40 * taux, payeCdf: 40 * taux, totalTx: null),
      const Settings(showTaxes: false),
    );
    expect(f.currencyCode, 'USD');
    expect(montant(f, 'Total à payer'), closeTo(40, 1e-9));
    expect(montant(f, 'Montant payé'), closeTo(40, 1e-9));
    expect(aLigne(f, 'Sous-total'), isFalse);
    expect(aLigne(f, 'Remise'), isFalse);
    expect(aLigne(f, 'Solde'), isFalse);
  });

  test('remise : sous-total moins remise égale le total à payer', () {
    final f = InvoiceFooter.of(
      vente(totalCdf: 36 * taux, payeCdf: 20 * taux),
      const Settings(showTaxes: false),
    );
    final sousTotal = montant(f, 'Sous-total');
    final remise = montant(f, 'Remise');
    expect(sousTotal, closeTo(40, 1e-9));
    expect(remise, closeTo(-4, 1e-9));
    expect(sousTotal + remise, closeTo(montant(f, 'Total à payer'), 1e-9));
    expect(montant(f, 'Solde dû'), closeTo(16, 1e-9));
    expect(f.format(remise), startsWith('-'));
  });

  test('TVA seulement si assujetti ET affichage des taxes', () {
    final s = vente(
      totalCdf: 40 * taux,
      payeCdf: 40 * taux,
      tva: 40 * 16 / 116 * taux,
    );

    final nonAssujetti = InvoiceFooter.of(
      s,
      const Settings(showTaxes: true, isTaxSubject: false),
    );
    expect(aLigne(nonAssujetti, 'TVA'), isFalse);

    final masque = InvoiceFooter.of(
      s,
      const Settings(showTaxes: false, isTaxSubject: true),
    );
    expect(aLigne(masque, 'TVA'), isFalse);

    final f = InvoiceFooter.of(
      s,
      const Settings(showTaxes: true, isTaxSubject: true),
    );
    final ht = montant(f, 'Total HT');
    final tva = montant(f, 'TVA');
    expect(tva, closeTo(40 * 16 / 116, 1e-9));
    expect(ht + tva, closeTo(montant(f, 'Total à payer'), 1e-9));
    expect(f.totals.firstWhere((l) => l.label.startsWith('TVA')).label,
        'TVA (16%)');
  });

  test('sans devise : document en CDF, jamais la devise de l\'app', () {
    final f = InvoiceFooter.of(
      vente(
        totalCdf: 112000,
        payeCdf: 100000,
        devise: null,
        tauxVente: null,
      ),
      const Settings(showTaxes: false),
    );
    expect(f.currencyCode, 'CDF');
    expect(montant(f, 'Total à payer'), 112000);
    expect(montant(f, 'Solde dû'), 12000);
  });

  test('trop perçu : monnaie rendue, pas de solde dû', () {
    final f = InvoiceFooter.of(
      vente(totalCdf: 40 * taux, payeCdf: 50 * taux),
      const Settings(showTaxes: false),
    );
    expect(montant(f, 'Monnaie rendue'), closeTo(10, 1e-9));
    expect(aLigne(f, 'Solde'), isFalse);
  });
}
