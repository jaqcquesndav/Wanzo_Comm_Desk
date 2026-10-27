import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/shared_widgets/kpi_board.dart';
import 'package:wanzo/core/shared_widgets/kpi_grid.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/features/dashboard/screens/dashboard_screen.dart';

/// Tableau de bord Général : six vignettes complètes, comme le mode Général
/// de l'app Gestion d'actifs. Le CDF et l'USD sont toujours montrés côte à
/// côte, et l'USD est le montant réellement enregistré en dollars, jamais une
/// conversion du CDF.
void main() {
  List<String> labels(List<KpiTile> tiles) => [for (final t in tiles) t.label];

  KpiData grosChiffres() => KpiData(
        salesTodayCdf: 12345678,
        salesTodayUsd: 1234.5,
        clientsServed: 0,
        receivables: 450000,
        expenses: 0,
        expensesCdf: 98765,
        expensesUsd: 12,
        stockValueAtCost: 3500000,
        potentialProfit: 800000,
      );

  test('exactement six vignettes, par paires CDF puis USD', () {
    final tiles = generalKpiTiles(
      KpiData(
        salesTodayCdf: 150000,
        salesTodayUsd: 42.5,
        clientsServed: 3,
        receivables: 0,
        expenses: 0,
        expensesCdf: 20000,
        expensesUsd: 7,
      ),
      revenueLabel: 'Revenus',
      receivablesColor: Colors.blue,
    );
    expect(labels(tiles), [
      'Revenus (CDF)',
      'Revenus (USD)',
      'Charges (CDF)',
      'Charges (USD)',
      'À encaisser',
      'Valeur du stock',
    ]);
    expect(tiles[0].value, formatCurrency(150000, 'CDF'));
    expect(tiles[1].value, formatCurrency(42.5, 'USD'));
    expect(tiles[2].value, formatCurrency(20000, 'CDF'));
    expect(tiles[3].value, formatCurrency(7, 'USD'));
  });

  test('chaque vignette est complète : titre, valeur, icône, sous-ligne', () {
    for (final stock in [0.0, 3500000.0]) {
      final tiles = generalKpiTiles(
        KpiData(
          salesTodayCdf: 1,
          salesTodayUsd: 1,
          clientsServed: 0,
          receivables: 0,
          expenses: 0,
          stockValueAtCost: stock,
          potentialProfit: stock / 4,
        ),
        revenueLabel: 'Revenus',
        receivablesColor: Colors.blue,
      );
      expect(tiles, hasLength(6), reason: 'stock $stock');
      for (final t in tiles) {
        expect(t.label, isNotEmpty);
        expect(t.value, isNotEmpty);
        expect(t.secondary, isNotNull, reason: t.label);
      }
    }
  });

  test('le bénéfice potentiel du stock est la sous-ligne, pas une septième',
      () {
    final tiles = generalKpiTiles(
      grosChiffres(),
      revenueLabel: 'Revenus',
      receivablesColor: Colors.blue,
    );
    expect(tiles, hasLength(6));
    expect(tiles.last.secondary,
        '+${formatCurrency(800000, 'CDF')} potentiel');
  });

  test('USD jamais converti : sans vente en dollars, la vignette USD vaut 0',
      () {
    final tiles = generalKpiTiles(
      KpiData(
        salesTodayCdf: 280000,
        salesTodayUsd: 0,
        clientsServed: 0,
        receivables: 0,
        expenses: 0,
        expensesCdf: 28000,
        expensesUsd: 0,
      ),
      revenueLabel: 'Revenus',
      receivablesColor: Colors.blue,
    );
    expect(tiles[1].value, formatCurrency(0, 'USD'));
    expect(tiles[3].value, formatCurrency(0, 'USD'));
    expect(tiles[0].value, formatCurrency(280000, 'CDF'));
  });

  test('colonnes selon la largeur et l\'orientation', () {
    expect(KpiGrid.columnsFor(288, Orientation.portrait, 6), 2);
    expect(KpiGrid.columnsFor(328, Orientation.portrait, 6), 2);
    expect(KpiGrid.columnsFor(768, Orientation.landscape, 6), 3);
    expect(KpiGrid.columnsFor(480, Orientation.landscape, 6), 3);
    expect(KpiGrid.columnsFor(768, Orientation.portrait, 6), 3);
    expect(KpiGrid.columnsFor(1400, Orientation.landscape, 6), 6);
  });

  Future<void> poser(
    WidgetTester tester, {
    required Size ecran,
    double police = 1.0,
  }) async {
    tester.view.physicalSize = ecran;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tiles = generalKpiTiles(
      grosChiffres(),
      revenueLabel: 'Revenus',
      receivablesColor: Colors.blue,
      onReceivables: () {},
    );
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: ecran,
          textScaler: TextScaler.linear(police),
        ),
        child: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              KpiGrid(tiles: tiles),
              const SizedBox(height: 300, child: Placeholder()),
            ],
          ),
        ),
      ),
    ));
  }

  const appareils = <String, Size>{
    'telephone portrait 320dp': Size(320, 568),
    'telephone portrait 360dp': Size(360, 740),
    'telephone paysage': Size(740, 360),
    'petit telephone paysage': Size(568, 320),
    'tablette portrait': Size(800, 1280),
    'tablette paysage': Size(1280, 800),
    'terminal POS': Size(1024, 600),
    'desktop etroit': Size(900, 700),
    'desktop large': Size(1920, 1080),
  };

  for (final entry in appareils.entries) {
    for (final police in [1.0, 1.3, 2.0]) {
      testWidgets(
          'six vignettes sans débordement : ${entry.key}, police x$police',
          (tester) async {
        await poser(tester, ecran: entry.value, police: police);
        expect(tester.takeException(), isNull);
        for (final l in [
          'Revenus (CDF)',
          'Revenus (USD)',
          'Charges (CDF)',
          'Charges (USD)',
          'À encaisser',
          'Valeur du stock',
        ]) {
          expect(find.text(l), findsOneWidget, reason: l);
        }
        // Toutes les vignettes ont la même taille et aucune ne sort de
        // l'écran.
        final cartes = tester.widgetList<Card>(find.byType(Card)).toList();
        expect(cartes, hasLength(6));
        final tailles = [
          for (final e in find.byType(Card).evaluate())
            tester.getSize(find.byWidget(e.widget)),
        ];
        for (final t in tailles) {
          expect(t.width, closeTo(tailles.first.width, 0.5));
          expect(t.height, closeTo(tailles.first.height, 0.5));
          expect(t.width, lessThanOrEqualTo(300));
        }
        for (final e in find.byType(Card).evaluate()) {
          final r = tester.getRect(find.byWidget(e.widget));
          expect(r.right, lessThanOrEqualTo(entry.value.width));
        }
      });
    }
  }

  testWidgets('portrait 360dp : deux colonnes, CDF et USD côte à côte',
      (tester) async {
    await poser(tester, ecran: const Size(360, 740));
    final cdf = tester.getRect(find.text('Revenus (CDF)'));
    final usd = tester.getRect(find.text('Revenus (USD)'));
    expect(usd.top, closeTo(cdf.top, 1));
    expect(usd.left, greaterThan(cdf.right));
    // Trois rangées de deux.
    final charges = tester.getRect(find.text('Charges (CDF)'));
    final stock = tester.getRect(find.text('Valeur du stock'));
    expect(charges.top, greaterThan(cdf.bottom));
    expect(stock.top, greaterThan(charges.bottom));
    expect(find.text(formatCurrency(1234.5, 'USD')), findsOneWidget);
  });

  testWidgets('paysage : trois colonnes sur deux rangées, CDF au-dessus de USD',
      (tester) async {
    await poser(tester, ecran: const Size(740, 360));
    final revCdf = tester.getRect(find.text('Revenus (CDF)'));
    final revUsd = tester.getRect(find.text('Revenus (USD)'));
    final chCdf = tester.getRect(find.text('Charges (CDF)'));
    final enc = tester.getRect(find.text('À encaisser'));
    final stock = tester.getRect(find.text('Valeur du stock'));
    // Rangée CDF : revenus, charges, à encaisser.
    expect(chCdf.top, closeTo(revCdf.top, 1));
    expect(enc.top, closeTo(revCdf.top, 1));
    // Rangée USD juste dessous, alignée sur sa paire.
    expect(revUsd.left, closeTo(revCdf.left, 1));
    expect(revUsd.top, greaterThan(revCdf.bottom));
    expect(stock.left, closeTo(enc.left, 1));
    // La grille tient dans la hauteur d'un téléphone en paysage.
    final derniere = tester.getRect(find.byType(Card).last);
    expect(derniere.bottom, lessThan(360));
  });

  testWidgets('desktop large : les six sur une rangée, jamais étirées',
      (tester) async {
    await poser(tester, ecran: const Size(1920, 1080));
    final premiere = tester.getRect(find.text('Revenus (CDF)'));
    final derniere = tester.getRect(find.text('Valeur du stock'));
    expect(derniere.top, closeTo(premiere.top, 1));
    expect(tester.getSize(find.byType(Card).first).width,
        lessThanOrEqualTo(300));
  });

  testWidgets('la vignette À encaisser mène au détail', (tester) async {
    var ouvert = false;
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: KpiGrid(
            tiles: generalKpiTiles(
              grosChiffres(),
              revenueLabel: 'Revenus',
              receivablesColor: Colors.blue,
              onReceivables: () => ouvert = true,
            ),
          ),
        ),
      ),
    ));
    expect(find.text('Voir détails'), findsOneWidget);
    await tester.tap(find.text('À encaisser'));
    expect(ouvert, isTrue);
  });
}
