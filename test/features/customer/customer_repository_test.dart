import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:wanzo/features/customer/repositories/customer_repository.dart';
import 'package:wanzo/features/sales/repositories/sales_repository.dart';
import 'package:hive/hive.dart';

@GenerateMocks([SalesRepository, Box])
void main() {
  late CustomerRepository customerRepository;
  late Directory dossier;

  // Le dépôt lit les boîtes Hive de l'appareil : un dossier temporaire
  // par test, vide.
  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('clients_');
    Hive.init(dossier.path);
    customerRepository = CustomerRepository();
    await customerRepository.init();
  });

  tearDown(() async {
    await Hive.close();
    await dossier.delete(recursive: true);
  });

  group('CustomerRepository', () {
    group('getUniqueCustomersCountForDateRange', () {
      test('aucune vente sur la période : zéro client servi', () async {
        final count = await customerRepository
            .getUniqueCustomersCountForDateRange(
              DateTime(2025, 6, 1),
              DateTime(2025, 6, 7),
            );
        expect(count, 0);
      });
    });
  });
}
