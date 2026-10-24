import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/modules/activity_mode.dart';
import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/services/business_context_service.dart';

/// Le mode d'activité n'était gardé que sur l'appareil : chaque poste avait le
/// sien et n'importe quel rôle le changeait. Il est désormais lu sur la fiche
/// entreprise (/auth/me) et écrit par un administrateur.
void main() {
  group('mode lu depuis /auth/me', () {
    test('le serveur fait foi quand il porte un choix', () {
      final r = BusinessContextService.resolveActivityMode(
        serverMode: 'restaurant',
        localMode: 'salon',
        alreadyAligned: false,
        isAdmin: false,
      );
      expect(r.mode, 'restaurant');
      expect(r.publishLocal, isFalse);
    });

    test('choix local antérieur, serveur jamais aligné : gardé et publié par un admin', () {
      final admin = BusinessContextService.resolveActivityMode(
        serverMode: 'retail',
        localMode: 'garage',
        alreadyAligned: false,
        isAdmin: true,
      );
      expect(admin.mode, 'garage');
      expect(admin.publishLocal, isTrue);
      final caissier = BusinessContextService.resolveActivityMode(
        serverMode: 'retail',
        localMode: 'garage',
        alreadyAligned: false,
        isAdmin: false,
      );
      expect(caissier.publishLocal, isFalse);
    });

    test('déjà aligné : un retour au Général décidé par l admin s impose', () {
      final r = BusinessContextService.resolveActivityMode(
        serverMode: 'retail',
        localMode: 'restaurant',
        alreadyAligned: true,
        isAdmin: false,
      );
      expect(r.mode, 'retail');
    });

    test('hôtel retiré de la boutique : mode Général', () {
      final r = BusinessContextService.resolveActivityMode(
        serverMode: 'hotel',
        localMode: null,
        alreadyAligned: false,
        isAdmin: true,
      );
      expect(r.mode, 'retail');
      expect(ActivityMode.fromString('hotel'), ActivityMode.retail);
      expect(ActivityMode.values.map((m) => m.apiValue), isNot(contains('hotel')));
    });
  });

  test('seuls admin et super admin changent le mode', () {
    expect(BusinessContextService.isAdminRole('admin'), isTrue);
    expect(BusinessContextService.isAdminRole('super_admin'), isTrue);
    expect(BusinessContextService.isAdminRole('manager'), isFalse);
    expect(BusinessContextService.isAdminRole('cashier'), isFalse);
    expect(BusinessContextService.isAdminRole(null), isFalse);
  });

  test('chaque mode garde une navigation', () {
    for (final m in ActivityMode.values) {
      expect(ModuleRegistry.sidebar(m, 'admin'), isNotEmpty, reason: m.name);
    }
  });
}
