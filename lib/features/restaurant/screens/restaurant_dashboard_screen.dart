import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';

import '../cubit/restaurant_orders_cubit.dart';
import '../models/restaurant_order.dart';

/// Tableau de bord du mode RESTAURANT (desktop / comptoir).
///
/// Volontairement DIFFÉRENT du tableau de bord boutique : pas de valeur de
/// stock ni d'indicateurs d'inventaire, mais les repères du service — commandes
/// en salle, en cuisine, chiffre du jour et plats les plus vendus. Les données
/// proviennent uniquement du `RestaurantOrdersCubit` (aucune dépendance
/// supplémentaire), ce qui garde l'écran léger et sans risque pour la boutique.
class RestaurantDashboardScreen extends StatelessWidget {
  const RestaurantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctx = BusinessContextService();
    final index = ModuleRegistry.indexOfSidebarRoute(
      ctx.activityMode,
      ctx.currentContext?.userRole,
      '/dashboard',
    );

    return WanzoScaffold(
      currentIndex: index < 0 ? 0 : index,
      title: 'Tableau de bord',
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.menu_book),
          tooltip: 'Composer la carte',
          onPressed: () => context.push('/restaurant/menu'),
        ),
        IconButton(
          icon: const Icon(Icons.point_of_sale),
          tooltip: 'Ouvrir le service',
          onPressed: () => context.go('/restaurant/orders'),
        ),
      ],
      body: BlocBuilder<RestaurantOrdersCubit, RestaurantOrdersState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final m = _RestaurantMetrics.from(state.orders);
          return LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 900;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _kpiRow(context, m),
                    const SizedBox(height: 28),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _section(
                              context,
                              'Commandes en cours',
                              _activeOrders(context, m.active),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _section(
                              context,
                              'Plats les plus vendus (aujourd\'hui)',
                              _topDishes(context, m.topDishes),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _section(context, 'Commandes en cours',
                          _activeOrders(context, m.active)),
                      const SizedBox(height: 24),
                      _section(context, 'Plats les plus vendus (aujourd\'hui)',
                          _topDishes(context, m.topDishes)),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _kpiRow(BuildContext context, _RestaurantMetrics m) {
    final cards = [
      _KpiCard(
        icon: Icons.room_service,
        color: const Color(0xFF0EA5E9),
        label: 'En service',
        value: '${m.active.length}',
      ),
      _KpiCard(
        icon: Icons.soup_kitchen,
        color: const Color(0xFFF59E0B),
        label: 'En cuisine',
        value: '${m.inKitchen}',
      ),
      _KpiCard(
        icon: Icons.payments,
        color: const Color(0xFF16A34A),
        label: 'Chiffre du jour',
        value: formatCurrency(m.revenueToday, 'CDF'),
      ),
      _KpiCard(
        icon: Icons.receipt_long,
        color: const Color(0xFF64748B),
        label: 'Réglées (jour)',
        value: '${m.paidTodayCount}',
      ),
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final card in cards)
          SizedBox(width: 220, child: card),
      ],
    );
  }

  Widget _activeOrders(BuildContext context, List<RestaurantOrder> orders) {
    if (orders.isEmpty) {
      return _hint(context, 'Aucune commande en cours pour le moment.');
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < orders.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              onTap: () => context.go('/restaurant/orders'),
              leading: CircleAvatar(
                backgroundColor:
                    _statusColor(orders[i].status).withValues(alpha: 0.16),
                child: Icon(Icons.receipt_long,
                    color: _statusColor(orders[i].status)),
              ),
              title: Text(
                orders[i].label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                  '${orders[i].itemCount} article(s) · ${orders[i].status.label}'),
              trailing: Text(
                formatCurrency(orders[i].totalCdf, 'CDF'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _topDishes(BuildContext context, List<_DishCount> dishes) {
    if (dishes.isEmpty) {
      return _hint(
        context,
        'Les plats les plus vendus s\'afficheront après les premiers règlements.',
      );
    }
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < dishes.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.12),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                dishes[i].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                '${dishes[i].quantity} vendu(s)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hint(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: theme.textTheme.bodyMedium),
    );
  }

  Color _statusColor(RestaurantOrderStatus status) {
    switch (status) {
      case RestaurantOrderStatus.open:
        return const Color(0xFF64748B);
      case RestaurantOrderStatus.sent:
        return const Color(0xFFF59E0B);
      case RestaurantOrderStatus.served:
        return const Color(0xFF0EA5E9);
      case RestaurantOrderStatus.paid:
        return const Color(0xFF16A34A);
      case RestaurantOrderStatus.cancelled:
        return const Color(0xFFDC2626);
    }
  }
}

/// Carte d'indicateur (KPI) : icône colorée, valeur, libellé.
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _KpiCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.16),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DishCount {
  final String name;
  final int quantity;
  const _DishCount(this.name, this.quantity);
}

/// Indicateurs restaurant dérivés des commandes (aucune dépendance externe).
class _RestaurantMetrics {
  final List<RestaurantOrder> active;
  final int inKitchen;
  final double revenueToday;
  final int paidTodayCount;
  final List<_DishCount> topDishes;

  const _RestaurantMetrics({
    required this.active,
    required this.inKitchen,
    required this.revenueToday,
    required this.paidTodayCount,
    required this.topDishes,
  });

  factory _RestaurantMetrics.from(List<RestaurantOrder> orders) {
    final now = DateTime.now();
    bool sameDay(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;

    final active = orders.where((o) => o.status.isActive).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final inKitchen =
        orders.where((o) => o.status == RestaurantOrderStatus.sent).length;

    final paidToday = orders
        .where((o) =>
            o.status == RestaurantOrderStatus.paid && sameDay(o.createdAt))
        .toList();
    final revenueToday =
        paidToday.fold<double>(0, (sum, o) => sum + o.totalCdf);

    // Plats les plus vendus : agrégat des réglées du jour ; repli sur toutes
    // les réglées si la journée vient de commencer.
    var source = paidToday;
    if (source.isEmpty) {
      source =
          orders.where((o) => o.status == RestaurantOrderStatus.paid).toList();
    }
    final counts = <String, int>{};
    for (final o in source) {
      for (final l in o.lines) {
        counts[l.productName] = (counts[l.productName] ?? 0) + l.quantity;
      }
    }
    final topDishes = counts.entries
        .map((e) => _DishCount(e.key, e.value))
        .toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));

    return _RestaurantMetrics(
      active: active,
      inKitchen: inKitchen,
      revenueToday: revenueToday,
      paidTodayCount: paidToday.length,
      topDishes: topDishes.take(5).toList(),
    );
  }
}
