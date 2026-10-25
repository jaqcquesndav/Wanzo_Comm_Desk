import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/shared_widgets/kpi_board.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/features/dashboard/screens/dashboard_screen.dart';

/// Tableau de bord Général : le CDF et l'USD sont toujours montrés côte à
/// côte, et l'USD est le montant réellement enregistré en dollars, jamais une
/// conversion du CDF.
void main() {
  KpiData data({double usd = 1234.5, double expUsd = 12}) => KpiData(
        salesTodayCdf: 12345678,
        salesTodayUsd: usd,
        clientsServed: 0,
        receivables: 450000,
        expenses: 0,
        expensesCdf: 98765,
        expensesUsd: expUsd,
        stockValueAtCost: 3500000,
        potentialProfit: 800000,
      );

  List<KpiTile> tiles(KpiData d) => generalKpiTiles(
        d,
        revenueLabel: 'Revenus',
        receivablesColor: Colors.blue,
      );

  test('chiffre d\'affaires et charges par paires CDF puis USD, en tête', () {
    final t = tiles(data());
    expect([for (final x in t.take(4)) x.label], [
      'Revenus (CDF)',
      'Revenus (USD)',
      'Charges (CDF)',
      'Charges (USD)',
    ]);
    expect(t.take(4).every((x) => x.weight == KpiWeight.pilote), isTrue);
    expect(t[0].value, formatCurrency(12345678, 'CDF'));
    expect(t[1].value, formatCurrency(1234.5, 'USD'));
    expect(t[2].value, formatCurrency(98765, 'CDF'));
    expect(t[3].value, formatCurrency(12, 'USD'));
  });

  test('USD jamais converti : sans opération en dollars, il vaut 0', () {
    final t = tiles(data(usd: 0, expUsd: 0));
    expect(t[1].value, formatCurrency(0, 'USD'));
    expect(t[3].value, formatCurrency(0, 'USD'));
  });

  for (final width in [900.0, 1280.0, 1600.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('desktop $width dp, police x$scale : CDF et USD côte à côte',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: KpiBoard(tiles: tiles(data())),
              ),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
        final cdf = tester.getRect(find.text('Revenus (CDF)'));
        final usd = tester.getRect(find.text('Revenus (USD)'));
        expect(usd.top, closeTo(cdf.top, 1));
        expect(usd.left, greaterThan(cdf.right));
        expect(find.text(formatCurrency(1234.5, 'USD')), findsOneWidget);
      });
    }
  }
}
