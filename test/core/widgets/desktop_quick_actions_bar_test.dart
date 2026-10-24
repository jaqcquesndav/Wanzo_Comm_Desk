import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/core/modules/activity_mode.dart';
import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/quick_actions/desktop_quick_actions.dart';
import 'package:wanzo/core/widgets/desktop/desktop_quick_actions_bar.dart';

/// Écrans principaux d'un mode : la sidebar, plus les écrans de travail.
Set<String> _mainRoutes(ActivityMode mode) => {
      for (final m in ModuleRegistry.sidebar(mode, 'admin')) m.route,
      '/operations',
    };

Set<String> _labels(ActivityMode mode) =>
    {for (final a in DesktopQuickActionsCatalog.forMode(mode)) a.label};

Future<void> _pumpBar(
  WidgetTester tester, {
  required ActivityMode mode,
  required String path,
  double width = 1920,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final bar = DesktopQuickActionsBar.forRoute(
    mode: mode,
    role: 'admin',
    path: path,
  );
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Column(children: [if (bar != null) bar]))),
  );
}

void main() {
  group('Configuration par mode', () {
    for (final mode in ActivityMode.values) {
      test('${mode.name} : barre sur chaque écran principal, actions du mode',
          () {
        final own = _labels(mode);
        final foreign = {
          for (final other in ActivityMode.values)
            if (other != mode) ..._labels(other),
        }.difference(own);
        for (final path in _mainRoutes(mode)) {
          expect(
            DesktopQuickActionsCatalog.isMainRoute(path, mode, 'admin'),
            isTrue,
            reason: '$path doit porter la barre en ${mode.name}',
          );
          final resolved = DesktopQuickActionsCatalog.resolve(
            mode: mode,
            role: 'admin',
            path: path,
          );
          expect(resolved.actions, isNotEmpty, reason: path);
          expect(
            resolved.actions.length,
            lessThanOrEqualTo(DesktopQuickActionsCatalog.maxActions),
          );
          expect(resolved.actions.first.id, resolved.primaryId);
          for (final a in resolved.actions) {
            expect(own, contains(a.label));
            expect(foreign, isNot(contains(a.label)),
                reason: '${a.label} vient d\'un autre mode');
            expect(a.label, isNot(contains('—')));
            expect(a.label, isNot(contains('&')));
          }
        }
      });
    }

    test('les fiches et formulaires n\'ont pas la barre', () {
      for (final path in ['/inventory/add', '/sale-detail/42', '/customers']) {
        expect(
          DesktopQuickActionsCatalog.isMainRoute(
              path, ActivityMode.retail, 'admin'),
          isFalse,
        );
      }
    });

    test('vocabulaire du mode', () {
      expect(_labels(ActivityMode.retail), contains('Nouvelle vente'));
      expect(_labels(ActivityMode.restaurant),
          containsAll(['Nouvelle commande', 'Encaisser', 'Carte']));
      expect(_labels(ActivityMode.salon),
          containsAll(['Nouveau ticket', 'Nouvelle prestation']));
      expect(_labels(ActivityMode.atelier), contains('Nouvelle commande'));
      expect(_labels(ActivityMode.atelier), contains('Nouvel intrant'));
      expect(_labels(ActivityMode.atelierMaintenance),
          containsAll(['Nouvelle intervention', 'Nouvelle pièce']));
      expect(_labels(ActivityMode.garage), contains('Nouvelle intervention'));
      expect(_labels(ActivityMode.imprimerie), contains('Nouveau travail'));
      expect(_labels(ActivityMode.pressing), contains('Nouveau dépôt'));
      expect(_labels(ActivityMode.services), contains('Nouvelle prestation'));
      // Pas de vente boutique en salon, pas de mesures en garage, etc.
      expect(_labels(ActivityMode.salon), isNot(contains('Nouvelle vente')));
      expect(_labels(ActivityMode.garage), isNot(contains('Nouveau produit')));
    });

    test('pas de doublon avec le bouton propre de l\'écran', () {
      String? ids(ActivityMode mode, String path) => DesktopQuickActionsCatalog
          .resolve(mode: mode, role: 'admin', path: path)
          .actions
          .map((a) => a.id)
          .join(',');
      expect(ids(ActivityMode.retail, '/sales'), isNot(contains('sale')));
      expect(ids(ActivityMode.retail, '/expenses'), isNot(contains('expense')));
      expect(ids(ActivityMode.retail, '/inventory'), isNot(contains('item')));
      expect(ids(ActivityMode.retail, '/contacts'),
          allOf(isNot(contains('customer')), isNot(contains('supplier'))));
      expect(ids(ActivityMode.restaurant, '/restaurant/board'),
          allOf(isNot(contains('restaurant_new_order')),
              isNot(contains('restaurant_checkout'))));
      expect(ids(ActivityMode.garage, '/atelier/board'),
          isNot(contains('atelier_new_work')));
      expect(ids(ActivityMode.salon, '/salon/prestations'),
          isNot(contains('salon_service')));
    });

    test('action principale selon l\'écran', () {
      expect(
        DesktopQuickActionsCatalog.resolve(
          mode: ActivityMode.restaurant,
          role: 'admin',
          path: '/restaurant/kitchen',
        ).primaryId,
        'restaurant_checkout',
      );
      expect(
        DesktopQuickActionsCatalog.resolve(
          mode: ActivityMode.retail,
          role: 'admin',
          path: '/expenses',
        ).primaryId,
        'sale',
      );
    });
  });

  group('Barre', () {
    for (final mode in ActivityMode.values) {
      testWidgets('${mode.name} : présente au tableau de bord, actions du mode',
          (tester) async {
        await _pumpBar(tester, mode: mode, path: '/dashboard');
        expect(find.byKey(const ValueKey('desktop-quick-actions-bar')),
            findsOneWidget);
        final resolved = DesktopQuickActionsCatalog.resolve(
          mode: mode,
          role: 'admin',
          path: '/dashboard',
        );
        for (final a in resolved.actions) {
          expect(find.text(a.label), findsOneWidget);
        }
        expect(find.text('Plus'), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
        // Action mise en avant : couleur primaire, sans fond coloré.
        expect(find.byWidgetPredicate((w) => w is FilledButton), findsNothing);
        final primaryColor =
            Theme.of(tester.element(find.byType(DesktopQuickActionsBar)))
                .colorScheme
                .primary;
        final primaryIcon = tester.widget<Icon>(find.descendant(
          of: find.byKey(ValueKey('quick-action-${resolved.primaryId}')),
          matching: find.byType(Icon),
        ));
        expect(primaryIcon.color, primaryColor);
      });
    }

    testWidgets('fenêtre étroite : débordement dans « Plus »', (tester) async {
      await _pumpBar(
        tester,
        mode: ActivityMode.retail,
        path: '/dashboard',
        width: 420,
      );
      expect(find.text('Plus'), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-action-sale')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-action-supplier')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('quick-actions-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('quick-action-menu-supplier')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pas de barre hors écran principal', (tester) async {
      await _pumpBar(tester, mode: ActivityMode.retail, path: '/inventory/add');
      expect(find.byKey(const ValueKey('desktop-quick-actions-bar')),
          findsNothing);
    });

    testWidgets('atelier : l\'action ouvre le board avec l\'intention',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => Scaffold(
              body: Column(children: [
                DesktopQuickActionsBar.forRoute(
                  mode: ActivityMode.garage,
                  role: 'admin',
                  path: '/dashboard',
                )!,
              ]),
            ),
          ),
          GoRoute(
            path: '/atelier/board',
            builder: (_, __) => const Text('board'),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Nouvelle intervention'));
      await tester.pumpAndSettle();
      expect(find.text('board'), findsOneWidget);
      expect(QuickActionIntents.take(QuickActionIntents.atelierNewWork), isTrue);
      expect(QuickActionIntents.take(QuickActionIntents.atelierNewWork), isFalse);
    });
  });
}
