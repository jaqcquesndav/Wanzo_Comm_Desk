import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/auth/read_only.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/features/auth/services/auth_backend_service.dart';
import 'package:wanzo/core/widgets/desktop/row_actions_menu.dart';
import 'package:wanzo/core/shared_widgets/responsive_action_bar.dart';
import 'package:wanzo/core/shared_widgets/app_bar_actions.dart';

/// Lecteur : aucune action d'écriture visible ; administrateur : tout visible
/// (règle unique core/auth/read_only.dart).
AuthMeResponse authMe(String role) => AuthMeResponse.fromJson({
      'user': {
        'id': 'u1',
        'email': 'membre@ympacta.cd',
        'role': role,
        'companyId': '655fec17-1111-4222-8333-944444444444',
      },
      'company': {'id': '655fec17-1111-4222-8333-944444444444', 'name': 'Ympacta'},
    });

Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  final ctx = BusinessContextService();

  setUp(() async {
    await ctx.clear();
    ReadOnlyAccess.debugOverride = null;
  });

  group('règle du lecteur', () {
    test("le rôle lecteur du serveur rend l'app en lecture seule", () async {
      await ctx.updateFromAuthMeResponse(authMe('viewer'));
      expect(ReadOnlyAccess.isReadOnly, isTrue);
      await ctx.updateFromAuthMeResponse(authMe('audit'));
      expect(ReadOnlyAccess.isReadOnly, isTrue);
      await ctx.updateFromAuthMeResponse(authMe('admin'));
      expect(ReadOnlyAccess.isReadOnly, isFalse);
    });

    test('libellés : écriture ou lecture', () {
      for (final l in ['Modifier', 'Annuler la vente', 'Supprimer', 'Nouvelle vente', 'Nouvelle dépense', 'Rétablir']) {
        expect(ReadOnlyAccess.isWriteLabel(l), isTrue, reason: l);
      }
      for (final l in ['Voir la fiche', 'Imprimer le PDF', 'Exporter', 'Historique', 'Rapport du jour']) {
        expect(ReadOnlyAccess.isWriteLabel(l), isFalse, reason: l);
      }
    });

    test('formulaires : le lecteur revient au tableau de bord', () {
      ReadOnlyAccess.debugOverride = () => true;
      expect(ReadOnlyAccess.redirectFor('/operations/sales/add'), '/dashboard');
      expect(ReadOnlyAccess.redirectFor('/inventory/edit/p1'), '/dashboard');
      expect(ReadOnlyAccess.redirectFor('/operations'), isNull);
      ReadOnlyAccess.debugOverride = () => false;
      expect(ReadOnlyAccess.redirectFor('/operations/sales/add'), isNull);
    });

    test('refus du serveur : message clair', () {
      expect(ReadOnlyAccess.isReadOnlyRefusal({'code': 'READ_ONLY_ROLE', 'message': 'x'}), isTrue);
      expect(ReadOnlyAccess.isReadOnlyRefusal({'error': {'code': 'READ_ONLY_ROLE'}}), isTrue);
      expect(ReadOnlyAccess.isReadOnlyRefusal({'code': 'CASH_ACCESS_DENIED'}), isFalse);
      expect(readOnlyRoleMessage, 'Votre rôle permet la consultation seulement');
    });
  });

  for (final readOnly in [true, false]) {
    group(readOnly ? 'lecteur' : 'administrateur', () {
      setUp(() => ReadOnlyAccess.debugOverride = () => readOnly);

      testWidgets('menu 3 points', (tester) async {
        await tester.pumpWidget(host(RowActionsMenu(actions: [
          RowAction(label: 'Voir la fiche', icon: Icons.visibility, onSelected: () {}),
          RowAction(label: 'Imprimer le PDF', icon: Icons.print, onSelected: () {}),
          RowAction(label: 'Modifier', icon: Icons.edit, onSelected: () {}),
          RowAction(label: 'Annuler la vente', icon: Icons.block, onSelected: () {}),
          RowAction(label: 'Supprimer', icon: Icons.delete, onSelected: () {}, destructive: true),
        ])));
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('Voir la fiche'), findsOneWidget);
        expect(find.text('Imprimer le PDF'), findsOneWidget);
        for (final l in ['Modifier', 'Annuler la vente', 'Supprimer']) {
          expect(find.text(l), readOnly ? findsNothing : findsOneWidget, reason: l);
        }
      });

      testWidgets("barre d'actions d'une fiche", (tester) async {
        await tester.pumpWidget(host(SizedBox(
          width: 800,
          child: ResponsiveActionBar(items: [
            ActionBarItem(icon: Icons.print, label: 'Imprimer', onPressed: () {}),
            ActionBarItem(icon: Icons.edit, label: 'Modifier', onPressed: () {}),
            ActionBarItem(icon: Icons.point_of_sale, label: 'Encaisser', onPressed: () {}),
          ]),
        )));
        expect(find.text('Imprimer'), findsOneWidget);
        expect(find.text('Modifier'), readOnly ? findsNothing : findsOneWidget);
        expect(find.text('Encaisser'), readOnly ? findsNothing : findsOneWidget);
      });

      test("boutons d'en-tête", () {
        final split = splitPageActions([
          IconButton(tooltip: 'Nouvelle vente', icon: const Icon(Icons.add), onPressed: () {}),
          IconButton(tooltip: 'Exporter', icon: const Icon(Icons.download), onPressed: () {}),
        ], maxVisible: 5);
        final labels = split.visible
            .map((w) => (w is IconButton ? w.tooltip : null) ?? '')
            .toList();
        expect(labels.contains('Exporter'), isTrue);
        expect(labels.contains('Nouvelle vente'), readOnly ? isFalse : isTrue);
      });

      testWidgets('WriteGate', (tester) async {
        await tester.pumpWidget(host(const WriteGate(child: Text('Vendre'))));
        expect(find.text('Vendre'), readOnly ? findsNothing : findsOneWidget);
      });
    });
  }
}
