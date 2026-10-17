import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/services/import/csv_import_service.dart';

const _entete =
    'nom,categorie,unite,prix_achat,prix_vente,quantite,devise,taux_change';

double? _tauxCentral(String code) {
  switch (code) {
    case 'USD':
      return 2800;
    case 'FCFA':
      return 4.5;
    default:
      return null;
  }
}

void main() {
  group('parseCSV', () {
    test('une ligne en CDF garde le taux 1', () {
      final r = CsvImportService.parseCSV(
        '$_entete\nSavon,hygiene,piece,500,800,10,CDF,1',
        rateToCdf: _tauxCentral,
      );
      expect(r.errors, isEmpty);
      final p = r.products.single;
      expect(p.inputCurrencyCode, 'CDF');
      expect(p.inputExchangeRate, 1.0);
      expect(p.sellingPriceInCdf, 800);
    });

    test('une ligne en USD prend le taux central', () {
      final r = CsvImportService.parseCSV(
        '$_entete\nSavon,hygiene,piece,10,21,10,USD,',
        rateToCdf: _tauxCentral,
      );
      expect(r.errors, isEmpty);
      final p = r.products.single;
      expect(p.inputCurrencyCode, 'USD');
      expect(p.inputExchangeRate, 2800);
      expect(p.sellingPriceInCdf, 21 * 2800);
      expect(p.sellingPriceInInputCurrency, 21);
    });

    test('un taux « 1 » recopie du modele n est pas pris pour un taux', () {
      final r = CsvImportService.parseCSV(
        '$_entete\nSavon,hygiene,piece,10,21,10,USD,1',
        rateToCdf: _tauxCentral,
      );
      expect(r.errors, isEmpty);
      expect(r.products.single.inputExchangeRate, 2800);
    });

    test('un taux du fichier superieur a 1 est retenu', () {
      final r = CsvImportService.parseCSV(
        '$_entete\nSavon,hygiene,piece,10,21,10,USD,2750',
        rateToCdf: _tauxCentral,
      );
      expect(r.products.single.inputExchangeRate, 2750);
    });

    test('une ligne en USD sans aucun taux est refusee', () {
      final r = CsvImportService.parseCSV(
        '$_entete\nSavon,hygiene,piece,10,21,10,USD,',
        rateToCdf: (_) => null,
      );
      expect(r.products, isEmpty);
      expect(r.errors.single, contains('Taux USD non défini'));
    });

    test('une devise inconnue est refusee', () {
      final r = CsvImportService.parseCSV(
        '$_entete\nSavon,hygiene,piece,10,21,10,EUR,1000',
        rateToCdf: _tauxCentral,
      );
      expect(r.products, isEmpty);
      expect(r.errors.single, contains('EUR'));
    });

    test('une devise vide prend la devise active de l app', () {
      final r = CsvImportService.parseCSV(
        '$_entete\nSavon,hygiene,piece,10,21,10,,',
        rateToCdf: _tauxCentral,
        defaultCurrencyCode: 'USD',
      );
      expect(r.errors, isEmpty);
      final p = r.products.single;
      expect(p.inputCurrencyCode, 'USD');
      expect(p.inputExchangeRate, 2800);
    });
  });

  group('fins de ligne', () {
    test('le modele fourni par l app se reimporte', () {
      final r = CsvImportService.parseCSV(
        CsvImportService.generateTemplate(),
        rateToCdf: _tauxCentral,
      );
      expect(r.errors, isEmpty);
      expect(r.products, hasLength(1));
    });

    test('un fichier en CRLF donne autant d articles que de lignes', () {
      final r = CsvImportService.parseCSV(
        '$_entete\r\nA,hygiene,piece,1,100,1,CDF,1\r\nB,hygiene,piece,1,200,1,CDF,1\r\n',
        rateToCdf: _tauxCentral,
      );
      expect(r.products.map((p) => p.name), ['A', 'B']);
    });
  });

  group('normalizeCurrencyCode', () {
    test('XAF est lu comme FCFA, FC et vide comme CDF', () {
      expect(CsvImportService.normalizeCurrencyCode('xaf', 'CDF'), 'FCFA');
      expect(CsvImportService.normalizeCurrencyCode('FC', 'USD'), 'CDF');
      expect(CsvImportService.normalizeCurrencyCode('', 'CDF'), 'CDF');
    });
  });
}
