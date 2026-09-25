import 'package:flutter_test/flutter_test.dart';

import 'package:wanzo/features/restaurant/models/menu_item.dart';
import 'package:wanzo/features/restaurant/models/restaurant_order.dart';

/// Le serveur renvoie ses colonnes `decimal` en TEXTE. Un plat ainsi reçu
/// doit se lire : sinon il est écarté en silence et la carte arrive vide.
void main() {
  test('un prix reçu en texte se lit', () {
    final plat = MenuItem.fromJson({
      'id': 'a',
      'name': 'Poulet mayo',
      'priceCdf': '8000.00', // tel que renvoyé par la base en production
      'course': 'plat',
      'priceInputCurrencyCode': 'USD',
      'priceInInputCurrency': '3.00',
    });
    expect(plat.priceCdf, 8000);
    expect(plat.priceInputCurrencyCode, 'USD');
    expect(plat.priceInInputCurrency, 3);
  });

  test('un plat ancien, sans devise d\'origine, reste lisible', () {
    final plat = MenuItem.fromJson(
        {'id': 'b', 'name': 'Liboke', 'priceCdf': 9000, 'course': 'plat'});
    expect(plat.priceCdf, 9000);
    expect(plat.priceInputCurrencyCode, isNull);
  });

  test('une ligne de commande avec un montant en texte se lit', () {
    final ligne = RestaurantOrderLine.fromJson({
      'productId': 'p',
      'productName': 'Fanta',
      'unitPriceCdf': '1500.00',
      'quantity': '2',
    });
    expect(ligne.unitPriceCdf, 1500);
    expect(ligne.quantity, 2);
  });
}
