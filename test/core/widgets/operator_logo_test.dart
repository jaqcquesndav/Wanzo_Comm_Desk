import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/widgets/operator_logo.dart';

Widget _host(Widget child,
    {double width = 320, double textScale = 1, bool dark = false}) {
  return MaterialApp(
    theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 640),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: Center(child: SizedBox(width: width, child: child)),
      ),
    ),
  );
}

void main() {
  group('OperatorBrand.resolve', () {
    test('codes SerdiPay', () {
      expect(OperatorBrand.resolve('MP'), OperatorBrand.mpesa);
      expect(OperatorBrand.resolve('om'), OperatorBrand.orangeMoney);
      expect(OperatorBrand.resolve('AM'), OperatorBrand.airtelMoney);
      expect(OperatorBrand.resolve('AF'), OperatorBrand.afrimoney);
    });

    test('noms et variantes', () {
      expect(OperatorBrand.resolve('M-Pesa (Vodacom)'), OperatorBrand.mpesa);
      expect(OperatorBrand.resolve('M-PESA'), OperatorBrand.mpesa);
      expect(OperatorBrand.resolve('Orange Money'), OperatorBrand.orangeMoney);
      expect(OperatorBrand.resolve('airtel'), OperatorBrand.airtelMoney);
      expect(OperatorBrand.resolve('Africell Money'), OperatorBrand.afrimoney);
      expect(OperatorBrand.resolve('afrimoney'), OperatorBrand.afrimoney);
    });

    test('inconnu', () {
      expect(OperatorBrand.resolve(null), isNull);
      expect(OperatorBrand.resolve(''), isNull);
      expect(OperatorBrand.resolve('WAVE'), isNull);
      expect(operatorLabel('WAVE'), 'WAVE');
      expect(operatorLabel(null), 'Mobile Money');
    });
  });

  testWidgets('logo connu : image de la marque, annoncée par son nom',
      (tester) async {
    await tester.pumpWidget(_host(const OperatorLogo('OM', size: 40)));
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName,
        'assets/images/operators/orange_money.png');
    expect(find.bySemanticsLabel('Orange Money'), findsOneWidget);
  });

  testWidgets('opérateur inconnu : icône téléphone et libellé', (tester) async {
    await tester.pumpWidget(_host(const OperatorChip('WAVE')));
    expect(find.byKey(const ValueKey('operator-logo-generic')), findsOneWidget);
    expect(find.byIcon(Icons.phone_android), findsOneWidget);
    expect(find.text('WAVE'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'sélecteur à 320 dp, police x2, ${dark ? 'mode sombre' : 'mode clair'}',
        (tester) async {
      OperatorBrand? picked;
      await tester.pumpWidget(_host(
        StatefulBuilder(
          builder: (context, setState) => OperatorSelector<OperatorBrand>(
            operators: OperatorBrand.values,
            selected: picked,
            onSelected: (op) => setState(() => picked = op),
          ),
        ),
        textScale: 2,
        dark: dark,
      ));
      expect(tester.takeException(), isNull);
      for (final op in OperatorBrand.values) {
        expect(find.text(op.label), findsOneWidget);
      }
      expect(find.byType(Image), findsNWidgets(4));
      await tester.tap(find.byKey(const ValueKey('operator-option-AF')));
      await tester.pump();
      expect(picked, OperatorBrand.afrimoney);
      expect(tester.takeException(), isNull);
    });
  }
}
