// ignore_for_file: deprecated_member_use_from_same_package
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wanzo/core/shared_widgets/kpi_board.dart';
import 'package:wanzo/core/shared_widgets/kpi_grid.dart';
import 'package:wanzo/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:wanzo/features/dashboard/bloc/operation_journal_bloc.dart';
import 'package:wanzo/features/dashboard/models/operation_journal_entry.dart';
import 'package:wanzo/features/dashboard/widgets/dashboard_operations_journal.dart';
import 'package:wanzo/features/dashboard/widgets/dashboard_sales_expense_chart.dart';
import 'package:wanzo/features/dashboard/widgets/mode_dashboard_layout.dart';
import 'package:wanzo/features/expenses/bloc/expense_bloc.dart';
import 'package:wanzo/features/inventory/bloc/inventory_bloc.dart';
import 'package:wanzo/features/inventory/bloc/inventory_event.dart';
import 'package:wanzo/features/inventory/bloc/inventory_state.dart';
import 'package:wanzo/features/sales/bloc/sales_bloc.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/l10n/app_localizations.dart';

class _Journal extends MockBloc<OperationJournalEvent, OperationJournalState>
    implements OperationJournalBloc {}

class _Expenses extends MockBloc<ExpenseEvent, ExpenseState>
    implements ExpenseBloc {}

class _Sales extends MockBloc<SalesEvent, SalesState> implements SalesBloc {}

class _Dashboard extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

class _Inventory extends MockBloc<InventoryEvent, InventoryState>
    implements InventoryBloc {}

OperationJournalLoaded _journalState(int count) {
  final now = DateTime.now();
  final ops = [
    for (var i = 0; i < count; i++)
      OperationJournalEntry(
        id: 'op$i',
        date: now.subtract(Duration(hours: i)),
        description: 'Ticket coupe et brushing, client numero $i du jour',
        type: OperationType.saleCash,
        amount: 125000.0 + i,
        currencyCode: i.isEven ? 'CDF' : 'USD',
        isDebit: false,
        isCredit: true,
        balanceAfter: 0,
        cashBalance: 9876543.21,
      ),
  ];
  return OperationJournalLoaded(
    operations: ops,
    filteredOperations: ops,
    startDate: DateTime(now.year, now.month, 1),
    endDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    groupedOperations: const {},
    openingBalance: 0,
    openingBalancesByCurrency: const {},
    openingCashBalances: const {},
    openingSalesBalances: const {},
    openingStockValues: const {},
  );
}

Sale _sale(int i) => Sale(
  id: 's$i',
  date: DateTime.now().subtract(Duration(days: i)),
  customerName: 'Client $i',
  items: const [],
  totalAmountInCdf: 50000.0 * (i + 1),
  paidAmountInCdf: 50000.0 * (i + 1),
  status: SaleStatus.completed,
  transactionCurrencyCode: 'CDF',
);

List<KpiTile> _tiles() => const [
  KpiTile(
    icon: Icons.payments,
    color: Color(0xFF16A34A),
    label: 'CA du jour (CDF)',
    value: '12 345 678,00 FC',
    secondary: '7 derniers jours',
    trend: [3, 5, 4, 8, 6, 9, 12],
  ),
  KpiTile(
    icon: Icons.payments,
    color: Color(0xFF16A34A),
    label: 'CA du jour (USD)',
    value: '1 234,00 \$',
    secondary: 'Encaissé en dollars',
  ),
  KpiTile(
    icon: Icons.savings_outlined,
    color: Color(0xFFF59E0B),
    label: 'Reste à verser (mois)',
    value: '345 000,00 FC',
    secondary: 'Commissions de l\'équipe',
  ),
  KpiTile(
    icon: Icons.groups_outlined,
    color: Color(0xFF0EA5E9),
    label: 'Clients servis (jour)',
    value: '18',
    secondary: 'Tickets du jour',
  ),
  KpiTile(
    icon: Icons.content_cut,
    color: Color(0xFF8B5CF6),
    label: 'Prestations',
    value: '24',
    secondary: 'Carte active',
  ),
  KpiTile(
    icon: Icons.badge_outlined,
    color: Color(0xFF197CA8),
    label: 'Coiffeurs',
    value: '6',
    secondary: 'Équipe active',
  ),
];

