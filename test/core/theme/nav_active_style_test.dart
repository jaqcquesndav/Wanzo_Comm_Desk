import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/utils/theme.dart';

/// Barres de navigation : l'élément actif n'a aucun fond coloré, son icône et
/// son libellé prennent la couleur primaire du thème (clair et sombre).
void main() {
  final themes = {
    'clair': WanzoTheme.lightTheme,
    'sombre': WanzoTheme.darkTheme,
  };

  for (final entry in themes.entries) {
    final theme = entry.value;
    final primary = theme.colorScheme.primary;
    const selected = {WidgetState.selected};
    const idle = <WidgetState>{};

    group('Thème ${entry.key}', () {
      test('NavigationBar : indicateur transparent, actif en primaire', () {
        final nav = theme.navigationBarTheme;
        expect(nav.indicatorColor, Colors.transparent);
        expect(nav.iconTheme!.resolve(selected)!.color, primary);
        expect(nav.labelTextStyle!.resolve(selected)!.color, primary);
        expect(nav.iconTheme!.resolve(idle)!.color, isNot(primary));
      });

      test('NavigationRail et BottomNavigationBar : actif en primaire', () {
        expect(theme.navigationRailTheme.indicatorColor, Colors.transparent);
        expect(theme.navigationRailTheme.selectedIconTheme!.color, primary);
        expect(theme.bottomNavigationBarTheme.selectedItemColor, primary);
        expect(theme.navigationDrawerTheme.indicatorColor, Colors.transparent);
      });

      testWidgets('rendu : icône active primaire, sans pastille', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              bottomNavigationBar: NavigationBar(
                selectedIndex: 2,
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home), label: 'A'),
                  NavigationDestination(icon: Icon(Icons.history), label: 'B'),
                  NavigationDestination(
                    icon: Icon(Icons.credit_card),
                    label: 'C',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final activeIcon = IconTheme.of(
          tester.element(find.byIcon(Icons.credit_card)),
        );
        expect(activeIcon.color, primary);
        final idleIcon = IconTheme.of(tester.element(find.byIcon(Icons.home)));
        expect(idleIcon.color, isNot(primary));
        final indicator = tester.widget<NavigationIndicator>(
          find.byType(NavigationIndicator).at(2),
        );
        expect(indicator.color, Colors.transparent);
      });
    });
  }
}
