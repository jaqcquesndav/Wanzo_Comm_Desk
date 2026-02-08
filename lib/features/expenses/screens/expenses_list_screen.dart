import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';

import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/table_export_button.dart';
import '../../../services/export/table_export_service.dart';
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

/// Helper pour obtenir la couleur du statut de paiement
/// Vue trésorerie: distinguer ce qui a impacté la caisse (décaissement effectif)
Color getDecaissementStatusColor(ExpensePaymentStatus? status) {
  switch (status) {
    case ExpensePaymentStatus.paid:
      return Colors.green; // ✅ Décaissé (sortie de caisse effective)
    case ExpensePaymentStatus.partial:
      return Colors.blue; // 🔵 Partiellement décaissé
    case ExpensePaymentStatus.unpaid:
      return Colors.orange; // ⚠️ Charge comptable, pas encore décaissé
    case ExpensePaymentStatus.credit:
      return Colors.purple; // 💳 À crédit (dette fournisseur)
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
    final dateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');

    return BlocBuilder<ExpenseBloc, ExpenseState>(
      builder: (context, state) {
        return WanzoScaffold(
          currentIndex: 2, // Index pour Charges dans le sidebar
          title: 'Charges', // Terminologie comptable: Charges = Dépenses
          appBarActions: [
            // Bouton d'export
            if (state is ExpensesLoaded && state.expenses.isNotEmpty)
              TableExportIconButton(
                config: TableExportConfig(
                  title: 'Liste des dépenses',
                  subtitle: 'Exporté le ${dateFormat.format(DateTime.now())}',
                  headers: ['Date', 'Motif', 'Catégorie', 'Montant'],
                  rows:
                      state.expenses
                          .map(
                            (e) => [
                              dateFormat.format(e.date),
                              e.motif,
                              e.category.displayName,
                              '${e.amount.toStringAsFixed(2)} ${e.currencyCode ?? "CDF"}',
                            ],
                          )
                          .toList(),
                  fileName: 'depenses',
                  companyName: 'Wanzo',
                ),
              ),
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
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ExpenseState state) {
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
                  () => context.read<ExpenseBloc>().add(const LoadExpenses()),
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
      return _buildExpensesList(context, state.expenses, state.totalExpenses);
    }

    return const Center(child: Text('Chargement...'));
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

        // Tableau des dépenses
        Expanded(
          child: _ExpensesDataTable(
            expenses: expenses,
            currencyFormat: currencyFormat,
            dateFormat: dateFormat,
            onExpenseTap: (expense) {
              final idForNavigation = expense.hiveKey;
              if (idForNavigation.isNotEmpty) {
                context.pushNamed(
                  AppRoute.expenseDetail.name,
                  pathParameters: {'id': idForNavigation},
                );
              }
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

/// Widget DataTable pour afficher les dépenses
class _ExpensesDataTable extends StatelessWidget {
  final List<Expense> expenses;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;
  final Function(Expense) onExpenseTap;

  const _ExpensesDataTable({
    required this.expenses,
    required this.currencyFormat,
    required this.dateFormat,
    required this.onExpenseTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: isCompact ? 16 : 32,
                horizontalMargin: isCompact ? 12 : 24,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 72,
                headingRowColor: WidgetStateProperty.all(
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                ),
                columns: [
                  DataColumn(
                    label: Text(
                      'Catégorie',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Motif',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Montant',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Date',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Colonne statut de paiement (vue trésorerie)
                  DataColumn(
                    label: Text(
                      'Décaissement', // Vue trésorerie
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isCompact)
                    DataColumn(
                      label: Text(
                        'Unité',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (!isCompact)
                    DataColumn(
                      label: Text(
                        'Moyen paiement',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
                rows:
                    expenses.map((expense) {
                      final categoryColor = _getCategoryColor(expense.category);

                      return DataRow(
                        onSelectChanged: (_) => onExpenseTap(expense),
                        cells: [
                          // Catégorie
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: categoryColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  child: Icon(
                                    expense.category.icon,
                                    size: 16,
                                    color: categoryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    expense.category.displayName,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: categoryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Motif
                          DataCell(
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isCompact ? 100 : 200,
                              ),
                              child: Text(
                                expense.motif,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          // Montant
                          DataCell(
                            Text(
                              currencyFormat.format(expense.amount),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                          // Date
                          DataCell(
                            Text(
                              dateFormat.format(expense.date),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          // Statut de paiement (vue trésorerie)
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: getDecaissementStatusColor(
                                  expense.paymentStatus,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: getDecaissementStatusColor(
                                    expense.paymentStatus,
                                  ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                expense.paymentStatus?.displayName ??
                                    'Non spécifié',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: getDecaissementStatusColor(
                                    expense.paymentStatus,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          // Unité (si pas compact)
                          if (!isCompact)
                            DataCell(
                              Text(
                                expense.businessUnitCode != null
                                    ? '${expense.businessUnitType?.code ?? 'company'} - ${expense.businessUnitCode}'
                                    : expense.businessUnitType?.code ??
                                        'company',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          // Moyen de paiement (si pas compact)
                          if (!isCompact)
                            DataCell(
                              Text(
                                expense.paymentMethod ?? '-',
                                style: theme.textTheme.bodySmall,
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
}
