import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../constants/colors.dart';
import '../../../core/modules/module_registry.dart';
import '../../../core/services/business_context_service.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../cubit/restaurant_orders_cubit.dart';
import '../models/restaurant_order.dart';

/// Écran cuisine (Kitchen Display System) — vue DESKTOP dédiée au personnel de
/// cuisine : les commandes envoyées (`sent`) s'affichent en grandes tuiles avec
/// le temps écoulé et le détail des articles ; un tap sur « Servie » les sort
/// de la file. Pensé pour un écran secondaire (dual-screen) en salle/cuisine.
///
/// Sur mobile, l'essentiel passe par le board Kanban ; le KDS plein écran est
/// réservé au desktop où la place le justifie.
class RestaurantKitchenScreen extends StatelessWidget {
  const RestaurantKitchenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctx = BusinessContextService();
    final index = ModuleRegistry.indexOfSidebarRoute(
      ctx.activityMode,
      ctx.currentContext?.userRole,
      '/restaurant/kitchen',
    );
    return WanzoScaffold(
      currentIndex: index < 0 ? 0 : index,
      title: 'Cuisine — commandes en préparation',
      appBarActions: [
        IconButton(
          tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh),
          onPressed: () => context.read<RestaurantOrdersCubit>().load(),
        ),
      ],
      body: BlocBuilder<RestaurantOrdersCubit, RestaurantOrdersState>(
        builder: (context, state) {
          final cooking = state.orders
              .where((o) => o.status == RestaurantOrderStatus.sent)
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

          if (cooking.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_menu, size: 56, color: Color(0xFF9CA3AF)),
                  SizedBox(height: 12),
                  Text('Aucune commande en cuisine',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, c) {
              // Tuiles larges (~320px), au moins 1 colonne.
              final cols = (c.maxWidth / 320).floor().clamp(1, 6);
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.82,
                ),
                itemCount: cooking.length,
                itemBuilder: (context, i) =>
                    _KitchenTicket(order: cooking[i]),
              );
            },
          );
        },
      ),
    );
  }
}

class _KitchenTicket extends StatelessWidget {
  final RestaurantOrder order;
  const _KitchenTicket({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsed = DateTime.now().difference(order.createdAt);
    final mins = elapsed.inMinutes;
    // Rouge après 15 min, orange après 8 — repère visuel d'urgence cuisine.
    final urgency = mins >= 15
        ? WanzoColors.danger
        : (mins >= 8 ? WanzoColors.warning : theme.colorScheme.primary);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgency.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : libellé (table) + chrono
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: urgency.withValues(alpha: 0.10),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    order.label,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.schedule, size: 15, color: urgency),
                const SizedBox(width: 4),
                Text(
                  mins <= 0 ? "à l'instant" : '$mins min',
                  style: TextStyle(
                      color: urgency, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
          // Lignes de la commande
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              children: [
                for (final l in order.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 1, right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${l.quantity}×',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: theme.colorScheme.primary)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.productName,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              if (l.note != null && l.note!.isNotEmpty)
                                Text('• ${l.note}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: WanzoColors.warning)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Action : marquer servie (sort de la cuisine)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context
                    .read<RestaurantOrdersCubit>()
                    .updateStatus(order.id, RestaurantOrderStatus.served),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Servie'),
                style: FilledButton.styleFrom(
                  backgroundColor: WanzoColors.success,
                  minimumSize: const Size.fromHeight(42),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
