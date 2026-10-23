import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanzo/features/labels/label_format.dart';
import 'package:wanzo/features/labels/label_item.dart';
import 'package:wanzo/features/labels/label_preview.dart';
import 'package:wanzo/features/labels/label_print_service.dart';
import 'package:wanzo/features/labels/print_labels_screen.dart';

final _items = [
  for (var i = 0; i < 6; i++)
    LabelItem(
      id: 'p$i',
      name: 'Article numéro $i avec un nom assez long pour être coupé',
      code: i == 0 ? 'WZ23ABCDE$i' : 'SKU-$i',
      codeIsGenerated: i == 0,
      price: '${(i + 1) * 1250} CDF',
      secondaryPrice: '${i + 1},00 \$',
      unit: 'pièce',
      extra: 'Lot L$i',
      stockQuantity: i.toDouble(),
    ),
];

Widget _app(Widget child, {double width = 320, double scale = 1.0}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 720),
        textScaler: TextScaler.linear(scale),
      ),
      child: child,
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final scale in [1.0, 1.3, 2.0]) {
    for (final width in [320.0, 1100.0]) {
      testWidgets('lot : ${width.toInt()} dp, police x$scale, sans débordement',
          (tester) async {
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app(
          PrintLabelsScreen(
            items: _items,
            selectedIds: const {'p0', 'p2'},
            companyName: 'Boutique Wanzo',
            target: LabelTarget.systemDialog,
            initialSettings: const LabelSettings(),
          ),
          width: width,
          scale: scale,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(LabelPreview), findsOneWidget);
        expect(find.text('Imprimer des étiquettes'), findsOneWidget);
        // Quantité par défaut : p0 stock 0 => 1, p2 stock 2 => 2.
        expect(find.text('3 étiquettes'), findsOneWidget);
      });
    }
  }

  testWidgets('quantité en pas et format personnalisé', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(
      PrintLabelsScreen(
        items: [_items[3]],
        target: LabelTarget.systemDialog,
        initialSettings: const LabelSettings(formatId: LabelFormat.customId),
      ),
      width: 400,
    ));
    await tester.pumpAndSettle();
    expect(find.text('3 étiquettes'), findsOneWidget);
    await tester.tap(find.byTooltip('Plus'));
    await tester.pump();
    expect(find.text('4 étiquettes'), findsOneWidget);
    await tester.tap(find.byTooltip('Moins'));
    await tester.pump();
    await tester.tap(find.byTooltip('Moins'));
    await tester.pump();
    expect(find.text('2 étiquettes'), findsOneWidget);

    expect(find.text('Largeur (mm)'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Largeur (mm)'), '8');
    await tester.pump();
    expect(find.text('Minimum 15 mm'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Largeur (mm)'), '70');
    await tester.pump();
    final preview = tester.getSize(find.byKey(const ValueKey('label-preview')));
    // 70 x 25 mm : aperçu au même rapport.
    expect(preview.width / preview.height, closeTo(70 / 25, 0.05));
    expect(tester.takeException(), isNull);
  });

  testWidgets('aucune sélection : impression désactivée', (tester) async {
    await tester.pumpWidget(_app(
      PrintLabelsScreen(
        items: _items,
        selectedIds: const {},
        target: LabelTarget.systemDialog,
        initialSettings: const LabelSettings(),
      ),
      width: 600,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Aucune étiquette'), findsOneWidget);
    final btn = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('label-print')));
    expect(btn.onPressed, isNull);
  });
}
