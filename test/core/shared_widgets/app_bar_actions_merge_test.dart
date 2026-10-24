import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/shared_widgets/app_bar_actions.dart';

/// Un menu de page typé (PopupMenuButton<String>) fusionné dans le menu
/// 3 points de l'en-tête exécute bien l'entrée choisie.
void main() {
  testWidgets('menu de page typé fusionné : le choix est exécuté',
      (tester) async {
    String? chosen;
    var exported = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: foldPageActions([
            IconButton(tooltip: 'Rechercher', icon: const Icon(Icons.search), onPressed: () {}),
            IconButton(tooltip: 'Filtrer', icon: const Icon(Icons.filter_list), onPressed: () {}),
            IconButton(tooltip: 'Exporter', icon: const Icon(Icons.download), onPressed: () => exported = true),
            PopupMenuButton<String>(
              onSelected: (v) => chosen = v,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'import', child: Text('Importer')),
              ],
            ),
          ]),
        ),
      ),
    ));
    expect(find.byKey(HeaderRules.overflowKey), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);

    await tester.tap(find.byKey(HeaderRules.overflowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importer'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(chosen, 'import');

    await tester.tap(find.byKey(HeaderRules.overflowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exporter'));
    await tester.pumpAndSettle();
    expect(exported, isTrue);
  });
}
