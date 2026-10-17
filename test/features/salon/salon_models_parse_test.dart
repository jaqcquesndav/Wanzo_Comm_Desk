import 'package:flutter_test/flutter_test.dart';

import 'package:wanzo/features/salon/models/salon_service.dart';
import 'package:wanzo/features/salon/models/stylist.dart';

/// Les colonnes Postgres `numeric` arrivent en CHAÎNE JSON ("50.00") : la
/// carte du salon ne doit ni planter ni afficher 0 pour autant.
void main() {
  group('SalonService.fromJson', () {
    test('lit les montants et la durée envoyés en chaîne', () {
      final s = SalonService.fromJson({
        'id': 'p1',
        'name': 'Coupe homme',
        'category': 'homme',
        'priceCdf': '57500.00',
        'priceInputCurrencyCode': 'USD',
        'priceInInputCurrency': '25.00',
        'durationMinutes': '45',
        'serviceCommissionPct': '10.50',
        'active': true,
        'position': '3.00',
      });
      expect(s.priceCdf, 57500);
      expect(s.priceInInputCurrency, 25);
      expect(s.priceInputCurrencyCode, 'USD');
      expect(s.durationMinutes, 45);
      expect(s.serviceCommissionPct, 10.5);
      expect(s.position, 3);
      expect(s.category, SalonServiceCategory.homme);
    });

    test('accepte aussi des nombres et garde null ce qui est absent', () {
      final s = SalonService.fromJson({
        'id': 'p2',
        'name': 'Tresses',
        'category': 'inconnue',
        'priceCdf': 30000,
        'priceInInputCurrency': null,
        'durationMinutes': null,
      });
      expect(s.priceCdf, 30000);
      expect(s.priceInInputCurrency, isNull);
      expect(s.durationMinutes, isNull);
      expect(s.serviceCommissionPct, isNull);
      expect(s.active, isTrue);
      // Catégorie inconnue : repli lisible plutôt qu'une exception.
      expect(s.category, SalonServiceCategory.autre);
    });

    test('une valeur illisible ne fait pas planter la carte', () {
      final s = SalonService.fromJson({
        'id': 'p3',
        'name': 'Soin',
        'priceCdf': 'abc',
        'durationMinutes': 'n/a',
      });
      expect(s.priceCdf, 0);
      expect(s.durationMinutes, isNull);
    });
  });

  group('Stylist.fromJson', () {
    test('commissions et loyer en chaîne', () {
      final st = Stylist.fromJson({
        'id': 'c1',
        'name': 'Aline',
        'payModel': 'booth_rent',
        'serviceCommissionPct': '40.00',
        'retailCommissionPct': '5',
        'boothRentAmount': '230000.00',
        'boothRentCurrencyCode': 'USD',
        'boothRentInInputCurrency': '100.00',
      });
      expect(st.payModel, StylistPayModel.boothRent);
      expect(st.serviceCommissionPct, 40);
      expect(st.retailCommissionPct, 5);
      expect(st.boothRentAmount, 230000);
      expect(st.boothRentInInputCurrency, 100);
      expect(st.boothRentCurrencyCode, 'USD');
    });
  });
}
