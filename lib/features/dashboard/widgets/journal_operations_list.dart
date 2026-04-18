import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wanzo/utils/theme.dart';
import '../models/operation_journal_entry.dart';
import '../bloc/operation_journal_bloc.dart';
import '../widgets/product_operation_image.dart';

/// Widget pour afficher la liste filtrée des opérations du journal en format tableau
/// groupées par jour avec soldes d'ouverture et de fermeture.
class JournalOperationsList extends StatelessWidget {
  final List<OperationJournalEntry> operations;
  final Map<DateTime, List<OperationJournalEntry>>? groupedOperations;
  final Map<DateTime, DailyBalanceSummary>? dailyBalances;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Function(OperationJournalEntry)? onOperationTap;

  const JournalOperationsList({
    super.key,
    required this.operations,
    this.groupedOperations,
    this.dailyBalances,
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

    // Affichage en tableau groupé par jour
    if (groupedOperations != null &&
        dailyBalances != null &&
        groupedOperations!.isNotEmpty) {
      return _GroupedOperationsDataTable(
        groupedOperations: groupedOperations!,
        dailyBalances: dailyBalances!,
        onOperationTap: onOperationTap,
      );
    }

    // Fallback: tableau plat sans en-têtes de jour
    return _OperationsDataTable(
      operations: operations,
      onOperationTap: onOperationTap,
    );
  }
}

/// Widget tableau groupé par jour avec en-têtes/pieds d'ouverture/fermeture
class _GroupedOperationsDataTable extends StatelessWidget {
  final Map<DateTime, List<OperationJournalEntry>> groupedOperations;
  final Map<DateTime, DailyBalanceSummary> dailyBalances;
  final Function(OperationJournalEntry)? onOperationTap;

  const _GroupedOperationsDataTable({
    required this.groupedOperations,
    required this.dailyBalances,
    this.onOperationTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayFormat = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '');
    final sortedDays = groupedOperations.keys.toList()..sort();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final day in sortedDays) ...[
            // En-tête de journée avec soldes d'ouverture
            _buildDayHeader(context, day, dayFormat, currencyFormat, theme),
            // Tableau des opérations du jour
            _OperationsDataTable(
              operations: groupedOperations[day] ?? [],
              onOperationTap: onOperationTap,
            ),
            // Pied de journée avec soldes de fermeture
            _buildDayFooter(context, day, currencyFormat, theme),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildDayHeader(
    BuildContext context,
    DateTime day,
    DateFormat dayFormat,
    NumberFormat currencyFormat,
    ThemeData theme,
  ) {
    final balance = dailyBalances[day];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            dayFormat.format(day),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const Spacer(),
          if (balance != null)
            ...balance.openingCash.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  'Ouv. ${e.key}: ${currencyFormat.format(e.value)} ${e.key}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayFooter(
    BuildContext context,
    DateTime day,
    NumberFormat currencyFormat,
    ThemeData theme,
  ) {
    final balance = dailyBalances[day];
    if (balance == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
        border: Border(top: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ...balance.closingCash.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                'Ferm. ${e.key}: ${currencyFormat.format(e.value)} ${e.key}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
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
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: DataTable(
                    columnSpacing: isCompact ? 12 : 24,
                    horizontalMargin: isCompact ? 8 : 16,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 64,
                    border: TableBorder(
                      horizontalInside: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.5),
                        width: 0.5,
                      ),
                    ),
                    headingRowColor: WidgetStateProperty.all(
                      theme.colorScheme.primary.withValues(alpha: 0.08),
                    ),
                    headingTextStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                    columns: [
                      const DataColumn(label: Text(''), numeric: false),
                      const DataColumn(label: Text('Description')),
                      const DataColumn(label: Text('Type')),
                      const DataColumn(label: Text('Date')),
                      const DataColumn(label: Text('Montant'), numeric: true),
                      if (!isCompact)
                        const DataColumn(label: Text('Solde'), numeric: true),
                    ],
                    rows:
                        operations.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final operation = entry.value;
                          final isPositive = operation.amount >= 0;
                          final amountColor =
                              isPositive
                                  ? WanzoTheme.success
                                  : WanzoTheme.danger;

                          return DataRow(
                            color: WidgetStateProperty.resolveWith<Color?>((
                              states,
                            ) {
                              if (states.contains(WidgetState.hovered)) {
                                return theme.colorScheme.primary.withValues(
                                  alpha: 0.06,
                                );
                              }
                              if (idx.isOdd) {
                                return theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3);
                              }
                              return null;
                            }),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        operation.description,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
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
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
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
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
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
