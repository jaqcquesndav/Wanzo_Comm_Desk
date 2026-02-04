import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/financial_account_bloc.dart';
import '../bloc/financial_account_event.dart';
import '../bloc/financial_account_state.dart';
import '../models/financial_account.dart';
import 'add_financial_account_screen.dart';

/// Écran de configuration des comptes financiers
class FinancialAccountSettingsScreen extends StatefulWidget {
  const FinancialAccountSettingsScreen({super.key});

  @override
  State<FinancialAccountSettingsScreen> createState() =>
      _FinancialAccountSettingsScreenState();
}

class _FinancialAccountSettingsScreenState
    extends State<FinancialAccountSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  FinancialAccountType? _currentFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Charger les comptes au démarrage
    context.read<FinancialAccountBloc>().add(const LoadFinancialAccounts());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comptes Financiers')),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            onTap: (index) {
              setState(() {
                switch (index) {
                  case 0:
                    _currentFilter = null;
                    break;
                  case 1:
                    _currentFilter = FinancialAccountType.bankAccount;
                    break;
                  case 2:
                    _currentFilter = FinancialAccountType.mobileMoney;
                    break;
                }
              });
              context.read<FinancialAccountBloc>().add(
                FilterAccountsByType(_currentFilter),
              );
            },
            tabs: const [
              Tab(text: 'Tous'),
              Tab(text: 'Banques'),
              Tab(text: 'Mobile Money'),
            ],
          ),
          Expanded(
            child: BlocConsumer<FinancialAccountBloc, FinancialAccountState>(
              listener: (context, state) {
                if (state is FinancialAccountError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else if (state is FinancialAccountOperationSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is FinancialAccountLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is FinancialAccountLoaded) {
                  return _buildAccountsList(context, state);
                } else if (state is FinancialAccountError) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Erreur de chargement',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((0.7 * 255).round()),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              context.read<FinancialAccountBloc>().add(
                                const LoadFinancialAccounts(),
                              );
                            },
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'Aucun compte configuré',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddAccount(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un compte'),
      ),
    );
  }

  Widget _buildAccountsList(
    BuildContext context,
    FinancialAccountLoaded state,
  ) {
    if (state.filteredAccounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getEmptyStateIcon(),
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((0.4 * 255).round()),
              ),
              const SizedBox(height: 16),
              Text(
                _getEmptyStateMessage(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _getEmptyStateSubtitle(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withAlpha((0.5 * 255).round()),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _navigateToAddAccount(context),
                icon: const Icon(Icons.add),
                label: Text(_getEmptyStateButtonText()),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<FinancialAccountBloc>().add(const LoadFinancialAccounts());
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.filteredAccounts.length,
        itemBuilder: (context, index) {
          final account = state.filteredAccounts[index];
          return _buildAccountCard(context, account);
        },
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, FinancialAccount account) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: account.isDefault ? Colors.green : Colors.blue,
          child: Icon(
            account.type == FinancialAccountType.bankAccount
                ? Icons.account_balance
                : Icons.phone_android,
            color: Colors.white,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                account.accountName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (account.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Par défaut',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(account.displayDescription),
            const SizedBox(height: 4),
            Text(
              'Ajouté le ${_formatDate(account.createdAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, value, account),
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Modifier'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (!account.isDefault)
                  const PopupMenuItem(
                    value: 'set_default',
                    child: ListTile(
                      leading: Icon(Icons.star),
                      title: Text('Définir par défaut'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text(
                      'Supprimer',
                      style: TextStyle(color: Colors.red),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
        ),
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    String action,
    FinancialAccount account,
  ) {
    switch (action) {
      case 'edit':
        _navigateToEditAccount(context, account);
        break;
      case 'set_default':
        context.read<FinancialAccountBloc>().add(
          SetDefaultFinancialAccount(account.id),
        );
        break;
      case 'delete':
        _showDeleteConfirmation(context, account);
        break;
    }
  }

  void _showDeleteConfirmation(BuildContext context, FinancialAccount account) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text(
              'Êtes-vous sûr de vouloir supprimer le compte "${account.accountName}" ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<FinancialAccountBloc>().add(
                    DeleteFinancialAccount(account.id),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
  }

  void _navigateToAddAccount(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddFinancialAccountScreen(),
      ),
    );
  }

  void _navigateToEditAccount(BuildContext context, FinancialAccount account) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddFinancialAccountScreen(account: account),
      ),
    );
  }

  IconData _getEmptyStateIcon() {
    switch (_currentFilter) {
      case FinancialAccountType.bankAccount:
        return Icons.account_balance;
      case FinancialAccountType.mobileMoney:
        return Icons.phone_android;
      default:
        return Icons.account_balance_wallet;
    }
  }

  String _getEmptyStateMessage() {
    switch (_currentFilter) {
      case FinancialAccountType.bankAccount:
        return 'Aucun compte bancaire';
      case FinancialAccountType.mobileMoney:
        return 'Aucun compte Mobile Money';
      default:
        return 'Aucun compte financier';
    }
  }

  String _getEmptyStateSubtitle() {
    switch (_currentFilter) {
      case FinancialAccountType.bankAccount:
        return 'Ajoutez vos comptes bancaires pour faciliter\nla gestion de vos transactions';
      case FinancialAccountType.mobileMoney:
        return 'Ajoutez vos comptes Mobile Money pour\nune gestion complète de vos paiements';
      default:
        return 'Configurez vos comptes bancaires et Mobile Money\npour gérer vos transactions financières';
    }
  }

  String _getEmptyStateButtonText() {
    switch (_currentFilter) {
      case FinancialAccountType.bankAccount:
        return 'Ajouter un compte bancaire';
      case FinancialAccountType.mobileMoney:
        return 'Ajouter Mobile Money';
      default:
        return 'Ajouter un compte';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
