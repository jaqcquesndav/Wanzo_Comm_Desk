import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';
import 'package:wanzo/features/invoice/utils/invoice_money.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/sales/models/sale_item.dart';
import 'package:wanzo/features/sales/services/sale_dto.dart';

/// Vente en CDF et en USD : base CDF cohérente, taux de la vente transmis,
/// aucun taux 1 implicite, et lecture tolérante de la réponse réelle du
/// contrôleur gestion (SaleResponseDto dans l'enveloppe ApiResponseInterceptor).
void main() {
  const taux = 2800.0;

  SaleItem ligneUsd(int qte, double prixUsd, {String? id}) => SaleItem(
        id: id,
        productId: 'p1',
        productName: 'Savon',
        quantity: qte,
        unitPrice: prixUsd,
        totalPrice: prixUsd * qte,
        currencyCode: 'USD',
        exchangeRate: taux,
        unitPriceInCdf: prixUsd * taux,
        totalPriceInCdf: prixUsd * qte * taux,
        itemType: SaleItemType.product,
      );

  SaleItem ligneCdf(int qte, double prix) => SaleItem(
        productId: 'p2',
        productName: 'Pain',
        quantity: qte,
        unitPrice: prix,
        totalPrice: prix * qte,
        currencyCode: 'CDF',
        exchangeRate: 1,
        unitPriceInCdf: prix,
        totalPriceInCdf: prix * qte,
        itemType: SaleItemType.product,
      );

  Sale venteUsd({double? rate = taux, double payeUsd = 4}) => Sale(
        id: 'local-1',
        date: DateTime(2026, 10, 17, 10),
        customerId: 'c1',
        customerName: 'Jean',
        items: [ligneUsd(2, 5)],
        totalAmountInCdf: 10 * taux,
        paidAmountInCdf: payeUsd * taux,
        status: SaleStatus.partiallyPaid,
        paymentMethod: 'Mobile Money',
        transactionCurrencyCode: 'USD',
        transactionExchangeRate: rate,
        totalAmountInTransactionCurrency: 10,
        paidAmountInTransactionCurrency: payeUsd,
        businessUnitType: BusinessUnitType.pos,
        notes: '',
      );

  group('Corps envoyé au backend (saleToApiDto)', () {
    test('vente USD : devise et taux de la vente, base CDF', () {
      final dto = saleToApiDto(venteUsd(), sourceMode: 'retail');
      expect(dto['transactionCurrencyCode'], 'USD');
      // `currencyCode` au niveau vente est une clé inconnue du DTO backend,
      // supprimée en silence : la vente était enregistrée en CDF.
      expect(dto.containsKey('currencyCode'), isFalse);
      expect(dto['exchangeRate'], taux);
      expect(dto['amountPaidInCdf'], 4 * taux);
      expect(dto['paidAmountInCdf'], 4 * taux);
      expect(dto['paidAmountInTransactionCurrency'], 4);
      final items = dto['items'] as List;
      expect(items.single['currencyCode'], 'USD');
      expect(items.single['unitPrice'], 5);
    });

    test('vente CDF : taux 1 par définition', () {
      final vente = Sale(
        id: 'l2',
        date: DateTime(2026, 10, 17),
        customerName: 'Comptoir',
        items: [ligneCdf(3, 1500)],
        totalAmountInCdf: 4500,
        paidAmountInCdf: 4500,
        status: SaleStatus.completed,
        transactionCurrencyCode: 'CDF',
      );
      final dto = saleToApiDto(vente, sourceMode: 'retail');
      expect(dto['exchangeRate'], 1.0);
      expect(dto['transactionCurrencyCode'], 'CDF');
      expect(dto['amountPaidInCdf'], 4500);
    });

    test('devise étrangère sans taux : refus, jamais un taux 1 muet', () {
      expect(
        () => saleToApiDto(venteUsd(rate: null), sourceMode: 'retail'),
        throwsStateError,
      );
      expect(
        () => saleToApiDto(venteUsd(rate: 1.0), sourceMode: 'retail'),
        throwsStateError,
      );
    });

    test('contrat DTO : enum unité en minuscules, pas de chaîne vide', () {
      final dto = saleToApiDto(venteUsd(), sourceMode: 'retail');
      expect(dto['businessUnitType'], 'pos');
      expect(dto.containsKey('notes'), isFalse);
      // Code canonique, jamais le libellé traduit.
      expect(dto['paymentMethod'], 'mobile_money');
      final sansMode = saleToApiDto(
        venteUsd().copyWith(paymentMethod: ''),
        sourceMode: 'retail',
      );
      expect(sansMode['paymentMethod'], 'cash');
    });

    test('identifiant de ligne émis seulement s il est connu', () {
      final avecId = venteUsd().copyWith(items: [ligneUsd(1, 5, id: 'srv-9')]);
      final sansId = venteUsd().copyWith(items: [ligneUsd(1, 5, id: '')]);
      expect(
        (saleToApiDto(avecId, sourceMode: 'r')['items'] as List).single['id'],
        'srv-9',
      );
      expect(
        (saleToApiDto(sansId, sourceMode: 'r')['items'] as List)
            .single
            .containsKey('id'),
        isFalse,
      );
      expect(
        saleToApiDto(avecId, includeItems: false, sourceMode: 'r')
            .containsKey('items'),
        isFalse,
      );
    });
  });

  group('Lecture de la réponse du contrôleur (Sale.fromJson)', () {
    // Forme exacte de SaleResponseDto.fromEntity (decimals convertis).
    Map<String, dynamic> reponse() => {
          'id': '7b0c',
          'customerName': 'Jean',
          'date': '2026-10-17T10:00:00.000Z',
          'totalAmountInCdf': 28000,
          'paidAmountInCdf': 11200,
          'status': 'partiallyPaid',
          'exchangeRate': 2800,
          'transactionCurrencyCode': 'USD',
          'totalAmountInTransactionCurrency': 10,
          'paidAmountInTransactionCurrency': 4,
          'discountPercentage': 0,
          'paymentMethod': 'mobile_money',
          'userId': 'u1',
          'items': [
            {
              'id': 'i1',
              'saleId': '7b0c',
              'itemType': 'product',
              'productId': 'p1',
              'productName': 'Savon',
              'quantity': 2,
              'unitPrice': 5,
              'discount': 0,
              'currencyCode': 'USD',
              'unitPriceInCdf': 14000,
              'totalPrice': 10,
              'totalPriceInCdf': 28000,
            },
          ],
          'createdAt': '2026-10-17T10:00:00.000Z',
          'updatedAt': '2026-10-17T10:00:00.000Z',
        };

    test('montants, devise et taux de la vente', () {
      final sale = Sale.fromJson(reponse());
      expect(sale.paidAmountInCdf, 11200);
      expect(sale.transactionCurrencyCode, 'USD');
      expect(sale.transactionExchangeRate, 2800);
      // Le taux de ligne absent de la réponse reprend celui de la vente.
      expect(sale.items.single.exchangeRate, 2800);
    });

    test('colonnes numeric en chaîne et lignes nulles tolérées', () {
      final brut = reponse()
        ..['totalAmountInCdf'] = '28000.00'
        ..['paidAmountInCdf'] = '11200.00'
        ..['exchangeRate'] = '2800.00'
        ..['items'] = null;
      final sale = Sale.fromJson(brut);
      expect(sale.totalAmountInCdf, 28000);
      expect(sale.paidAmountInCdf, 11200);
      expect(sale.items, isEmpty);
    });

    test('une vente mal formée n invalide pas la liste', () {
      final ventes = parseSaleList([reponse(), {'id': 'casse'}, 'x']);
      expect(ventes.length, 1);
    });
  });

  group('Pièces dérivées de la base CDF (InvoiceMoney)', () {
    test('vente USD : total, payé et solde au taux de la vente', () {
      final sale = venteUsd();
      final money = InvoiceMoney.forSale(sale);
      expect(money.currencyCode, 'USD');
      final f = money.figures(sale, showTax: false);
      expect(f.total, closeTo(10, 1e-9));
      expect(f.received, closeTo(4, 1e-9));
      expect(f.due, closeTo(6, 1e-9));
      expect(f.lines, closeTo(10, 1e-9));
    });

    test('vente USD sans taux : présentée en CDF, jamais réétiquetée', () {
      final sale = venteUsd(rate: null).copyWith(
        totalAmountInTransactionCurrency: 0,
      );
      final money = InvoiceMoney.forSale(sale);
      expect(money.currencyCode, 'CDF');
      expect(money.fromCdf(28000), 28000);
    });

    test('vente CDF : montants identiques à la base', () {
      final sale = Sale(
        id: 'l3',
        date: DateTime(2026, 10, 17),
        customerName: 'Comptoir',
        items: [ligneCdf(2, 2500)],
        totalAmountInCdf: 5000,
        paidAmountInCdf: 6000,
        status: SaleStatus.completed,
        transactionCurrencyCode: 'CDF',
      );
      final f = InvoiceMoney.forSale(sale).figures(sale, showTax: false);
      expect(f.total, 5000);
      expect(f.change, 1000);
      expect(f.due, 0);
    });
  });
}
