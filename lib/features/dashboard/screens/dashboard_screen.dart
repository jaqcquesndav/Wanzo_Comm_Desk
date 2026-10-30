import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wanzo/core/shared_widgets/kpi_board.dart';
import 'package:wanzo/core/shared_widgets/kpi_grid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/l10n/app_localizations.dart'; // Corrected import path

import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:wanzo/features/dashboard/bloc/operation_journal_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/features/sales/bloc/sales_bloc.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/settings/bloc/settings_bloc.dart';
import 'package:wanzo/features/settings/bloc/settings_state.dart';
import 'package:wanzo/features/settings/models/settings.dart';
import 'package:wanzo/constants/spacing.dart';
import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/features/expenses/bloc/expense_bloc.dart';
import 'package:wanzo/features/dashboard/widgets/dashboard_operations_journal.dart';
import 'package:wanzo/features/dashboard/widgets/dashboard_sales_expense_chart.dart';
import 'package:wanzo/features/inventory/bloc/inventory_bloc.dart';
import 'package:wanzo/features/inventory/bloc/inventory_event.dart';
import 'package:wanzo/features/inventory/bloc/inventory_state.dart';
import 'package:wanzo/core/services/sync_service.dart';
import 'package:get_it/get_it.dart';
import 'package:wanzo/core/modules/mode_vocabulary.dart';

// Model for KPI data
class KpiData {
  final double salesTodayCdf;
  final double salesTodayUsd;
  final int clientsServed;
  final double receivables;
  final double expenses;
  final double expensesCdf;
  final double expensesUsd;
  // Stock values
  final double stockValueAtCost; // Valeur du stock au prix d'achat
  final double stockValueAtSalePrice; // Valeur du stock au prix de vente
  final double potentialProfit; // Bénéfice potentiel

  KpiData({
    required this.salesTodayCdf,
    required this.salesTodayUsd,
    required this.clientsServed,
    required this.receivables,
    required this.expenses,
    this.expensesCdf = 0.0,
    this.expensesUsd = 0.0,
    this.stockValueAtCost = 0.0,
    this.stockValueAtSalePrice = 0.0,
    this.potentialProfit = 0.0,
  });
}

/// Les six vignettes du tableau de bord Général, par paires CDF | USD.
///
/// Meme grille que le mode General de l'app Gestion d'actifs : chiffre
/// d'affaires CDF | USD, charges CDF | USD, puis a encaisser et valeur du
/// stock, chacune avec sa sous-ligne. Le CDF est la devise de base (OHADA) ;
/// l'USD est le montant REELLEMENT enregistre en dollars, jamais une
/// conversion du CDF.
List<KpiTile> generalKpiTiles(
  KpiData kpiData, {
  required String revenueLabel,
  required Color receivablesColor,
  VoidCallback? onReceivables,
}) {
  return [
    // Chiffre d'affaires du jour : CDF | USD.
    KpiTile(
      label: '$revenueLabel (CDF)',
      value: formatCurrency(kpiData.salesTodayCdf, 'CDF'),
      secondary: 'Chiffre d\'affaires',
      icon: Icons.trending_up,
      color: Colors.green,
    ),
    KpiTile(
      label: '$revenueLabel (USD)',
      value: formatCurrency(kpiData.salesTodayUsd, 'USD'),
      secondary: 'Chiffre d\'affaires',
      icon: Icons.trending_up,
      color: Colors.green,
    ),
    // Charges du jour : CDF | USD.
    KpiTile(
      label: 'Charges (CDF)',
      value: formatCurrency(kpiData.expensesCdf, 'CDF'),
      secondary: 'Dépenses engagées',
      icon: Icons.trending_down,
      color: Colors.red,
    ),
    KpiTile(
      label: 'Charges (USD)',
      value: formatCurrency(kpiData.expensesUsd, 'USD'),
      secondary: 'Dépenses engagées',
      icon: Icons.trending_down,
      color: Colors.red,
    ),
    KpiTile(
      label: 'À encaisser',
      value: formatCurrency(kpiData.receivables, 'CDF'),
      secondary: 'Créances clients',
      icon: Icons.schedule_send,
      color: receivablesColor,
      // Ouvre les ventes a encaisser (non payees ou partielles).
      onTap: onReceivables,
    ),
    // Le benefice potentiel du stock revient en sous-ligne : six vignettes,
    // jamais une septieme qui casse la grille.
    KpiTile(
      label: 'Valeur du stock',
      value: formatCurrency(kpiData.stockValueAtCost, 'CDF'),
      secondary: kpiData.stockValueAtCost > 0
          ? '+${formatCurrency(kpiData.potentialProfit, 'CDF')} potentiel'
          : 'Au prix d\'achat',
      icon: Icons.inventory_2,
      color: Colors.blueGrey,
    ),
  ];
}

