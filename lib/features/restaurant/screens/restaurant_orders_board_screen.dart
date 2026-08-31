import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/modules/module_registry.dart';
import '../../../core/services/business_context_service.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/kanban/kanban_board.dart';
import '../../customer/bloc/customer_bloc.dart';
import '../../customer/bloc/customer_event.dart';
import '../../customer/bloc/customer_state.dart';
import '../../customer/models/customer.dart';
import '../cubit/restaurant_orders_cubit.dart';
import '../models/restaurant_order.dart';
import '../widgets/restaurant_order_quick_view_dialog.dart';
import 'restaurant_floor_plan_view.dart';

/// Vue « Commandes » du restaurant en board Kanban (façon Trello/Asana).
///
/// Colonnes = statuts de service. Glisser une carte entre les colonnes actives
/// (En saisie → En cuisine → Servie) change son statut. L'encaissement (statut
/// « Réglée ») passe TOUJOURS par la caisse (création d'une `Sale`) : la colonne
/// Réglée n'accepte donc pas le dépôt direct. Remplace la liste desktop bancale.
/// Mode d'affichage de l'écran commandes : plan de salle (tables) ou board
/// Kanban (flux de service). Le plan de salle est la vue par défaut.
enum _OrdersView { plan, board }

class RestaurantOrdersBoardScreen extends StatefulWidget {
  const RestaurantOrdersBoardScreen({super.key});

  @override
  State<RestaurantOrdersBoardScreen> createState() =>
      _RestaurantOrdersBoardScreenState();
}

class _RestaurantOrdersBoardScreenState
    extends State<RestaurantOrdersBoardScreen> {
  // Plan de salle par défaut (prise de commande table-first).
  _OrdersView _view = _OrdersView.plan;

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
    // Conserve le shell de l'app (sidebar + header) comme les autres écrans.
    final ctx = BusinessContextService();
    final index = ModuleRegistry.indexOfSidebarRoute(
      ctx.activityMode,
      ctx.currentContext?.userRole,
      '/restaurant/board',
    );
    return WanzoScaffold(
      currentIndex: index < 0 ? 0 : index,
      title: 'Commandes',
      appBarActions: [
        IconButton(
          tooltip: 'Ouvrir la caisse',
          icon: const Icon(Icons.point_of_sale_outlined),
          onPressed: () => context.push('/restaurant/orders'),
        ),
      ],
      body: Column(
        children: [
          // Bascule Plan de salle / Board — les deux partagent le même cubit.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<_OrdersView>(
                segments: const [
                  ButtonSegment(
                    value: _OrdersView.plan,
                    label: Text('Plan de salle'),
                    icon: Icon(Icons.table_restaurant),
                  ),
                  ButtonSegment(
                    value: _OrdersView.board,
                    label: Text('Board'),
                    icon: Icon(Icons.view_kanban_outlined),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (s) =>
                    setState(() => _view = s.first),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _view == _OrdersView.plan
                ? const RestaurantFloorPlanView()
                : _buildBoard(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(BuildContext context) {
    return BlocBuilder<RestaurantOrdersCubit, RestaurantOrdersState>(
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
            onTapItem: (order) =>
                showRestaurantOrderQuickView(context, cubit, order),
          );
        },
      );
  }

  Future<void> _createOrder(
    BuildContext context,
    RestaurantOrdersCubit cubit,
  ) async {
    // Charge les clients existants pour proposer des suggestions dans le champ
    // « Libellé », tout en laissant saisir librement une table (« Table 4 »…).
    final customerBloc = context.read<CustomerBloc>()..add(const LoadCustomers());
    String typed = '';
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle commande'),
        content: SizedBox(
          width: 360,
          child: BlocBuilder<CustomerBloc, CustomerState>(
            bloc: customerBloc,
            builder: (context, state) {
              final customers = <Customer>[
                if (state is CustomersLoaded)
                  ...state.customers
                else if (state is CustomerSearchResults)
                  ...state.customers,
              ];
              return Autocomplete<Customer>(
                optionsBuilder: (value) {
                  final q = value.text.trim().toLowerCase();
                  if (q.isEmpty) return const Iterable<Customer>.empty();
                  return customers.where(
                    (c) =>
                        c.name.toLowerCase().contains(q) ||
                        c.phoneNumber.toLowerCase().contains(q),
                  );
                },
                displayStringForOption: (c) => c.name,
                onSelected: (c) => typed = c.name,
                fieldViewBuilder:
                    (context, textController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: textController,
                    focusNode: focusNode,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Libellé (Table 4, Emporter, nom du client…)',
                    ),
                    onChanged: (v) => typed = v,
                    onSubmitted: (v) => Navigator.pop(ctx, v),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 240,
                          maxWidth: 360,
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              leading: const Icon(Icons.person, size: 20),
                              title: Text(option.name),
                              subtitle: option.phoneNumber.isNotEmpty
                                  ? Text(option.phoneNumber)
                                  : null,
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, typed),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (label != null && label.trim().isNotEmpty) {
      await cubit.openOrder(label);
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
    // Carte façon Trello : ombre douce, sans bordure (cohérent avec l'atelier).
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
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
