import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/shared_widgets/searchable_select.dart';
import 'package:wanzo/core/utils/adaptive_pull_up.dart';
import 'package:wanzo/features/auth/widgets/join_code_form.dart';

/// App desktop : plus de feuille du bas. Ce qui ouvrait un pull-up ouvre une
/// modale centrée (Dialog) : titre, bouton Fermer visible, Échap pour fermer,
/// largeur bornée et jamais de Scaffold dedans.
void main() {
  Future<void> open(
    WidgetTester tester,
    Size size,
    void Function(BuildContext) action,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => action(context),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  void expectModal(WidgetTester tester, String title, {double maxWidth = 560}) {
    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Dialog), matching: find.byType(Scaffold)),
      findsNothing,
    );
    expect(find.text(title), findsOneWidget);
    expect(find.byKey(const ValueKey('modal-close')), findsOneWidget);
    final dialogWidth = tester
        .getSize(find.descendant(
            of: find.byType(Dialog), matching: find.byType(Material)).first)
        .width;
    expect(dialogWidth, lessThanOrEqualTo(maxWidth));
  }

  for (final size in [const Size(1280, 800), const Size(500, 700)]) {
    testWidgets('aide « Rejoindre » en modale (${size.width.toInt()} px)',
        (tester) async {
      await open(tester, size, showJoinHelpSheet);
      expectModal(tester, 'Rejoindre une entreprise');

      // Échap ferme la modale.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });
  }

  testWidgets('sélection recherchable en modale, fermer par le bouton',
      (tester) async {
    await open(
      tester,
      const Size(1280, 800),
      (context) => showSearchableSelect<String>(
        context,
        title: 'Choisir un client',
        items: const ['Alpha', 'Bravo', 'Charlie'],
        itemLabel: (s) => s,
      ),
    );
    expectModal(tester, 'Choisir un client');
    expect(find.text('Bravo'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('modal-close')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('pull-up adaptatif : modale même en fenêtre étroite',
      (tester) async {
    await open(
      tester,
      const Size(480, 700),
      (context) => showAdaptivePullUp<void>(
        context,
        title: 'Véhicule',
        builder: (_) => const Text('contenu'),
      ),
    );
    expectModal(tester, 'Véhicule');
    expect(find.text('contenu'), findsOneWidget);
  });
}
