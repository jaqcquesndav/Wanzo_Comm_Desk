import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/widgets/operator_logo.dart';
import 'package:wanzo/features/settings/models/financial_account.dart';

/// Afrimoney ajouté EN FIN d'enum : les index Hive des comptes déjà
/// enregistrés (Airtel 0, Orange 1, M-Pesa 2) ne bougent pas.
void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mm_provider');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(44)) {
      Hive.registerAdapter(MobileMoneyProviderAdapter());
    }
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('index figés, Afrimoney en 3', () {
    expect(MobileMoneyProvider.airtelMoney.index, 0);
    expect(MobileMoneyProvider.orangeMoney.index, 1);
    expect(MobileMoneyProvider.mpesa.index, 2);
    expect(MobileMoneyProvider.afrimoney.index, 3);
  });

  test('aller-retour Hive de chaque opérateur', () async {
    final box = await Hive.openBox<MobileMoneyProvider>('mm');
    for (final p in MobileMoneyProvider.values) {
      await box.put(p.name, p);
    }
    await box.close();
    final relu = await Hive.openBox<MobileMoneyProvider>('mm');
    for (final p in MobileMoneyProvider.values) {
      expect(relu.get(p.name), p);
    }
  });

  test('libellé et logo Afrimoney', () {
    expect(OperatorBrand.resolve(MobileMoneyProvider.afrimoney),
        OperatorBrand.afrimoney);
  });
}
