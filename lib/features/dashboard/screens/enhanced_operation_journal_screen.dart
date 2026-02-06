import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:wanzo/utils/theme.dart';
import '../bloc/operation_journal_bloc.dart';
import '../models/journal_filter.dart';
import '../models/operation_journal_entry.dart';
import '../widgets/journal_filter_panel.dart';
import '../widgets/journal_operations_list.dart';
import '../widgets/product_operation_image.dart';
import '../../../services/journal_export_service.dart';
import '../../auth/bloc/auth_bloc.dart';

/// Écran principal du journal des opérations avec filtrage avancé
class EnhancedOperationJournalScreen extends StatefulWidget {
  const EnhancedOperationJournalScreen({super.key});

  @override
  State<EnhancedOperationJournalScreen> createState() =>
      _EnhancedOperationJournalScreenState();
}

class _EnhancedOperationJournalScreenState
    extends State<EnhancedOperationJournalScreen> {
  bool _isFilterPanelVisible = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Charger les opérations au début
    context.read<OperationJournalBloc>().add(
      LoadOperationsWithFilter(filter: JournalFilter.defaultFilter()),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: _buildAppBar(context, l10n),
      body: Column(
        children: [
          // Panneau de filtres (collapsible)
          if (_isFilterPanelVisible) ...[
            _buildFilterPanel(),
            const Divider(height: 1),
          ],

          // Barre d'outils avec résumé et actions
          _buildToolbar(context, l10n),
          const Divider(height: 1),

          // Liste des opérations
          Expanded(child: _buildOperationsList()),
        ],
      ),
      floatingActionButton: _buildFloatingActions(context),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return AppBar(
      title: const Text('Journal des Opérations'),
      elevation: 0,
      actions: [
        // Bouton pour filtres de période (nouveau)
        IconButton(
          icon: const Icon(Icons.calendar_month_rounded),
          onPressed: () => _showPeriodFilter(context),
          tooltip: 'Filtrer par période',
        ),

        // Bouton pour basculer les filtres avancés
        IconButton(
          icon: Icon(
            _isFilterPanelVisible ? Icons.filter_list_off : Icons.filter_list,
          ),
          onPressed: () {
            setState(() {
              _isFilterPanelVisible = !_isFilterPanelVisible;
            });
          },
          tooltip:
              _isFilterPanelVisible
                  ? 'Masquer les filtres'
                  : 'Afficher les filtres',
        ),

        // Bouton d'export
        BlocBuilder<OperationJournalBloc, OperationJournalState>(
          builder: (context, state) {
            return IconButton(
              icon: const Icon(Icons.download),
              onPressed:
                  state is OperationJournalLoaded && state.operations.isNotEmpty
                      ? () =>
                          _exportOperations(context, state.filteredOperations)
                      : null,
              tooltip: 'Exporter en PDF',
            );
          },
        ),

        // Menu des options
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, value),
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Actualiser'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Paramètres'),
                    dense: true,
                  ),
                ),
              ],
        ),
      ],
    );
  }

  Widget _buildFilterPanel() {
    return BlocBuilder<OperationJournalBloc, OperationJournalState>(
      builder: (context, state) {
        final currentFilter =
            state is OperationJournalLoaded
                ? (state.activeFilter ?? JournalFilter.defaultFilter())
                : JournalFilter.defaultFilter();

        return Padding(
          padding: const EdgeInsets.all(WanzoTheme.spacingMd),
          child: JournalFilterPanel(
            initialFilter: currentFilter,
            onFilterChanged: (filter) {
              context.read<OperationJournalBloc>().add(
                LoadOperationsWithFilter(filter: filter),
              );
            },
            onReset: () {
              context.read<OperationJournalBloc>().add(
                LoadOperationsWithFilter(filter: JournalFilter.defaultFilter()),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context, AppLocalizations l10n) {
    return BlocBuilder<OperationJournalBloc, OperationJournalState>(
      builder: (context, state) {
        if (state is! OperationJournalLoaded) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: WanzoTheme.spacingMd,
            vertical: WanzoTheme.spacingSm,
          ),
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          child: Row(
            children: [
              // Résumé des résultats
              Expanded(child: _buildResultsSummary(context, state)),

              // Actions rapides
              _buildQuickActions(context, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultsSummary(
    BuildContext context,
    OperationJournalLoaded state,
  ) {
    final theme = Theme.of(context);
    final totalOperations = state.filteredOperations.length;

    // === CALCUL PAR CATÉGORIE COMPTABLE (pas de mélange!) ===
    // Trésorerie: opérations qui impactent la caisse
    final cashOperations = state.filteredOperations.where(
      (op) => op.type.impactsCash,
    );
    final cashIn = cashOperations
        .where((op) => op.amount > 0)
        .fold<double>(0.0, (sum, op) => sum + op.amount);
    final cashOut = cashOperations
        .where((op) => op.amount < 0)
        .fold<double>(0.0, (sum, op) => sum + op.amount.abs());
    final netCash = cashIn - cashOut;

    // Ventes: chiffre d'affaires
    final salesTotal = state.filteredOperations
        .where((op) => op.type.isSalesOperation)
        .fold<double>(0.0, (sum, op) => sum + op.amount.abs());

    // Stock: mouvements
    final stockOperations = state.filteredOperations.where(
      (op) => op.type.impactsStock,
    );
    final stockIn = stockOperations
        .where((op) => op.type == OperationType.stockIn)
        .fold<double>(0.0, (sum, op) => sum + op.amount.abs());
    final stockOut = stockOperations
        .where((op) => op.type == OperationType.stockOut)
        .fold<double>(0.0, (sum, op) => sum + op.amount.abs());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$totalOperations opération${totalOperations > 1 ? 's' : ''}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (totalOperations > 0) ...[
          const SizedBox(height: 4),
          // Résumé par catégorie (correctement séparé)
          if (cashOperations.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 12,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  'Trésorerie: +${cashIn.toStringAsFixed(0)} / -${cashOut.toStringAsFixed(0)} = ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  '${netCash >= 0 ? '+' : ''}${netCash.toStringAsFixed(0)} CDF',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        netCash >= 0 ? WanzoTheme.success : WanzoTheme.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          if (salesTotal > 0)
            Row(
              children: [
                Icon(Icons.trending_up, size: 12, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  'CA (Ventes): ${salesTotal.toStringAsFixed(0)} CDF',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          if (stockOperations.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.inventory_2,
                  size: 12,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  'Stock: ↑${stockIn.toStringAsFixed(0)} / ↓${stockOut.toStringAsFixed(0)} CDF',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    OperationJournalLoaded state,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouton de tri rapide
        IconButton(
          icon: const Icon(Icons.sort, size: 20),
          onPressed: () => _showQuickSortMenu(context, state),
          tooltip: 'Options de tri',
        ),

        // Bouton de recherche rapide
        IconButton(
          icon: const Icon(Icons.search, size: 20),
          onPressed: () => _showQuickSearch(context),
          tooltip: 'Recherche rapide',
        ),
      ],
    );
  }

  Widget _buildOperationsList() {
    return BlocBuilder<OperationJournalBloc, OperationJournalState>(
      builder: (context, state) {
        if (state is OperationJournalLoading) {
          return const JournalOperationsList(operations: [], isLoading: true);
        }

        if (state is OperationJournalError) {
          return JournalOperationsList(
            operations: [],
            errorMessage: state.message,
            onRetry: () {
              context.read<OperationJournalBloc>().add(
                LoadOperationsWithFilter(filter: JournalFilter.defaultFilter()),
              );
            },
          );
        }

        if (state is OperationJournalLoaded) {
          return JournalOperationsList(
            operations: state.filteredOperations,
            onOperationTap:
                (operation) => _showOperationDetails(context, operation),
          );
        }

        return const JournalOperationsList(operations: []);
      },
    );
  }

  Widget _buildFloatingActions(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouton pour remonter en haut
        FloatingActionButton.small(
          heroTag: "scroll_to_top",
          onPressed: () {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          },
          tooltip: 'Remonter',
          child: const Icon(Icons.keyboard_arrow_up),
        ),

        const SizedBox(height: WanzoTheme.spacingSm),

        // Bouton d'actualisation
        FloatingActionButton(
          heroTag: "refresh",
          onPressed: () {
            context.read<OperationJournalBloc>().add(
              LoadOperationsWithFilter(
                filter:
                    context.read<OperationJournalBloc>().state
                            is OperationJournalLoaded
                        ? (context.read<OperationJournalBloc>().state
                                    as OperationJournalLoaded)
                                .activeFilter ??
                            JournalFilter.defaultFilter()
                        : JournalFilter.defaultFilter(),
              ),
            );
          },
          tooltip: 'Actualiser',
          child: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'refresh':
        context.read<OperationJournalBloc>().add(
          LoadOperationsWithFilter(
            filter:
                context.read<OperationJournalBloc>().state
                        is OperationJournalLoaded
                    ? ((context.read<OperationJournalBloc>().state
                                as OperationJournalLoaded)
                            .activeFilter ??
                        JournalFilter.defaultFilter())
                    : JournalFilter.defaultFilter(),
          ),
        );
        break;
      case 'settings':
        _showSettingsDialog(context);
        break;
    }
  }

  void _exportOperations(BuildContext context, List operations) async {
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

      // Récupération de l'utilisateur actuel et du filtre
      final authState = context.read<AuthBloc>().state;
      final currentUser =
          authState is AuthAuthenticated ? authState.user : null;

      final journalState = context.read<OperationJournalBloc>().state;
      final activeFilter =
          journalState is OperationJournalLoaded
              ? journalState.activeFilter ?? JournalFilter.defaultFilter()
              : JournalFilter.defaultFilter();

      // Export du PDF
      await JournalExportService.exportAndShare(
        operations: operations.cast(),
        filter: activeFilter,
        currentUser: currentUser,
        companyName: 'WANZO', // Peut être configuré
        companyAddress: 'Kinshasa, République Démocratique du Congo',
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

  void _showQuickSortMenu(BuildContext context, OperationJournalLoaded state) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => _QuickSortBottomSheet(
            currentFilter: state.activeFilter ?? JournalFilter.defaultFilter(),
            onSortChanged: (filter) {
              context.read<OperationJournalBloc>().add(
                LoadOperationsWithFilter(filter: filter),
              );
            },
          ),
    );
  }

  void _showQuickSearch(BuildContext context) {
    showSearch(context: context, delegate: _OperationSearchDelegate());
  }

  void _showOperationDetails(BuildContext context, operation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _OperationDetailsBottomSheet(operation: operation),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Paramètres du Journal'),
            content: const Text('Paramètres en cours de développement'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          ),
    );
  }

  void _showPeriodFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => Container(
            padding: EdgeInsets.only(
              left: WanzoTheme.spacingLg,
              right: WanzoTheme.spacingLg,
              top: WanzoTheme.spacingLg,
              bottom:
                  MediaQuery.of(context).viewInsets.bottom +
                  WanzoTheme.spacingLg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: WanzoTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Filtrer par Période',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: WanzoTheme.spacingLg),

                // Filtres de période prédéfinis
                Wrap(
                  spacing: WanzoTheme.spacingSm,
                  runSpacing: WanzoTheme.spacingSm,
                  children: [
                    _buildPeriodChip(context, 'Aujourd\'hui', () {
                      final now = DateTime.now();
                      final todayStart = DateTime(now.year, now.month, now.day);
                      final todayEnd = DateTime(
                        now.year,
                        now.month,
                        now.day,
                        23,
                        59,
                        59,
                      );
                      _applyPeriodFilter(context, todayStart, todayEnd);
                    }),
                    _buildPeriodChip(context, 'Cette semaine', () {
                      final now = DateTime.now();
                      final startOfWeek = now.subtract(
                        Duration(days: now.weekday - 1),
                      );
                      final weekStart = DateTime(
                        startOfWeek.year,
                        startOfWeek.month,
                        startOfWeek.day,
                      );
                      final weekEnd = DateTime(
                        now.year,
                        now.month,
                        now.day,
                        23,
                        59,
                        59,
                      );
                      _applyPeriodFilter(context, weekStart, weekEnd);
                    }),
                    _buildPeriodChip(context, 'Ce mois', () {
                      final now = DateTime.now();
                      final monthStart = DateTime(now.year, now.month, 1);
                      final monthEnd = DateTime(
                        now.year,
                        now.month + 1,
                        0,
                        23,
                        59,
                        59,
                      );
                      _applyPeriodFilter(context, monthStart, monthEnd);
                    }),
                    _buildPeriodChip(context, 'Ce trimestre', () {
                      final now = DateTime.now();
                      final quarter = ((now.month - 1) ~/ 3) + 1;
                      final quarterStart = DateTime(
                        now.year,
                        (quarter - 1) * 3 + 1,
                        1,
                      );
                      final quarterEnd = DateTime(
                        now.year,
                        quarter * 3 + 1,
                        0,
                        23,
                        59,
                        59,
                      );
                      _applyPeriodFilter(context, quarterStart, quarterEnd);
                    }),
                    _buildPeriodChip(context, 'Cette année', () {
                      final now = DateTime.now();
                      final yearStart = DateTime(now.year, 1, 1);
                      final yearEnd = DateTime(now.year, 12, 31, 23, 59, 59);
                      _applyPeriodFilter(context, yearStart, yearEnd);
                    }),
                    _buildPeriodChip(context, 'Toutes', () {
                      _applyPeriodFilter(context, null, null);
                    }),
                  ],
                ),

                const SizedBox(height: WanzoTheme.spacingLg),

                // Bouton pour sélection personnalisée
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Ouvrir le panneau de filtres dans l'écran parent
                      setState(() {
                        _isFilterPanelVisible = true;
                      });
                    },
                    icon: const Icon(Icons.date_range_rounded),
                    label: const Text('Période personnalisée'),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildPeriodChip(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: WanzoTheme.primary.withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: WanzoTheme.primary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  void _applyPeriodFilter(
    BuildContext context,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    final currentState = context.read<OperationJournalBloc>().state;
    JournalFilter currentFilter = JournalFilter.defaultFilter();

    if (currentState is OperationJournalLoaded) {
      currentFilter =
          currentState.activeFilter ?? JournalFilter.defaultFilter();
    }

    final newFilter = JournalFilter(
      startDate: startDate,
      endDate: endDate,
      selectedTypes: currentFilter.selectedTypes,
      selectedCurrencies: currentFilter.selectedCurrencies,
      selectedPaymentMethods: currentFilter.selectedPaymentMethods,
      minAmount: currentFilter.minAmount,
      maxAmount: currentFilter.maxAmount,
      searchQuery: currentFilter.searchQuery,
      sortBy: currentFilter.sortBy,
      sortAscending: currentFilter.sortAscending,
    );

    context.read<OperationJournalBloc>().add(
      LoadOperationsWithFilter(filter: newFilter),
    );

    Navigator.pop(context);

    // Afficher un message de confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          startDate == null && endDate == null
              ? 'Filtre de période supprimé'
              : 'Période appliquée: ${startDate != null ? DateFormat.yMd().format(startDate) : 'Début'} - ${endDate != null ? DateFormat.yMd().format(endDate) : 'Fin'}',
        ),
        backgroundColor: WanzoTheme.success,
      ),
    );
  }
}

/// Bottom sheet pour le tri rapide
class _QuickSortBottomSheet extends StatelessWidget {
  final JournalFilter currentFilter;
  final Function(JournalFilter) onSortChanged;

  const _QuickSortBottomSheet({
    required this.currentFilter,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(WanzoTheme.spacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Options de tri', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: WanzoTheme.spacingMd),

          ...JournalSortOption.values.map((option) {
            final isSelected = currentFilter.sortBy == option;
            return ListTile(
              leading: Radio<JournalSortOption>(
                value: option,
                groupValue: currentFilter.sortBy,
                onChanged: (value) {
                  if (value != null) {
                    onSortChanged(currentFilter.copyWith(sortBy: value));
                    Navigator.of(context).pop();
                  }
                },
              ),
              title: Text(option.displayName),
              trailing:
                  isSelected
                      ? IconButton(
                        icon: Icon(
                          currentFilter.sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                        ),
                        onPressed: () {
                          onSortChanged(
                            currentFilter.copyWith(
                              sortAscending: !currentFilter.sortAscending,
                            ),
                          );
                          Navigator.of(context).pop();
                        },
                      )
                      : null,
            );
          }),
        ],
      ),
    );
  }
}

/// Délégué de recherche pour les opérations
class _OperationSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isNotEmpty) {
      final filter = JournalFilter.defaultFilter().copyWith(searchQuery: query);
      context.read<OperationJournalBloc>().add(
        LoadOperationsWithFilter(filter: filter),
      );
      close(context, query);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Text('Tapez pour rechercher dans les opérations...'),
    );
  }
}

/// Bottom sheet pour les détails d'une opération
class _OperationDetailsBottomSheet extends StatelessWidget {
  final OperationJournalEntry operation;

  const _OperationDetailsBottomSheet({required this.operation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMd().add_Hm();
    final isPositive = operation.amount >= 0;
    final amountColor = isPositive ? WanzoTheme.success : WanzoTheme.danger;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête
              Container(
                padding: const EdgeInsets.all(WanzoTheme.spacingLg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Détails de l\'opération',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            operation.type.displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Contenu
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(WanzoTheme.spacingLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image du produit (si disponible)
                      if (operation.productId != null) ...[
                        Center(
                          child: ProductOperationImage(
                            operation: operation,
                            size: 120.0,
                          ),
                        ),
                        const SizedBox(height: WanzoTheme.spacingLg),
                      ],

                      // Carte avec montant
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(WanzoTheme.spacingMd),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Montant',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  Text(
                                    '${isPositive ? '+' : ''}${NumberFormat.currency(locale: 'fr_FR', symbol: operation.currencyCode).format(operation.amount)}',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: amountColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Solde après opération',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                  Text(
                                    NumberFormat.currency(
                                      locale: 'fr_FR',
                                      symbol: operation.currencyCode,
                                    ).format(
                                      operation.getRelevantBalance() ?? 0,
                                    ),
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: WanzoTheme.spacingMd),

                      // Informations de base
                      _buildInfoSection(context, 'Informations générales', [
                        _DetailRow(
                          icon: Icons.description,
                          label: 'Description',
                          value: operation.description,
                        ),
                        _DetailRow(
                          icon: Icons.access_time,
                          label: 'Date',
                          value: dateFormat.format(operation.date),
                        ),
                        if (operation.productName != null)
                          _DetailRow(
                            icon: Icons.inventory_2,
                            label: 'Produit',
                            value: operation.productName!,
                          ),
                        if (operation.quantity != null)
                          _DetailRow(
                            icon: Icons.numbers,
                            label: 'Quantité',
                            value: operation.quantity!.toString(),
                          ),
                        if (operation.paymentMethod != null)
                          _DetailRow(
                            icon: Icons.payment,
                            label: 'Méthode de paiement',
                            value: operation.paymentMethod!,
                          ),
                      ]),

                      // Soldes par devise (si disponible)
                      if (operation.balancesByCurrency != null &&
                          operation.balancesByCurrency!.isNotEmpty) ...[
                        const SizedBox(height: WanzoTheme.spacingMd),
                        _buildInfoSection(
                          context,
                          'Soldes par devise',
                          operation.balancesByCurrency!.entries
                              .map(
                                (entry) => _DetailRow(
                                  icon: Icons.account_balance_wallet,
                                  label: entry.key,
                                  value: NumberFormat.currency(
                                    locale: 'fr_FR',
                                    symbol: entry.key,
                                  ).format(entry.value),
                                ),
                              )
                              .toList(),
                        ),
                      ],

                      // ID du document lié (si disponible)
                      if (operation.relatedDocumentId != null) ...[
                        const SizedBox(height: WanzoTheme.spacingMd),
                        Card(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(WanzoTheme.spacingMd),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.link,
                                  size: 20,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: WanzoTheme.spacingSm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Document lié',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color:
                                                  theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                      ),
                                      Text(
                                        operation.relatedDocumentId!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: WanzoTheme.spacingSm),
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(WanzoTheme.spacingMd),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

/// Widget pour afficher une ligne de détail
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WanzoTheme.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: WanzoTheme.spacingSm),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
