import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:wanzo/core/utils/currency_formatter.dart';
import '../cubit/restaurant_orders_cubit.dart';
import '../models/restaurant_order.dart';
import '../services/restaurant_api_service.dart';
import '../widgets/restaurant_order_quick_view_dialog.dart';

/// Vue « Plan de salle » : une grille de tables (module restaurant, backend) où
/// chaque table affiche son état de service en direct.
///
/// L'état est DÉRIVÉ localement des commandes du [RestaurantOrdersCubit] :
///  - LIBRE  → aucune commande active dont le `label` correspond à la table ;
///  - OCCUPÉE → une commande active correspond (on montre articles + total).
///
/// Le rapprochement table ↔ commande se fait par libellé (insensible à la casse
/// et aux espaces), car le modèle de commande n'est PAS modifié : une commande
/// ouverte pour « Table 4 » porte exactement ce libellé. Taper une table libre
/// ouvre une nouvelle commande pré-remplie avec son libellé et l'ouvre à la
/// caisse ; taper une table occupée rouvre sa commande existante.
///
/// Adaptation desktop : cette app n'a PAS de route `/restaurant/orders/:id` ;
/// la caisse ([RestaurantPosScreen], route `/restaurant/orders`) sélectionne la
/// commande via son état interne. On lui passe donc l'id via le query param
/// `orderId` (la caisse le lit pour pré-sélectionner la commande).
///
/// Tout est tolérant au hors-ligne : les tables viennent du backend, mais si
/// elles ne se chargent pas on affiche un message + un repli vers le flux de
/// commande libre existant (le board Kanban reste disponible en parallèle).
class RestaurantFloorPlanView extends StatefulWidget {
  const RestaurantFloorPlanView({super.key});

  @override
  State<RestaurantFloorPlanView> createState() =>
      _RestaurantFloorPlanViewState();
}

class _RestaurantFloorPlanViewState extends State<RestaurantFloorPlanView> {
  final RestaurantApiService _api = RestaurantApiService();
  List<RestaurantTable> _tables = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tables = await _api.getTables();
      if (!mounted) return;
      setState(() {
        // On n'affiche que les tables actives sur le plan de salle.
        _tables = tables.where((t) => t.active).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Impossible de charger les tables. Vérifiez votre connexion, ou '
            'utilisez une commande libre.';
        _loading = false;
      });
    }
  }

  /// Normalise un libellé pour le rapprochement table ↔ commande.
  String _norm(String s) => s.trim().toLowerCase();

  /// Retrouve la commande active correspondant à une table (la plus récente
  /// si plusieurs), ou `null` si la table est libre.
  RestaurantOrder? _orderFor(
      RestaurantTable table, List<RestaurantOrder> active) {
    final key = _norm(table.label);
    RestaurantOrder? match;
    for (final o in active) {
      if (_norm(o.label) == key) {
        if (match == null || o.createdAt.isAfter(match.createdAt)) {
          match = o;
        }
      }
    }
    return match;
  }

  /// Ouvre la caisse sur une commande donnée (pré-sélection via query param).
  void _openPos(String orderId) {
    context.push('/restaurant/orders?orderId=$orderId');
  }

  Future<void> _onTapTable(
    RestaurantTable table,
    RestaurantOrder? existing,
  ) async {
    if (existing != null) {
      // Table occupée → aperçu rapide de sa commande (actions en contexte, sans
      // quitter le plan de salle) : ouvrir/encaisser/renommer/annuler.
      showRestaurantOrderQuickView(
        context,
        context.read<RestaurantOrdersCubit>(),
        existing,
      );
      return;
    }
    // Table libre → ouvrir une nouvelle commande pré-remplie avec le libellé.
    final cubit = context.read<RestaurantOrdersCubit>();
    final order = await cubit.openOrder(table.label);
    if (!mounted) return;
    _openPos(order.id);
  }

  /// Repli hors-ligne / sans tables : ouvrir une commande libre (même flux que
  /// le board), afin que le service ne soit jamais bloqué.
  Future<void> _createFreeOrder() async {
    final cubit = context.read<RestaurantOrdersCubit>();
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle commande'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Libellé (Table 4, Emporter, nom…)',
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
      final order = await cubit.openOrder(label);
      if (mounted) _openPos(order.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _FloorPlanError(
        message: _error!,
        onRetry: _load,
        onFreeOrder: _createFreeOrder,
      );
    }
    if (_tables.isEmpty) {
      return _FloorPlanEmpty(
        onManageTables: () => context.push('/restaurant/tables'),
        onFreeOrder: _createFreeOrder,
        onRefresh: _load,
      );
    }
    // Re-dérive l'état à chaque changement de commande (BlocBuilder).
    return BlocBuilder<RestaurantOrdersCubit, RestaurantOrdersState>(
      builder: (context, state) {
        final active = state.active;
        return RefreshIndicator(
          onRefresh: _load,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Grille responsive desktop : colonnes calées sur la largeur
              // (~190px par carte), min 2, jusqu'à 8 sur les grands écrans.
              final crossAxisCount =
                  (constraints.maxWidth / 190).floor().clamp(2, 8);
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                itemCount: _tables.length,
                itemBuilder: (context, index) {
                  final table = _tables[index];
                  final order = _orderFor(table, active);
                  return _TableCard(
                    table: table,
                    order: order,
                    onTap: () => _onTapTable(table, order),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// Carte d'une table sur le plan de salle. Verte = libre, ambre = occupée.
/// Occupée : affiche le nombre d'articles et le total de la commande.
class _TableCard extends StatelessWidget {
  final RestaurantTable table;
  final RestaurantOrder? order;
  final VoidCallback onTap;

  const _TableCard({
    required this.table,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final occupied = order != null;
    // Vert = libre ; ambre = occupée (cohérent avec les accents du board).
    const freeColor = Color(0xFF16A34A);
    const busyColor = Color(0xFFF59E0B);
    final accent = occupied ? busyColor : freeColor;

    return Material(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.table_restaurant, size: 20, color: accent),
                  const Spacer(),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                table.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                occupied ? 'Occupée' : 'Libre',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (occupied) ...[
                const SizedBox(height: 4),
                Text(
                  '${order!.itemCount} article(s)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  formatCurrency(order!.totalCdf, 'CDF'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// État vide : aucune table configurée. Oriente vers la gestion des tables et
/// laisse la possibilité d'une commande libre.
class _FloorPlanEmpty extends StatelessWidget {
  final VoidCallback onManageTables;
  final Future<void> Function() onFreeOrder;
  final Future<void> Function() onRefresh;

  const _FloorPlanEmpty({
    required this.onManageTables,
    required this.onFreeOrder,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.table_restaurant,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Aucune table configurée. Créez vos tables pour piloter le plan '
              'de salle, ou ouvrez une commande libre.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onFreeOrder(),
                  icon: const Icon(Icons.add),
                  label: const Text('Commande libre'),
                ),
                FilledButton.icon(
                  onPressed: onManageTables,
                  icon: const Icon(Icons.table_restaurant),
                  label: const Text('Gérer les tables'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Erreur de chargement (hors-ligne) : message + réessayer + repli commande libre.
class _FloorPlanError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  final Future<void> Function() onFreeOrder;

  const _FloorPlanError({
    required this.message,
    required this.onRetry,
    required this.onFreeOrder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onFreeOrder(),
                  icon: const Icon(Icons.add),
                  label: const Text('Commande libre'),
                ),
                FilledButton.icon(
                  onPressed: () => onRetry(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
