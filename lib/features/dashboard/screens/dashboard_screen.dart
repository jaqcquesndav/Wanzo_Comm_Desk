import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wanzo/core/shared_widgets/kpi_board.dart';
import '../utils/open_journal_operation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/core/services/currency_service.dart';
import 'package:intl/intl.dart';
import 'package:wanzo/l10n/app_localizations.dart'; // Corrected import path

import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:wanzo/features/dashboard/bloc/operation_journal_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/features/dashboard/models/journal_filter.dart';
import 'package:wanzo/features/cash_session/cash_access.dart';
import 'package:wanzo/features/sales/bloc/sales_bloc.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/settings/bloc/settings_bloc.dart';
import 'package:wanzo/features/settings/bloc/settings_state.dart';
import 'package:wanzo/features/settings/models/settings.dart';
import 'package:wanzo/constants/spacing.dart';
import 'package:wanzo/constants/border_radius.dart';
import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/features/dashboard/models/operation_journal_entry.dart'; // Import for OperationTypeUIIcon
import 'package:wanzo/services/journal_export_service.dart';
import 'package:wanzo/features/auth/bloc/auth_bloc.dart';
import 'package:wanzo/features/expenses/bloc/expense_bloc.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/features/dashboard/widgets/expense_chart_widget.dart';
import 'package:wanzo/features/inventory/bloc/inventory_bloc.dart';
import 'package:wanzo/features/inventory/bloc/inventory_event.dart';
import 'package:wanzo/features/inventory/bloc/inventory_state.dart';
import 'package:wanzo/core/services/sync_service.dart';
import 'package:get_it/get_it.dart';
import 'package:wanzo/core/modules/mode_vocabulary.dart';
import 'package:wanzo/core/utils/desktop_modal.dart';

enum _ExpandedView { none, operationsJournal }

/// Sortie du PDF du journal : aperçu avant impression (usage desktop), fichier
/// enregistré à l'endroit choisi, ou partage système.
enum _JournalPdfAction { print, save, share }

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

