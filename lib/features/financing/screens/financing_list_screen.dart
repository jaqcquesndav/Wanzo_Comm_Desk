import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../../core/services/form_navigation_service.dart';
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
        onPressed:
            () => FormNavigationService.instance.openFinancingForm(
              context,
              onSuccess:
                  () => context.read<FinancingBloc>().add(
                    const LoadFinancingRequests(),
                  ),
            ),
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
            // Tri chronologique : plus récentes en premier
            final sortedRequests = List<FinancingRequest>.from(state.requests)
              ..sort((a, b) => b.requestDate.compareTo(a.requestDate));
            return _buildFinancingList(context, sortedRequests);
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
            onPressed:
                () => FormNavigationService.instance.openFinancingForm(
                  context,
                  onSuccess:
                      () => context.read<FinancingBloc>().add(
                        const LoadFinancingRequests(),
                      ),
                ),
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

        // Tableau des financements
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: DataTable(
                          columnSpacing: 24,
                          horizontalMargin: 16,
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 72,
                          border: TableBorder(
                            horizontalInside: BorderSide(
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.5),
                              width: 0.5,
                            ),
                          ),
                          headingRowColor: WidgetStateProperty.all(
                            Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.08),
                          ),
                          headingTextStyle: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          columns: const [
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Institution')),
                            DataColumn(label: Text('Montant'), numeric: true),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Statut')),
                          ],
                          rows:
                              requests.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final request = entry.value;
                                final statusColor = _getStatusColor(
                                  request.status,
                                );
                                final statusText = _getStatusText(
                                  request.status,
                                );
                                final theme = Theme.of(context);

                                return DataRow(
                                  color: WidgetStateProperty.resolveWith<
                                    Color?
                                  >((states) {
                                    if (states.contains(WidgetState.hovered)) {
                                      return theme.colorScheme.primary
                                          .withValues(alpha: 0.06);
                                    }
                                    if (idx.isOdd) {
                                      return theme
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.3);
                                    }
                                    return null;
                                  }),
                                  onSelectChanged: (_) {
                                    context.pushNamed(
                                      'financing_detail',
                                      pathParameters: {'id': request.id},
                                      extra: request,
                                    );
                                  },
                                  cells: [
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: statusColor
                                                .withValues(alpha: 0.2),
                                            child: Icon(
                                              Icons.account_balance,
                                              size: 16,
                                              color: statusColor,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            request.type.displayName,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        request.institution.displayName,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        NumberFormat.currency(
                                          locale: 'fr_FR',
                                          symbol: request.currency,
                                        ).format(request.amount),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.purple[700],
                                            ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        dateFormat.format(request.requestDate),
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: statusColor.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: statusColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ),
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
