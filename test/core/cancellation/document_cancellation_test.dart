import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/cancellation/cancel_reason_form.dart';
import 'package:wanzo/core/cancellation/document_cancellation.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/features/sales/models/sale.dart';

void main() {
  group('motif obligatoire', () {
    test('vide ou trop court : refusé ; 3 caractères : accepté', () {
      expect(validateCancelReason(null), isNotNull);
      expect(validateCancelReason('   '), isNotNull);
      expect(validateCancelReason('ab'), isNotNull);
      expect(validateCancelReason('abc'), isNull);
    });

    test('choix rapide seul, complété, ou « Autre » qui exige le texte', () {
      expect(composeCancelReason('Doublon', ''), 'Doublon');
      expect(
        composeCancelReason('Erreur de saisie', 'prix faux'),
        'Erreur de saisie : prix faux',
      );
      expect(composeCancelReason('Autre', ''), '');
      expect(composeCancelReason('Autre', 'client parti'), 'client parti');
      expect(composeCancelReason(null, 'texte libre'), 'texte libre');
    });

    test('textes sans tiret long ni esperluette', () {
      for (final t in [
        cancelExplanation(CancellableDocument.sale),
        cancelExplanation(CancellableDocument.expense),
        ...kSaleCancelPresets,
        ...kExpenseCancelPresets,
      ]) {
        expect(t.contains('—'), isFalse, reason: t);
        expect(t.contains('&'), isFalse, reason: t);
      }
    });
  });

  group('rôles', () {
    test('annuler : admin, propriétaire, gérant, comptable', () {
      for (final r in ['admin', 'owner', 'super_admin', 'manager', 'accountant']) {
        expect(canCancelDocument(r), isTrue, reason: r);
      }
      for (final r in ['cashier', 'sales', 'staff', null, '']) {
        expect(canCancelDocument(r), isFalse, reason: '$r');
      }
    });

    test('rétablir : admin et comptable seulement', () {
      expect(canRestoreDocument('admin'), isTrue);
      expect(canRestoreDocument('ACCOUNTANT'), isTrue);
      expect(canRestoreDocument('manager'), isFalse);
      expect(canRestoreDocument('cashier'), isFalse);
    });
  });

  group('réponse du serveur', () {
    test('cancelledBy objet ou texte, motif et date lus', () {
      final info = CancellationInfo.fromJson({
        'cancelledAt': '2026-10-27T08:30:00.000Z',
        'cancelledBy': {'id': 'u1', 'email': 'marie@x.cd', 'name': 'Marie'},
        'cancelReason': 'Doublon',
      });
      expect(info.byId, 'u1');
      expect(info.byName, 'Marie');
      expect(info.reason, 'Doublon');
      expect(info.at, isNotNull);
      expect(cancellationBanner(info), startsWith('Annulée le '));
      expect(cancellationBanner(info), endsWith('par Marie : Doublon'));

      final byEmail = CancellationInfo.fromJson({
        'cancelledBy': {'id': 'u2', 'email': 'jo@x.cd'},
      });
      expect(byEmail.byName, 'jo@x.cd');
    });

    test('Sale.fromJson : statut annulé, trace et doublon possible', () {
      final sale = Sale.fromJson({
        'id': 's1',
        'date': '2026-10-27T08:00:00.000Z',
        'customerName': 'Client',
        'items': [],
        'totalAmountInCdf': '5000.00',
        'paidAmountInCdf': 5000,
        'status': 'cancelled',
        'cancelledAt': '2026-10-27T09:00:00.000Z',
        'cancelledBy': {'id': 'u1', 'name': 'Marie'},
        'cancelReason': 'Erreur de saisie',
        'possibleDuplicateOf': 's0',
      });
      expect(sale.isCancelled, isTrue);
      expect(sale.cancelledByName, 'Marie');
      expect(sale.cancelReason, 'Erreur de saisie');
      expect(sale.possibleDuplicateOf, 's0');
      final restored = sale.copyWith(
        status: SaleStatus.completed,
        clearCancellation: true,
      );
      expect(restored.isCancelled, isFalse);
      expect(restored.cancelReason, isNull);
      expect(restored.cancelledAt, isNull);
    });

    test('Expense.fromJson : statut annulé, total qui l\'écarte', () {
      Map<String, dynamic> json(String id, {bool cancelled = false}) => {
        'id': id,
        'date': '2026-10-27T08:00:00.000Z',
        'motif': 'Transport',
        'amount': 1000,
        'category': 'transport',
        if (cancelled) 'status': 'cancelled',
        if (cancelled) 'cancelReason': 'Doublon',
      };
      final active = Expense.fromJson(json('e1'));
      final cancelled = Expense.fromJson(json('e2', cancelled: true));
      expect(active.isCancelled, isFalse);
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.cancelReason, 'Doublon');
      final active2 = [active, cancelled].where((e) => !e.isCancelled);
      expect(active2.fold<double>(0, (t, e) => t + e.amount), 1000);
    });

    test('doublon possible lu à la racine ou dans data', () {
      expect(possibleDuplicateIn({'possibleDuplicateOf': 'a'}), 'a');
      expect(
        possibleDuplicateIn({
          'data': {'possibleDuplicateOf': 'b'},
        }),
        'b',
      );
      expect(possibleDuplicateIn({'data': {}}), isNull);
    });

    test('refus du serveur et route absente', () {
      expect(isServerRefusal(AuthorizationException('Interdit')), isTrue);
      expect(isServerRefusal(BadRequestException('Motif')), isTrue);
      expect(isServerRefusal(NetworkException('coupure')), isFalse);
      expect(isServerRefusal(ServerException('panne', statusCode: 503)), isFalse);
      expect(isServerRefusal(AuthenticationException('jeton')), isFalse);
      expect(
        isMissingRoute(NotFoundException('Cannot POST /sales/x/cancel')),
        isTrue,
      );
      expect(isMissingRoute(NotFoundException('Vente non trouvée')), isFalse);
    });
  });

  group('formulaire du motif', () {
    Future<List<String>> pump(WidgetTester tester) async {
      final confirmed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CancelReasonForm(
                doc: CancellableDocument.sale,
                presets: kSaleCancelPresets,
                confirmLabel: 'Annuler la vente',
                explanation: cancelExplanation(CancellableDocument.sale),
                onConfirm: confirmed.add,
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      return confirmed;
    }

    FilledButton confirmButton(WidgetTester tester) => tester.widget<FilledButton>(
      find.byKey(const ValueKey('cancel-reason-confirm')),
    );

    testWidgets('bouton grisé sans motif, actif après un choix rapide', (
      tester,
    ) async {
      final confirmed = await pump(tester);
      expect(confirmButton(tester).onPressed, isNull);
      expect(find.textContaining('pourra être rétablie'), findsOneWidget);

      await tester.tap(find.text('Doublon'));
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('cancel-reason-confirm')));
      await tester.pump();
      expect(confirmed, ['Doublon']);
    });

    testWidgets('« Autre » exige un texte d\'au moins 3 caractères', (
      tester,
    ) async {
      final confirmed = await pump(tester);
      await tester.tap(find.text('Autre'));
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('cancel-reason-details')),
        'ok',
      );
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('cancel-reason-details')),
        'Client parti sans payer',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cancel-reason-confirm')));
      await tester.pump();
      expect(confirmed, ['Client parti sans payer']);
    });
  });
}
