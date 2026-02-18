import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wanzo/features/expenses/bloc/expense_bloc.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/core/shared_widgets/wanzo_app_bar.dart';
import 'package:wanzo/core/shared_widgets/smart_attachment.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart'; // Pour les permissions

class ExpenseDetailScreen extends StatefulWidget {
  final String expenseId;

  // Constante pour le breakpoint desktop
  static const double desktopBreakpoint = 900.0;

  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ExpenseBloc>().add(LoadExpenseById(widget.expenseId));
    _checkPermissions();
  }

  // Obtenir la couleur selon le statut de paiement
  Color _getStatusColor(ExpensePaymentStatus? status) {
    switch (status) {
      case ExpensePaymentStatus.paid:
        return Colors.green;
      case ExpensePaymentStatus.partial:
        return Colors.orange;
      case ExpensePaymentStatus.unpaid:
      case null:
        return Colors.red;
      case ExpensePaymentStatus.credit:
        return Colors.blue;
    }
  }

  // Afficher le dialogue pour enregistrer un paiement partiel
  void _showPartialPaymentDialog(BuildContext context, Expense expense) {
    final remainingAmount = expense.remainingAmount;
    final TextEditingController amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Enregistrer un paiement'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Montant restant: ${NumberFormat.currency(symbol: '${expense.effectiveCurrencyCode} ', decimalDigits: 2).format(remainingAmount)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Montant payé',
                      prefixText: '${expense.effectiveCurrencyCode} ',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer un montant';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Montant invalide';
                      }
                      if (amount > remainingAmount) {
                        return 'Le montant dépasse le reste à payer';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final paidAmount = double.parse(amountController.text);
                    final newTotalPaid =
                        (expense.paidAmount ?? 0.0) + paidAmount;
                    final newStatus =
                        newTotalPaid >= expense.amount
                            ? ExpensePaymentStatus.paid
                            : ExpensePaymentStatus.partial;

                    final updatedExpense = expense.copyWith(
                      paidAmount: newTotalPaid,
                      paymentStatus: newStatus,
                    );

                    context.read<ExpenseBloc>().add(
                      UpdateExpense(updatedExpense),
                    );
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Paiement enregistré')),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          ),
    );
  }

  // Vérifier et demander les permissions nécessaires au démarrage
  Future<void> _checkPermissions() async {
    // Vérifier les permissions de stockage
    final storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      // Ne pas demander immédiatement, attendre l'action de l'utilisateur
      // La permission sera demandée lors de la première utilisation
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= ExpenseDetailScreen.desktopBreakpoint;

        return Scaffold(
          appBar: WanzoAppBar(
            title: 'Détails de la Dépense',
            onBackPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/operations');
              }
            },
          ),
          body: Stack(
            children: [
              BlocBuilder<ExpenseBloc, ExpenseState>(
                builder: (context, state) {
                  if (state is ExpenseLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is ExpenseLoaded) {
                    final expense = state.expense;
                    return isDesktop
                        ? _buildDesktopLayout(context, expense, currencyFormat)
                        : _buildMobileLayout(context, expense, currencyFormat);
                  } else if (state is ExpenseError) {
                    return Center(child: Text('Erreur: ${state.message}'));
                  }
                  return const Center(
                    child: Text('Veuillez charger une dépense.'),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Layout desktop: 2 colonnes
  Widget _buildDesktopLayout(
    BuildContext context,
    Expense expense,
    NumberFormat currencyFormat,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colonne principale (détails)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainCard(context, expense, currencyFormat),
                const SizedBox(height: 24),
                _buildPaymentStatusCard(context, expense, currencyFormat),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Sidebar (pièces jointes + actions)
          SizedBox(
            width: 350,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAttachmentsCard(context, expense),
                const SizedBox(height: 16),
                if (expense.paymentStatus != ExpensePaymentStatus.paid)
                  _buildDesktopActionsCard(context, expense),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Layout mobile: colonne verticale
  Widget _buildMobileLayout(
    BuildContext context,
    Expense expense,
    NumberFormat currencyFormat,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildMainCard(context, expense, currencyFormat),
          const SizedBox(height: 24),
          _buildPaymentStatusCard(context, expense, currencyFormat),
          const SizedBox(height: 24),
          _buildAttachmentsCard(context, expense),
        ],
      ),
    );
  }

  /// Carte principale avec informations de base
  Widget _buildMainCard(
    BuildContext context,
    Expense expense,
    NumberFormat currencyFormat,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icône pour la catégorie
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(expense.category),
                    color: Theme.of(context).primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                // Détails principaux
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.motif,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat(
                          'dd MMMM yyyy',
                          'fr_FR',
                        ).format(expense.date),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Montant avec devise
                      Text(
                        currencyFormat.format(expense.amount),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            // Informations détaillées
            _buildDetailItem(
              context,
              'Catégorie',
              expense.category.displayName,
              Icons.category,
            ),
            _buildDetailItem(
              context,
              'Méthode de paiement',
              expense.paymentMethod ?? 'Non spécifiée',
              Icons.payment,
            ),
            if (expense.beneficiary != null && expense.beneficiary!.isNotEmpty)
              _buildDetailItem(
                context,
                'Bénéficiaire',
                expense.beneficiary!,
                Icons.person,
              ),
            if (expense.notes != null && expense.notes!.isNotEmpty)
              _buildDetailItem(context, 'Notes', expense.notes!, Icons.note),
          ],
        ),
      ),
    );
  }

  /// Carte état du paiement
  Widget _buildPaymentStatusCard(
    BuildContext context,
    Expense expense,
    NumberFormat currencyFormat,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section État du paiement
            Row(
              children: [
                Icon(Icons.payment, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Text(
                  'État du paiement',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      expense.paymentStatus,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(expense.paymentStatus),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    expense.paymentStatusText,
                    style: TextStyle(
                      color: _getStatusColor(expense.paymentStatus),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Montants détaillés
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Montant total:',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        currencyFormat.format(expense.amount),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Montant payé:',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        currencyFormat.format(expense.paidAmount ?? 0.0),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  if (expense.remainingAmount > 0) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reste à payer:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          currencyFormat.format(expense.remainingAmount),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Boutons d'action pour mobile
            if (expense.paymentStatus != ExpensePaymentStatus.paid) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  if (expense.remainingAmount > 0) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            () => _showPartialPaymentDialog(context, expense),
                        icon: const Icon(Icons.payments),
                        label: const Text('Paiement partiel'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsPaid(context, expense),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Marquer comme Payé'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Carte pièces jointes
  Widget _buildAttachmentsCard(BuildContext context, Expense expense) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_file, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Pièces Jointes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SmartAttachmentGrid(
              urls: expense.attachmentUrls ?? [],
              localPaths: expense.localAttachmentPaths ?? [],
            ),
          ],
        ),
      ),
    );
  }

  /// Actions card pour desktop
  Widget _buildDesktopActionsCard(BuildContext context, Expense expense) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (expense.remainingAmount > 0) ...[
              OutlinedButton.icon(
                onPressed: () => _showPartialPaymentDialog(context, expense),
                icon: const Icon(Icons.payments),
                label: const Text('Enregistrer paiement partiel'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              onPressed: () => _markAsPaid(context, expense),
              icon: const Icon(Icons.check_circle),
              label: const Text('Marquer comme Payé'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Marquer la dépense comme payée
  void _markAsPaid(BuildContext context, Expense expense) {
    final Expense updatedExpense = expense.copyWith(
      paymentStatus: ExpensePaymentStatus.paid,
      paidAmount: expense.amount,
    );
    context.read<ExpenseBloc>().add(UpdateExpense(updatedExpense));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dépense marquée comme payée')),
    );
  }

  // Méthode pour obtenir l'icône correspondant à la catégorie
  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.rent:
        return Icons.home;
      case ExpenseCategory.utilities:
        return Icons.electrical_services;
      case ExpenseCategory.supplies:
        return Icons.shopping_basket;
      case ExpenseCategory.salaries:
        return Icons.people;
      case ExpenseCategory.marketing:
        return Icons.campaign;
      case ExpenseCategory.transport:
        return Icons.directions_car;
      case ExpenseCategory.maintenance:
        return Icons.build;
      case ExpenseCategory.inventory:
        return Icons.inventory_2;
      case ExpenseCategory.equipment:
        return Icons.construction;
      case ExpenseCategory.taxes:
        return Icons.receipt_long;
      case ExpenseCategory.insurance:
        return Icons.security;
      case ExpenseCategory.loan:
        return Icons.account_balance;
      case ExpenseCategory.office:
        return Icons.business_center;
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
        return Icons.precision_manufacturing;
      case ExpenseCategory.consulting:
        return Icons.support_agent;
      case ExpenseCategory.research:
        return Icons.science;
      case ExpenseCategory.fuel:
        return Icons.local_gas_station;
      case ExpenseCategory.entertainment:
        return Icons.card_giftcard;
      case ExpenseCategory.communication:
        return Icons.phone_in_talk;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }

  // Méthode pour créer un élément détaillé
  Widget _buildDetailItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
