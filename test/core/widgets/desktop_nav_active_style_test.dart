import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/widgets/desktop/desktop_sidebar.dart';

/// Règle : aucun fond coloré derrière l'élément actif de la sidebar ; seuls
/// son icône et son libellé prennent la couleur primaire du thème.
void main() {
  const items = [
    DesktopNavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Tableau de bord',
      route: '/dashboard',
    ),
    DesktopNavItem(
      icon: Icons.groups_outlined,
      label: 'Contacts',
      route: '/contacts',
    ),
  ];

  for (final brightness in Brightness.values) {
    testWidgets('sidebar ${brightness.name} : actif sans fond, en primaire',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final theme = ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF197CA8),
          brightness: brightness,
        ),
      );
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: Row(children: [
            DesktopSidebar(currentIndex: 0, items: items, isExpanded: true),
          ]),
        ),
      ));
      await tester.pumpAndSettle();

      final primary = theme.colorScheme.primary;
      final activeIcon = tester.widget<Icon>(find.byIcon(Icons.dashboard));
      expect(activeIcon.color, primary);
      final activeLabel = tester.widget<Text>(find.text('Tableau de bord'));
      expect(activeLabel.style?.color, primary);
      final inactiveIcon =
          tester.widget<Icon>(find.byIcon(Icons.groups_outlined));
      expect(inactiveIcon.color, isNot(primary));

      // Aucun conteneur coloré (ni bordure) derrière l'élément actif.
      final decorated = find.ancestor(
        of: find.byIcon(Icons.dashboard),
        matching: find.byType(AnimatedContainer),
      );
      for (final c in tester.widgetList<AnimatedContainer>(decorated)) {
        final d = c.decoration;
        if (d is BoxDecoration) {
          expect(d.color == null || d.color!.a == 0, isTrue);
          expect(d.border, isNull);
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
}
