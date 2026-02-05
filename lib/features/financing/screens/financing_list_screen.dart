import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../bloc/financing_bloc.dart';
import '../models/financing_request.dart';

/// Écran de liste des financements
class FinancingListScreen extends StatefulWidget {
  const FinancingListScreen({super.key});

  @override
  State<FinancingListScreen> createState() => _FinancingListScreenState();
}

class _FinancingListScreenState extends State<FinancingListScreen> {
  @override
  void initState() {
    super.initState();
    // Charger les financements au démarrage
    context.read<FinancingBloc>().add(const LoadFinancingRequests());
  }

  @override
  Widget build(BuildContext context) {
    return WanzoScaffold(
      currentIndex: 4, // Index pour Financement dans le sidebar
      title: 'Financement',
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () => _showFilterDialog(context),
          tooltip: 'Filtrer',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed:
              () => context.read<FinancingBloc>().add(
                const LoadFinancingRequests(),
              ),
          tooltip: 'Actualiser',
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/operations/financing/add'),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle demande'),
      ),
      body: BlocBuilder<FinancingBloc, FinancingState>(
        builder: (context, state) {
          if (state is FinancingLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is FinancingError) {
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
                        () => context.read<FinancingBloc>().add(
                          const LoadFinancingRequests(),
                        ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          if (state is FinancingLoadSuccess) {
            if (state.requests.isEmpty) {
              return _buildEmptyState(context);
            }
            return _buildFinancingList(context, state.requests);
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
          Icon(
            Icons.account_balance_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune demande de financement',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Soumettez votre première demande de financement',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/operations/financing/add'),
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle demande'),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancingList(
    BuildContext context,
    List<FinancingRequest> requests,
  ) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Calculer le total des montants
    final totalAmount = requests.fold<double>(
      0,
      (sum, req) => sum + req.amount,
    );

    return Column(
      children: [
        // En-tête avec total
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.purple.withValues(alpha: 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${requests.length} demande${requests.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Total: ${NumberFormat.currency(locale: 'fr_FR', symbol: 'USD').format(totalAmount)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[700],
                ),
              ),
            ],
          ),
        ),

        // Liste des financements
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final statusColor = _getStatusColor(request.status);
              final statusText = _getStatusText(request.status);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.2),
                    child: Icon(Icons.account_balance, color: statusColor),
                  ),
                  title: Text(
                    request.type.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.institution.displayName,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        NumberFormat.currency(
                          locale: 'fr_FR',
                          symbol: request.currency,
                        ).format(request.amount),
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        dateFormat.format(request.requestDate),
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
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  isThreeLine: true,
                  onTap: () {
                    context.pushNamed(
                      'financing_detail',
                      pathParameters: {'id': request.id},
                      extra: request,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
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

  String _getStatusText(String status) {
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

  void _showFilterDialog(BuildContext context) {
    String? selectedStatus;
    FinancingType? selectedType;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filtrer les financements'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String?>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Statut',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tous les statuts'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('En attente'),
                        ),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text('Approuvé'),
                        ),
                        DropdownMenuItem(
                          value: 'disbursed',
                          child: Text('Décaissé'),
                        ),
                        DropdownMenuItem(
                          value: 'repaying',
                          child: Text('En remboursement'),
                        ),
                        DropdownMenuItem(
                          value: 'fully_repaid',
                          child: Text('Remboursé'),
                        ),
                        DropdownMenuItem(
                          value: 'rejected',
                          child: Text('Rejeté'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => selectedStatus = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<FinancingType?>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<FinancingType?>(
                          value: null,
                          child: Text('Tous les types'),
                        ),
                        ...FinancingType.values.map((type) {
                          return DropdownMenuItem<FinancingType?>(
                            value: type,
                            child: Text(type.displayName),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => selectedType = value);
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
                    this.context.read<FinancingBloc>().add(
                      LoadFinancingRequests(
                        status: selectedStatus,
                        type: selectedType,
                      ),
                    );
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