/// Écran principal du tableau de bord
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late OperationJournalBloc _operationJournalBloc;
  late SalesBloc _salesBloc;
  late ExpenseBloc _expenseBloc;
  late DashboardBloc _dashboardBloc;

  /// Vue agrandie du journal des opérations (« Voir tout »).
  bool _journalExpanded = false;
  bool _isChartExpanded = false;

  // Souscription pour écouter les changements de dépenses
  StreamSubscription? _expenseSubscription;
  // Souscription pour écouter la fin de synchronisation
  StreamSubscription? _syncSubscription;

  String _getDisplayCurrencyCode(Settings settings) {
    final Currency activeAppCurrency = settings.activeCurrency;
    return activeAppCurrency.code;
  }

  @override
  void initState() {
    super.initState();
    _operationJournalBloc = BlocProvider.of<OperationJournalBloc>(context);
    _salesBloc = BlocProvider.of<SalesBloc>(context);
    _expenseBloc = BlocProvider.of<ExpenseBloc>(context);
    _dashboardBloc = BlocProvider.of<DashboardBloc>(context);

    final now = DateTime.now();
    _dashboardBloc.add(LoadDashboardData(date: now));

    // Charger l'inventaire pour afficher les images des produits dans le journal
    context.read<InventoryBloc>().add(LoadProducts());

    _operationJournalBloc.add(
      LoadOperations(
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      ),
    );
    _salesBloc.add(
      LoadSalesByDateRange(
        startDate: now.subtract(const Duration(days: 365)),
        endDate: now,
      ),
    );
    _expenseBloc.add(
      LoadExpensesByDateRange(now.subtract(const Duration(days: 365)), now),
    );

    // Écouter les changements d'état de l'ExpenseBloc pour rafraîchir le dashboard
    _expenseSubscription = _expenseBloc.stream.listen((expenseState) {
      if (expenseState is ExpensesLoaded) {
        // Rafraîchir le dashboard quand les dépenses changent
        _dashboardBloc.add(RefreshDashboardData(DateTime.now()));
      }
    });

    // Écouter le SyncService pour recharger les ventes après synchronisation
    if (GetIt.instance.isRegistered<SyncService>()) {
      final syncService = GetIt.instance<SyncService>();
      _syncSubscription = syncService.syncStatus.listen((status) {
        if (status == SyncStatus.completed) {
          debugPrint(
            '🔄 Sync terminée - Rechargement des ventes, dépenses et journal pour le dashboard',
          );
          final now = DateTime.now();
          _salesBloc.add(
            LoadSalesByDateRange(
              startDate: now.subtract(const Duration(days: 365)),
              endDate: now,
            ),
          );
          _expenseBloc.add(
            LoadExpensesByDateRange(
              now.subtract(const Duration(days: 365)),
              now,
            ),
          );
          // Recharger le journal des opérations
          _operationJournalBloc.add(
            LoadOperations(
              startDate: DateTime(now.year, now.month, 1),
              endDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
            ),
          );
          // Recharger l'inventaire
          context.read<InventoryBloc>().add(LoadProducts());
          _dashboardBloc.add(RefreshDashboardData(now));
        }
      });
    }
  }

  @override
  void dispose() {
    // Annuler les souscriptions pour éviter les fuites de mémoire
    _expenseSubscription?.cancel();
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _expandOperationsJournal() {
    setState(() => _journalExpanded = true);
  }

  void _collapseView() {
    setState(() => _journalExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsState = context.watch<SettingsBloc>().state;

    Settings settings;
    if (settingsState is SettingsLoaded) {
      settings = settingsState.settings;
    } else if (settingsState is SettingsUpdated) {
      settings = settingsState.settings;
    } else {
      return WanzoScaffold(
        currentIndex: 0,
        title: l10n.dashboardScreenTitle,
        body: Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading),
        ),
      );
    }
    final String displayCurrencyCode = _getDisplayCurrencyCode(settings);

    if (_journalExpanded) {
      return OperationsJournalExpandedView(
        displayCurrencyCode: displayCurrencyCode,
        onCollapse: _collapseView,
      );
    }

    return WanzoScaffold(
      currentIndex: 0,
      title: l10n.dashboardScreenTitle,
      // Les actions rapides sont portées par le shell (dock du mode).
      body: _buildDashboardContent(
        context,
        l10n,
        settings,
        displayCurrencyCode,
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    AppLocalizations l10n,
    Settings settings,
    String displayCurrencyCode,
  ) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, dashboardState) {
        final salesState = context.watch<SalesBloc>().state;
        final inventoryState = context.watch<InventoryBloc>().state;

        if (dashboardState is DashboardLoading ||
            (salesState is SalesLoading && salesState is! SalesLoaded)) {
          return Center(
            child: CircularProgressIndicator(
              semanticsLabel: l10n.commonLoading,
            ),
          );
        }

        if (dashboardState is DashboardError) {
          return Center(
            child: Text('${l10n.commonError}: ${dashboardState.message}'),
          );
        }

        if (salesState is SalesError && dashboardState is! DashboardError) {
          return Center(
            child: Text(
              '${l10n.commonErrorDataUnavailable}: ${salesState.message}',
            ),
          );
        }
        if (dashboardState is DashboardLoaded) {
          // Récupérer les valeurs de stock depuis l'inventaire
          double stockValueAtCost = 0.0;
          double stockValueAtSalePrice = 0.0;
          double potentialProfit = 0.0;

          if (inventoryState is ProductsLoaded) {
            stockValueAtCost = inventoryState.totalInventoryValueInCdf;
            stockValueAtSalePrice =
                inventoryState.totalInventoryValueAtSalePrice;
            potentialProfit = inventoryState.potentialProfit;
          }

          final kpiData = KpiData(
            salesTodayCdf: dashboardState.salesTodayCdf,
            salesTodayUsd: dashboardState.salesTodayUsd,
            clientsServed: dashboardState.clientsServedToday,
            receivables: dashboardState.receivables,
            expenses: dashboardState.expenses,
            expensesCdf: dashboardState.expensesCdf,
            expensesUsd: dashboardState.expensesUsd,
            stockValueAtCost: stockValueAtCost,
            stockValueAtSalePrice: stockValueAtSalePrice,
            potentialProfit: potentialProfit,
          );

          List<Sale> recentSales = [];
          if (salesState is SalesLoaded) {
            recentSales = salesState.sales;
          }

          return RefreshIndicator(
            onRefresh: () async {
              final now = DateTime.now();
              _dashboardBloc.add(LoadDashboardData(date: now));
              _salesBloc.add(
                LoadSalesByDateRange(
                  startDate: now.subtract(const Duration(days: 365)),
                  endDate: now,
                ),
              );
              _expenseBloc.add(
                LoadExpensesByDateRange(
                  now.subtract(const Duration(days: 365)),
                  now,
                ),
              );
              _operationJournalBloc.add(
                LoadOperations(
                  startDate: DateTime(now.year, now.month, 1),
                  endDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
                ),
              );
              // Rafraîchir aussi l'inventaire
              context.read<InventoryBloc>().add(const LoadProducts());
            },
            child: ListView(
              padding: const EdgeInsets.all(WanzoSpacing.md),
              children: [
                _buildResponsiveKpiAndChart(
                  context,
                  kpiData,
                  recentSales,
                  l10n,
                  displayCurrencyCode,
                ),
                const SizedBox(height: WanzoSpacing.lg),
                DashboardOperationsJournal(
                  displayCurrencyCode: displayCurrencyCode,
                  onExpand: _expandOperationsJournal,
                ),
              ],
            ),
          );
        }
        // Fallback for any other unhandled state (e.g., initial state or if dashboardState is not DashboardLoaded)
        return Center(child: Text(l10n.commonLoading));
      },
    );
  }

  /// Les six vignettes du tableau de bord Général, puis la courbe en dessous.
  ///
  /// Les deux devises sont TOUJOURS montrees cote a cote, comme dans l'app
  /// Gestion d'actifs : le CDF (devise de base OHADA) et l'USD REELLEMENT
  /// encaisse ou depense en dollars. [KpiGrid] pose les six sur une rangee
  /// sur desktop large, en 3 colonnes sur fenetre etroite, sans jamais etirer.
  Widget _buildResponsiveKpiAndChart(
    BuildContext context,
    KpiData kpiData,
    List<Sale> recentSales,
    AppLocalizations l10n,
    String displayCurrencyCode,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KpiGrid(
          detailsLabel: l10n.dashboardCardViewDetails,
          tiles: generalKpiTiles(
            kpiData,
            revenueLabel: ModeVocabulary.current.revenue,
            receivablesColor: Theme.of(context).colorScheme.primary,
            onReceivables: () => context.go('/sales?filtre=a_encaisser'),
          ),
        ),
        const SizedBox(height: WanzoSpacing.md),
        DashboardSalesExpenseChart(
          sales: recentSales,
          isExpanded: _isChartExpanded,
          onToggleExpansion: () {
            setState(() {
              _isChartExpanded = !_isChartExpanded;
            });
          },
          // Données stock et clients pour le mode étendu
          stockValueAtCost: kpiData.stockValueAtCost,
          stockValueAtSalePrice: kpiData.stockValueAtSalePrice,
          potentialProfit: kpiData.potentialProfit,
          clientsServed: kpiData.clientsServed,
        ),
      ],
    );
  }
}
