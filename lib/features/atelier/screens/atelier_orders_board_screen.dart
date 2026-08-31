import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../constants/colors.dart';
import '../../../core/modules/activity_mode.dart';
import '../../../core/modules/module_registry.dart';
import '../../../core/services/business_context_service.dart';
import '../../../core/services/form_navigation_service.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/kanban/kanban_board.dart';
import '../../sales/bloc/sales_bloc.dart';
import '../../sales/models/sale_item.dart';
import '../../sales/screens/add_sale_screen.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../../settings/bloc/settings_state.dart';
import '../../settings/models/settings.dart';
import '../cubit/atelier_orders_cubit.dart';
import '../models/atelier_order.dart';
import '../services/atelier_perf.dart';
import '../services/atelier_sheet_pdf.dart';
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
    // Métier courant → libellés d'étapes ADAPTÉS (un atelier de maintenance
    // n'affiche pas « Coupe/Couture » mais « Diagnostic/Réparation/Test »).
    final boardMetier = ctx.activityMode == ActivityMode.atelierMaintenance
        ? AtelierMetier.maintenance
        : AtelierMetier.couture;
    final index = ModuleRegistry.indexOfSidebarRoute(
      ctx.activityMode,
      ctx.currentContext?.userRole,
      '/atelier/board',
    );
    return WanzoScaffold(
      currentIndex: index < 0 ? 0 : index,
      title: boardMetier == AtelierMetier.maintenance
          ? 'Commandes — Maintenance'
          : 'Commandes — Atelier',
      appBarActions: [
        IconButton(
          tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh),
          onPressed: () => context.read<AtelierOrdersCubit>().load(),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        tooltip: 'Nouvelle commande',
        child: const Icon(Icons.add),
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
                title: status.labelFor(boardMetier),
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

          return Column(
            children: [
              _PerfKpis(orders: state.orders),
              Expanded(
                child: KanbanBoard<AtelierOrder>(
                  columns: columns,
                  itemId: (o) => o.id,
                  cardBuilder: (context, o) => _AtelierCard(order: o),
                  onMoveItem: (order, toColumnId) {
                    final target = AtelierOrderStatusX.fromApiValue(toColumnId);
                    if (target == order.status) return;
                    cubit.updateStatus(order.id, target);
                  },
                  onTapItem: (order) => _showActions(context, cubit, order),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {AtelierOrder? order}) async {
    final cubit = context.read<AtelierOrdersCubit>();
    final child = BlocProvider.value(
      value: cubit,
      child: AtelierOrderFormScreen(order: order),
    );
    // Desktop/tablet : ouvrir en modal (comme vente/dépense/produit via
    // FormNavigationService) plutôt qu'une page pleine. Le formulaire se ferme
    // lui-même (Navigator.pop) et met à jour le cubit → le board se rafraîchit.
    if (FormNavigationService.instance.shouldUseModal(context)) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 720,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: child,
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => child),
      );
    }
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
              '${order.customerName ?? 'Client'} · ${order.status.labelFor(order.metier)}\n'
              'Total ${formatCurrency(order.totalAmount, order.currencyCode)}'
              ' · Reste ${formatCurrency(order.remainingAmount, order.currencyCode)}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: Text(
              order.metier == AtelierMetier.maintenance
                  ? 'Fiche de réparation / imprimer'
                  : 'Bon de commande / imprimer',
            ),
            subtitle: const Text('État de sortie imprimable (A4)'),
            onTap: () {
              Navigator.pop(ctx);
              _printSheet(context, order);
            },
          ),
          const Divider(height: 1),
          if (order.status.isActive) ...[
            for (final next in _nextStatuses(order.status))
              ListTile(
                leading: Icon(Icons.arrow_forward, color: _accent[next]),
                title: Text('Passer à « ${next.labelFor(order.metier)} »'),
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

  /// Génère et ouvre la fiche imprimable (état de sortie) de la commande.
  /// Métier-aware : le service choisit la mise en page selon `order.metier`.
  Future<void> _printSheet(BuildContext context, AtelierOrder order) async {
    final messenger = ScaffoldMessenger.of(context);
    Settings? settings;
    final settingsState = context.read<SettingsBloc>().state;
    if (settingsState is SettingsLoaded) {
      settings = settingsState.settings;
    } else if (settingsState is SettingsUpdated) {
      settings = settingsState.settings;
    }
    try {
      await AtelierSheetPdf.printSheet(order, settings: settings);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Impossible de générer la fiche : $e')),
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

/// Bandeau de KPI de performance de prestation (en-tête du board). Destinés à
/// terme à alimenter la cote crédit de l'entreprise.
class _PerfKpis extends StatelessWidget {
  final List<AtelierOrder> orders;
  const _PerfKpis({required this.orders});

  @override
  Widget build(BuildContext context) {
    final p = computeAtelierPerf(orders);
    if (!p.hasData) return const SizedBox.shrink();
    final theme = Theme.of(context);

    Widget kpi(IconData icon, String value, String label) => Expanded(
          child: Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 10.5, color: Color(0xFF6B7280)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          kpi(Icons.pending_actions_outlined, '${p.inProgress}', 'En cours'),
          kpi(Icons.timer_outlined,
              p.avgCycleDays > 0 ? '${p.avgCycleDays.toStringAsFixed(1)} j' : '—',
              'Délai moyen'),
          kpi(Icons.verified_outlined,
              p.onTimeRate > 0 ? '${(p.onTimeRate * 100).round()} %' : '—',
              'À temps'),
        ],
      ),
    );
  }
}
