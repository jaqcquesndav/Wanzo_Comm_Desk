import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/constants/colors.dart';
import 'package:wanzo/core/widgets/desktop/desktop_sidebar.dart';

/// Sidebar desktop : fond bleu, texte blanc. L'élément actif n'a ni fond, ni
/// bordure, ni pastille : son icône et son libellé sont en blanc plein et en
/// gras, les autres en blanc atténué.
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
    testWidgets('sidebar ${brightness.name} : actif blanc, gras, sans fond',
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

      // Fond bleu en clair (bleu nuit en sombre), comme à l'origine.
      final sidebarBox = tester
          .widgetList<Container>(find.descendant(
            of: find.byType(DesktopSidebar),
            matching: find.byType(Container),
          ))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .first;
      expect(
        sidebarBox.color,
        brightness == Brightness.light
            ? WanzoColors.primary
            : const Color(0xFF111827),
      );

      final activeIcon = tester.widget<Icon>(find.byIcon(Icons.dashboard));
      expect(activeIcon.color, Colors.white);
      final activeLabel = tester.widget<Text>(find.text('Tableau de bord'));
      expect(activeLabel.style?.color, Colors.white);
      expect(activeLabel.style?.fontWeight, FontWeight.w700);
      final inactiveIcon =
          tester.widget<Icon>(find.byIcon(Icons.groups_outlined));
      expect(inactiveIcon.color, Colors.white.withValues(alpha: 0.7));
      final inactiveLabel = tester.widget<Text>(find.text('Contacts'));
      expect(inactiveLabel.style?.fontWeight, isNot(FontWeight.w700));

      // Aucun conteneur coloré, bordure ni pastille derrière l'élément actif.
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
      final dots = find.descendant(
        of: find.byType(DesktopSidebar),
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle),
      );
      expect(dots, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