/// Vignettes du tableau de bord Général, par paires CDF | USD.
///
/// Le CDF est la devise de base (OHADA) ; l'USD est le montant REELLEMENT
/// enregistre en dollars (ventes et depenses saisies en USD), jamais une
/// conversion du CDF. Les deux devises sont toujours montrees, comme dans
/// l'app Assets, pour suivre l'USD de bout en bout.
List<KpiTile> generalKpiTiles(
  KpiData kpiData, {
  required String revenueLabel,
  required Color receivablesColor,
  VoidCallback? onReceivables,
}) {
  return [
    // Chiffre d'affaires du jour : CDF | USD.
    KpiTile(
      weight: KpiWeight.pilote,
      label: '$revenueLabel (CDF)',
      value: formatCurrency(kpiData.salesTodayCdf, 'CDF'),
      secondary: 'Chiffre d\'affaires',
      icon: Icons.trending_up,
      color: Colors.green,
    ),
    KpiTile(
      weight: KpiWeight.pilote,
      label: '$revenueLabel (USD)',
      value: formatCurrency(kpiData.salesTodayUsd, 'USD'),
      secondary: 'Chiffre d\'affaires',
      icon: Icons.trending_up,
      color: Colors.green,
    ),
    // Charges du jour : CDF | USD.
    KpiTile(
      weight: KpiWeight.pilote,
      label: 'Charges (CDF)',
      value: formatCurrency(kpiData.expensesCdf, 'CDF'),
      secondary: 'Dépenses engagées',
      icon: Icons.trending_down,
      color: Colors.red,
    ),
    KpiTile(
      weight: KpiWeight.pilote,
      label: 'Charges (USD)',
      value: formatCurrency(kpiData.expensesUsd, 'USD'),
      secondary: 'Dépenses engagées',
      icon: Icons.trending_down,
      color: Colors.red,
    ),
    KpiTile(
      label: 'Valeur du stock',
      value: formatCurrency(kpiData.stockValueAtCost, 'CDF'),
      icon: Icons.inventory_2,
      color: Colors.blueGrey,
    ),
    // Benefice potentiel du stock : sa propre vignette (une vignette de suivi
    // porte un chiffre seul ; en sous-ligne il debordait a grande police).
    if (kpiData.stockValueAtCost > 0)
      KpiTile(
        label: 'Bénéfice potentiel',
        value: '+${formatCurrency(kpiData.potentialProfit, 'CDF')}',
        icon: Icons.savings_outlined,
        color: Colors.green,
      ),
    KpiTile(
      label: 'À encaisser',
      value: formatCurrency(kpiData.receivables, 'CDF'),
      icon: Icons.schedule_send,
      color: receivablesColor,
      // Ouvre les ventes a encaisser (non payees ou partielles).
      onTap: onReceivables,
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
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  _ExpandedView _expandedView = _ExpandedView.none;
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

  /// Lignes affichées dans le journal agrandi, augmentées par « Charger plus ».
  static const int _journalPageSize = 100;
  int _journalLimit = _journalPageSize;

  void _expandOperationsJournal() {
    setState(() {
      _expandedView = _ExpandedView.operationsJournal;
      _journalLimit = _journalPageSize;
    });
  }

  void _collapseView() {
    setState(() {
      _expandedView = _ExpandedView.none;
    });
  }

  /// Exporte les opérations du journal (filtre actif) en PDF
  void _exportJournalOperations(
    BuildContext context,
    OperationJournalLoaded journalState,
    _JournalPdfAction action,
  ) async {
    try {
      // Affichage d'un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Génération du PDF en cours...'),
                ],
              ),
            ),
      );

      // Récupération de l'utilisateur actuel
      final authState = context.read<AuthBloc>().state;
      final currentUser =
          authState is AuthAuthenticated ? authState.user : null;

      // Utilisation du filtre actif ou filtre par défaut
      final activeFilter =
          journalState.activeFilter ?? JournalFilter.defaultFilter();

      final currencyService = _currencyServiceOf(context);
      String? successMessage;
      switch (action) {
        case _JournalPdfAction.print:
          await JournalExportService.exportAndPrint(
            operations: journalState.operations,
            filter: activeFilter,
            currentUser: currentUser,
            currencyService: currencyService,
          );
          break;
        case _JournalPdfAction.save:
          final path = await JournalExportService.exportAndSave(
            operations: journalState.operations,
            filter: activeFilter,
            currentUser: currentUser,
            currencyService: currencyService,
          );
          if (path != null) successMessage = 'Journal enregistré : $path';
          break;
        case _JournalPdfAction.share:
          await JournalExportService.exportAndShare(
            operations: journalState.operations,
            filter: activeFilter,
            currentUser: currentUser,
            currencyService: currencyService,
          );
          break;
      }

      // Fermeture de l'indicateur de chargement
      if (context.mounted) {
        Navigator.of(context).pop();
        if (successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Fermeture de l'indicateur de chargement en cas d'erreur
      if (context.mounted) {
        Navigator.of(context).pop();

        // Message d'erreur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération du PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildExpandedView({
    required String title,
    required Widget content,
    required VoidCallback onCollapse,
    bool isJournal = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final settingsState = context.watch<SettingsBloc>().state;
    if (settingsState is! SettingsLoaded && settingsState is! SettingsUpdated) {
      return WanzoScaffold(
        currentIndex: 0,
        title: title,
        onBackPressed: onCollapse,
        body: Center(child: Text(l10n.commonLoading)),
      );
    }

    List<Widget> actions = [];
    if (isJournal) {
      actions.addAll([
        // Bouton pour filtres rapides
        IconButton(
          icon: const Icon(Icons.filter_list),
          tooltip: 'Filtres rapides',
          onPressed: () => _showQuickFilters(context, l10n),
        ),
        // Bouton pour filtres de période (ancien PopupMenuButton)
        PopupMenuButton<String>(
          icon: const Icon(Icons.calendar_month_rounded),
          tooltip: 'Filtrer par période',
          onSelected: (value) {
            DateTime now = DateTime.now();
            DateTime startDate = now;
            DateTime endDate = now;

            if (value == 'today') {
              startDate = DateTime(now.year, now.month, now.day);
              endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
            } else if (value == 'this_month') {
              startDate = DateTime(now.year, now.month, 1);
              endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
            } else if (value == 'this_year') {
              startDate = DateTime(now.year, 1, 1);
              endDate = DateTime(now.year, 12, 31, 23, 59, 59);
            } else if (value == 'custom') {
              _selectDateRangeInternal(context, l10n, (start, end) {
                if (!mounted) return;
                _operationJournalBloc.add(
                  FilterPeriodChanged(newStartDate: start, newEndDate: end),
                );
              });
              return;
            } else {
              return;
            }
            _operationJournalBloc.add(
              FilterPeriodChanged(newStartDate: startDate, newEndDate: endDate),
            );
          },
          itemBuilder:
              (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'today',
                  child: Text(l10n.commonToday),
                ),
                PopupMenuItem<String>(
                  value: 'this_month',
                  child: Text(l10n.commonThisMonth),
                ),
                PopupMenuItem<String>(
                  value: 'this_year',
                  child: Text(l10n.commonThisYear),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'custom',
                  child: Text(l10n.commonCustom),
                ),
              ],
        ),
        // Un seul export : le PDF des opérations affichées (filtre actif).
        BlocBuilder<OperationJournalBloc, OperationJournalState>(
          builder: (context, journalState) {
            final hasData =
                journalState is OperationJournalLoaded &&
                journalState.operations.isNotEmpty;
            return PopupMenuButton<_JournalPdfAction>(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: l10n.dashboardJournalExportExportButton,
              enabled: hasData,
              onSelected: (action) {
                if (journalState is OperationJournalLoaded) {
                  _exportJournalOperations(context, journalState, action);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _JournalPdfAction.print,
                  child: ListTile(
                    leading: Icon(Icons.print_outlined),
                    title: Text('Aperçu et impression'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _JournalPdfAction.save,
                  child: ListTile(
                    leading: Icon(Icons.save_alt),
                    title: Text('Enregistrer le PDF'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _JournalPdfAction.share,
                  child: ListTile(
                    leading: Icon(Icons.share_outlined),
                    title: Text('Partager'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            );
          },
        ),
      ]);
    }

    // Shell de l'application conservé (navigation, barre) avec un retour vers
    // le tableau de bord.
    return WanzoScaffold(
      currentIndex: 0,
      title: title,
      appBarActions: actions,
      onBackPressed: onCollapse,
      body: Padding(
        padding: const EdgeInsets.all(WanzoSpacing.md),
        child: content,
      ),
    );
  }

  Future<void> _selectDateRangeInternal(
    BuildContext context,
    AppLocalizations l10n,
    Function(DateTime, DateTime) onRangeSelected,
  ) async {
    final locale = Localizations.localeOf(context);
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start:
            _selectedStartDate ??
            DateTime.now().subtract(const Duration(days: 7)),
        end: _selectedEndDate ?? DateTime.now(),
      ),
      helpText: l10n.dashboardJournalExportSelectDateRangeTitle,
      cancelText: l10n.commonCancel.toUpperCase(),
      confirmText: l10n.commonConfirm.toUpperCase(),
      locale: locale,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            // Customizations if needed
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final endDate = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
      );
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = endDate;
      });
      onRangeSelected(picked.start, endDate);
    }
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

    if (_expandedView != _ExpandedView.none) {
      String title;
      Widget content;
      bool isJournal = false;

      // Seul le Journal des Opérations reste
      title = l10n.dashboardOperationsJournalTitle;
      isJournal = true;
      content = _buildOperationsJournal(
        context,
        true,
        l10n,
        displayCurrencyCode,
      );

      return _buildExpandedView(
        title: title,
        content: content,
        onCollapse: _collapseView,
        isJournal: isJournal,
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
                _buildTabbedRecentSalesAndJournal(
                  context,
                  recentSales,
                  l10n,
                  displayCurrencyCode,
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

  /// Indicateurs du tableau de bord Général, puis la courbe en dessous.
  ///
  /// Les deux devises sont TOUJOURS montrees cote a cote, comme dans l'app
  /// Assets : le CDF (devise de base OHADA) et l'USD REELLEMENT encaisse ou
  /// depense en dollars (ventes et depenses saisies en USD, jamais une
  /// conversion). Chiffre d'affaires et charges en tete, par paires CDF | USD ;
  /// [KpiBoard] n'etire jamais les vignettes sur grand ecran.
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
        KpiBoard(
          tiles: generalKpiTiles(
            kpiData,
            revenueLabel: ModeVocabulary.current.revenue,
            receivablesColor: Theme.of(context).colorScheme.primary,
            onReceivables: () => context.go('/sales?filtre=a_encaisser'),
          ),
        ),
        const SizedBox(height: WanzoSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 250),
          child: _buildCombinedChart(context, recentSales, l10n, kpiData),
        ),
      ],
    );
  }

  Widget _buildCombinedChart(
    BuildContext context,
    List<Sale> recentSales,
    AppLocalizations l10n,
    KpiData kpiData,
  ) {
    return BlocBuilder<ExpenseBloc, ExpenseState>(
      builder: (context, expenseState) {
        final expenses =
            expenseState is ExpensesLoaded
                ? expenseState.expenses
                : <Expense>[];

        return SalesExpenseChartWidget(
          sales: recentSales,
          expenses: expenses,
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
        );
      },
    );
  }

  Widget _buildTabbedRecentSalesAndJournal(
    BuildContext context,
    List<Sale> recentSales,
    AppLocalizations l10n,
    String displayCurrencyCode,
  ) {
    return DefaultTabController(
      length: 1, // Seulement 1 onglet maintenant
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(
                text: l10n.dashboardOperationsJournalTitle,
              ), // Seul onglet restant
            ],
          ),
          SizedBox(
            // Hauteur ajustée pour un seul onglet
            height: 420,
            child: TabBarView(
              children: [
                _buildOperationsJournal(
                  context,
                  false,
                  l10n,
                  displayCurrencyCode,
                ), // Seul contenu
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsJournal(
    BuildContext context,
    bool isExpanded,
    AppLocalizations l10n,
    String displayCurrencyCode,
  ) {
    final locale = Localizations.localeOf(context).languageCode;
    final DateFormat dateFormat = DateFormat.yMd(locale);
    final DateFormat timeFormat = DateFormat.Hm(locale);

    // Vue miniature pour le dashboard avec limitation de hauteur stricte
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(
        vertical: 4.0,
      ), // Marge verticale réduite
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WanzoSpacing.sm), // Padding réduit
        child: Column(
          mainAxisSize:
              MainAxisSize.min, // Important: minimize vertical space usage
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.dashboardOperationsJournalTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bouton de filtrage rapide
                    IconButton(
                      icon: const Icon(Icons.filter_list, size: 20),
                      onPressed: () => _showQuickFilters(context, l10n),
                      tooltip: 'Filtres rapides',
                    ),
                    // Bouton "Voir tout" / "Fermer" avec texte responsif
                    TextButton(
                      onPressed: () {
                        if (_expandedView == _ExpandedView.operationsJournal) {
                          _collapseView();
                        } else {
                          _expandOperationsJournal();
                        }
                      },
                      child: Text(
                        _expandedView == _ExpandedView.operationsJournal
                            ? 'Fermer'
                            : (MediaQuery.of(context).size.width < 600
                                ? 'Tout'
                                : l10n.dashboardOperationsJournalViewAll),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4), // Espace réduit
            // Période et vue en vigueur : ce que l'export reprendra.
            BlocBuilder<OperationJournalBloc, OperationJournalState>(
              buildWhen: (_, s) => s is OperationJournalLoaded,
              builder: (context, journalState) {
                if (journalState is! OperationJournalLoaded) {
                  return const SizedBox.shrink();
                }
                final view = journalState.activeFilter?.view ?? JournalView.all;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${view.label} · ${dateFormat.format(journalState.startDate)} au ${dateFormat.format(journalState.endDate)}'
                    ' · ${journalState.operations.length} opération(s)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
            BlocBuilder<OperationJournalBloc, OperationJournalState>(
              builder: (context, journalState) {
                if (journalState is OperationJournalLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: l10n.commonLoading,
                    ),
                  );
                } else if (journalState is OperationJournalError) {
                  return Center(
                    child: Text('${l10n.commonError}: ${journalState.message}'),
                  );
                } else if (journalState is OperationJournalLoaded) {
                  if (journalState.operations.isEmpty) {
                    return SizedBox(
                      height: isExpanded ? 200 : 100,
                      child: Center(
                        child: Text(
                          l10n.dashboardOperationsJournalNoData,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    );
                  }
                  // Limiter aux 10 dernières opérations pour la vue en miniature
                  // En mode étendu, limiter à 100 entrées maximum pour éviter les problèmes de performance et d'overflow
                  // Plus récentes d'abord ; la vue agrandie se déroule par
                  // pages (« Charger plus »).
                  final sorted = [...journalState.operations]
                    ..sort((a, b) => b.date.compareTo(a.date));
                  final entriesToShow =
                      isExpanded
                          ? sorted.take(_journalLimit).toList()
                          : sorted.take(10).toList();

                  final hasMoreEntries =
                      (!isExpanded && sorted.length > 10) ||
                      (isExpanded && sorted.length > _journalLimit);

                  return isExpanded
                      ? SizedBox(
                        height:
                            MediaQuery.of(context).size.height *
                            0.75, // Utilisez plus de hauteur d'écran (75%)
                        child: Column(
                          children: [
                            Expanded(
                              child: _buildOperationsDataTable(
                                context,
                                entriesToShow,
                                displayCurrencyCode,
                                l10n,
                                dateFormat,
                                timeFormat,
                                isExpanded: true,
                              ),
                            ),
                            if (hasMoreEntries)
                              TextButton.icon(
                                onPressed: () => setState(
                                  () => _journalLimit += _journalPageSize,
                                ),
                                icon: const Icon(Icons.expand_more),
                                label: Text(
                                  'Charger plus '
                                  '(${entriesToShow.length} sur ${sorted.length})',
                                ),
                              ),
                          ],
                        ),
                      )
                      : SizedBox(
                        height:
                            300, // Hauteur fixe pour le mode réduit, plus petite que précédemment
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: _buildOperationsDataTable(
                                context,
                                entriesToShow,
                                displayCurrencyCode,
                                l10n,
                                dateFormat,
                                timeFormat,
                                isExpanded: false,
                              ),
                            ),
                            if (hasMoreEntries)
                              SizedBox(
                                // SizedBox plus petit pour réduire la hauteur
                                height: 30,
                                child: InkWell(
                                  onTap: _expandOperationsJournal,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4.0,
                                    ), // Padding vertical réduit
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.expand_more,
                                          size: 14,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Voir plus d\'opérations',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize:
                                                11, // Taille de texte réduite
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                }
                return Center(child: Text(l10n.commonErrorDataUnavailable));
              },
            ),
          ],
        ), // Closes Column
      ), // Closes Padding
    ); // Closes Card
  }

  /// Construit un DataTable pour afficher les opérations du journal
  Widget _buildOperationsDataTable(
    BuildContext context,
    List<OperationJournalEntry> entries,
    String displayCurrencyCode,
    AppLocalizations l10n,
    DateFormat dateFormat,
    DateFormat timeFormat, {
    required bool isExpanded,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: isCompact ? 12 : 20,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 48,
                headingRowHeight: 40,
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                columns: [
                  const DataColumn(label: Text('')), // Icône
                  const DataColumn(label: Text('Description')),
                  if (!isCompact) const DataColumn(label: Text('Type')),
                  const DataColumn(label: Text('Date')),
                  const DataColumn(label: Text('Montant'), numeric: true),
                  if (!isCompact)
                    DataColumn(
                      label: Text(l10n.dashboardOperationsJournalBalanceLabel),
                      numeric: true,
                    ),
                ],
                rows:
                    entries.map((entry) {
                      final effectiveCurrencyCode =
                          entry.currencyCode ?? 'CDF'; // sans code : base CDF
                      String amountDisplay;
                      Color amountColor;

                      if (entry.isDebit) {
                        amountDisplay =
                            "- ${formatCurrency(entry.amount.abs(), effectiveCurrencyCode)}";
                        amountColor = Colors.redAccent;
                      } else if (entry.isCredit) {
                        amountDisplay =
                            "+ ${formatCurrency(entry.amount.abs(), effectiveCurrencyCode)}";
                        amountColor = Colors.green;
                      } else {
                        amountDisplay = formatCurrency(
                          entry.amount,
                          effectiveCurrencyCode,
                        );
                        amountColor = Theme.of(context).colorScheme.onSurface;
                      }

                      return DataRow(
                        // Une ligne du journal reflète un document : on l'ouvre
                        // (vente, dépense, produit) ; sans pièce, un message le
                        // dit, jamais de clic muet.
                        onSelectChanged: (_) {
                          openJournalOperationDocument(context, entry);
                        },
                        cells: [
                          DataCell(
                            Icon(
                              entry.type.icon,
                              size: 18,
                              color:
                                  entry.isDebit
                                      ? Colors.redAccent
                                      : Colors.green,
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isCompact ? 120 : 200,
                              ),
                              child: Text(
                                entry.description,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                          if (!isCompact)
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (entry.isDebit
                                          ? Colors.redAccent
                                          : Colors.green)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  entry.type.displayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        entry.isDebit
                                            ? Colors.redAccent
                                            : Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          DataCell(
                            Text(
                              "${dateFormat.format(entry.date)} ${timeFormat.format(entry.date)}",
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(
                            Text(
                              amountDisplay,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: amountColor,
                              ),
                            ),
                          ),
                          if (!isCompact)
                            DataCell(
                              // Solde de caisse tenu dans la devise de la
                              // ligne : jamais affiché sous un autre code.
                              Text(
                                entry.cashBalance == null
                                    ? '-'
                                    : formatCurrency(
                                      entry.cashBalance!,
                                      effectiveCurrencyCode,
                                    ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Affiche les filtres rapides pour le journal des opérations
  void _showQuickFilters(BuildContext context, AppLocalizations l10n) {
    final current = context.read<OperationJournalBloc>().currentFilter;
    showDesktopModal(
      context,
      title: 'Filtres du journal',
      contentPadding: EdgeInsets.zero,
      builder:
          (sheetContext) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(WanzoSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vue',
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: WanzoSpacing.sm),
                  // Tout, Caisse (espèces) ou Comptabilité : la période
                  // affichée est conservée, l'export suit.
                  Wrap(
                    spacing: WanzoSpacing.sm,
                    runSpacing: WanzoSpacing.sm,
                    children: [
                      for (final view in visibleJournalViews(canSeeCash(context)))
                        ChoiceChip(
                          label: Text(view.label),
                          tooltip: view.hint,
                          selected:
                              current.view == view &&
                              current.selectedTypes.isEmpty,
                          onSelected: (_) {
                            _applyQuickFilter(
                              context,
                              JournalFilter.forView(view),
                            );
                            Navigator.pop(sheetContext);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: WanzoSpacing.md),
                  Text(
                    'Type',
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: WanzoSpacing.sm),
                  Wrap(
                    spacing: WanzoSpacing.sm,
                    runSpacing: WanzoSpacing.sm,
                    children: [
                      _buildQuickFilterChip(context, ModeVocabulary.current.sales, () {
                        _applyQuickFilter(context, JournalFilter.salesOnly());
                        Navigator.pop(sheetContext);
                      }),
                      _buildQuickFilterChip(context, ModeVocabulary.current.stock, () {
                        _applyQuickFilter(context, JournalFilter.stockOnly());
                        Navigator.pop(sheetContext);
                      }),
                      _buildQuickFilterChip(context, 'Dépenses', () {
                        _applyQuickFilter(context, JournalFilter.expensesOnly());
                        Navigator.pop(sheetContext);
                      }),
                      _buildQuickFilterChip(context, 'Dettes', () {
                        _applyQuickFilter(context, JournalFilter.customerDebts());
                        Navigator.pop(sheetContext);
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildQuickFilterChip(
    BuildContext context,
    String label,
    VoidCallback onPressed,
  ) {
    return ActionChip(
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _applyQuickFilter(BuildContext context, JournalFilter filter) {
    // Appliquer le filtre au bloc du journal des opérations
    context.read<OperationJournalBloc>().add(
      LoadOperationsWithFilter(filter: filter),
    );
  }
}

/// Taux de la société fournis par l'application (null s'ils sont absents) :
/// les PDF du journal consolident leurs totaux en CDF avec ces taux.
CurrencyService? _currencyServiceOf(BuildContext context) {
  try {
    return context.read<CurrencyService>();
  } catch (_) {
    return null;
  }
}
