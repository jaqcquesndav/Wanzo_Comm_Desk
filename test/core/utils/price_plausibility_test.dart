import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/utils/price_plausibility.dart';

void main() {
  group('prixAnormalementBas', () {
    test('un prix en francs sous 50 FC est suspect', () {
      expect(prixAnormalementBas(21, 'CDF'), isTrue);
      expect(prixAnormalementBas(49.99, 'cdf'), isTrue);
    });

    test('un prix en francs a partir de 50 FC passe', () {
      expect(prixAnormalementBas(50, 'CDF'), isFalse);
      expect(prixAnormalementBas(2800, 'CDF'), isFalse);
    });

    test('un prix en devise sous 0,10 est suspect', () {
      expect(prixAnormalementBas(0.01, 'USD'), isTrue);
      expect(prixAnormalementBas(0.09, 'FCFA'), isTrue);
    });

    test('un prix en devise a partir de 0,10 passe', () {
      expect(prixAnormalementBas(0.10, 'USD'), isFalse);
      expect(prixAnormalementBas(21, 'USD'), isFalse);
    });

    test('un prix nul ou negatif n est jamais signale', () {
      expect(prixAnormalementBas(0, 'CDF'), isFalse);
      expect(prixAnormalementBas(0, 'USD'), isFalse);
      expect(prixAnormalementBas(-5, 'CDF'), isFalse);
      expect(prixAnormalementBas(double.nan, 'CDF'), isFalse);
    });
  });

  group('encaissementDisproportionne', () {
    test('un recu au-dela de 20 fois le total est suspect', () {
      expect(encaissementDisproportionne(recu: 126, total: 0.05), isTrue);
      expect(encaissementDisproportionne(recu: 2001, total: 100), isTrue);
    });

    test('un recu jusqu a 20 fois le total passe', () {
      expect(encaissementDisproportionne(recu: 2000, total: 100), isFalse);
      expect(encaissementDisproportionne(recu: 150, total: 100), isFalse);
    });

    test('un total nul n est pas juge', () {
      expect(encaissementDisproportionne(recu: 500, total: 0), isFalse);
    });
  });

  group('libellePrix', () {
    test('francs sans decimales inutiles, devise a deux decimales', () {
      expect(libellePrix(21, 'CDF'), '21 FC');
      expect(libellePrix(12.5, 'CDF'), '12,50 FC');
      expect(libellePrix(0.01, 'usd'), '0,01 USD');
    });
  });
}
