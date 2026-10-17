import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/core/navigation/app_router.dart';
import 'package:intl/intl.dart';

import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/shared_widgets/empty_state_view.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/platform/platform_service.dart';
import 'package:wanzo/core/services/form_navigation_service.dart';
import 'package:wanzo/core/widgets/desktop/desktop_data_table.dart';
import 'package:wanzo/core/widgets/desktop/row_actions_menu.dart';
import 'package:wanzo/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/expenses/repositories/expense_repository.dart';
import 'package:wanzo/features/sales/repositories/sales_repository.dart';

import '../bloc/operations_bloc.dart';
import '../models/operation_row.dart';
import 'package:wanzo/core/modules/mode_vocabulary.dart';

// Extension for SaleStatus to get a display name
extension SaleStatusExtension on SaleStatus {
  String get displayName {
    switch (this) {
      case SaleStatus.pending:
        return 'En attente';
      case SaleStatus.completed:
        return 'Terminée';
      case SaleStatus.cancelled:
        return 'Annulée';
      case SaleStatus.partiallyPaid:
        return 'Partiellement payée';
    }
  }
}

class OperationsScreen extends StatelessWidget {
  const OperationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => OperationsBloc(
            salesRepository: context.read<SalesRepository>(),
            expenseRepository: context.read<ExpenseRepository>(),
          )..add(const LoadOperations()), // Initial load
      child: const _OperationsView(),
    );
  }
}

class _OperationsView extends StatefulWidget {
  const _OperationsView();

  @override
  State<_OperationsView> createState() => _OperationsViewState();
}

