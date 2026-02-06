import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/table_export_button.dart';
import '../../../services/export/table_export_service.dart';
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
    final dateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');

    return BlocBuilder<SalesBloc, SalesState>(
      builder: (context, state) {
        return WanzoScaffold(
          currentIndex: 1, // Index pour Revenus dans le sidebar
          title: 'Revenus', // Terminologie comptable: Revenus = Ventes
          appBarActions: [
            // Bouton d'export
            if (state is SalesLoaded && state.sales.isNotEmpty)
              TableExportIconButton(
                config: TableExportConfig(
                  title: 'Liste des ventes',
                  subtitle: 'Exporté le ${dateFormat.format(DateTime.now())}',
                  headers: [
                    'Date',
                    'Client',
                    'Produits',
                    'Total',
                    'Statut',
                    'Paiement',
                  ],
                  rows:
                      state.sales
                          .map(
                            (s) => [
                              dateFormat.format(s.date),
                              s.customerName,
                              s.items.length.toString(),
                              '${s.totalAmountInCdf.toStringAsFixed(2)} ${s.transactionCurrencyCode ?? "CDF"}',
                              s.status.displayName,
                              s.paymentMethod ?? '',
                            ],
                          )
                          .toList(),
                  fileName: 'ventes',
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
              onPressed: () => context.read<SalesBloc>().add(const LoadSales()),
              tooltip: 'Actualiser',
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/operations/sales/add'),
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle vente'),
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, SalesState state) {
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
              onPressed: () => context.read<SalesBloc>().add(const LoadSales()),
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
      return _buildSalesList(context, state.sales, state.totalAmountInCdf);
    }

    return const Center(child: Text('Chargement...'));
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

        // Tableau des ventes
        Expanded(
          child: _SalesDataTable(
            sales: sales,
            currencyFormat: currencyFormat,
            dateFormat: dateFormat,
            onSaleTap: (sale) {
              context.pushNamed(
                AppRoute.saleDetail.name,
                pathParameters: {'id': sale.id},
                extra: sale,
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

/// Widget DataTable pour afficher les ventes
class _SalesDataTable extends StatelessWidget {
  final List<Sale> sales;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;
  final Function(Sale) onSaleTap;

  const _SalesDataTable({
    required this.sales,
    required this.currencyFormat,
    required this.dateFormat,
    required this.onSaleTap,
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
                      'Client',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Articles',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    numeric: true,
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
                  DataColumn(
                    label: Text(
                      'Statut',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isCompact)
                    DataColumn(
                      label: Text(
                        'Encaissement', // Vue trésorerie
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      numeric:
                          false, // Changed to false since we use badges now
                    ),
                ],
                rows:
                    sales.map((sale) {
                      final itemsCount = sale.items.fold<int>(
                        0,
                        (sum, item) => sum + item.quantity,
                      );

                      return DataRow(
                        onSelectChanged: (_) => onSaleTap(sale),
                        cells: [
                          // Client
                          DataCell(
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isCompact ? 100 : 180,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: sale.status.color
                                        .withValues(alpha: 0.2),
                                    child: Icon(
                                      Icons.person,
                                      size: 16,
                                      color: sale.status.color,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      sale.customerName,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Articles
                          DataCell(
                            Text(
                              '$itemsCount',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          // Montant
                          DataCell(
                            Text(
                              currencyFormat.format(sale.totalAmountInCdf),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          // Date
                          DataCell(
                            Text(
                              isCompact
                                  ? DateFormat('dd/MM').format(sale.date)
                                  : dateFormat.format(sale.date),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          // Statut
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: sale.status.color.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sale.status.color.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                sale.status.displayName,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: sale.status.color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          // Payé (si pas compact) - Vue trésorerie avec badge
                          if (!isCompact)
                            DataCell(
                              _buildPaymentStatusBadge(
                                context,
                                sale.paidAmountInCdf,
                                sale.totalAmountInCdf,
                                currencyFormat,
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

  /// Badge de statut de paiement pour la vue trésorerie
  /// Affiche clairement si le paiement a impacté la caisse
  Widget _buildPaymentStatusBadge(
    BuildContext context,
    double paidAmount,
    double totalAmount,
    NumberFormat currencyFormat,
  ) {
    final theme = Theme.of(context);
    final percentage = totalAmount > 0 ? (paidAmount / totalAmount * 100) : 0;
    final isFullyPaid = paidAmount >= totalAmount;
    final isPartiallyPaid = paidAmount > 0 && paidAmount < totalAmount;
    final isNotPaid = paidAmount <= 0;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isFullyPaid) {
      statusColor = Colors.green;
      statusText = 'Encaissé';
      statusIcon = Icons.check_circle;
    } else if (isPartiallyPaid) {
      statusColor = Colors.blue;
      statusText = '${percentage.toStringAsFixed(0)}%';
      statusIcon = Icons.pie_chart;
    } else {
      statusColor = Colors.orange;
      statusText = 'Non encaissé';
      statusIcon = Icons.schedule;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 12, color: statusColor),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (isPartiallyPaid || isNotPaid) ...[
          const SizedBox(width: 8),
          Text(
            currencyFormat.format(paidAmount),
            style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
          ),
        ],
      ],
    );
  }
}
