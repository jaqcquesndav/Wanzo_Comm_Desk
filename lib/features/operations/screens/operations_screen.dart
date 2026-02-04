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

    return ListView.builder(
      itemCount: allOperations.length,
      itemBuilder: (context, index) {
        final item = allOperations[index];
        if (item is Sale) {
          return _buildSaleListItem(context, item);
        } else if (item is Expense) {
          return _buildExpenseListItem(context, item);
        } else if (item is FinancingRequest) {
          return _buildFinancingListItem(context, item);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSalesView(BuildContext context, List<Sale> sales) {
    if (sales.isEmpty) {
      return const Center(child: Text('Aucune vente à afficher.'));
    }
    return ListView.builder(
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        return _buildSaleListItem(context, sale);
      },
    );
  }

  Widget _buildExpensesView(BuildContext context, List<Expense> expenses) {
    if (expenses.isEmpty) {
      return const Center(child: Text('Aucune dépense à afficher.'));
    }
    return ListView.builder(
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
        return _buildExpenseListItem(context, expense);
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
    return ListView.builder(
      itemCount: financingRequests.length,
      itemBuilder: (context, index) {
        final financing = financingRequests[index];
        return _buildFinancingListItem(context, financing);
      },
    );
  }

  Widget _buildSaleListItem(BuildContext context, Sale sale) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(sale.customerName),
        subtitle: Text(
          'Total: ${NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA').format(sale.totalAmountInCdf)} - ${DateFormat('dd/MM/yyyy').format(sale.date)}',
        ),
        trailing: Text(
          sale.status.displayName,
          style: TextStyle(color: _getStatusColor(sale.status)),
        ),
        onTap: () {
          // MODIFIED: Pass the sale object as extra, pathParameters still needed for route matching
          context.pushNamed(
            AppRoute.saleDetail.name,
            pathParameters: {'id': sale.id},
            extra: sale,
          );
        },
      ),
    );
  }

  Widget _buildExpenseListItem(BuildContext context, Expense expense) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(expense.motif),
        subtitle: Text(
          'Montant: ${NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA').format(expense.amount)} - ${DateFormat('dd/MM/yyyy').format(expense.date)}',
        ),
        trailing: Text(
          expense.category.displayName,
        ), // MODIFIED: Use displayName from ExpenseCategoryExtension
        onTap: () {
          // MODIFIED: Use expense.hiveKey for pathParameters
          // This ensures we use localId if server id is not yet available.
          final String idForNavigation = expense.hiveKey;
          if (idForNavigation.isNotEmpty) {
            context.pushNamed(
              AppRoute.expenseDetail.name,
              pathParameters: {'id': idForNavigation},
            );
          } else {
            // Handle case where no valid ID is available (should ideally not happen if localId is always generated)
            debugPrint("Error: Expense has no valid ID for navigation.");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Erreur: Impossible d\'ouvrir les détails de cette dépense.',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildFinancingListItem(
    BuildContext context,
    FinancingRequest financing,
  ) {
    // Fonction pour obtenir la couleur selon le statut
    Color getStatusColor(String status) {
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

    // Fonction pour obtenir le texte à afficher selon le statut
    String getStatusText(String status) {
      switch (status) {
        case 'approved':
          return 'Approuvé';
        case 'pending':
          return 'En attente';
        case 'disbursed':
          return 'Décaissé';
        case 'repaying':
          return 'En remboursement';
        case 'fully_repaid':
          return 'Remboursé';
        case 'rejected':
          return 'Rejeté';
        default:
          return 'Inconnu';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(
          '${financing.type.displayName} - ${financing.institution.displayName}',
        ),
        subtitle: Text(
          'Montant: ${NumberFormat.currency(locale: 'fr_FR', symbol: financing.currency).format(financing.amount)} - ${DateFormat('dd/MM/yyyy').format(financing.requestDate)}',
        ),
        trailing: Text(
          getStatusText(financing.status),
          style: TextStyle(color: getStatusColor(financing.status)),
        ),
        onTap: () {
          // Naviguer vers les détails du financement
          context.pushNamed(
            'financing_detail',
            pathParameters: {'id': financing.id},
            extra: financing,
          );
        },
      ),
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

// Helper to get display name for ExpenseCategory (if not already in your model)
// Assuming ExpenseCategory has a displayName getter or similar
// extension ExpenseCategoryExtension on ExpenseCategory {
//   String get displayName {
//     // Add your mappings here
//     return toString().split('.').last;
//   }
// }
