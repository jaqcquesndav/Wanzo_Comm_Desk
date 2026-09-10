import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:wanzo/core/utils/currency_formatter.dart';
import '../cubit/restaurant_orders_cubit.dart';
import '../models/menu_item.dart';
import '../models/restaurant_order.dart';
import '../repositories/menu_repository.dart';
import '../services/restaurant_api_service.dart';
import '../widgets/order_dish_thumbs.dart';
import '../widgets/restaurant_order_quick_view_dialog.dart';

/// Vue « Plan de salle » : une grille de tables (module restaurant, backend) où
/// chaque table affiche son état de service en direct.
///
/// L'état est DÉRIVÉ localement des commandes du [RestaurantOrdersCubit] :
///  - LIBRE  → aucune commande active liée à la table ;
///  - OCCUPÉE → une commande active y est liée (on montre articles + total).
///
/// Rapprochement table ↔ commande : par `tableId` EN PRIORITÉ (lien fort, posé à
/// l'ouverture d'une commande depuis une table), avec repli sur le libellé
/// normalisé pour les commandes antérieures (rétro-compatibilité). Les commandes
/// à EMPORTER n'occupent jamais une table.
///
/// Adaptation desktop : cette app n'a PAS de route `/restaurant/orders/:id` ;
/// la caisse ([RestaurantPosScreen], route `/restaurant/orders`) sélectionne la
/// commande via le query param `orderId`.
///
/// Robustesse hors-ligne : on conserve le DERNIER état connu (cache mémoire)
/// pour ne pas afficher un plan vide qui clignote ; un échec de rafraîchissement
/// affiche un bandeau discret sans effacer les tables déjà chargées. Le plan est
/// aussi rafraîchi (silencieusement) quand le cubit change, pas seulement au
/// premier montage.
class RestaurantFloorPlanView extends StatefulWidget {
  const RestaurantFloorPlanView({super.key});

  @override
  State<RestaurantFloorPlanView> createState() =>
      _RestaurantFloorPlanViewState();
}

class _RestaurantFloorPlanViewState extends State<RestaurantFloorPlanView> {
  final RestaurantApiService _api = RestaurantApiService();

  /// Cache mémoire du dernier plan connu (partagé entre instances/onglets) :
  /// évite un plan vide clignotant au retour sur l'écran ou hors-ligne.
  static List<RestaurantTable> _cachedTables = [];

  List<RestaurantTable> _tables = [];
  Map<String, MenuItem> _menuById = const {};
  bool _loading = true;
  bool _offline = false; // rafraîchissement échoué mais tables encore connues
  String? _error; // erreur bloquante seulement quand aucune table connue
  int _lastActiveCount = 0;

  @override
  void initState() {
    super.initState();
    _tables = List<RestaurantTable>.from(_cachedTables);
    _loading = _tables.isEmpty;
    _loadMenu();
    _load(silent: _tables.isNotEmpty);
  }

  Future<void> _loadMenu() async {
    final map = await MenuRepository().loadMap();
    if (!mounted) return;
    setState(() => _menuById = map);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final tables = await _api.getTables();
      if (!mounted) return;
      final active = tables.where((t) => t.active).toList();
      _cachedTables = active;
      setState(() {
        _tables = active;
        _loading = false;
        _offline = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_tables.isEmpty) {
          _error =
              'Impossible de charger les tables. Vérifiez votre connexion, ou '
              'utilisez une commande libre.';
        } else {
          _offline = true;
        }
      });
    }
  }

  void _onCubitChanged(RestaurantOrdersState state) {
    final count = state.active.length;
    if (count == _lastActiveCount) return;
    _lastActiveCount = count;
    if (!_loading) _load(silent: true);
  }

  String _norm(String s) => s.trim().toLowerCase();

  /// Retrouve la commande active liée à une table : par `tableId` d'abord (lien
  /// fort), puis par libellé (rétro-compat). Ignore les commandes à emporter.
  RestaurantOrder? _orderFor(
      RestaurantTable table, List<RestaurantOrder> active) {
    RestaurantOrder? byId;
    RestaurantOrder? byLabel;
    final key = _norm(table.label);
    for (final o in active) {
      if (o.type == RestaurantOrderType.takeaway) continue;
      if (o.tableId != null && o.tableId == table.id) {
        if (byId == null || o.createdAt.isAfter(byId.createdAt)) byId = o;
      } else if (o.tableId == null && _norm(o.label) == key) {
        if (byLabel == null || o.createdAt.isAfter(byLabel.createdAt)) {
          byLabel = o;
        }
      }
    }
    return byId ?? byLabel;
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
    // Table libre → nouvelle commande SUR PLACE liée fortement à la table.
    final cubit = context.read<RestaurantOrdersCubit>();
    final order = await cubit.openOrder(
      table.label,
      tableId: table.id,
      type: RestaurantOrderType.dineIn,
    );
    if (!mounted) return;
    _openPos(order.id);
  }

  /// Repli hors-ligne / sans tables : ouvrir une commande libre (même flux que
  /// le board), afin que le service ne soit jamais bloqué. Choix sur place / à
  /// emporter.
  Future<void> _createFreeOrder() async {
    final cubit = context.read<RestaurantOrdersCubit>();
    final controller = TextEditingController();
    RestaurantOrderType type = RestaurantOrderType.dineIn;
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nouvelle commande'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<RestaurantOrderType>(
                segments: const [
                  ButtonSegment(
                    value: RestaurantOrderType.dineIn,
                    icon: Icon(Icons.restaurant),
                    label: Text('Sur place'),
                  ),
                  ButtonSegment(
                    value: RestaurantOrderType.takeaway,
                    icon: Icon(Icons.takeout_dining),
                    label: Text('À emporter'),
                  ),
                ],
                selected: {type},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setLocal(() => type = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: type == RestaurantOrderType.takeaway
                      ? 'Libellé (nom du client, Emporter…)'
                      : 'Libellé (Table 4, nom…)',
                ),
                onSubmitted: (v) => Navigator.pop(ctx, v),
              ),
            ],
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
      ),
    );
    if (label != null && label.trim().isNotEmpty) {
      final order = await cubit.openOrder(label, type: type);
      if (mounted) _openPos(order.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RestaurantOrdersCubit, RestaurantOrdersState>(
      listener: (context, state) => _onCubitChanged(state),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _tables.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tables.isEmpty && _error != null) {
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
    return BlocBuilder<RestaurantOrdersCubit, RestaurantOrdersState>(
      builder: (context, state) {
        final active = state.active;
        return Column(
          children: [
            if (_offline) _offlineBanner(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _load(silent: true),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Grille responsive desktop : ~190px par carte, min 2,
                    // jusqu'à 8 sur les grands écrans.
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
                          menuById: _menuById,
                          onTap: () => _onTapTable(table, order),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _offlineBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => _load(silent: true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.cloud_off,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Plan hors-ligne (dernier état connu). Cliquer pour réessayer.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte d'une table sur le plan de salle. Verte = libre, ambre = occupée.
/// Occupée : aperçu photo des plats + nombre d'articles + total de la commande.
class _TableCard extends StatelessWidget {
  final RestaurantTable table;
  final RestaurantOrder? order;
  final Map<String, MenuItem> menuById;
  final VoidCallback onTap;

  const _TableCard({
    required this.table,
    required this.order,
    required this.menuById,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final occupied = order != null;
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
                  if (occupied)
                    OrderDishThumbs(
                      order: order!,
                      menuById: menuById,
                      size: 36,
                      radius: 8,
                    )
                  else
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
