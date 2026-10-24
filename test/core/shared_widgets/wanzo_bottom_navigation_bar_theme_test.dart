import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/shared_widgets/wanzo_bottom_navigation_bar.dart';

/// Les couleurs de la barre de navigation suivent le thème (mode sombre
/// compris) au lieu d'être codées en dur.
void main() {
  final items = [
    BottomNavItem(icon: Icons.home, label: 'Accueil', route: '/'),
    BottomNavItem(icon: Icons.settings, label: 'Réglages', route: '/r'),
  ];

  Future<BottomNavigationBar> pumpBar(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
        bottomNavigationBar: WanzoBottomNavigationBar(
          currentIndex: 0,
          items: items,
          onTap: (_) {},
        ),
      ),
    ));
    return tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
  }

  testWidgets('mode clair : couleurs du colorScheme', (tester) async {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    );
    final bar = await pumpBar(tester, theme);
    expect(bar.selectedItemColor, theme.colorScheme.primary);
    expect(bar.unselectedItemColor, theme.colorScheme.onSurfaceVariant);
  });

  testWidgets('mode sombre : le bleu clair du thème sombre', (tester) async {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
    );
    final bar = await pumpBar(tester, theme);
    expect(bar.selectedItemColor, theme.colorScheme.primary);
    expect(bar.unselectedItemColor, theme.colorScheme.onSurfaceVariant);
  });
}
