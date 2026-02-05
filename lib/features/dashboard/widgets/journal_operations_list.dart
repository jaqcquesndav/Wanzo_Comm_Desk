import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wanzo/utils/theme.dart';
import '../models/operation_journal_entry.dart';
import '../widgets/product_operation_image.dart';

/// Widget pour afficher la liste filtrée des opérations du journal en format tableau
class JournalOperationsList extends StatelessWidget {
  final List<OperationJournalEntry> operations;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Function(OperationJournalEntry)? onOperationTap;

  const JournalOperationsList({
    super.key,
    required this.operations,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.onOperationTap,
  });

  @override
  Widget build(BuildContext context) {
    // État de chargement
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(WanzoTheme.spacingXl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // État d'erreur
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(WanzoTheme.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: WanzoTheme.spacingMd),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: WanzoTheme.spacingMd),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Liste vide
    if (operations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(WanzoTheme.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: WanzoTheme.spacingMd),
              Text(
                'Aucune opération trouvée',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: WanzoTheme.spacingSm),
              Text(
                'Essayez de modifier vos filtres pour voir plus d\'opérations',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Affichage en tableau
    return _OperationsDataTable(
      operations: operations,
      onOperationTap: onOperationTap,
    );
  }
}

/// Widget tableau pour les opérations
class _OperationsDataTable extends StatelessWidget {
  final List<OperationJournalEntry> operations;
  final Function(OperationJournalEntry)? onOperationTap;

  const _OperationsDataTable({required this.operations, this.onOperationTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM HH:mm');
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: isCompact ? 12 : 24,
                horizontalMargin: isCompact ? 8 : 16,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 64,
                headingRowColor: WidgetStateProperty.all(
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                ),
                columns: [
                  const DataColumn(label: Text(''), numeric: false),
                  DataColumn(
                    label: Text(
                      'Description',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Type',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                      'Montant',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    numeric: true,
                  ),
                  if (!isCompact)
                    DataColumn(
                      label: Text(
                        'Solde',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      numeric: true,
                    ),
                ],
                rows:
                    operations.map((operation) {
                      final isPositive = operation.amount >= 0;
                      final amountColor =
                          isPositive ? WanzoTheme.success : WanzoTheme.danger;

                      return DataRow(
                        onSelectChanged:
                            onOperationTap != null
                                ? (_) => onOperationTap!(operation)
                                : null,
                        cells: [
                          // Icône/Image
                          DataCell(_buildOperationIcon(context, operation)),
                          // Description
                          DataCell(
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isCompact ? 120 : 200,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    operation.description,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (operation.productName != null)
                                    Text(
                                      operation.productName!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // Type
                          DataCell(_buildTypeChip(context, operation)),
                          // Date
                          DataCell(
                            Text(
                              dateFormat.format(operation.date),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          // Montant
                          DataCell(
                            Text(
                              '${isPositive ? '+' : ''}${currencyFormat.format(operation.amount)} ${operation.currencyCode}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: amountColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Solde (si pas compact)
                          if (!isCompact)
                            DataCell(
                              Text(
                                '${currencyFormat.format(operation.getRelevantBalance() ?? 0)} ${operation.currencyCode}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
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
        );
      },
    );
  }

  Widget _buildOperationIcon(
    BuildContext context,
    OperationJournalEntry operation,
  ) {
    // Pour les opérations liées aux produits, afficher l'image du produit
    if (operation.type == OperationType.saleCash ||
        operation.type == OperationType.saleCredit ||
        operation.type == OperationType.saleInstallment ||
        operation.type == OperationType.stockOut ||
        operation.type == OperationType.stockIn) {
      return ProductOperationImage(operation: operation, size: 36.0);
    }

    // Pour les autres opérations, utiliser l'icône générique
    final theme = Theme.of(context);

    Color backgroundColor;
    Color iconColor;

    switch (operation.type) {
      case OperationType.cashOut:
        backgroundColor = WanzoTheme.danger.withValues(alpha: 0.1);
        iconColor = WanzoTheme.danger;
        break;
      case OperationType.cashIn:
      case OperationType.customerPayment:
        backgroundColor = WanzoTheme.info.withValues(alpha: 0.1);
        iconColor = WanzoTheme.info;
        break;
      case OperationType.supplierPayment:
      case OperationType.financingRepayment:
        backgroundColor = WanzoTheme.warning.withValues(alpha: 0.1);
        iconColor = WanzoTheme.warning;
        break;
      case OperationType.financingRequest:
      case OperationType.financingApproved:
        backgroundColor = WanzoTheme.success.withValues(alpha: 0.1);
        iconColor = WanzoTheme.success;
        break;
      default:
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        iconColor = theme.colorScheme.onSurfaceVariant;
        break;
    }

    return CircleAvatar(
      backgroundColor: backgroundColor,
      radius: 18,
      child: Icon(operation.type.icon, color: iconColor, size: 16),
    );
  }

  Widget _buildTypeChip(BuildContext context, OperationJournalEntry operation) {
    final theme = Theme.of(context);

    Color chipColor;
    switch (operation.type) {
      case OperationType.saleCash:
      case OperationType.saleCredit:
      case OperationType.saleInstallment:
        chipColor = WanzoTheme.success;
        break;
      case OperationType.cashOut:
      case OperationType.supplierPayment:
        chipColor = WanzoTheme.danger;
        break;
      case OperationType.cashIn:
      case OperationType.customerPayment:
        chipColor = WanzoTheme.info;
        break;
      case OperationType.stockIn:
        chipColor = Colors.teal;
        break;
      case OperationType.stockOut:
        chipColor = Colors.orange;
        break;
      default:
        chipColor = theme.colorScheme.outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(WanzoTheme.borderRadiusSm),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        operation.type.displayName,
        style: theme.textTheme.labelSmall?.copyWith(
          color: chipColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
