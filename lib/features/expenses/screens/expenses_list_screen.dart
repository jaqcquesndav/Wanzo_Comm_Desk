import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../../core/navigation/app_router.dart';
import '../bloc/expense_bloc.dart';
import '../models/expense.dart';

/// Helper pour obtenir la couleur d'une catégorie de dépense
Color _getCategoryColor(ExpenseCategory category) {
  switch (category) {
    case ExpenseCategory.rent:
      return Colors.brown;
    case ExpenseCategory.utilities:
      return Colors.amber;
    case ExpenseCategory.supplies:
      return Colors.teal;
    case ExpenseCategory.salaries:
      return Colors.indigo;
    case ExpenseCategory.marketing:
      return Colors.pink;
    case ExpenseCategory.transport:
      return Colors.blue;
    case ExpenseCategory.maintenance:
      return Colors.orange;
    case ExpenseCategory.inventory:
      return Colors.green;
    case ExpenseCategory.equipment:
      return Colors.blueGrey;
    case ExpenseCategory.taxes:
      return Colors.red;
    case ExpenseCategory.insurance:
      return Colors.purple;
    case ExpenseCategory.loan:
      return Colors.deepPurple;
    default:
      return Colors.grey;
  }
}

/// Écran de liste des dépenses
class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  @override
  void initState() {
    super.initState();
    // Charger les dépenses au démarrage
    context.read<ExpenseBloc>().add(const LoadExpenses());
  }

  @override
  Widget build(BuildContext context) {
    return WanzoScaffold(
      currentIndex: 2, // Index pour Dépenses dans le sidebar
      title: 'Dépenses',
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () => _showFilterDialog(context),
          tooltip: 'Filtrer',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed:
              () => context.read<ExpenseBloc>().add(const LoadExpenses()),
          tooltip: 'Actualiser',
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expenses/add'),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle dépense'),
      ),
      body: BlocBuilder<ExpenseBloc, ExpenseState>(
        builder: (context, state) {
          if (state is ExpenseLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ExpenseError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text('Erreur: ${state.message}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed:
                        () => context.read<ExpenseBloc>().add(
                          const LoadExpenses(),
                        ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          if (state is ExpensesLoaded) {
            if (state.expenses.isEmpty) {
              return _buildEmptyState(context);
            }
            return _buildExpensesList(
              context,
              state.expenses,
              state.totalExpenses,
            );
          }

          return const Center(child: Text('Chargement...'));
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucune dépense enregistrée',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Commencez par enregistrer votre première dépense',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/expenses/add'),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une dépense'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesList(
    BuildContext context,
    List<Expense> expenses,
    double totalAmount,
  ) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'CDF',
    );
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      children: [
        // En-tête avec total
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.red.withValues(alpha: 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${expenses.length} dépense${expenses.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Total: ${currencyFormat.format(totalAmount)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
        ),

        // Liste des dépenses
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              final categoryColor = _getCategoryColor(expense.category);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: categoryColor.withValues(alpha: 0.2),
                    child: Icon(expense.category.icon, color: categoryColor),
                  ),
                  title: Text(
                    expense.motif,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currencyFormat.format(expense.amount),
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        dateFormat.format(expense.date),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      expense.category.displayName,
                      style: TextStyle(
                        color: categoryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  isThreeLine: true,
                  onTap: () {
                    final idForNavigation = expense.hiveKey;
                    if (idForNavigation.isNotEmpty) {
                      context.pushNamed(
                        AppRoute.expenseDetail.name,
                        pathParameters: {'id': idForNavigation},
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showFilterDialog(BuildContext context) {
    ExpenseCategory? selectedCategory;
    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filtrer les dépenses'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<ExpenseCategory?>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<ExpenseCategory?>(
                          value: null,
                          child: Text('Toutes les catégories'),
                        ),
                        ...ExpenseCategory.values.map((category) {
                          return DropdownMenuItem<ExpenseCategory?>(
                            value: category,
                            child: Text(category.displayName),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => selectedCategory = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        startDate != null
                            ? 'Du: ${DateFormat('dd/MM/yyyy').format(startDate!)}'
                            : 'Date de début',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => startDate = picked);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        endDate != null
                            ? 'Au: ${DateFormat('dd/MM/yyyy').format(endDate!)}'
                            : 'Date de fin',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => endDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedCategory != null) {
                      this.context.read<ExpenseBloc>().add(
                        LoadExpensesByCategory(selectedCategory!),
                      );
                    } else if (startDate != null && endDate != null) {
                      this.context.read<ExpenseBloc>().add(
                        LoadExpensesByDateRange(startDate!, endDate!),
                      );
                    } else {
                      this.context.read<ExpenseBloc>().add(
                        const LoadExpenses(),
                      );
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Appliquer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
