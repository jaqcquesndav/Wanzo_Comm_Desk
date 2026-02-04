import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../../core/navigation/app_router.dart';
import '../bloc/sales_bloc.dart';
import '../models/sale.dart';

/// Extension pour afficher le nom du statut
extension SaleStatusDisplayExtension on SaleStatus {
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

  Color get color {
    switch (this) {
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

/// Écran de liste des ventes
class SalesListScreen extends StatefulWidget {
  const SalesListScreen({super.key});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  @override
  void initState() {
    super.initState();
    // Charger les ventes au démarrage
    context.read<SalesBloc>().add(const LoadSales());
  }

  @override
  Widget build(BuildContext context) {
    return WanzoScaffold(
      currentIndex: 1, // Index pour Ventes dans le sidebar
      title: 'Ventes',
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () => _showFilterDialog(context),
          tooltip: 'Filtrer',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => context.read<SalesBloc>().add(const LoadSales()),
          tooltip: 'Actualiser',
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/operations/sales/add'),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle vente'),
      ),
      body: BlocBuilder<SalesBloc, SalesState>(
        builder: (context, state) {
          if (state is SalesLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SalesError) {
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
                        () => context.read<SalesBloc>().add(const LoadSales()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          if (state is SalesLoaded) {
            if (state.sales.isEmpty) {
              return _buildEmptyState(context);
            }
            return _buildSalesList(
              context,
              state.sales,
              state.totalAmountInCdf,
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
          Icon(Icons.point_of_sale_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucune vente enregistrée',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Commencez par créer votre première vente',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/operations/sales/add'),
            icon: const Icon(Icons.add),
            label: const Text('Créer une vente'),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesList(
    BuildContext context,
    List<Sale> sales,
    double totalAmount,
  ) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'CDF',
    );
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Column(
      children: [
        // En-tête avec total
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${sales.length} vente${sales.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Total: ${currencyFormat.format(totalAmount)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),

        // Liste des ventes
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: sales.length,
            itemBuilder: (context, index) {
              final sale = sales[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: sale.status.color.withValues(alpha: 0.2),
                    child: Icon(Icons.receipt_long, color: sale.status.color),
                  ),
                  title: Text(
                    sale.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currencyFormat.format(sale.totalAmountInCdf),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        dateFormat.format(sale.date),
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
                      color: sale.status.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      sale.status.displayName,
                      style: TextStyle(
                        color: sale.status.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  isThreeLine: true,
                  onTap: () {
                    context.pushNamed(
                      AppRoute.saleDetail.name,
                      pathParameters: {'id': sale.id},
                      extra: sale,
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

  void _showFilterDialog(BuildContext context) {
    SaleStatus? selectedStatus;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filtrer les ventes'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<SaleStatus?>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<SaleStatus?>(
                        value: null,
                        child: Text('Tous les statuts'),
                      ),
                      ...SaleStatus.values.map((status) {
                        return DropdownMenuItem<SaleStatus?>(
                          value: status,
                          child: Text(status.displayName),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => selectedStatus = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedStatus != null) {
                      this.context.read<SalesBloc>().add(
                        LoadSalesByStatus(selectedStatus!),
                      );
                    } else {
                      this.context.read<SalesBloc>().add(const LoadSales());
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
