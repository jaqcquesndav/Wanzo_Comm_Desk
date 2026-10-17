import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/enums/user_role.dart';
import 'package:wanzo/features/auth/models/join_request.dart';
import 'package:wanzo/features/settings/screens/invoice_settings_screen.dart';

/// Règles des réglages : taux de change saisis et droits par rôle.
void main() {
  group('taux de change saisi', () {
    test('accepte virgule décimale et espaces', () {
      expect(parsePositiveRate('2 850,50'), 2850.5);
      expect(parsePositiveRate(' 2800 '), 2800);
    });

    test('jamais de taux nul, négatif ou illisible (pas de taux implicite)', () {
      expect(parsePositiveRate('0'), isNull);
      expect(parsePositiveRate('-1'), isNull);
      expect(parsePositiveRate('abc'), isNull);
      expect(parsePositiveRate(''), isNull);
      expect(parsePositiveRate(null), isNull);
    });
  });

  group('droits par rôle', () {
    UserRole r(String v) => UserRoleExtension.fromApiValue(v);

    test('comptes financiers : administrateur, super admin et comptable', () {
      expect(r('admin').canManageFinancialAccounts, isTrue);
      expect(r('super_admin').canManageFinancialAccounts, isTrue);
      expect(r('accountant').canManageFinancialAccounts, isTrue);
      expect(r('cashier').canManageFinancialAccounts, isFalse);
      expect(r('manager').canManageFinancialAccounts, isFalse);
      expect(r('inconnu').canManageFinancialAccounts, isFalse);
    });

    test('profil de l entreprise modifiable par un administrateur seulement', () {
      expect(r('admin').isAdmin, isTrue);
      expect(r('super_admin').isAdmin, isTrue);
      expect(r('accountant').isAdmin, isFalse);
      expect(r('staff').isAdmin, isFalse);
    });

    test('demandes de rattachement : administrateur ou propriétaire', () {
      expect(canDecideJoinRequests('admin'), isTrue);
      expect(canDecideJoinRequests('owner'), isTrue);
      expect(canDecideJoinRequests('sme_owner'), isTrue);
      expect(canDecideJoinRequests('cashier'), isFalse);
      expect(canDecideJoinRequests(null), isFalse);
    });
  });
}
