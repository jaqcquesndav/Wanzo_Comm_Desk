import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/proforma/models/proforma.dart';
import 'package:wanzo/features/proforma/services/proforma_document.dart';

/// Facture proforma : totaux en base CDF, numéro provisoire, devise sans
/// taux 1, aperçu imprimable sans vente enregistrée.
void main() {
  Proforma proforma({String? number, String currency = 'USD', double rate = 2800}) =>
      Proforma(
        id: 'p1',
        number: number,
        provisionalNumber: 'PF-PROV-AB12-3',
        sourceType: ProformaSource.sale,
        customerName: 'Banque X',
        contactName: 'M. Ilunga',
        lines: const [
          ProformaLine(
              label: 'Eau 50 cl',
              quantity: 40,
              unitPriceCdf: 1000,
              itemType: 'product',
              productId: 'p-eau'),
          ProformaLine(label: 'Pause-café', quantity: 40, unitPriceCdf: 14000),
        ],
        currencyCode: currency,
        exchangeRate: rate,
        validUntil: DateTime(2026, 11, 17),
        issuedAt: DateTime(2026, 10, 18, 10),
      );

  test('total en base CDF et dans la devise de présentation', () {
    final p = proforma();
    expect(p.totalCdf, 600000);
    expect(p.totalInCurrency, 214.29);
  });

  test('numéro provisoire tant que le serveur ne l\'a pas numérotée', () {
    expect(proforma().isProvisional, isTrue);
    expect(proforma().displayNumber, 'PF-PROV-AB12-3');
    final def = proforma(number: 'PF-2026-0007');
    expect(def.isProvisional, isFalse);
    expect(def.displayNumber, 'PF-2026-0007');
    expect(def.mention.provisional, isFalse);
    expect(proforma().mention.attention, 'M. Ilunga');
  });

  test('envoi au serveur : article du stock déclaré, plat en service, validité', () {
    final json = proforma().toApiJson();
    final lines = json['lines'] as List;
    expect(lines[0], containsPair('itemType', 'product'));
    expect(lines[0], containsPair('productId', 'p-eau'));
    expect(lines[1], containsPair('itemType', 'service'));
    expect((lines[1] as Map).containsKey('productId'), isFalse);
    expect(json['validUntil'], '2026-11-17');
    expect(json['exchangeRate'], 2800);
  });

  test('copie locale relue à l\'identique (hors ligne)', () {
    final relu = Proforma.fromJson(proforma().toJson());
    expect(relu.provisionalNumber, 'PF-PROV-AB12-3');
    expect(relu.synced, isFalse);
    expect(relu.totalCdf, 600000);
    expect(relu.lines.first.isProduct, isTrue);
  });

  test('aperçu imprimable : aucune somme payée, devise et base CDF gardées', () {
    final sale = ProformaDocument.previewSale(proforma());
    expect(sale.paidAmountInCdf, 0);
    expect(sale.totalAmountInCdf, 600000);
    expect(sale.transactionCurrencyCode, 'USD');
    expect(sale.items, hasLength(2));
  });

  test('en CDF, aucun taux appliqué', () {
    final p = proforma(currency: 'CDF', rate: 1);
    expect(p.totalInCurrency, 600000);
    expect(p.toApiJson().containsKey('exchangeRate'), isFalse);
  });

  test('convertie hors ligne : reste à envoyer, statut et vente portés par l envoi', () {
    final p = proforma(number: 'PF-2026-0007')
        .copyWith(status: ProformaStatus.converted, convertedSaleId: 'v-1', synced: false);
    final relu = Proforma.fromJson(p.toJson());
    expect(relu.synced, isFalse);
    final api = relu.toApiJson();
    expect(api['status'], 'converted');
    expect(api['convertedSaleId'], 'v-1');
    expect(proforma().toApiJson().containsKey('status'), isFalse);
  });

  test('quantité décimale : jamais arrondie sur la pièce', () {
    final p = Proforma(
      id: 'p2',
      sourceType: ProformaSource.sale,
      lines: const [ProformaLine(label: 'Viande', quantity: 2.5, unitPriceCdf: 10000)],
      issuedAt: DateTime(2026, 10, 18),
    );
    final item = ProformaDocument.previewSale(p).items.single;
    expect(item.quantity, 1);
    expect(item.productName, contains('2,5'));
    expect(item.totalPriceInCdf, 25000);
  });
}
