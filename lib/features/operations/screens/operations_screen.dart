import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/core/navigation/app_router.dart';
import 'package:intl/intl.dart';

import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/expenses/repositories/expense_repository.dart';
import 'package:wanzo/features/sales/repositories/sales_repository.dart';
import 'package:wanzo/features/financing/models/financing_request.dart';
import 'package:wanzo/features/financing/repositories/financing_repository.dart';

import '../bloc/operations_bloc.dart';

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
            financingRepository: context.read<FinancingRepository>(),
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
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabListener = () {
      if (mounted) {
        setState(() {}); // To rebuild FAB if its properties change with tab
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

  @override
  Widget build(BuildContext context) {
    const int operationsPageIndex = 1; // Index for Operations in BottomNavBar

    return WanzoScaffold(
      currentIndex: operationsPageIndex,
      title: 'Opérations', // Title for the WanzoAppBar
      appBarActions: [
        // Actions for the WanzoAppBar
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () {
            _showFilterDialog(context);
          },
        ),
      ],
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Tout'),
              Tab(text: 'Ventes'),
              Tab(text: 'Dépenses'),
              Tab(text: 'Financements'),
            ],
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
          ),
          Expanded(
            child: BlocBuilder<OperationsBloc, OperationsState>(
              builder: (context, state) {
                if (state is OperationsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is OperationsLoaded) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAllOperationsView(
                        context,
                        state.sales,
                        state.expenses,
                        state.financingRequests,
                      ),
                      _buildSalesView(context, state.sales),
                      _buildExpensesView(context, state.expenses),
                      _buildFinancingView(context, state.financingRequests),
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
                          Icon(
                            Icons.error_outline,
                            color: Colors.red[700],
                            size: 50,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réessayer'),
                            onPressed: () {
                              context.read<OperationsBloc>().add(
                                const LoadOperations(),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const Center(
                  child: Text('Veuillez charger les opérations.'),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final operationsBloc = context.read<OperationsBloc>();

          if (_tabController.index == 0 || _tabController.index == 1) {
            await context.pushNamed('add_sale_from_operations');
          } else if (_tabController.index == 2) {
            await context.pushNamed('add_expense_from_operations');
          } else if (_tabController.index == 3) {
            await context.pushNamed('add_financing_from_operations');
          }

          // Toujours recharger après retour de la navigation
          // Les données peuvent avoir changé même si l'utilisateur n'a pas explicitement ajouté quelque chose
          if (mounted) {
            operationsBloc.add(const LoadOperations());
          }
        },
        tooltip:
            _tabController.index <= 1
                ? 'Ajouter une vente'
                : (_tabController.index == 2
                    ? 'Ajouter une dépense'
                    : 'Ajouter un financement'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAllOperationsView(
    BuildContext context,
    List<Sale> sales,
    List<Expense> expenses,
    List<FinancingRequest> financingRequests,
  ) {
    List<dynamic> allOperations = [...sales, ...expenses, ...financingRequests];
    allOperations.sort((a, b) {
      DateTime dateA;
      DateTime dateB;

      if (a is Sale) {
        dateA = a.date;
      } else if (a is Expense) {
        dateA = a.date;
      } else if (a is FinancingRequest) {
        dateA = a.requestDate;
      } else {
        dateA = DateTime.now();
      }

      if (b is Sale) {
        dateB = b.date;
      } else if (b is Expense) {
        dateB = b.date;
      } else if (b is FinancingRequest) {
        dateB = b.requestDate;
      } else {
        dateB = DateTime.now();
      }

      return dateB.compareTo(dateA); // Sort in descending order (newest first)
    });

    if (allOperations.isEmpty) {
      return const Center(child: Text('Aucune opération à afficher.'));
    }

    return _AllOperationsDataTable(
      sales: sales,
      expenses: expenses,
      financingRequests: financingRequests,
      onSaleTap: (sale) {
        context.pushNamed(
          AppRoute.saleDetail.name,
          pathParameters: {'id': sale.id},
          extra: sale,
        );
      },
      onExpenseTap: (expense) {
        final String idForNavigation = expense.hiveKey;
        if (idForNavigation.isNotEmpty) {
          context.pushNamed(
            AppRoute.expenseDetail.name,
            pathParameters: {'id': idForNavigation},
          );
        }
      },
      onFinancingTap: (financing) {
        context.pushNamed(
          'financing_detail',
          pathParameters: {'id': financing.id},
          extra: financing,
        );
      },
    );
  }

  Widget _buildSalesView(BuildContext context, List<Sale> sales) {
    if (sales.isEmpty) {
      return const Center(child: Text('Aucune vente à afficher.'));
    }
    return _SalesDataTable(
      sales: sales,
      onSaleTap: (sale) {
        context.pushNamed(
          AppRoute.saleDetail.name,
          pathParameters: {'id': sale.id},
          extra: sale,
        );
      },
    );
  }

  Widget _buildExpensesView(BuildContext context, List<Expense> expenses) {
    if (expenses.isEmpty) {
      return const Center(child: Text('Aucune dépense à afficher.'));
    }
    return _ExpensesDataTable(
      expenses: expenses,
      onExpenseTap: (expense) {
        final String idForNavigation = expense.hiveKey;
        if (idForNavigation.isNotEmpty) {
          context.pushNamed(
            AppRoute.expenseDetail.name,
            pathParameters: {'id': idForNavigation},
          );
        }
      },
    );
  }

  Widget _buildFinancingView(
    BuildContext context,
    List<FinancingRequest> financingRequests,
  ) {
    if (financingRequests.isEmpty) {
      return const Center(child: Text('Aucun financement à afficher.'));
    }
    return _FinancingDataTable(
      financingRequests: financingRequests,
      onFinancingTap: (financing) {
        context.pushNamed(
          'financing_detail',
          pathParameters: {'id': financing.id},
          extra: financing,
        );
      },
    );
  }

  Future<void> _showFilterDialog(BuildContext context) async {
    DateTime? selectedStartDate;
    DateTime? selectedEndDate = DateTime.now();
    // String? paymentStatus; // Old: using string
    SaleStatus? selectedSaleStatus; // New: using SaleStatus enum

    // Access BLoC via context.read within the builder or where needed
    final operationsBloc = BlocProvider.of<OperationsBloc>(context);

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              title: const Text('Filtrer les Opérations'),
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
                        labelText: 'Statut de Vente',
                      ),
                      hint: const Text(
                        'Tous les statuts',
                      ), // Shown when value is null
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<SaleStatus?>(
                          value: null, // Represents "All"
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
                        // Convert SaleStatus? to String? for the event
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

// =============================================
// DataTable Widgets pour affichage tabulaire
// =============================================

/// Widget DataTable pour l'onglet "Tout" combinant ventes, dépenses et financements
class _AllOperationsDataTable extends StatelessWidget {
  final List<Sale> sales;
  final List<Expense> expenses;
  final List<FinancingRequest> financingRequests;
  final Function(Sale) onSaleTap;
  final Function(Expense) onExpenseTap;
  final Function(FinancingRequest) onFinancingTap;

  const _AllOperationsDataTable({
    required this.sales,
    required this.expenses,
    required this.financingRequests,
    required this.onSaleTap,
    required this.onExpenseTap,
    required this.onFinancingTap,
  });

  @override
  Widget build(BuildContext context) {
    // Créer une liste unifiée d'opérations triées par date
    final List<_OperationItem> allOperations = [
      ...sales.map(
        (s) => _OperationItem(
          type: 'Vente',
          description: s.customerName,
          amount: s.totalAmountInCdf,
          date: s.date,
          icon: Icons.shopping_cart,
          color: Colors.green,
          onTap: () => onSaleTap(s),
          status: s.status.displayName,
          statusColor: _getSaleStatusColor(s.status),
        ),
      ),
      ...expenses.map(
        (e) => _OperationItem(
          type: 'Dépense',
          description: e.motif,
          amount: -e.amount,
          date: e.date,
          icon: Icons.money_off,
          color: Colors.red,
          onTap: () => onExpenseTap(e),
          status: e.category.displayName,
          statusColor: Colors.orange,
        ),
      ),
      ...financingRequests.map(
        (f) => _OperationItem(
          type: 'Financement',
          description: '${f.type.displayName} - ${f.institution.displayName}',
          amount: f.amount,
          date: f.requestDate,
          icon: Icons.account_balance,
          color: Colors.blue,
          onTap: () => onFinancingTap(f),
          status: _getFinancingStatusText(f.status),
          statusColor: _getFinancingStatusColor(f.status),
        ),
      ),
    ];

    // Trier par date décroissante
    allOperations.sort((a, b) => b.date.compareTo(a.date));

    if (allOperations.isEmpty) {
      return const Center(child: Text('Aucune opération à afficher.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: isCompact ? 16 : 24,
              headingRowColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              columns: [
                const DataColumn(label: Text('Type')),
                const DataColumn(label: Text('Description')),
                if (!isCompact) const DataColumn(label: Text('Statut')),
                const DataColumn(label: Text('Date')),
                const DataColumn(label: Text('Montant'), numeric: true),
              ],
              rows:
                  allOperations.map((op) {
                    return DataRow(
                      onSelectChanged: (_) => op.onTap(),
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(op.icon, size: 18, color: op.color),
                              const SizedBox(width: 8),
                              Text(op.type),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            op.description,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
                                color: op.statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                op.status,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: op.statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        DataCell(Text(DateFormat('dd/MM/yy').format(op.date))),
                        DataCell(
                          Text(
                            NumberFormat.currency(
                              locale: 'fr_FR',
                              symbol: 'FC',
                            ).format(op.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: op.amount >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        );
      },
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

  String _getFinancingStatusText(String status) {
    switch (status) {
      case 'approved':
        return 'Approuvé';
      case 'pending':
        return 'En attente';
      case 'disbursed':
        return 'Décaissé';
      case 'repaying':
        return 'Remboursement';
      case 'fully_repaid':
        return 'Remboursé';
      case 'rejected':
        return 'Rejeté';
      default:
        return 'Inconnu';
    }
  }

  Color _getFinancingStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'disbursed':
      case 'repaying':
        return Colors.blue;
      case 'fully_repaid':
        return Colors.purple;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Modèle interne pour unifier les opérations
class _OperationItem {
  final String type;
  final String description;
  final double amount;
  final DateTime date;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String status;
  final Color statusColor;

  _OperationItem({
    required this.type,
    required this.description,
    required this.amount,
    required this.date,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.status,
    required this.statusColor,
  });
}

/// Widget DataTable pour l'onglet Ventes
class _SalesDataTable extends StatelessWidget {
  final List<Sale> sales;
  final Function(Sale) onSaleTap;

  const _SalesDataTable({required this.sales, required this.onSaleTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: isCompact ? 12 : 20,
              headingRowColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              columns: [
                const DataColumn(label: Text('Client')),
                if (!isCompact) const DataColumn(label: Text('Articles')),
                const DataColumn(label: Text('Date')),
                const DataColumn(label: Text('Statut')),
                if (!isCompact) const DataColumn(label: Text('Payé')),
                const DataColumn(label: Text('Total'), numeric: true),
              ],
              rows:
                  sales.map((sale) {
                    final articlesCount = sale.items.length;
                    return DataRow(
                      onSelectChanged: (_) => onSaleTap(sale),
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                child: Text(
                                  sale.customerName.isNotEmpty
                                      ? sale.customerName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                sale.customerName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (!isCompact) DataCell(Text('$articlesCount')),
                        DataCell(
                          Text(DateFormat('dd/MM/yy').format(sale.date)),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                sale.status,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              sale.status.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                color: _getStatusColor(sale.status),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        if (!isCompact)
                          DataCell(
                            Text(
                              NumberFormat.currency(
                                locale: 'fr_FR',
                                symbol: 'FC',
                              ).format(sale.paidAmountInCdf),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        DataCell(
                          Text(
                            NumberFormat.currency(
                              locale: 'fr_FR',
                              symbol: 'FC',
                            ).format(sale.totalAmountInCdf),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(SaleStatus status) {
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
}

/// Widget DataTable pour l'onglet Dépenses
class _ExpensesDataTable extends StatelessWidget {
  final List<Expense> expenses;
  final Function(Expense) onExpenseTap;

  const _ExpensesDataTable({
    required this.expenses,
    required this.onExpenseTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: isCompact ? 12 : 20,
              headingRowColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              columns: [
                const DataColumn(label: Text('Catégorie')),
                const DataColumn(label: Text('Motif')),
                const DataColumn(label: Text('Date')),
                if (!isCompact) const DataColumn(label: Text('Paiement')),
                const DataColumn(label: Text('Montant'), numeric: true),
              ],
              rows:
                  expenses.map((expense) {
                    return DataRow(
                      onSelectChanged: (_) => onExpenseTap(expense),
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  expense.category.displayName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            expense.motif,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        DataCell(
                          Text(DateFormat('dd/MM/yy').format(expense.date)),
                        ),
                        if (!isCompact)
                          DataCell(Text(expense.paymentMethod ?? '-')),
                        DataCell(
                          Text(
                            NumberFormat.currency(
                              locale: 'fr_FR',
                              symbol: 'FC',
                            ).format(expense.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
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
}

/// Widget DataTable pour l'onglet Financements
class _FinancingDataTable extends StatelessWidget {
  final List<FinancingRequest> financingRequests;
  final Function(FinancingRequest) onFinancingTap;

  const _FinancingDataTable({
    required this.financingRequests,
    required this.onFinancingTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: isCompact ? 12 : 20,
              headingRowColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              columns: [
                const DataColumn(label: Text('Type')),
                const DataColumn(label: Text('Institution')),
                const DataColumn(label: Text('Date')),
                const DataColumn(label: Text('Statut')),
                const DataColumn(label: Text('Montant'), numeric: true),
              ],
              rows:
                  financingRequests.map((financing) {
                    return DataRow(
                      onSelectChanged: (_) => onFinancingTap(financing),
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_balance,
                                size: 18,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(financing.type.displayName),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            financing.institution.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DataCell(
                          Text(
                            DateFormat(
                              'dd/MM/yy',
                            ).format(financing.requestDate),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                financing.status,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusText(financing.status),
                              style: TextStyle(
                                fontSize: 11,
                                color: _getStatusColor(financing.status),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            NumberFormat.currency(
                              locale: 'fr_FR',
                              symbol: financing.currency,
                            ).format(financing.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved':
        return 'Approuvé';
      case 'pending':
        return 'En attente';
      case 'disbursed':
        return 'Décaissé';
      case 'repaying':
        return 'Remboursement';
      case 'fully_repaid':
        return 'Remboursé';
      case 'rejected':
        return 'Rejeté';
      default:
        return 'Inconnu';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'disbursed':
      case 'repaying':
        return Colors.blue;
      case 'fully_repaid':
        return Colors.purple;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
