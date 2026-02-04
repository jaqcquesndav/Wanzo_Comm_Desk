import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wanzo/utils/theme.dart';
import '../models/operation_journal_entry.dart';
import '../widgets/product_operation_image.dart';

/// Widget pour afficher la liste filtrée des opérations du journal
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

    // Liste des opérations
    return ListView.separated(
      itemCount: operations.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final operation = operations[index];
        return _OperationTile(
          operation: operation,
          onTap:
              onOperationTap != null ? () => onOperationTap!(operation) : null,
        );
      },
    );
  }
}

/// Tuile individuelle pour une opération
class _OperationTile extends StatelessWidget {
  final OperationJournalEntry operation;
  final VoidCallback? onTap;

  const _OperationTile({required this.operation, this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: WanzoTheme.spacingMd,
            vertical: WanzoTheme.spacingSm,
          ),
          onTap: onTap,
          leading: _buildOperationIcon(context),
          title: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  constraints.maxWidth * 0.6, // Limiter à 60% de la largeur
            ),
            child: _buildOperationTitle(context),
          ),
          subtitle: _buildOperationSubtitle(context),
          trailing: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  constraints.maxWidth * 0.3, // Limiter à 30% de la largeur
            ),
            child: _buildAmountWidget(context),
          ),
          dense: false,
        );
      },
    );
  }

  Widget _buildOperationIcon(BuildContext context) {
    // Pour les opérations liées aux produits, afficher l'image du produit
    if (operation.type == OperationType.saleCash ||
        operation.type == OperationType.saleCredit ||
        operation.type == OperationType.saleInstallment ||
        operation.type == OperationType.stockOut ||
        operation.type == OperationType.stockIn) {
      return ProductOperationImage(operation: operation, size: 48.0);
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
      radius: 24,
      child: Icon(operation.type.icon, color: iconColor, size: 20),
    );
  }

  Widget _buildOperationTitle(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          flex: 3, // Give more space to description
          child: Text(
            operation.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: WanzoTheme.spacingSm),
        Flexible(
          // Make chip flexible instead of taking fixed space
          child: _buildTypeChip(context),
        ),
      ],
    );
  }

  Widget _buildOperationSubtitle(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMd().add_Hm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(
              Icons.access_time,
              size: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              dateFormat.format(operation.date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        if (operation.productName != null) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  operation.productName!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        if (operation.paymentMethod != null) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.payment,
                size: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Text(
                operation.paymentMethod!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTypeChip(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 80, // Limit chip width to prevent overflow
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: WanzoTheme.spacingSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(WanzoTheme.borderRadiusSm),
      ),
      child: Text(
        operation.type.displayName,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildAmountWidget(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = operation.amount >= 0;
    final color = isPositive ? WanzoTheme.success : WanzoTheme.danger;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${isPositive ? '+' : ''}${NumberFormat.currency(locale: 'fr_FR', symbol: operation.currencyCode).format(operation.amount)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${operation.getBalanceLabel()}: ${NumberFormat.currency(locale: 'fr_FR', symbol: operation.currencyCode).format(operation.getRelevantBalance() ?? 0)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
