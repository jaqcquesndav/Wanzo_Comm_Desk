import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/services/form_navigation_service.dart';
import 'package:wanzo/core/shared_widgets/quick_actions_sheet.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/widgets/smart_image.dart';
import 'package:wanzo/features/inventory/models/product.dart';
import 'package:wanzo/features/inventory/repositories/inventory_repository.dart';

import '../cubit/restaurant_orders_cubit.dart';
import '../models/restaurant_order.dart';
import '../widgets/restaurant_order_quick_view_dialog.dart';

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

    // Les actions clés (service, cuisine, carte…) sont présentées via la
    // feuille partagée d'actions rapides, ouverte depuis un unique déclencheur
    // (le bouton flottant), et jamais dupliquées dans le corps de la page.
    return WanzoScaffold(
      currentIndex: index < 0 ? 0 : index,
      title: 'Tableau de bord',
      floatingActionButton: FloatingActionButton(
        heroTag: 'restaurant_dashboard_fab',
        tooltip: 'Actions rapides',
        onPressed: () => _showRestaurantQuickActions(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
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

  /// Actions rapides du service (équivalent restaurant des actions rapides de
  /// la boutique) présentées via la feuille partagée — même présentation et
  /// même ordre que l'application mobile.
  void _showRestaurantQuickActions(BuildContext context) {
    showWanzoQuickActions(
      context,
      actions: [
        QuickActionItem(
          icon: Icons.add_shopping_cart,
          color: const Color(0xFF0EA5E9),
          label: 'Nouvelle commande',
          onTap: () => context.go('/restaurant/board'),
        ),
        // Vente directe : un restaurant vend aussi des produits STOCKABLES
        // (bouteilles, pâtisserie…) hors carte. On garde la facturation
        // boutique — sur desktop, le formulaire de vente s'ouvre en modal.
        QuickActionItem(
          icon: Icons.point_of_sale,
          color: const Color(0xFF197CA8),
          label: 'Vente directe',
          onTap: () => FormNavigationService.instance.openSaleForm(context),
        ),
        QuickActionItem(
          icon: Icons.soup_kitchen,
          color: const Color(0xFFF59E0B),
          label: 'Cuisine',
          onTap: () => context.go('/restaurant/board'),
        ),
        QuickActionItem(
          icon: Icons.menu_book,
          color: const Color(0xFF8B5CF6),
          label: 'Carte',
          onTap: () => context.push('/restaurant/menu'),
        ),
        QuickActionItem(
          icon: Icons.point_of_sale,
          color: const Color(0xFF16A34A),
          // Action sans commande : oriente vers le plan de salle / board pour
          // choisir la commande à encaisser (pas la caisse vide).
          label: 'Encaisser',
          onTap: () => context.push('/restaurant/board'),
        ),
        QuickActionItem(
          icon: Icons.money_off,
          color: Colors.red,
          label: 'Dépense',
          onTap: () => context.push('/expenses/add'),
        ),
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
      _KpiCard(
        icon: Icons.timer_outlined,
        color: const Color(0xFF8B5CF6),
        label: 'Temps service moy.',
        value: m.avgServiceMinutes > 0
            ? '${m.avgServiceMinutes.round()} min'
            : '—',
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
    // La liste peut grandir en plein service : on plafonne à 5 et on renvoie
    // vers le tableau des commandes (Kanban) pour tout voir.
    const int cap = 5;
    final shown = orders.take(cap).toList();
    final hasMore = orders.length > cap;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              // Commande concrète → aperçu rapide d'actions (mêmes actions que
              // le board / le plan de salle), sans quitter le tableau de bord.
              onTap: () => showRestaurantOrderQuickView(
                context,
                context.read<RestaurantOrdersCubit>(),
                shown[i],
              ),
              leading: CircleAvatar(
                backgroundColor:
                    _statusColor(shown[i].status).withValues(alpha: 0.16),
                child: Icon(Icons.receipt_long,
                    color: _statusColor(shown[i].status)),
              ),
              title: Text(
                shown[i].label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                  '${shown[i].itemCount} article(s) · ${shown[i].status.label}'),
              trailing: Text(
                formatCurrency(shown[i].totalCdf, 'CDF'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          if (hasMore) ...[
            const Divider(height: 1),
            ListTile(
              onTap: () => context.go('/restaurant/board'),
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: Text('Voir toutes les commandes (${orders.length})'),
              trailing: const Icon(Icons.chevron_right),
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
    // Résolution de la photo du plat par productId (même source que le POS /
    // la carte : le catalogue produits). Repli sur l'icône de catégorie.
    final products = <String, Product>{
      for (final p in _allProducts(context)) p.id: p,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < dishes.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: _dishLeading(context, products[dishes[i].productId], i),
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

  /// Vignette du plat : photo produit (réseau/local) avec un badge de rang, ou
  /// l'icône de catégorie en repli lorsque le produit n'a pas d'image.
  Widget _dishLeading(BuildContext context, Product? product, int index) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        children: [
          SmartImage(
            imageUrl: product?.imageUrl,
            imagePath: product?.imagePath,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(8),
            placeholderIcon: product?.category.icon ?? Icons.restaurant,
            placeholderColor: theme.colorScheme.surfaceContainerHighest,
            placeholderIconSize: 20,
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(6),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Catalogue produits (source des photos). Lecture directe du repository —
  /// même mécanisme que le POS restaurant. Repli silencieux si indisponible.
  List<Product> _allProducts(BuildContext context) {
    try {
      return context.read<InventoryRepository>().getAllProducts();
    } catch (_) {
      return const [];
    }
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
  final String productId;
  final String name;
  final int quantity;
  const _DishCount(this.productId, this.name, this.quantity);
}

/// Indicateurs restaurant dérivés des commandes (aucune dépendance externe).
class _RestaurantMetrics {
  final List<RestaurantOrder> active;
  final int inKitchen;
  final double revenueToday;
  final int paidTodayCount;
  final List<_DishCount> topDishes;
  final double avgServiceMinutes; // temps moyen création → servie (prestation)

  const _RestaurantMetrics({
    required this.active,
    required this.inKitchen,
    required this.revenueToday,
    required this.paidTodayCount,
    required this.topDishes,
    required this.avgServiceMinutes,
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
    // Agrégat par productId (permet de résoudre la photo du plat), en
    // conservant un libellé représentatif.
    final counts = <String, int>{};
    final names = <String, String>{};
    for (final o in source) {
      for (final l in o.lines) {
        counts[l.productId] = (counts[l.productId] ?? 0) + l.quantity;
        names[l.productId] = l.productName;
      }
    }
    final topDishes = counts.entries
        .map((e) => _DishCount(e.key, names[e.key] ?? '', e.value))
        .toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));

    // Temps de service moyen (prestation) : création → « servie ».
    final durations =
        orders.map((o) => o.serviceTime).whereType<Duration>().toList();
    final avgServiceMinutes = durations.isEmpty
        ? 0.0
        : durations.map((d) => d.inMinutes).reduce((a, b) => a + b) /
            durations.length;

    return _RestaurantMetrics(
      active: active,
      inKitchen: inKitchen,
      revenueToday: revenueToday,
      paidTodayCount: paidToday.length,
      topDishes: topDishes.take(5).toList(),
      avgServiceMinutes: avgServiceMinutes,
    );
  }
}