Widget _orders() => Card(
  margin: EdgeInsets.zero,
  child: Column(
    children: [
      for (var i = 0; i < 3; i++)
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
          title: Text(
            'Table $i, terrasse',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('4 article(s) · En cuisine'),
          trailing: const Text('1 250 000,00 FC'),
        ),
    ],
  ),
);

Widget _dishes() => Card(
  margin: EdgeInsets.zero,
  child: Column(
    children: [
      for (var i = 0; i < 5; i++)
        ListTile(
          title: Text(
            'Poulet mayo frites maison numero $i',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Text('12 vendu(s)'),
        ),
    ],
  ),
);

/// Corps d'un tableau de bord de mode, tel que le composent les écrans salon
/// et restaurant : vignettes, graphique, sections du métier, journal.
Widget _body({required bool restaurant, VoidCallback? onExpand}) {
  return ModeDashboardLayout(
    onRefresh: () async {},
    bottomSpacing: 80,
    kpis: KpiGrid(tiles: _tiles()),
    chart: ModeDashboardChart(includeStock: !restaurant),
    middle:
        restaurant
            ? DashboardSectionsGroup(
              sections: [
                DashboardSection(
                  title: 'Commandes en cours',
                  child: _orders(),
                ),
                DashboardSection(
                  title: 'Plats les plus vendus (aujourd\'hui)',
                  tabLabel: 'Plats les plus vendus',
                  child: _dishes(),
                ),
              ],
            )
            : null,
    journal: DashboardOperationsJournal(
      displayCurrencyCode: 'CDF',
      onExpand: onExpand ?? () {},
    ),
  );
}

Widget _app(Widget body, {int operations = 14, double scale = 1.0}) {
  final journal = _Journal();
  whenListen(
    journal,
    const Stream<OperationJournalState>.empty(),
    initialState: _journalState(operations),
  );
  final expenses = _Expenses();
  whenListen(
    expenses,
    const Stream<ExpenseState>.empty(),
    initialState: const ExpensesLoaded(expenses: []),
  );
  final sales = _Sales();
  whenListen(
    sales,
    const Stream<SalesState>.empty(),
    initialState: SalesLoaded(sales: [for (var i = 0; i < 20; i++) _sale(i)]),
  );
  final dashboard = _Dashboard();
  whenListen(
    dashboard,
    const Stream<DashboardState>.empty(),
    initialState: DashboardInitial(),
  );
  final inventory = _Inventory();
  whenListen(
    inventory,
    const Stream<InventoryState>.empty(),
    initialState: const InventoryInitial(),
  );
  return MultiBlocProvider(
    providers: [
      BlocProvider<OperationJournalBloc>.value(value: journal),
      BlocProvider<ExpenseBloc>.value(value: expenses),
      BlocProvider<SalesBloc>.value(value: sales),
      BlocProvider<DashboardBloc>.value(value: dashboard),
      BlocProvider<InventoryBloc>.value(value: inventory),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
      home: Scaffold(body: body),
    ),
  );
}

/// Clés des sections, dans l'ordre où la liste les déclare.
List<Key> _declaredOrder(WidgetTester tester) {
  final list = tester.widget<ListView>(
    find.descendant(
      of: find.byType(ModeDashboardLayout),
      matching: find.byType(ListView),
    ).first,
  );
  final delegate = list.childrenDelegate as SliverChildListDelegate;
  return [
    for (final w in delegate.children)
      if (w is KeyedSubtree && w.key != null) w.key!,
  ];
}

const _sizes = <String, Size>{
  'portrait 320dp': Size(320, 568),
  'portrait 360dp': Size(360, 740),
  'paysage telephone': Size(740, 360),
  'tablette portrait': Size(800, 1280),
  'terminal POS 1024x600': Size(1024, 600),
  'desktop 1366x768': Size(1366, 768),
  'desktop large': Size(1920, 1080),
};

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Fait défiler la liste jusqu'au bas en vérifiant qu'aucune section ne
/// déborde en chemin.
Future<void> _scrollThrough(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 30; i++) {
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }
}

