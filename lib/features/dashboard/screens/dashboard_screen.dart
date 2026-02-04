import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wanzo/l10n/app_localizations.dart'; // Corrected import path

import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:wanzo/features/dashboard/bloc/operation_journal_bloc.dart';
import 'package:wanzo/features/dashboard/services/journal_service.dart';
import 'package:wanzo/features/dashboard/models/journal_filter.dart';
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
import 'package:wanzo/features/dashboard/widgets/operations_dock.dart';

enum _ExpandedView { none, operationsJournal }

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
  late JournalService _journalService;
  late DashboardBloc _dashboardBloc;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  _ExpandedView _expandedView = _ExpandedView.none;
  bool _isChartExpanded = false;

  // Souscription pour écouter les changements de dépenses
  StreamSubscription? _expenseSubscription;

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
    _journalService = JournalService();

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
  }

  @override
  void dispose() {
    // Annuler la souscription pour éviter les fuites de mémoire
    _expenseSubscription?.cancel();
    super.dispose();
  }

  void _expandOperationsJournal() {
    setState(() {
      _expandedView = _ExpandedView.operationsJournal;
    });
  }

  void _collapseView() {
    setState(() {
      _expandedView = _ExpandedView.none;
    });
  }

  /// Exporte les opérations du journal en PDF
  void _exportJournalOperations(
    BuildContext context,
    OperationJournalLoaded journalState,
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

      // Export du PDF - on laisse les paramètres de l'entreprise être récupérés du service
      await JournalExportService.exportAndShare(
        operations: journalState.operations,
        filter: activeFilter,
        currentUser: currentUser,
      );

      // Fermeture de l'indicateur de chargement
      if (context.mounted) {
        Navigator.of(context).pop();

        // Message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF généré et partagé avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
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

    Settings settings;
    if (settingsState is SettingsLoaded) {
      settings = settingsState.settings;
    } else if (settingsState is SettingsUpdated) {
      settings = settingsState.settings;
    } else {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
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
        IconButton(
          icon: const Icon(Icons.picture_as_pdf),
          tooltip: l10n.dashboardJournalExportExportButton,
          onPressed: () {
            _exportOperationsJournalToPdfInternal(context, l10n, settings);
          },
        ),
        // IconButton(
        //   icon: const Icon(Icons.print),
        //   tooltip: l10n.dashboardJournalExportPrintButton, // This key exists
        //   onPressed: () {
        //     // _printOperationsJournalInternal(context, l10n, settings); // Kept commented
        //   },
        // ),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onCollapse,
        ),
        actions: actions,
      ),
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

  Future<void> _exportOperationsJournalToPdfInternal(
    BuildContext context,
    AppLocalizations l10n,
    Settings settings,
  ) async {
    final journalState = _operationJournalBloc.state;

    if (journalState is OperationJournalLoaded) {
      if (_selectedStartDate == null || _selectedEndDate == null) {
        await _selectDateRangeInternal(context, l10n, (start, end) async {
          if (!mounted) return;
          final file = await _journalService.generateJournalPdf(
            journalState.operations,
            start,
            end,
            journalState.openingCashBalances['CDF'] ?? 0.0,
            l10n,
            settings,
          );
          if (!mounted) return;
          // Utiliser le context actuel car mounted a été vérifié
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                file != null
                    ? l10n.dashboardJournalExportSuccessMessage
                    : l10n.dashboardJournalExportFailureMessage,
              ),
            ),
          );
        });
      } else {
        if (!mounted) return;
        final file = await _journalService.generateJournalPdf(
          journalState.operations,
          _selectedStartDate!,
          _selectedEndDate!,
          journalState.openingCashBalances['CDF'] ?? 0.0,
          l10n,
          settings,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              file != null
                  ? l10n.dashboardJournalExportSuccessMessage
                  : l10n.dashboardJournalExportFailureMessage,
            ),
          ),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.dashboardJournalExportNoDataForPeriod)),
      );
    }
  }

  // Future<void> _printOperationsJournalInternal(BuildContext context, AppLocalizations l10n, Settings settings) async {
  //   final journalState = _operationJournalBloc.state;
  //   if (journalState is OperationJournalLoaded) {
  //      if (_selectedStartDate == null || _selectedEndDate == null) {
  //       await _selectDateRangeInternal(context, l10n, (start, end) async {
  //         if (!mounted) return; // Check mounted
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(content: Text(l10n.dashboardJournalExportPrintingMessage)),
  //         );
  //         // await _journalService.printJournalPdf( // Method does not exist
  //         //   journalState.operations,
  //         //   start,
  //         //   end,
  //         //   journalState.openingBalance,
  //         //   l10n,
  //         //   settings
  //         // );
  //       });
  //     } else {
  //       if (!mounted) return; // Check mounted
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text(l10n.dashboardJournalExportPrintingMessage)),
  //       );
  //       // await _journalService.printJournalPdf( // Method does not exist
  //       //   journalState.operations,
  //       //   _selectedStartDate!,
  //       //   _selectedEndDate!,
  //       //   journalState.openingBalance,
  //       //   l10n,
  //       //   settings
  //       // );
  //     }
  //   } else {
  //     if (!mounted) return; // Check mounted
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(l10n.dashboardJournalExportNoDataForPeriod)),
  //     );
  //   }
  // }

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
      body: Stack(
        children: [
          // Contenu principal du dashboard
          _buildDashboardContent(context, l10n, settings, displayCurrencyCode),
          // Dock des opérations rapides en bas au centre
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(child: OperationsDock()),
          ),
        ],
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

  /// Construit la disposition responsive des KPI et du graphique
  /// - Mode portrait : Grille adaptative de KPI puis graphique en dessous
  /// - Mode paysage/desktop : KPI à gauche, graphique à droite
  Widget _buildResponsiveKpiAndChart(
    BuildContext context,
    KpiData kpiData,
    List<Sale> recentSales,
    AppLocalizations l10n,
    String displayCurrencyCode,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        // Breakpoints pour le layout
        const double mobileBreakpoint = 400;
        const double tabletBreakpoint = 700;
        const double desktopBreakpoint = 1000;

        // Taille minimale d'une carte KPI
        const double minCardWidth = 140;
        const double maxCardWidth = 200;

        // Déterminer le nombre de colonnes dynamiquement
        int crossAxisCount;
        double cardAspectRatio;

        if (availableWidth < mobileBreakpoint) {
          // Très petit écran: 1 colonne
          crossAxisCount = 1;
          cardAspectRatio = 3.0;
        } else if (availableWidth < tabletBreakpoint) {
          // Mobile: 2 colonnes
          crossAxisCount = 2;
          cardAspectRatio = 1.8;
        } else if (availableWidth < desktopBreakpoint) {
          // Tablet: 3 colonnes
          crossAxisCount = 3;
          cardAspectRatio = 1.5;
        } else {
          // Desktop: 5 colonnes (toutes les cartes sur une ligne)
          crossAxisCount = 5;
          cardAspectRatio = 1.3;
        }

        final kpiCards = [
          // 1. Ventes USD
          _buildResponsiveStatCard(
            context,
            title: '${l10n.dashboardHeaderSalesToday} (USD)',
            value: formatCurrency(kpiData.salesTodayUsd, 'USD'),
            icon: Icons.monetization_on,
            color: Colors.blue,
            l10n: l10n,
            isCompact: availableWidth < mobileBreakpoint,
          ),
          // 2. Ventes CDF
          _buildResponsiveStatCard(
            context,
            title: '${l10n.dashboardHeaderSalesToday} (CDF)',
            value: formatCurrency(kpiData.salesTodayCdf, 'CDF'),
            icon: Icons.monetization_on,
            color: Colors.green,
            l10n: l10n,
            isCompact: availableWidth < mobileBreakpoint,
          ),
          // 3. Dépenses USD
          _buildResponsiveStatCard(
            context,
            title: 'Dépenses (USD)',
            value: formatCurrency(kpiData.expensesUsd, 'USD'),
            icon: Icons.money_off,
            color: Colors.red.shade300,
            l10n: l10n,
            isCompact: availableWidth < mobileBreakpoint,
          ),
          // 4. Dépenses CDF
          _buildResponsiveStatCard(
            context,
            title: 'Dépenses (CDF)',
            value: formatCurrency(kpiData.expensesCdf, 'CDF'),
            icon: Icons.money_off,
            color: Colors.red,
            l10n: l10n,
            isCompact: availableWidth < mobileBreakpoint,
          ),
          // 5. Valeur Stock
          _buildResponsiveStatCard(
            context,
            title: 'Valeur Stock',
            value: formatCurrency(kpiData.stockValueAtCost, 'CDF'),
            icon: Icons.inventory_2,
            color: Colors.orange,
            l10n: l10n,
            subtitle:
                kpiData.stockValueAtCost > 0
                    ? '+${formatCurrency(kpiData.potentialProfit, 'CDF')} potentiel'
                    : null,
            isCompact: availableWidth < mobileBreakpoint,
          ),
        ];

        // Layout desktop large: graphique à gauche, KPI à droite
        if (availableWidth >= desktopBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Graphique à gauche avec contraintes minimales
              Expanded(
                flex: 2,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 300,
                    minHeight: 280,
                  ),
                  child: _buildCombinedChart(
                    context,
                    recentSales,
                    l10n,
                    kpiData,
                  ),
                ),
              ),
              const SizedBox(width: WanzoSpacing.md),
              // Colonne des KPI à droite
              Expanded(
                flex: 1,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: minCardWidth,
                    maxWidth: maxCardWidth * 1.5,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < kpiCards.length; i++) ...[
                        kpiCards[i],
                        if (i < kpiCards.length - 1)
                          const SizedBox(height: WanzoSpacing.sm),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // Layout mobile/tablet: Grille de KPI puis graphique en dessous
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grille adaptative des KPI
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: WanzoSpacing.sm,
                crossAxisSpacing: WanzoSpacing.sm,
                childAspectRatio: cardAspectRatio,
              ),
              itemCount: kpiCards.length,
              itemBuilder: (context, index) => kpiCards[index],
            ),
            const SizedBox(height: WanzoSpacing.lg),
            // Graphique avec contraintes minimales
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 250),
              child: _buildCombinedChart(context, recentSales, l10n, kpiData),
            ),
          ],
        );
      },
    );
  }

  /// Carte KPI responsive qui s'adapte à la taille disponible
  Widget _buildResponsiveStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required AppLocalizations l10n,
    String? subtitle,
    bool isCompact = false,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? WanzoSpacing.sm : WanzoSpacing.md,
          vertical: isCompact ? WanzoSpacing.xs : WanzoSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Titre et icône
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isCompact ? 10 : 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Icon(icon, color: color, size: isCompact ? 14 : 16),
              ],
            ),
            SizedBox(height: isCompact ? 2 : WanzoSpacing.xs / 2),
            // Valeur - FittedBox pour éviter l'overflow
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: isCompact ? 14 : 16,
                ),
                maxLines: 1,
              ),
            ),
            // Sous-titre optionnel
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: isCompact ? 8 : 9,
                      color: Colors.green.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            SizedBox(height: isCompact ? 2 : WanzoSpacing.xs / 2),
            // Lien "Voir détails"
            InkWell(
              onTap: () {
                debugPrint('Voir détails pour: $title');
              },
              child: Text(
                l10n.dashboardCardViewDetails,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.primaryColor,
                  fontSize: isCompact ? 9 : 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Ancienne méthode conservée pour compatibilité mais non utilisée
  // ignore: unused_element
  Widget _buildHeaderStats(
    BuildContext context,
    KpiData kpiData,
    AppLocalizations l10n,
    String displayCurrencyCode,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final isWide = mediaQuery.size.width > 600;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final kpiCards = [
      _buildStatCard(
        context,
        title: '${l10n.dashboardHeaderSalesToday} (CDF)',
        value: formatCurrency(kpiData.salesTodayCdf, 'CDF'),
        icon: Icons.monetization_on,
        color: Colors.green,
        l10n: l10n,
      ),
      _buildStatCard(
        context,
        title: '${l10n.dashboardHeaderSalesToday} (USD)',
        value: formatCurrency(kpiData.salesTodayUsd, 'USD'),
        icon: Icons.monetization_on,
        color: Colors.blue,
        l10n: l10n,
      ),
      _buildStatCard(
        context,
        title: 'Valeur Stock',
        value: formatCurrency(kpiData.stockValueAtCost, 'CDF'),
        icon: Icons.inventory_2,
        color: Colors.orange,
        l10n: l10n,
        subtitle:
            kpiData.stockValueAtCost > 0
                ? '+${formatCurrency(kpiData.potentialProfit, 'CDF')} potentiel'
                : null,
      ),
      _buildStatCard(
        context,
        title: 'Dépenses',
        value: formatCurrency(kpiData.expenses, displayCurrencyCode),
        icon: Icons.money_off,
        color: Colors.red,
        l10n: l10n,
      ),
    ];

    if (isWide || isLandscape) {
      // Sur grand écran ou paysage, placer les KPI à gauche et le graphique à droite
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 260,
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              children: [
                ...kpiCards.map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: WanzoSpacing.md),
                    child: card,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: WanzoSpacing.lg),
          Expanded(
            child: SizedBox(
              height: 250,
              child: Center(
                child: Text(
                  'Graphique disponible dans la section principale',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Sur mobile portrait, utiliser Wrap pour éviter l'overflow
      return Wrap(
        spacing: WanzoSpacing.md,
        runSpacing: WanzoSpacing.md,
        children: kpiCards,
      );
    }
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required AppLocalizations l10n,
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WanzoSpacing.md,
          vertical: WanzoSpacing.xs,
        ), // Réduit le padding vertical
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min, // Minimise la taille de la colonne
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 11, // Réduit la taille du titre
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  icon,
                  color: color,
                  size: 16,
                ), // Réduits la taille de l'icône
              ],
            ),
            const SizedBox(
              height: WanzoSpacing.xs / 2,
            ), // Réduit l'espace entre le titre et la valeur
            // Utiliser un SingleChildScrollView horizontal pour les grands nombres
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                value,
                style:
                    value.length > 10
                        ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize:
                              16, // Réduit la taille pour tous les nombres
                        )
                        : Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize:
                              18, // Réduit la taille pour les nombres courts
                        ),
              ),
            ),
            // Sous-titre optionnel (pour le bénéfice potentiel par exemple)
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 9,
                    color: Colors.green.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(
              height: WanzoSpacing.xs / 2,
            ), // Réduit l'espace entre la valeur et le lien
            InkWell(
              onTap: () {
                // Action de navigation désactivée pour l'instant
                debugPrint('Voir détails pour: $title');
              },
              child: Text(
                l10n.dashboardCardViewDetails,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontSize: 10, // Réduit la taille du texte du lien
                ),
              ),
            ),
          ],
        ),
      ),
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
                    // Bouton d'exportation (visible seulement en mode agrandi)
                    if (_expandedView == _ExpandedView.operationsJournal)
                      BlocBuilder<OperationJournalBloc, OperationJournalState>(
                        builder: (context, journalState) {
                          final hasData =
                              journalState is OperationJournalLoaded &&
                              journalState.operations.isNotEmpty;
                          return IconButton(
                            icon: const Icon(Icons.file_download, size: 20),
                            onPressed:
                                hasData
                                    ? () => _exportJournalOperations(
                                      context,
                                      journalState,
                                    )
                                    : null,
                            tooltip: 'Exporter en PDF',
                          );
                        },
                      ),
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
                  final entriesToShow =
                      isExpanded
                          ? journalState.operations.take(100).toList()
                          : journalState.operations.take(10).toList();

                  final hasMoreEntries =
                      (!isExpanded && journalState.operations.length > 10) ||
                      (isExpanded && journalState.operations.length > 100);

                  return isExpanded
                      ? SizedBox(
                        height:
                            MediaQuery.of(context).size.height *
                            0.75, // Utilisez plus de hauteur d'écran (75%)
                        child: ListView.separated(
                          padding:
                              EdgeInsets.zero, // Supprime le padding par défaut
                          shrinkWrap:
                              false, // Don't shrink wrap, let the SizedBox handle the size
                          physics:
                              const AlwaysScrollableScrollPhysics(), // Enable scrolling
                          itemCount: entriesToShow.length,
                          separatorBuilder:
                              (context, index) => const Divider(
                                height: 0,
                                thickness: 1,
                                indent: 72,
                                endIndent: 16,
                              ),
                          itemBuilder: (context, index) {
                            final entry = entriesToShow[index];
                            final entryCurrencyCode =
                                entry.currencyCode ?? displayCurrencyCode;
                            return _buildJournalEntry(
                              context,
                              entry,
                              entryCurrencyCode,
                              displayCurrencyCode,
                              l10n,
                              dateFormat,
                              timeFormat,
                            );
                          },
                        ),
                      )
                      : SizedBox(
                        height:
                            300, // Hauteur fixe pour le mode réduit, plus petite que précédemment
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              // Using Expanded inside fixed height SizedBox for proper constraint
                              child: ListView.separated(
                                padding:
                                    EdgeInsets
                                        .zero, // Supprime le padding par défaut
                                shrinkWrap:
                                    false, // Keep false as we're using Expanded in a fixed height container
                                physics:
                                    const BouncingScrollPhysics(), // Permet le défilement avec effet de rebond
                                itemCount: entriesToShow.length,
                                separatorBuilder:
                                    (context, index) => const Divider(
                                      height: 0,
                                      thickness: 1,
                                      indent: 72,
                                      endIndent: 16,
                                    ),
                                itemBuilder: (context, index) {
                                  final entry = entriesToShow[index];
                                  final entryCurrencyCode =
                                      entry.currencyCode ?? displayCurrencyCode;
                                  return _buildJournalEntry(
                                    context,
                                    entry,
                                    entryCurrencyCode,
                                    displayCurrencyCode,
                                    l10n,
                                    dateFormat,
                                    timeFormat,
                                  );
                                },
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

  Widget _buildJournalEntry(
    BuildContext context,
    OperationJournalEntry entry,
    String entryCurrencyCode,
    String displayCurrencyCode,
    AppLocalizations l10n,
    DateFormat dateFormat,
    DateFormat timeFormat,
  ) {
    String amountDisplay = "";
    Color amountColor = Theme.of(context).colorScheme.onSurface;

    // Utiliser le code de devise de l'entrée si disponible, sinon utiliser le code par défaut
    final effectiveCurrencyCode = entry.currencyCode ?? entryCurrencyCode;

    if (entry.isDebit) {
      amountDisplay =
          "- ${formatCurrency(entry.amount.abs(), effectiveCurrencyCode)}";
      amountColor = Colors.redAccent;
    } else if (entry.isCredit) {
      amountDisplay =
          "+ ${formatCurrency(entry.amount.abs(), effectiveCurrencyCode)}";
      amountColor = Colors.green;
    } else {
      amountDisplay = formatCurrency(entry.amount, effectiveCurrencyCode);
    }
    return ListTile(
      dense: true, // Rendre le ListTile plus compact
      contentPadding: const EdgeInsets.only(
        left: 8,
        right: 8,
      ), // Padding horizontal minimal
      visualDensity: const VisualDensity(
        vertical: -4,
        horizontal: -4,
      ), // Réduire encore plus l'espacement vertical et horizontal
      minVerticalPadding: 0, // Minimiser le padding vertical
      minLeadingWidth: 24, // Réduit l'espace alloué à l'icône leading
      horizontalTitleGap: 8, // Réduit l'écart entre l'icône et le titre
      leading: Icon(
        entry.type.icon,
        size: 14, // Réduire davantage la taille de l'icône
        color: entry.isDebit ? Colors.redAccent : Colors.green,
      ),
      title: Text(
        entry.description,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize:
              11, // Réduire davantage la taille pour économiser de l'espace vertical
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "${dateFormat.format(entry.date)} ${timeFormat.format(entry.date)}",
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize:
              9, // Réduire davantage la taille pour économiser de l'espace vertical
        ),
      ),
      trailing: SizedBox(
        width: 100, // Width réduite
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize:
              MainAxisSize.min, // Pour réduire la hauteur de la colonne
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                amountDisplay,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                  fontSize:
                      10, // Taille uniforme et réduite pour tous les montants
                ),
                textAlign: TextAlign.right,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${l10n.dashboardOperationsJournalBalanceLabel}: ${formatCurrency(entry.cashBalance ?? 0.0, displayCurrencyCode)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize:
                      8, // Taille réduite et uniforme pour tous les soldes
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
      onTap: () {
        // Vue détail d'opération non implémentée
        debugPrint('Opération: ${entry.description}');
      },
    );
  }

  /// Affiche les filtres rapides pour le journal des opérations
  void _showQuickFilters(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(WanzoSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filtres Rapides',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: WanzoSpacing.md),

                // Filtres par type d'opération
                Wrap(
                  spacing: WanzoSpacing.sm,
                  runSpacing: WanzoSpacing.sm,
                  children: [
                    _buildQuickFilterChip(context, 'Toutes', () {
                      _applyQuickFilter(context, JournalFilter.defaultFilter());
                      Navigator.pop(context);
                    }),
                    _buildQuickFilterChip(context, 'Ventes', () {
                      _applyQuickFilter(context, JournalFilter.salesOnly());
                      Navigator.pop(context);
                    }),
                    _buildQuickFilterChip(context, 'Stock', () {
                      _applyQuickFilter(context, JournalFilter.stockOnly());
                      Navigator.pop(context);
                    }),
                    _buildQuickFilterChip(context, 'Dépenses', () {
                      _applyQuickFilter(context, JournalFilter.expensesOnly());
                      Navigator.pop(context);
                    }),
                    _buildQuickFilterChip(context, 'Dettes', () {
                      _applyQuickFilter(context, JournalFilter.customerDebts());
                      Navigator.pop(context);
                    }),
                  ],
                ),

                const SizedBox(height: WanzoSpacing.lg),

                // Bouton pour accéder aux filtres avancés
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _expandOperationsJournal();
                    },
                    icon: const Icon(Icons.tune),
                    label: const Text('Filtres Avancés'),
                  ),
                ),
              ],
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
