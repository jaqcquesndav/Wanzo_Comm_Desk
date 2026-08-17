import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../constants/colors.dart';
import '../../../core/modules/module_registry.dart';
import '../../../core/services/business_context_service.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/kanban/kanban_board.dart';
import '../../sales/bloc/sales_bloc.dart';
import '../../sales/models/sale_item.dart';
import '../../sales/screens/add_sale_screen.dart';
import '../cubit/atelier_orders_cubit.dart';
import '../models/atelier_order.dart';
import '../widgets/atelier_actor_chip.dart';
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
    // Conserve le shell de l'app (sidebar + header) : sinon écran nu sans
    // navigation. Même approche que les autres écrans principaux.
    final ctx = BusinessContextService();
    final index = ModuleRegistry.indexOfSidebarRoute(
      ctx.activityMode,
      ctx.currentContext?.userRole,
      '/atelier/board',
    );
    return WanzoScaffold(
      currentIndex: index < 0 ? 0 : index,
      title: 'Commandes — Atelier',
      appBarActions: [
        IconButton(
          tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh),
          onPressed: () => context.read<AtelierOrdersCubit>().load(),
        ),
      ],
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
    // Présentation adaptative : feuille depuis le bas sur mobile ; dialog centré
    // et compact sur grand écran.
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    List<Widget> actions(BuildContext ctx) => [
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
              leading: const Icon(Icons.receipt_long, color: WanzoColors.success),
              title: const Text('Facturer / encaisser'),
              subtitle: const Text('Ouvre le formulaire de vente (ticket + facture)'),
              onTap: () {
                Navigator.pop(ctx);
                _settleViaInvoice(context, cubit, order);
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
              leading: Icon(Icons.cancel_outlined, color: Theme.of(ctx).colorScheme.error),
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
        ];

    if (isWide) {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: actions(ctx),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions(ctx),
          ),
        ),
      );
    }
  }

  /// Facturation/encaissement d'une commande via le FORMULAIRE DE VENTE normal
  /// (workflow cohérent : ticket de caisse, facture, journal des opérations).
  /// La vente créée est rattachée à la commande.
  void _settleViaInvoice(
    BuildContext context,
    AtelierOrdersCubit cubit,
    AtelierOrder order,
  ) {
    final salesBloc = context.read<SalesBloc>();
    final amountToBill =
        order.remainingAmount > 0 ? order.remainingAmount : order.totalAmount;
    final line = SaleItem.withCalculatedTotal(
      // UUID de la commande (pas un produit du stock) : le backend crée l'item
      // sans référence produit ni décrément de stock (article de service).
      productId: order.id,
      productName: order.label,
      quantity: 1,
      unitPrice: amountToBill,
      currencyCode: order.currencyCode,
      exchangeRate: order.exchangeRate,
      itemType: SaleItemType.service,
      notes: '[Atelier] ${order.modelDetails ?? ''} (commande ${order.id})'.trim(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: salesBloc),
            BlocProvider.value(value: cubit),
          ],
          child: AddSaleScreen(
            initialCustomerId: order.customerId,
            initialCustomerName: order.customerName,
            initialItems: [line],
            initialPaidAmount: amountToBill,
            initialCurrencyCode: order.currencyCode,
            initialNotes: 'Règlement commande atelier « ${order.label} »',
            onSaleCreated: (sale) {
              final paid = sale.paidAmountInTransactionCurrency ?? 0;
              final coversBalance = paid + 0.01 >= amountToBill;
              if (coversBalance) {
                cubit.updateStatus(
                  order.id,
                  AtelierOrderStatus.paid,
                  saleId: sale.id,
                );
              } else {
                cubit.updateOrder(order.id, {
                  'saleId': sale.id,
                  'advanceAmount': order.advanceAmount + paid,
                });
              }
            },
          ),
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
    // Carte façon Trello : surface + ombre douce, SANS bordure (fini l'aspect
    // « grillagé/éclaté » où chaque carte était encadrée d'un trait).
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
                      ? WanzoColors.warning
                      : WanzoColors.success,
                ),
              ),
            ],
          ),
          // Attribution façon Trello : qui a validé la dernière étape.
          if (order.lastActionByName != null) ...[
            const SizedBox(height: 8),
            AtelierActorChip(
              name: order.lastActionByName!,
              avatarUrl: order.lastActionByAvatar,
              action: order.lastAction,
              at: order.lastActionAt,
            ),
          ],
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