class _OperationsViewState extends State<_OperationsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VoidCallback? _tabListener;

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabListener = () {
      if (mounted) {
        setState(() {}); // Libellé du bouton de création selon l'onglet
      }
    };
    _tabController.addListener(_tabListener!);
  }

  @override
  void dispose() {
    if (_tabListener != null) {
      _tabController.removeListener(_tabListener!);
    }
    _tabController.dispose();
    super.dispose();
  }

  String get _createLabel =>
      _tabController.index <= 1
          // « Ajouter une prestation » en salon, « une commande » en
          // restaurant : le bouton nomme ce que l'exploitant enregistre.
          ? ModeVocabulary.current.addSaleLabel
          : 'Ajouter une dépense';

  Future<void> _openCreateFromOperations(BuildContext context) async {
    final operationsBloc = context.read<OperationsBloc>();
    DashboardBloc? dashboardBloc;
    try {
      dashboardBloc = context.read<DashboardBloc>();
    } catch (_) {
      dashboardBloc = null;
    }

    // Même porte que le reste de l'app : dialogue sur grand écran, page
    // complète sur fenêtre étroite.
    final forms = FormNavigationService.instance;
    if (_tabController.index == 0 || _tabController.index == 1) {
      await forms.openSaleForm(context);
    } else if (_tabController.index == 2) {
      await forms.openExpenseForm(context);
    }

    // Toujours recharger après retour : la table ET les vignettes du tableau
    // de bord (revenus, charges), comme sur le mobile.
    if (mounted) {
      operationsBloc.add(const LoadOperations());
      dashboardBloc?.add(LoadDashboardData(date: DateTime.now()));
    }
  }

  void _openSale(BuildContext context, Sale sale) {
    context.pushNamed(
      AppRoute.saleDetail.name,
      pathParameters: {'id': sale.id},
      extra: sale,
    );
  }

  void _openExpense(BuildContext context, Expense expense) {
    final String idForNavigation = expense.hiveKey;
    if (idForNavigation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir le détail de cette dépense.'),
        ),
      );
      return;
    }
    context.pushNamed(
      AppRoute.expenseDetail.name,
      pathParameters: {'id': idForNavigation},
    );
  }

  void _openRow(BuildContext context, OperationRow row) {
    if (row.sale != null) {
      _openSale(context, row.sale!);
    } else if (row.expense != null) {
      _openExpense(context, row.expense!);
    }
  }

  @override
  Widget build(BuildContext context) {
    const int operationsPageIndex = 1; // Index for Operations in BottomNavBar
    final bool isNarrow =
        MediaQuery.sizeOf(context).width <
        PlatformService.instance.tabletMinWidth;

    return BlocBuilder<OperationsBloc, OperationsState>(
      builder: (context, state) {
        return WanzoScaffold(
          currentIndex: operationsPageIndex,
          title: 'Opérations',
          appBarActions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filtrer les opérations',
              onPressed: () => _showFilterDialog(context),
            ),
          ],
          body: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: [
                  const Tab(text: 'Tout'),
                  Tab(text: ModeVocabulary.current.sales),
                  const Tab(text: 'Dépenses'),
                ],
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
              ),
              Expanded(child: _buildTabContent(context, state, isNarrow)),
            ],
          ),
          // Fenêtre étroite : bouton flottant icône seule (libellé en
          // tooltip) ; sinon le bouton de création vit dans la barre de table.
          floatingActionButton:
              isNarrow
                  ? FloatingActionButton(
                    onPressed: () => _openCreateFromOperations(context),
                    tooltip: _createLabel,
                    child: const Icon(Icons.add),
                  )
                  : null,
        );
      },
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    OperationsState state,
    bool isNarrow,
  ) {
    if (state is OperationsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is OperationsLoaded) {
      final VoidCallback? onAdd =
          isNarrow ? null : () => _openCreateFromOperations(context);
      return TabBarView(
        controller: _tabController,
        children: [
          _buildAllOperationsView(context, state, onAdd),
          _buildSalesView(context, state.sales, onAdd),
          _buildExpensesView(context, state.expenses, onAdd),
        ],
      );
    }
    if (state is OperationsError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 50),
              const SizedBox(height: 16),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.red[700]),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                onPressed: () {
                  context.read<OperationsBloc>().add(const LoadOperations());
                },
              ),
            ],
          ),
        ),
      );
    }
    return const Center(child: Text('Veuillez charger les opérations.'));
  }

  // ===========================================================================
  // Onglet « Tout »
  // ===========================================================================

  Widget _buildAllOperationsView(
    BuildContext context,
    OperationsLoaded state,
    VoidCallback? onAdd,
  ) {
    final rows = OperationRow.merge(state.sales, state.expenses);
    if (rows.isEmpty) {
      return EmptyStateView(
        icon: Icons.receipt_long,
        message: 'Aucune opération à afficher.',
        actionLabel: onAdd != null ? _createLabel : null,
        onAction: onAdd,
        actionIcon: Icons.add,
      );
    }

    return DesktopDataTable<OperationRow>(
      data: rows,
      onAdd: onAdd,
      addButtonLabel: _createLabel,
      searchHint: 'Rechercher une opération...',
      searchFilter:
          (row, query) =>
              row.description.toLowerCase().contains(query) ||
              _rowStatus(row).toLowerCase().contains(query),
      columns: const [
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Description')),
        DataColumn(label: Text('Statut')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Montant'), numeric: true),
        DataColumn(label: Text('')),
      ],
      rowBuilder: (row) {
        void open() => _openRow(context, row);
        final color = row.isSale ? Colors.green : Colors.red;
        return DataRow(
          cells: [
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    row.isSale ? Icons.shopping_cart : Icons.money_off,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Text(row.isSale ? ModeVocabulary.current.sale : 'Dépense'),
                ],
              ),
              onTap: open,
            ),
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  row.description,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              onTap: open,
            ),
            DataCell(_statusCell(row), onTap: open),
            DataCell(Text(_dateFormat.format(row.date)), onTap: open),
            DataCell(
              Text(
                formatCurrency(row.amount, row.currencyCode),
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              onTap: open,
            ),
            DataCell(_openMenu(open)),
          ],
        );
      },
      exportHeaders: const [
        'Type',
        'Date',
        'Description',
        'Statut',
        'Montant',
        'Devise',
      ],
      exportConfig: DataTableExportConfig(
        title: 'Toutes les opérations',
        subtitle: 'Exporté le ${_dateFormat.format(DateTime.now())}',
        fileName: 'operations',
        rowDataExtractor: (item) {
          final row = item as OperationRow;
          return [
            row.isSale ? ModeVocabulary.current.sale : 'Dépense',
            row.date,
            row.description,
            _rowStatus(row),
            row.amount,
            row.currencyCode,
          ];
        },
      ),
    );
  }

  // ===========================================================================
  // Onglet Ventes
  // ===========================================================================

  Widget _buildSalesView(
    BuildContext context,
    List<Sale> sales,
    VoidCallback? onAdd,
  ) {
    if (sales.isEmpty) {
      return EmptyStateView(
        icon: Icons.point_of_sale,
        message: 'Aucune vente à afficher.',
        actionLabel: onAdd != null ? _createLabel : null,
        onAction: onAdd,
        actionIcon: Icons.add,
      );
    }
    final rows =
        sales.map((s) => OperationRow.fromSale(s)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return DesktopDataTable<OperationRow>(
      data: rows,
      onAdd: onAdd,
      addButtonLabel: _createLabel,
      searchHint: 'Rechercher un client...',
      searchFilter:
          (row, query) =>
              row.description.toLowerCase().contains(query) ||
              _rowStatus(row).toLowerCase().contains(query),
      columns: const [
        DataColumn(label: Text('Client')),
        DataColumn(label: Text('Articles'), numeric: true),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Statut')),
        DataColumn(label: Text('Payé'), numeric: true),
        DataColumn(label: Text('Total'), numeric: true),
        DataColumn(label: Text('')),
      ],
      rowBuilder: (row) {
        final sale = row.sale!;
        void open() => _openSale(context, sale);
        return DataRow(
          cells: [
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      sale.customerName.isNotEmpty
                          ? sale.customerName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      sale.customerName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              onTap: open,
            ),
            DataCell(Text('${sale.items.length}'), onTap: open),
            DataCell(Text(_dateFormat.format(sale.date)), onTap: open),
            DataCell(_statusCell(row), onTap: open),
            DataCell(
              Text(formatCurrency(row.paid, row.currencyCode)),
              onTap: open,
            ),
            DataCell(
              Text(
                formatCurrency(row.amount, row.currencyCode),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: open,
            ),
            DataCell(_openMenu(open)),
          ],
        );
      },
      exportHeaders: const [
        'Date',
        'Client',
        'Statut',
        'Paiement',
        'Payé',
        'Total',
        'Devise',
      ],
      exportConfig: DataTableExportConfig(
        title: 'Liste des ${ModeVocabulary.current.sales.toLowerCase()}',
        subtitle: 'Exporté le ${_dateFormat.format(DateTime.now())}',
        fileName: 'ventes',
        rowDataExtractor: (item) {
          final row = item as OperationRow;
          return [
            row.date,
            row.description,
            _rowStatus(row),
            row.sale?.paymentMethod ?? '',
            row.paid,
            row.amount,
            row.currencyCode,
          ];
        },
      ),
    );
  }

  // ===========================================================================
  // Onglet Dépenses
  // ===========================================================================

  Widget _buildExpensesView(
    BuildContext context,
    List<Expense> expenses,
    VoidCallback? onAdd,
  ) {
    if (expenses.isEmpty) {
      return EmptyStateView(
        icon: Icons.money_off,
        message: 'Aucune dépense à afficher.',
        actionLabel: onAdd != null ? _createLabel : null,
        onAction: onAdd,
        actionIcon: Icons.add,
      );
    }
    final rows =
        expenses.map(OperationRow.fromExpense).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return DesktopDataTable<OperationRow>(
      data: rows,
      onAdd: onAdd,
      addButtonLabel: _createLabel,
      searchHint: 'Rechercher une dépense...',
      searchFilter:
          (row, query) =>
              row.description.toLowerCase().contains(query) ||
              row.expense!.category.displayName.toLowerCase().contains(query),
      columns: const [
        DataColumn(label: Text('Catégorie')),
        DataColumn(label: Text('Motif')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Paiement')),
        DataColumn(label: Text('Montant'), numeric: true),
        DataColumn(label: Text('')),
      ],
      rowBuilder: (row) {
        final expense = row.expense!;
        void open() => _openExpense(context, expense);
        return DataRow(
          cells: [
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getCategoryIcon(expense.category),
                    size: 18,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  _chip(expense.category.displayName, Colors.orange),
                ],
              ),
              onTap: open,
            ),
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  expense.motif,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              onTap: open,
            ),
            DataCell(Text(_dateFormat.format(expense.date)), onTap: open),
            DataCell(Text(expense.paymentMethod ?? '-'), onTap: open),
            DataCell(
              Text(
                formatCurrency(expense.amount, expense.effectiveCurrencyCode),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              onTap: open,
            ),
            DataCell(_openMenu(open)),
          ],
        );
      },
      exportHeaders: const [
        'Date',
        'Motif',
        'Catégorie',
        'Paiement',
        'Montant',
        'Devise',
      ],
      exportConfig: DataTableExportConfig(
        title: 'Liste des dépenses',
        subtitle: 'Exporté le ${_dateFormat.format(DateTime.now())}',
        fileName: 'depenses',
        rowDataExtractor: (item) {
          final row = item as OperationRow;
          final expense = row.expense!;
          return [
            expense.date,
            expense.motif,
            expense.category.displayName,
            expense.paymentMethod ?? '',
            expense.amount,
            expense.effectiveCurrencyCode,
          ];
        },
      ),
    );
  }

  // ===========================================================================
  // Cellules partagées
  // ===========================================================================

  /// Actions de ligne en menu 3 points (règle des tables desktop).
  Widget _openMenu(VoidCallback open) {
    return RowActionsMenu(
      actions: [
        RowAction(label: 'Ouvrir', icon: Icons.open_in_new, onSelected: open),
      ],
    );
  }

  String _rowStatus(OperationRow row) {
    if (row.sale != null) {
      return row.isOverdue
          ? '${row.sale!.status.displayName} (en retard)'
          : row.sale!.status.displayName;
    }
    return row.expense?.category.displayName ?? '';
  }

  Widget _statusCell(OperationRow row) {
    if (row.sale == null) {
      return _chip(row.expense?.category.displayName ?? '', Colors.orange);
    }
    final sale = row.sale!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip(sale.status.displayName, _getSaleStatusColor(sale.status)),
        if (row.isOverdue) ...[const SizedBox(width: 6), _buildOverdueBadge()],
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Petit badge « En retard » pour une créance échue (parité mobile).
  Widget _buildOverdueBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red),
          SizedBox(width: 3),
          Text(
            'En retard',
            style: TextStyle(
              color: Colors.red,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSaleStatusColor(SaleStatus status) {
    switch (status) {
      case SaleStatus.completed:
        return Colors.green;
      case SaleStatus.pending:
        return Colors.orange;
      case SaleStatus.partiallyPaid:
        return Colors.blue;
      case SaleStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.rent:
        return Icons.home;
      case ExpenseCategory.utilities:
        return Icons.electrical_services;
      case ExpenseCategory.salaries:
        return Icons.people;
      case ExpenseCategory.supplies:
        return Icons.inventory_2;
      case ExpenseCategory.transport:
        return Icons.local_shipping;
      case ExpenseCategory.maintenance:
        return Icons.build;
      case ExpenseCategory.communication:
        return Icons.phone;
      case ExpenseCategory.marketing:
        return Icons.campaign;
      case ExpenseCategory.taxes:
        return Icons.account_balance;
      case ExpenseCategory.insurance:
        return Icons.security;
      case ExpenseCategory.inventory:
        return Icons.warehouse;
      case ExpenseCategory.equipment:
        return Icons.handyman;
      case ExpenseCategory.loan:
        return Icons.monetization_on;
      case ExpenseCategory.office:
        return Icons.business;
      case ExpenseCategory.training:
        return Icons.school;
      case ExpenseCategory.travel:
        return Icons.flight;
      case ExpenseCategory.software:
        return Icons.computer;
      case ExpenseCategory.advertising:
        return Icons.ads_click;
      case ExpenseCategory.legal:
        return Icons.gavel;
      case ExpenseCategory.manufacturing:
        return Icons.factory;
      case ExpenseCategory.consulting:
        return Icons.support_agent;
      case ExpenseCategory.research:
        return Icons.biotech;
      case ExpenseCategory.fuel:
        return Icons.local_gas_station;
      case ExpenseCategory.entertainment:
        return Icons.celebration;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }

  Future<void> _showFilterDialog(BuildContext context) async {
    DateTime? selectedStartDate;
    DateTime? selectedEndDate = DateTime.now();
    SaleStatus? selectedSaleStatus;

    final operationsBloc = BlocProvider.of<OperationsBloc>(context);

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              title: const Text('Filtrer les opérations'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: stfContext,
                          initialDate: selectedStartDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) {
                          stfSetState(() {
                            selectedStartDate = picked;
                          });
                        }
                      },
                      child: Text(
                        'Date de début: ${selectedStartDate != null ? DateFormat('dd/MM/yyyy').format(selectedStartDate!) : 'Non définie'}',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: stfContext,
                          initialDate: selectedEndDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) {
                          stfSetState(() {
                            selectedEndDate = picked;
                          });
                        }
                      },
                      child: Text(
                        'Date de fin: ${DateFormat('dd/MM/yyyy').format(selectedEndDate!)}',
                      ),
                    ),
                    DropdownButtonFormField<SaleStatus?>(
                      value: selectedSaleStatus,
                      decoration: const InputDecoration(
                        labelText: 'Statut de vente',
                      ),
                      hint: const Text('Tous les statuts'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<SaleStatus?>(
                          value: null,
                          child: Text('Tous les statuts'),
                        ),
                        ...SaleStatus.values.map((SaleStatus status) {
                          return DropdownMenuItem<SaleStatus?>(
                            value: status,
                            child: Text(status.displayName),
                          );
                        }),
                      ],
                      onChanged: (SaleStatus? newValue) {
                        stfSetState(() {
                          selectedSaleStatus = newValue;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Annuler'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                TextButton(
                  child: const Text('Appliquer'),
                  onPressed: () {
                    operationsBloc.add(
                      LoadOperations(
                        startDate: selectedStartDate,
                        endDate: selectedEndDate,
                        paymentStatus:
                            selectedSaleStatus?.toString().split('.').last,
                      ),
                    );
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
