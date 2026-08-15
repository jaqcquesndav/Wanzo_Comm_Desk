import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/kanban/kanban_board.dart';
import '../cubit/restaurant_orders_cubit.dart';
import '../models/restaurant_order.dart';

/// Vue « Commandes » du restaurant en board Kanban (façon Trello/Asana).
///
/// Colonnes = statuts de service. Glisser une carte entre les colonnes actives
/// (En saisie → En cuisine → Servie) change son statut. L'encaissement (statut
/// « Réglée ») passe TOUJOURS par la caisse (création d'une `Sale`) : la colonne
/// Réglée n'accepte donc pas le dépôt direct. Remplace la liste desktop bancale.
class RestaurantOrdersBoardScreen extends StatelessWidget {
  const RestaurantOrdersBoardScreen({super.key});

  static const _accent = <RestaurantOrderStatus, Color>{
    RestaurantOrderStatus.open: Color(0xFF64748B), // slate
    RestaurantOrderStatus.sent: Color(0xFFF59E0B), // amber
    RestaurantOrderStatus.served: Color(0xFF0EA5E9), // sky
    RestaurantOrderStatus.paid: Color(0xFF16A34A), // green
    RestaurantOrderStatus.cancelled: Color(0xFFDC2626), // red
  };

  // Ordre d'affichage des colonnes = flux naturel du service.
  static const _columnOrder = <RestaurantOrderStatus>[
    RestaurantOrderStatus.open,
    RestaurantOrderStatus.sent,
    RestaurantOrderStatus.served,
    RestaurantOrderStatus.paid,
    RestaurantOrderStatus.cancelled,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commandes'),
        actions: [
          IconButton(
            tooltip: 'Ouvrir la caisse',
            icon: const Icon(Icons.point_of_sale_outlined),
            onPressed: () => context.push('/restaurant/orders'),
          ),
        ],
      ),
      body: BlocBuilder<RestaurantOrdersCubit, RestaurantOrdersState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final cubit = context.read<RestaurantOrdersCubit>();
          final columns = [
            for (final status in _columnOrder)
              KanbanColumnData<RestaurantOrder>(
                id: status.apiValue,
                title: status.label,
                color: _accent[status]!,
                items: state.orders
                    .where((o) => o.status == status)
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
                // L'encaissement passe par la caisse ; l'annulation par une
                // confirmation (tap) → on n'accepte pas le dépôt direct.
                acceptsDrops: status != RestaurantOrderStatus.paid &&
                    status != RestaurantOrderStatus.cancelled,
                onAdd: status == RestaurantOrderStatus.open
                    ? () => _createOrder(context, cubit)
                    : null,
              ),
          ];

          return KanbanBoard<RestaurantOrder>(
            columns: columns,
            itemId: (o) => o.id,
            cardBuilder: (context, o) => _OrderCard(order: o),
            onMoveItem: (order, toColumnId) {
              final target = RestaurantOrderStatusX.fromApiValue(toColumnId);
              if (target == order.status) return;
              cubit.updateStatus(order.id, target);
            },
            onTapItem: (order) => _showActions(context, cubit, order),
          );
        },
      ),
    );
  }

  Future<void> _createOrder(
    BuildContext context,
    RestaurantOrdersCubit cubit,
  ) async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle commande'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Libellé (Table 4, Emporter, nom du client…)',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (label != null && label.trim().isNotEmpty) {
      await cubit.openOrder(label);
    }
  }

  void _showActions(
    BuildContext context,
    RestaurantOrdersCubit cubit,
    RestaurantOrder order,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.label,
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      formatCurrency(order.totalCdf, 'CDF'),
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${order.itemCount} article(s) · ${order.status.label}',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
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
                  leading: const Icon(Icons.point_of_sale_outlined),
                  title: const Text('Encaisser (caisse)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/restaurant/orders');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                  title: const Text('Annuler la commande'),
                  onTap: () {
                    cubit.cancel(order.id);
                    Navigator.pop(ctx);
                  },
                ),
              ] else
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Supprimer de la liste'),
                  onTap: () {
                    cubit.deleteOrder(order.id);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// Statuts atteignables depuis un statut actif (flux avant uniquement).
  List<RestaurantOrderStatus> _nextStatuses(RestaurantOrderStatus current) {
    switch (current) {
      case RestaurantOrderStatus.open:
        return [RestaurantOrderStatus.sent, RestaurantOrderStatus.served];
      case RestaurantOrderStatus.sent:
        return [RestaurantOrderStatus.served];
      case RestaurantOrderStatus.served:
        return const [];
      case RestaurantOrderStatus.paid:
      case RestaurantOrderStatus.cancelled:
        return const [];
    }
  }
}

/// Carte d'une commande sur le board.
class _OrderCard extends StatelessWidget {
  final RestaurantOrder order;
  const _OrderCard({required this.order});

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
          Row(
            children: [
              Expanded(
                child: Text(
                  order.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _timeAgo(order.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${order.itemCount} article(s)',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                formatCurrency(order.totalCdf, 'CDF'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  }
}
