import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/enums/user_role.dart';

/// La traduction des rôles de l'app est celle du serveur : chaque rôle de la
/// matrice (test/fixtures/role_access_matrix.json, copie de Wanzo_Backend
/// packages/shared/src/auth/role-access-matrix.snapshot.json) donne le rôle
/// de sa colonne commerce, super_admin excepté (superAdmin ici).
void main() {
  final matrix = jsonDecode(
    File('test/fixtures/role_access_matrix.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('fromApiValue reproduit la matrice du serveur', () {
    for (final entry in matrix.entries) {
      final expected = entry.key == 'super_admin'
          ? 'super_admin'
          : (entry.value as Map<String, dynamic>)['commerce'] as String;
      expect(
        UserRoleExtension.fromApiValue(entry.key).apiValue,
        expected,
        reason: entry.key,
      );
    }
  });

  test('un rôle inconnu est lecteur, jamais employé ; un rôle absent est employé', () {
    expect(UserRoleExtension.fromApiValue('role_inconnu'), UserRole.viewer);
    expect(UserRoleExtension.fromApiValue('Super Admin'), UserRole.superAdmin);
    expect(UserRoleExtension.fromApiValue(''), UserRole.staff);
    expect(UserRole.viewer.isReadOnly, isTrue);
    expect(UserRole.viewer.canAccessCashSession, isFalse);
  });

  test('les rôles en lecture seule du serveur sont lecteurs dans l\'app', () {
    for (final entry in matrix.entries) {
      final row = entry.value as Map<String, dynamic>;
      if (row['readOnly'] == true) {
        expect(UserRoleExtension.fromApiValue(entry.key).isReadOnly, isTrue, reason: entry.key);
      }
    }
  });
}
