import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/invoice/services/invoice_service.dart';
import 'package:wanzo/features/invoice/utils/invoice_tax.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/sales/models/sale_item.dart';
import 'package:wanzo/features/settings/models/settings.dart';
import 'package:wanzo/services/receipt_printer_service.dart';

/// TVA sur les pièces de vente (facture A4, reçu, ticket POS).
///
/// Défaut du 30 oct. : une entreprise au régime NORMAL, affichage des taxes
/// activé, ne voyait plus la TVA. La vente lue du serveur n'a pas de
/// `taxAmount` (NULL pour presque toutes les ventes en prod), alors que la
/// comptabilité extrait bien 16 % du TTC. La pièce doit montrer la TVA
/// comptabilisée, et une entreprise non assujettie qui affiche les taxes voit
/// la mention de non-assujettissement, sans montant.
void main() {
  const tauxUsd = 2800.0;

  SaleItem ligneCdf(int qte, double prix) => SaleItem(
        productName: 'Article',
        quantity: qte,
        unitPrice: prix,
        totalPrice: prix * qte,
        currencyCode: 'CDF',
        exchangeRate: 1,
        unitPriceInCdf: prix,
        totalPriceInCdf: prix * qte,
        itemType: SaleItemType.product,
      );

  SaleItem ligneUsd(int qte, double prixUsd) => SaleItem(
        productName: 'Article',
        quantity: qte,
        unitPrice: prixUsd,
        totalPrice: prixUsd * qte,
        currencyCode: 'USD',
        exchangeRate: tauxUsd,
        unitPriceInCdf: prixUsd * tauxUsd,
        totalPriceInCdf: prixUsd * qte * tauxUsd,
        itemType: SaleItemType.product,
      );

  /// Vente telle que relue du serveur : ni HT ni TVA enregistrés.
  Sale venteCdf({double? amountHT, double? taxAmount}) => Sale(
        id: 'vente-cdf-01',
        date: DateTime(2026, 10, 30, 9),
        customerName: 'Client',
        items: [ligneCdf(2, 500)],
        totalAmountInCdf: 1000,
        paidAmountInCdf: 1000,
        status: SaleStatus.completed,
        transactionCurrencyCode: 'CDF',
        transactionExchangeRate: 1,
        amountHT: amountHT,
        taxAmount: taxAmount,
        paymentMethod: 'cash',
      );

  Sale venteUsd() => Sale(
        id: 'vente-usd-01',
        date: DateTime(2026, 10, 30, 9),
        customerName: 'Client',
        items: [ligneUsd(2, 29), ligneUsd(1, 58)],
        totalAmountInCdf: 116 * tauxUsd,
        paidAmountInCdf: 116 * tauxUsd,
        status: SaleStatus.completed,
        transactionCurrencyCode: 'USD',
        transactionExchangeRate: tauxUsd,
        totalAmountInTransactionCurrency: 116,
        paymentMethod: 'cash',
      );

  const normalAffiche = Settings(showTaxes: true, isTaxSubject: true);
  const normalMasque = Settings(showTaxes: false, isTaxSubject: true);
  const exonereAffiche = Settings(showTaxes: true, isTaxSubject: false);
  const exonereMasque = Settings(showTaxes: false, isTaxSubject: false);

  double montant(InvoiceFooter f, String label) =>
      f.totals.firstWhere((l) => l.label.startsWith(label)).amount;
  bool aLigne(InvoiceFooter f, String label) =>
      f.totals.any((l) => l.label.startsWith(label));

  group('règle partagée', () {
    test('le réglage décide si, le régime décide comment', () {
      expect(invoiceTaxMode(showTaxes: true, isTaxSubject: true),
          InvoiceTaxMode.charged);
      expect(invoiceTaxMode(showTaxes: true, isTaxSubject: false),
          InvoiceTaxMode.notApplicable);
      expect(invoiceTaxMode(showTaxes: false, isTaxSubject: true),
          InvoiceTaxMode.hidden);
      expect(invoiceTaxMode(showTaxes: false, isTaxSubject: false),
          InvoiceTaxMode.hidden);
    });

    test('taux de calcul : régime et produit, jamais le réglage d\'affichage', () {
      expect(saleLineTaxRate(isTaxSubject: true), tvaRateRdc);
      expect(saleLineTaxRate(isTaxSubject: true, productRate: 0), tvaRateRdc);
      expect(saleLineTaxRate(isTaxSubject: true, productRate: 8), 8);
      expect(saleLineTaxRate(isTaxSubject: false, productRate: 16), 0);
    });

    test('comptabilisation inchangée : TVA extraite du TTC comme la compta', () {
      // Écriture réelle FAC-2026-9EA36EA6 (30 oct.) : 1 000 FC TTC,
      // TVA collectée 137,93 et produit 862,07.
      final tva = accountedSaleTaxCdf(isTaxSubject: true, totalTtcCdf: 1000);
      expect(tva, closeTo(137.93, 0.005));
      expect(1000 - tva, closeTo(862.07, 0.005));
    });

    test('vente portant son HT (Comm_Desk) : la TVA figée fait foi', () {
      expect(
        accountedSaleTaxCdf(
          isTaxSubject: true,
          totalTtcCdf: 1000,
          amountHtCdf: 900,
          taxAmountCdf: 100,
        ),
        100,
      );
      expect(
        accountedSaleTaxCdf(
          isTaxSubject: true,
          totalTtcCdf: 1000,
          amountHtCdf: 900,
        ),
        100,
      );
    });

    test('TVA locale non transmise ignorée : la compta extrait 16 %', () {
      expect(
        accountedSaleTaxCdf(
          isTaxSubject: true,
          totalTtcCdf: 1160,
          taxAmountCdf: 50,
        ),
        closeTo(160, 1e-9),
      );
    });

    test('non assujetti : jamais de TVA, même avec un montant enregistré', () {
      expect(
        accountedSaleTaxCdf(
          isTaxSubject: false,
          totalTtcCdf: 1000,
          amountHtCdf: 862.07,
          taxAmountCdf: 137.93,
        ),
        0,
      );
    });
  });

  group('facture A4 et reçu PDF', () {
    test('NORMAL, affichage activé, vente CDF sans TVA enregistrée', () {
      final f = InvoiceFooter.of(venteCdf(), normalAffiche);
      expect(f.currencyCode, 'CDF');
      expect(montant(f, 'Total HT'), closeTo(862.07, 0.005));
      expect(montant(f, 'TVA'), closeTo(137.93, 0.005));
      expect(montant(f, 'Total à payer'), 1000);
      expect(montant(f, 'Total HT') + montant(f, 'TVA'), closeTo(1000, 1e-9));
      expect(f.totals.firstWhere((l) => l.label.startsWith('TVA')).label,
          'TVA (16%)');
      expect(f.taxNote, isNull);
    });

    test('NORMAL, affichage activé, vente USD : HT, TVA et TTC en USD', () {
      final f = InvoiceFooter.of(venteUsd(), normalAffiche);
      expect(f.currencyCode, 'USD');
      expect(montant(f, 'Total HT'), closeTo(100, 1e-9));
      expect(montant(f, 'TVA'), closeTo(16, 1e-9));
      expect(montant(f, 'Total à payer'), closeTo(116, 1e-9));
    });

    test('NORMAL, affichage désactivé : aucune TVA, comme avant', () {
      final f = InvoiceFooter.of(venteCdf(), normalMasque);
      expect(aLigne(f, 'TVA'), isFalse);
      expect(aLigne(f, 'Total HT'), isFalse);
      expect(f.taxNote, isNull);
      expect(montant(f, 'Total à payer'), 1000);
    });

    test('SMT ou FORFAITAIRE, affichage activé : mention, montants intacts', () {
      for (final vente in [venteCdf(), venteUsd()]) {
        final f = InvoiceFooter.of(vente, exonereAffiche);
        expect(aLigne(f, 'TVA'), isFalse);
        expect(aLigne(f, 'Total HT'), isFalse);
        expect(f.taxNote, tvaNotApplicableMention);
        expect(f.figures.tax, 0);
      }
      expect(montant(InvoiceFooter.of(venteCdf(), exonereAffiche),
          'Total à payer'), 1000);
      expect(montant(InvoiceFooter.of(venteUsd(), exonereAffiche),
          'Total à payer'), closeTo(116, 1e-9));
    });

    test('SMT ou FORFAITAIRE, affichage désactivé : rien', () {
      final f = InvoiceFooter.of(venteCdf(), exonereMasque);
      expect(aLigne(f, 'TVA'), isFalse);
      expect(f.taxNote, isNull);
    });

    test('vente portant son HT : la TVA imprimée est celle comptabilisée', () {
      final f = InvoiceFooter.of(
        venteCdf(amountHT: 900, taxAmount: 100),
        normalAffiche,
      );
      expect(montant(f, 'Total HT'), 900);
      expect(montant(f, 'TVA'), 100);
    });
  });

  group('ticket POS (ESC/POS)', () {
    String ticket(Sale s, Settings settings) => latin1.decode(
          ReceiptPrinterService().buildCashReceiptBytes(s, settings),
          allowInvalid: true,
        );

    test('NORMAL, affichage activé : Total HT et TVA 16 %', () {
      for (final s in [venteCdf(), venteUsd()]) {
        final t = ticket(s, normalAffiche);
        expect(t, contains('Total HT'));
        expect(t, contains('TVA 16%'));
        expect(t, isNot(contains('non applicable')));
      }
    });

    test('NORMAL, affichage désactivé : aucune TVA', () {
      final t = ticket(venteCdf(), normalMasque);
      expect(t, isNot(contains('TVA')));
      expect(t, isNot(contains('Total HT')));
    });

    test('non assujetti, affichage activé : mention sans montant', () {
      final t = ticket(venteUsd(), exonereAffiche);
      expect(t, contains('TVA non applicable'));
      expect(t, isNot(contains('TVA 16%')));
      expect(t, isNot(contains('Total HT')));
    });

    test('non assujetti, affichage désactivé : aucune TVA', () {
      final t = ticket(venteCdf(), exonereMasque);
      expect(t, isNot(contains('TVA')));
    });
  });
}