void main() {
  group('Salon', () {
    testWidgets('ordre : vignettes, graphique, journal', (tester) async {
      await _setSize(tester, const Size(360, 740));
      await tester.pumpWidget(_app(_body(restaurant: false)));
      await tester.pump();
      expect(_declaredOrder(tester), [
        ModeDashboardKeys.kpis,
        ModeDashboardKeys.chart,
        ModeDashboardKeys.journal,
      ]);
      // Le graphique est rendu sous les vignettes, sur toute la largeur.
      final kpis = tester.getRect(find.byKey(ModeDashboardKeys.kpis));
      final chart = tester.getRect(find.byKey(ModeDashboardKeys.chart));
      expect(chart.top, greaterThan(kpis.top));
      expect(chart.width, kpis.width);
      await tester.scrollUntilVisible(
        find.byKey(ModeDashboardKeys.journal),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Journal des Opérations'), findsWidgets);
    });

    for (final e in _sizes.entries) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('aucun débordement, ${e.key}, police x$scale', (
          tester,
        ) async {
          await _setSize(tester, e.value);
          await tester.pumpWidget(
            _app(_body(restaurant: false), scale: scale),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          await _scrollThrough(tester);
        });
      }
    }
  });

  group('Restaurant', () {
    testWidgets('ordre : vignettes, graphique, sections, journal', (
      tester,
    ) async {
      await _setSize(tester, const Size(360, 740));
      await tester.pumpWidget(_app(_body(restaurant: true)));
      await tester.pump();
      expect(_declaredOrder(tester), [
        ModeDashboardKeys.kpis,
        ModeDashboardKeys.chart,
        ModeDashboardKeys.middle,
        ModeDashboardKeys.journal,
      ]);
    });

    testWidgets('téléphone : sections en onglets', (tester) async {
      await _setSize(tester, const Size(360, 740));
      await tester.pumpWidget(_app(_body(restaurant: true)));
      await tester.scrollUntilVisible(
        find.byKey(ModeDashboardKeys.middle),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Commandes en cours'), findsOneWidget);
      expect(find.text('Plats les plus vendus'), findsOneWidget);
      expect(find.text('Table 0, terrasse'), findsOneWidget);
      await tester.tap(find.text('Plats les plus vendus'));
      await tester.pumpAndSettle();
      expect(find.text('Table 0, terrasse'), findsNothing);
      expect(find.text('Poulet mayo frites maison numero 0'), findsOneWidget);
    });

    testWidgets('grand écran : sections côte à côte', (tester) async {
      await _setSize(tester, const Size(1920, 1080));
      await tester.pumpWidget(_app(_body(restaurant: true)));
      await tester.scrollUntilVisible(
        find.byKey(ModeDashboardKeys.middle),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final orders = tester.getRect(find.text('Table 0, terrasse'));
      final dish = tester.getRect(
        find.text('Poulet mayo frites maison numero 0'),
      );
      expect(dish.left, greaterThan(orders.right));
      expect(
        find.text('Plats les plus vendus (aujourd\'hui)'),
        findsOneWidget,
      );
    });

    for (final e in _sizes.entries) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('aucun débordement, ${e.key}, police x$scale', (
          tester,
        ) async {
          await _setSize(tester, e.value);
          await tester.pumpWidget(_app(_body(restaurant: true), scale: scale));
          await tester.pump();
          expect(tester.takeException(), isNull);
          await _scrollThrough(tester);
        });
      }
    }
  });

  group('Journal partagé (mode Général)', () {
    testWidgets('dix dernières opérations, « Tout » ouvre la vue agrandie', (
      tester,
    ) async {
      await _setSize(tester, const Size(360, 740));
      var expanded = 0;
      await tester.pumpWidget(
        _app(
          ListView(
            children: [
              DashboardOperationsJournal(
                displayCurrencyCode: 'CDF',
                onExpand: () => expanded++,
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Tab), findsOneWidget);
      expect(find.text('Journal des Opérations'), findsWidgets);
      expect(find.textContaining('14 opération(s)'), findsOneWidget);
      // Plus récente d'abord ; la onzième n'est jamais rendue.
      expect(find.textContaining('client numero 0 du jour'), findsOneWidget);
      expect(find.textContaining('client numero 10 du jour'), findsNothing);
      expect(find.text('Voir plus d\'opérations'), findsOneWidget);
      await tester.tap(find.text('Tout'));
      expect(expanded, 1);
      await tester.tap(find.text('Voir plus d\'opérations'));
      expect(expanded, 2);
    });

    testWidgets('journal vide : message sans débordement', (tester) async {
      await _setSize(tester, const Size(320, 568));
      await tester.pumpWidget(
        _app(
          ListView(
            children: [
              DashboardOperationsJournal(
                displayCurrencyCode: 'CDF',
                onExpand: () {},
              ),
            ],
          ),
          operations: 0,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Voir plus d\'opérations'), findsNothing);
    });
  });
}
