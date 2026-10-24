import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/core/modules/activity_mode.dart';
import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/quick_actions/desktop_quick_actions.dart';
import 'package:wanzo/core/widgets/desktop/operations_dock.dart';

/// Écrans principaux d'un mode : la sidebar, plus les écrans de travail.
Set<String> _mainRoutes(ActivityMode mode) => {
      for (final m in ModuleRegistry.sidebar(mode, 'admin')) m.route,
      '/operations',
    };

Set<String> _labels(ActivityMode mode) =>
    {for (final a in DesktopQuickActionsCatalog.forMode(mode)) a.label};

Future<void> _pumpHost(
  WidgetTester tester, {
  required List<DesktopQuickAction> actions,
  double width = 1400,
  int rows = 0,
  bool fab = false,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  OperationsDock.expanded.value = true;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        floatingActionButton: fab
            ? FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add))
            : null,
        body: OperationsDockHost(
          actions: actions,
          hasFloatingActionButton: fab,
          child: ListView(
            children: [
              for (var i = 0; i < rows; i++)
                ListTile(title: Text('Ligne $i')),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Dock par mode', () {
    for (final mode in ActivityMode.values) {
      test('${mode.name} : dock sur chaque écran principal, actions du mode',
          () {
        final own = _labels(mode);
        final foreign = {
          for (final other in ActivityMode.values)
            if (other != mode) ..._labels(other),
        }.difference(own);
        for (final path in _mainRoutes(mode)) {
          final actions = DesktopQuickActionsCatalog.forScreen(
            mode: mode,
            role: 'admin',
            path: path,
          );
          expect(actions, isNotEmpty, reason: '$path doit porter le dock');
          expect(
            actions.length,
            lessThanOrEqualTo(DesktopQuickActionsCatalog.maxActions),
          );
          for (final a in actions) {
            expect(own, contains(a.label));
            expect(foreign, isNot(contains(a.label)),
                reason: '${a.label} vient d\'un autre mode');
            expect(a.label, isNot(contains('—')));
            expect(a.label, isNot(contains('&')));
          }
        }
      });

      testWidgets('${mode.name} : dock flottant au tableau de bord',
          (tester) async {
        final actions = DesktopQuickActionsCatalog.forScreen(
          mode: mode,
          role: 'admin',
          path: '/dashboard',
        );
        await _pumpHost(tester, actions: actions);
        expect(find.byKey(const ValueKey('operations-dock')), findsOneWidget);
        for (final a in actions) {
          expect(find.byKey(ValueKey('dock-action-${a.id}')), findsOneWidget);
          expect(find.byTooltip(a.label), findsOneWidget);
        }
        expect(find.byKey(const ValueKey('operations-dock-more')),
            findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    test('fiches et formulaires : pas de dock', () {
      for (final path in [
        '/inventory/add',
        '/sale-detail/42',
        '/customers',
        '/inventory/product/7',
      ]) {
        expect(
          DesktopQuickActionsCatalog.forScreen(
            mode: ActivityMode.retail,
            role: 'admin',
            path: path,
          ),
          isEmpty,
          reason: path,
        );
      }
    });

    test('vocabulaire du mode', () {
      expect(_labels(ActivityMode.retail), contains('Nouvelle vente'));
      expect(_labels(ActivityMode.restaurant),
          containsAll(['Nouvelle commande', 'Encaisser', 'Carte']));
      expect(_labels(ActivityMode.salon),
          containsAll(['Nouveau ticket', 'Nouvelle prestation']));
      expect(_labels(ActivityMode.atelier), contains('Nouvel intrant'));
      expect(_labels(ActivityMode.atelierMaintenance),
          containsAll(['Nouvelle intervention', 'Nouvelle pièce']));
      expect(_labels(ActivityMode.imprimerie), contains('Nouveau travail'));
      expect(_labels(ActivityMode.pressing), contains('Nouveau dépôt'));
      expect(_labels(ActivityMode.services), contains('Nouvelle prestation'));
      expect(_labels(ActivityMode.salon), isNot(contains('Nouvelle vente')));
      expect(_labels(ActivityMode.garage), isNot(contains('Nouveau produit')));
    });

    test('pas de doublon avec le bouton propre de l\'écran', () {
      String ids(ActivityMode mode, String path) => DesktopQuickActionsCatalog
          .forScreen(mode: mode, role: 'admin', path: path)
          .map((a) => a.id)
          .join(',');
      expect(ids(ActivityMode.retail, '/sales'), isNot(contains('sale')));
      expect(ids(ActivityMode.retail, '/expenses'), isNot(contains('expense')));
      expect(ids(ActivityMode.retail, '/inventory'), isNot(contains('item')));
      expect(ids(ActivityMode.salon, '/salon/prestations'),
          isNot(contains('salon_service')));
    });

    test('mode Général : mêmes actions et couleurs que le dock d\'origine', () {
      final actions = DesktopQuickActionsCatalog.forScreen(
        mode: ActivityMode.retail,
        role: 'admin',
        path: '/dashboard',
      );
      expect(actions.map((a) => a.id).take(5),
          ['sale', 'item', 'expense', 'customer', 'supplier']);
      expect(actions.map((a) => a.color).take(5), [
        Colors.green,
        Colors.orange,
        Colors.redAccent,
        Colors.blueAccent,
        Colors.purpleAccent,
      ]);
    });
  });

  group('Dock flottant', () {
    final actions = DesktopQuickActionsCatalog.forScreen(
      mode: ActivityMode.retail,
      role: 'admin',
      path: '/dashboard',
    );

    for (final expanded in [true, false]) {
      testWidgets(
          'la dernière ligne reste visible au-dessus du dock '
          '(${expanded ? 'déplié' : 'replié'})', (tester) async {
        await _pumpHost(tester, actions: actions, rows: 60);
        if (!expanded) {
          await tester.tap(find.byKey(const ValueKey('operations-dock-collapse')));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('operations-dock-expand')),
              findsOneWidget);
        }
        await tester.scrollUntilVisible(find.text('Ligne 59'), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        final last = tester.getRect(find.text('Ligne 59'));
        final dock = tester.getRect(find.byKey(const ValueKey('operations-dock')));
        expect(last.bottom, lessThanOrEqualTo(dock.top));
        // Le contenu s'arrête au-dessus du dock.
        final content =
            tester.getRect(find.byKey(const ValueKey('operations-dock-content')));
        expect(content.bottom, lessThanOrEqualTo(dock.top));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('replier puis déplier', (tester) async {
      await _pumpHost(tester, actions: actions);
      await tester.tap(find.byKey(const ValueKey('operations-dock-collapse')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dock-action-sale')).hitTestable(),
          findsNothing);
      await tester.tap(find.byKey(const ValueKey('operations-dock-expand')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dock-action-sale')).hitTestable(),
          findsOneWidget);
    });

    for (final width in [320.0, 420.0, 560.0]) {
      testWidgets('fenêtre étroite ($width) : menu « Plus », sans débordement',
          (tester) async {
        await _pumpHost(tester, actions: actions, width: width, fab: true);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('operations-dock-more')),
            findsOneWidget);
        final dock = tester.getRect(find.byKey(const ValueKey('operations-dock')));
        expect(dock.left, greaterThanOrEqualTo(0));
        expect(dock.right, lessThanOrEqualTo(width));
        await tester.tap(find.byKey(const ValueKey('operations-dock-more')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('dock-menu-supplier')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('atelier : l\'action ouvre le board avec l\'intention',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      OperationsDock.expanded.value = true;
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => Scaffold(
              body: OperationsDockHost(
                actions: DesktopQuickActionsCatalog.forScreen(
                  mode: ActivityMode.garage,
                  role: 'admin',
                  path: '/dashboard',
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          GoRoute(
            path: '/atelier/board',
            builder: (_, __) => const Text('board'),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dock-action-atelier_new_work')));
      await tester.pumpAndSettle();
      expect(find.text('board'), findsOneWidget);
      expect(QuickActionIntents.take(QuickActionIntents.atelierNewWork), isTrue);
      expect(QuickActionIntents.take(QuickActionIntents.atelierNewWork), isFalse);
    });
  });
}
