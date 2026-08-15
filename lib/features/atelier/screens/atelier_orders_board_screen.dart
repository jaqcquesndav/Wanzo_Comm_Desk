import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/kanban/kanban_board.dart';
import '../cubit/atelier_orders_cubit.dart';
import '../models/atelier_order.dart';
import 'atelier_order_form_screen.dart';

/// Board Kanban des commandes de confection (couture/cordonnerie).
///
/// Colonnes = étapes de fabrication. Glisser une carte entre étapes actives
/// change son statut ; « Marquer réglée » déclenche la facturation automatique
/// (création d'une vente côté backend). Réutilise le même `KanbanBoard` que le
/// restaurant → cohérence et zéro duplication de logique board.
class AtelierOrdersBoardScreen extends StatelessWidget {
  const AtelierOrdersBoardScreen({super.key});

  static const _accent = <AtelierOrderStatus, Color>{
    AtelierOrderStatus.draft: Color(0xFF64748B),
    AtelierOrderStatus.measured: Color(0xFF8B5CF6),
    AtelierOrderStatus.cutting: Color(0xFFF59E0B),
    AtelierOrderStatus.sewing: Color(0xFF0EA5E9),
    AtelierOrderStatus.ready: Color(0xFF14B8A6),
    AtelierOrderStatus.delivered: Color(0xFF6366F1),
    AtelierOrderStatus.paid: Color(0xFF16A34A),
    AtelierOrderStatus.cancelled: Color(0xFFDC2626),
  };

  static const _columnOrder = <AtelierOrderStatus>[
    AtelierOrderStatus.draft,
    AtelierOrderStatus.measured,
    AtelierOrderStatus.cutting,
    AtelierOrderStatus.sewing,
    AtelierOrderStatus.ready,
    AtelierOrderStatus.delivered,
    AtelierOrderStatus.paid,
    AtelierOrderStatus.cancelled,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commandes — Atelier'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AtelierOrdersCubit>().load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle commande'),
      ),
      body: BlocBuilder<AtelierOrdersCubit, AtelierOrdersState>(
        builder: (context, state) {
          if (state.loading && state.orders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null && state.orders.isEmpty) {
            return _ErrorView(
              message: state.error!,
              onRetry: () => context.read<AtelierOrdersCubit>().load(),
            );
          }
          final cubit = context.read<AtelierOrdersCubit>();
          final columns = [
            for (final status in _columnOrder)
              KanbanColumnData<AtelierOrder>(
                id: status.apiValue,
                title: status.label,
                color: _accent[status]!,
                items: state.orders.where((o) => o.status == status).toList(),
                // Le règlement (facturation auto) et l'annulation passent par le
                // menu d'actions (tap) → pas de dépôt direct dans ces colonnes.
                acceptsDrops: status != AtelierOrderStatus.paid &&
                    status != AtelierOrderStatus.cancelled,
                onAdd: status == AtelierOrderStatus.draft
                    ? () => _openForm(context)
                    : null,
              ),
          ];

          return KanbanBoard<AtelierOrder>(
            columns: columns,
            itemId: (o) => o.id,
            cardBuilder: (context, o) => _AtelierCard(order: o),
            onMoveItem: (order, toColumnId) {
              final target = AtelierOrderStatusX.fromApiValue(toColumnId);
              if (target == order.status) return;
              cubit.updateStatus(order.id, target);
            },
            onTapItem: (order) => _showActions(context, cubit, order),
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {AtelierOrder? order}) async {
    final cubit = context.read<AtelierOrdersCubit>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: AtelierOrderFormScreen(order: order),
        ),
      ),
    );
  }

  void _showActions(
    BuildContext context,
    AtelierOrdersCubit cubit,
    AtelierOrder order,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(order.label, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${order.customerName ?? 'Client'} · ${order.status.label}\n'
                'Total ${formatCurrency(order.totalAmount, order.currencyCode)}'
                ' · Reste ${formatCurrency(order.remainingAmount, order.currencyCode)}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ),
            const Divider(),
            if (order.status.isActive) ...[
              for (final next in _nextStatuses(order.status))
                ListTile(
                  leading: Icon(Icons.arrow_forward, color: _accent[next]),
                  title: Text('Passer à « ${next.label} »'),
                  onTap: () {
                    cubit.updateStatus(order.id, next);
                    Navigator.pop(ctx);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.receipt_long, color: Color(0xFF16A34A)),
                title: const Text('Marquer réglée (facturer)'),
                subtitle: const Text('Génère automatiquement la vente'),
                onTap: () {
                  cubit.updateStatus(order.id, AtelierOrderStatus.paid);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openForm(context, order: order);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: const Text('Annuler la commande'),
                onTap: () {
                  cubit.updateStatus(order.id, AtelierOrderStatus.cancelled);
                  Navigator.pop(ctx);
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Supprimer'),
                onTap: () {
                  cubit.deleteOrder(order.id);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  List<AtelierOrderStatus> _nextStatuses(AtelierOrderStatus current) {
    const flow = [
      AtelierOrderStatus.draft,
      AtelierOrderStatus.measured,
      AtelierOrderStatus.cutting,
      AtelierOrderStatus.sewing,
      AtelierOrderStatus.ready,
      AtelierOrderStatus.delivered,
    ];
    final idx = flow.indexOf(current);
    if (idx < 0 || idx >= flow.length - 1) return const [];
    return [flow[idx + 1]];
  }
}

class _AtelierCard extends StatelessWidget {
  final AtelierOrder order;
  const _AtelierCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.label,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          if (order.customerName != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    order.customerName!,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (order.exitDate != null) ...[
                Icon(Icons.event_outlined, size: 13, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Text(_fmtDate(order.exitDate!), style: theme.textTheme.labelSmall),
              ],
              const Spacer(),
              Text(
                order.remainingAmount > 0
                    ? 'Reste ${formatCurrency(order.remainingAmount, order.currencyCode)}'
                    : formatCurrency(order.totalAmount, order.currencyCode),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: order.remainingAmount > 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
