import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/auth/user_rights.dart';
import 'package:wanzo/core/enums/user_role.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/features/auth/models/user.dart';
import 'package:wanzo/features/auth/services/auth_backend_service.dart';

/// Propriétaire qui crée son entreprise après sa première connexion : l'app
/// ne doit plus lui refuser le choix du mode (« seul un administrateur »).
AuthMeResponse authMe({required String role, bool owner = false}) =>
    AuthMeResponse.fromJson({
      'user': {
        'id': 'u1',
        'email': 'owner@ympacta.cd',
        'role': role,
        'isCompanyOwner': owner,
        'companyId': '655fec17-1111-4222-8333-944444444444',
      },
      'company': {'id': '655fec17-1111-4222-8333-944444444444', 'name': 'Ympacta'},
    });

void main() {
  final ctx = BusinessContextService();

  setUp(() async {
    await ctx.clear();
    RoleRefresh.instance.reset();
    RoleRefresh.instance.runner = null;
    RoleRefresh.instance.clock = DateTime.now;
  });

  group('fromApiValue', () {
    test('owner, sme_owner, sme_admin sont administrateurs', () {
      for (final v in ['owner', 'sme_owner', 'sme_admin', 'ADMIN']) {
        expect(UserRoleExtension.fromApiValue(v), UserRole.admin, reason: v);
      }
    });
    test('superadmin et super_admin donnent superAdmin', () {
      expect(UserRoleExtension.fromApiValue('superadmin'), UserRole.superAdmin);
      expect(UserRoleExtension.fromApiValue('super_admin'), UserRole.superAdmin);
    });
    test('rôles du référentiel', () {
      expect(UserRoleExtension.fromApiValue('commerce_manager'), UserRole.manager);
      expect(UserRoleExtension.fromApiValue('avec_treasurer'), UserRole.accountant);
      expect(UserRoleExtension.fromApiValue('stock_keeper'), UserRole.inventoryManager);
      expect(UserRoleExtension.fromApiValue('salesperson'), UserRole.sales);
    });
    test('inconnu', () {
      expect(UserRoleExtension.isKnownApiValue('unknown'), isFalse);
      expect(UserRoleExtension.isKnownApiValue(null), isFalse);
      expect(UserRoleExtension.isKnownApiValue('staff'), isTrue);
    });
  });

  group('UserRights (source unique : contexte de /auth/me)', () {
    test('propriétaire au rôle « owner » : administrateur', () async {
      await ctx.updateFromAuthMeResponse(authMe(role: 'owner'));
      expect(UserRights.adminStatus(), AdminRightsStatus.admin);
    });

    test('isCompanyOwner vrai : administrateur même si le rôle lu est staff', () async {
      await ctx.updateFromAuthMeResponse(authMe(role: 'staff', owner: true));
      expect(UserRights.isAdmin(), isTrue);
    });

    test('rôle passé de staff à admin sur le serveur : suivi sans redémarrage', () async {
      await ctx.updateFromAuthMeResponse(authMe(role: 'staff'));
      expect(UserRights.adminStatus(), AdminRightsStatus.notAdmin);

      // Relecture branchée comme dans l'app : /auth/me réécrit le contexte.
      RoleRefresh.instance.runner = (_) => ctx.updateFromAuthMeResponse(authMe(role: 'admin'));
      await RoleRefresh.instance.onResumed();
      expect(UserRights.adminStatus(), AdminRightsStatus.admin);
    });

    test('aucun rôle connu : inconnu, jamais « staff »', () async {
      expect(UserRights.adminStatus(), AdminRightsStatus.unknown);
      await ctx.updateFromAuthMeResponse(AuthMeResponse.fromJson({
        'user': {'id': 'u1', 'email': 'e@x.cd'},
      }));
      expect(ctx.userRole, UserRoleExtension.unknownApiValue);
      expect(UserRights.adminStatus(), AdminRightsStatus.unknown);
    });
  });

  group('Repli jeton (claim de rôle absent)', () {
    test('claim absent sans rôle connu : inconnu', () {
      expect(roleFromTokenClaim(null), UserRoleExtension.unknownApiValue);
      expect(roleFromTokenClaim(<dynamic>[]), UserRoleExtension.unknownApiValue);
    });
    test('claim absent : dernier rôle connu du serveur', () {
      expect(roleFromTokenClaim(null, lastKnownServerRole: 'admin'), 'admin');
    });
    test('claim présent : il fait foi', () {
      expect(roleFromTokenClaim(['cashier'], lastKnownServerRole: 'admin'), 'cashier');
    });
    test('updateFromUser avec un rôle inconnu garde le rôle et la propriété du serveur', () async {
      await ctx.updateFromAuthMeResponse(authMe(role: 'staff', owner: true));
      await ctx.updateFromUser(User(
        id: 'google-oauth2|1',
        name: 'Owner',
        email: 'owner@ympacta.cd',
        phone: '',
        role: UserRoleExtension.unknownApiValue,
        emailVerified: true,
        phoneVerified: false,
      ));
      expect(ctx.userRole, 'staff');
      expect(UserRights.isAdmin(), isTrue);
    });
  });

  group('RoleRefresh', () {
    test('premier plan : au plus une relecture toutes les 5 minutes', () async {
      var now = DateTime(2026, 10, 30, 12);
      var runs = 0;
      RoleRefresh.instance.clock = () => now;
      RoleRefresh.instance.runner = (_) async => runs++;

      await RoleRefresh.instance.onResumed();
      await RoleRefresh.instance.onResumed();
      expect(runs, 1);
      now = now.add(const Duration(minutes: 5));
      await RoleRefresh.instance.onResumed();
      expect(runs, 2);
    });

    test('refus 403 de droits : relecture, pas pour un compte suspendu ni /auth/me', () {
      expect(isRoleForbidden(403, {'message': "Seul l'administrateur"}), isTrue);
      expect(isRoleForbidden(403, {'code': 'ACCOUNT_SUSPENDED'}), isFalse);
      expect(isRoleForbidden(403, {'code': 'MEMBERSHIP_SUSPENDED'}), isFalse);
      expect(isRoleForbidden(403, {'code': 'SUBSCRIPTION_REQUIRED'}), isFalse);
      expect(isRoleForbidden(403, {}, endpoint: 'auth/me'), isFalse);
      expect(isRoleForbidden(401, {}), isFalse);
    });
  });
}
