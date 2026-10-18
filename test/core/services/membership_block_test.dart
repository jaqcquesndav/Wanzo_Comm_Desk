// Membre bloqué ou retiré de son entreprise : lecture du refus du serveur
// (toutes les enveloppes) et garde de l'entreprise connue (purge, hors ligne).

import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/features/auth/services/join_request_service.dart'
    show joinRequestErrorMessage;
import 'package:wanzo/core/services/account_block_notifier.dart';
import 'package:wanzo/core/services/company_scope_guard.dart';

const _msg =
    'Votre accès à cette entreprise a été suspendu par son administrateur.';

void main() {
  group('MEMBERSHIP_SUSPENDED, quelle que soit l\'enveloppe', () {
    final enveloppes = <String, dynamic>{
      'à plat': {'code': 'MEMBERSHIP_SUSPENDED', 'message': _msg},
      'Nest {statusCode, code, message}': {
        'statusCode': 403,
        'code': 'MEMBERSHIP_SUSPENDED',
        'message': _msg,
      },
      '{success:false, error:{code}}': {
        'success': false,
        'error': {'code': 'MEMBERSHIP_SUSPENDED', 'message': _msg},
      },
      '{data:{...}}': {
        'data': {'code': 'MEMBERSHIP_SUSPENDED', 'message': _msg},
      },
      'gestion ré-enveloppée': {
        'success': false,
        'data': {
          'success': false,
          'error': {'code': 'MEMBERSHIP_SUSPENDED', 'message': _msg},
        },
      },
      'message objet': {
        'statusCode': 403,
        'message': {'code': 'MEMBERSHIP_SUSPENDED', 'message': _msg},
      },
    };

    enveloppes.forEach((nom, corps) {
      test(nom, () {
        final refus = AccountBlockNotifier.lireRefus(corps);
        expect(refus, isNotNull);
        expect(refus!.kind, AccountBlockKind.membership);
        expect(refus.isMembership, isTrue);
        expect(refus.message, _msg);
        expect(AccountBlockNotifier.codeErreur(corps), 'MEMBERSHIP_SUSPENDED');
      });
    });

    test('sans message : texte par défaut', () {
      final refus = AccountBlockNotifier.lireRefus({
        'code': 'MEMBERSHIP_SUSPENDED',
      });
      expect(refus!.message, _msg);
    });

    test('un simple refus de droits n\'est pas un blocage', () {
      expect(
        AccountBlockNotifier.lireRefus({
          'statusCode': 403,
          'message': 'Forbidden resource',
        }),
        isNull,
      );
      expect(
        AccountBlockNotifier.lireRefus({
          'success': false,
          'error': {'code': 'INSUFFICIENT_ROLE'},
        }),
        isNull,
      );
      expect(AccountBlockNotifier.lireRefus('texte'), isNull);
    });

    test('ACCOUNT_SUSPENDED reste reconnu, enveloppé ou non', () {
      final plat = AccountBlockNotifier.lireRefus({
        'code': 'ACCOUNT_SUSPENDED',
        'message': 'Suspendu',
        'support': {'email': 'aide@wanzo.test'},
      });
      expect(plat!.kind, AccountBlockKind.account);
      expect(plat.supportEmail, 'aide@wanzo.test');

      final enveloppe = AccountBlockNotifier.lireRefus({
        'success': false,
        'error': {'code': 'ACCOUNT_SUSPENDED', 'message': 'Suspendu'},
      });
      expect(enveloppe!.kind, AccountBlockKind.account);
      expect(enveloppe.message, 'Suspendu');
    });

    test('un compte fermé l\'emporte sur un accès suspendu', () {
      final n = AccountBlockNotifier.instance..clear();
      n.signal(const AccountBlockDetail(
        message: _msg,
        kind: AccountBlockKind.membership,
      ));
      n.signal(const AccountBlockDetail(message: 'Compte suspendu'));
      expect(n.value!.kind, AccountBlockKind.account);
      // L'inverse ne remplace rien.
      n.signal(const AccountBlockDetail(
        message: _msg,
        kind: AccountBlockKind.membership,
      ));
      expect(n.value!.kind, AccountBlockKind.account);
      n.clear();
    });
  });

  test('409 ALREADY_MEMBER_ELSEWHERE : texte clair, même enveloppé', () {
    for (final corps in [
      {'statusCode': 409, 'code': 'ALREADY_MEMBER_ELSEWHERE', 'message': 'x'},
      {
        'success': false,
        'error': {'code': 'ALREADY_MEMBER_ELSEWHERE', 'message': 'x'},
      },
    ]) {
      expect(
        joinRequestErrorMessage(
          ServerException('x', statusCode: 409, responseBody: corps),
        ),
        "Ce compte est déjà membre d'une autre entreprise.",
      );
    }
  });

  group('garde de l\'entreprise connue', () {
    late int purges;
    late MemoryCompanyScopeStore store;
    late CompanyScopeGuard guard;

    setUp(() {
      purges = 0;
      store = MemoryCompanyScopeStore();
      guard = CompanyScopeGuard(purge: () async => purges++, store: store);
    });

    test('retrait (entreprise -> aucune) : purge et souvenir persistant', () async {
      await guard.recordServerAnswer(userId: 'u1', companyId: 'c1');
      expect(purges, 0);
      final purge = await guard.recordServerAnswer(
        userId: 'u1',
        companyId: null,
        revokedFromCompanyId: 'c1',
      );
      expect(purge, isTrue);
      expect(purges, 1);

      // Redémarrage : un nouveau garde relit le disque.
      final apres = CompanyScopeGuard(purge: () async => purges++, store: store);
      expect(await apres.lastKnownWithoutCompany('u1'), isTrue);
      expect(await apres.lastKnownWithoutCompany('autre'), isFalse);
      expect((await apres.lastKnown())!.wasRevoked, isTrue);
    });

    test('même entreprise : rien n\'est effacé', () async {
      await guard.recordServerAnswer(userId: 'u1', companyId: 'c1');
      await guard.recordServerAnswer(userId: 'u1', companyId: 'c1');
      expect(purges, 0);
    });

    test('autre entreprise : purge', () async {
      await guard.recordServerAnswer(userId: 'u1', companyId: 'c1');
      await guard.recordServerAnswer(userId: 'u1', companyId: 'c2');
      expect(purges, 1);
    });

    test('purge impossible : rien n\'est noté, elle sera retentée', () async {
      final fragile = CompanyScopeGuard(
        purge: () async => throw StateError('pas prêt'),
        store: MemoryCompanyScopeStore(
          const CompanyScopeSnapshot(userId: 'u1', companyId: 'c1'),
        ),
      );
      final purge = await fragile.recordServerAnswer(userId: 'u1');
      expect(purge, isFalse);
      expect((await fragile.lastKnown())!.companyId, 'c1');
    });
  });
}
