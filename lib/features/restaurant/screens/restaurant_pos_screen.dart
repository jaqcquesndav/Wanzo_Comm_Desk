import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/shared_widgets/empty_state_view.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/widgets/smart_image.dart';
import 'package:wanzo/features/customer/bloc/customer_bloc.dart';
import 'package:wanzo/features/customer/bloc/customer_event.dart';
import 'package:wanzo/features/customer/bloc/customer_state.dart';
import 'package:wanzo/features/customer/models/customer.dart';

import '../cubit/restaurant_orders_cubit.dart';
import '../models/menu_course.dart';
import '../models/menu_item.dart';
import '../models/restaurant_order.dart';
import '../repositories/menu_repository.dart';
import '../widgets/restaurant_order_quick_view_dialog.dart';

/// Point de vente restaurant — mise en page desktop dense en 3 colonnes :
/// MENU (la CARTE) | TICKET (commande en cours) | CAISSE (encaissement).
/// Un bandeau supérieur sélectionne la commande active (table/emporter).
///
/// La CARTE est un vrai catalogue de plats ([MenuItem]) authorés directement,
/// PAS une surcouche du stock. La vente directe de produits stockables se fait
/// via l'action « Vente directe » du tableau de bord (facturation boutique).
///
/// L'encaissement passe par la facturation UNIFIÉE ([AddSaleScreen], via
/// [openRestaurantInvoice]) — MÊME page que la boutique et l'atelier — et non
/// une caisse « maison » : ticket de caisse, facture et journal en découlent.
///
/// Ce n'est PAS le mobile étiré : tout est visible d'un coup, adapté au comptoir.

/// Petit badge de catégorie (« Plats », « Boissons »…) posé sur la photo.
class _CourseBadge extends StatelessWidget {
  final String label;
  const _CourseBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class RestaurantPosScreen extends StatefulWidget {
  /// Commande à pré-sélectionner à l'ouverture (ex. depuis le plan de salle),
  /// passée via le query param `orderId` de la route `/restaurant/orders`.
  final String? initialOrderId;

  const RestaurantPosScreen({super.key, this.initialOrderId});

  @override
  State<RestaurantPosScreen> createState() => _RestaurantPosScreenState();
}

class _RestaurantPosScreenState extends State<RestaurantPosScreen> {
  final MenuRepository _menuRepo = MenuRepository();
  List<MenuItem> _dishes = [];
  bool _menuLoading = true;
  String? _selectedOrderId;
  String _search = '';

  @override
  void initState() {
    super.initState();
    // Pré-sélection depuis le plan de salle (query param `orderId`).
    _selectedOrderId = widget.initialOrderId;
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    final dishes = await _menuRepo.loadAll();
    if (!mounted) return;
    setState(() {
      _dishes = dishes;
      _menuLoading = false;
    });
  }

  /// Plats de la CARTE, filtrés par recherche (nom + description), groupés et
  /// triés par catégorie (entrée → plat → … → boisson).
  Map<MenuCourse, List<MenuItem>> get _menuByCourse {
    final q = _search.trim().toLowerCase();
    final grouped = <MenuCourse, List<MenuItem>>{};
    for (final item in _dishes) {
      if (q.isNotEmpty) {
        final inName = item.name.toLowerCase().contains(q);
        final inDesc = (item.description?.toLowerCase().contains(q)) ?? false;
        if (!inName && !inDesc) continue;
      }
      grouped.putIfAbsent(item.course, () => []).add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final ctx = BusinessContextService();
    final index = ModuleRegistry.indexOfSidebarRoute(
      ctx.activityMode,
      ctx.currentContext?.userRole,
      '/restaurant/orders',
    );
    return WanzoScaffold(
      currentIndex: index < 0 ? 0 : index,
      title: 'Restaurant',
      // La caisse est une page poussée (depuis le tableau de bord / le board) :
      // on garantit un retour fiable, avec repli sur le tableau de bord quand
      // elle a été atteinte via `context.go` (pile vide → rien à dépiler).
      onBackPressed: () =>
          context.canPop() ? context.pop() : context.go('/dashboard'),
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.menu_book),
          tooltip: 'Composer la carte',
          onPressed: () =>
              context.push('/restaurant/menu').then((_) => _loadMenu()),
        ),
      ],
      body: BlocBuilder<RestaurantOrdersCubit, RestaurantOrdersState>(
        builder: (context, state) {
          final orders = state.active;
          // Auto-sélection cohérente si la commande courante disparaît.
          final selected = state.byId(_selectedOrderId ?? '');
          return Column(
              children: [
                _buildOrderStrip(orders, selected),
                const Divider(height: 1),
                Expanded(
                  child: selected == null
                      ? const EmptyStateView(
                          icon: Icons.restaurant_menu,
                          message:
                              'Ouvrez une commande pour démarrer le service.',
                        )
                      : LayoutBuilder(
                          builder: (context, c) {
                            // Large : 3 colonnes Menu | Ticket | Caisse.
                            // Compact : 2 colonnes, la caisse est empilée sous
                            // le ticket (évite l'écrasement / overflow).
                            final wide = c.maxWidth >= 1080;
                            if (wide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                      flex: 3, child: _buildMenu(selected)),
                                  const VerticalDivider(width: 1),
                                  Expanded(
                                      flex: 2, child: _buildTicket(selected)),
                                  const VerticalDivider(width: 1),
                                  SizedBox(
                                    width: 340,
                                    child: _buildCheckout(selected),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 3, child: _buildMenu(selected)),
                                const VerticalDivider(width: 1),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    children: [
                                      Expanded(child: _buildTicket(selected)),
                                      const Divider(height: 1),
                                      _buildCheckout(selected),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      );
  }

  // ── Bandeau des commandes actives ───────────────────────────────────────
  Widget _buildOrderStrip(List<RestaurantOrder> orders, RestaurantOrder? sel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: _promptNewOrder,
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final o in orders)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${o.label} · ${o.itemCount}'),
                        selected: o.id == sel?.id,
                        onSelected: (_) =>
                            setState(() => _selectedOrderId = o.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Colonne 1 : Menu (la carte) ──────────────────────────────────────────
  Widget _buildMenu(RestaurantOrder order) {
    if (_menuLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Carte vide (aucun plat authoré) → inviter à la composer.
    if (_dishes.isEmpty) {
      return EmptyStateView(
        icon: Icons.restaurant_menu,
        message: 'La carte est vide.\nAjoutez vos plats pour prendre les commandes.',
        actionLabel: 'Composer la carte',
        actionIcon: Icons.edit,
        onAction: () =>
            context.push('/restaurant/menu').then((_) => _loadMenu()),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher un plat…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(child: _buildCarte(order)),
      ],
    );
  }

  // Carte : plats authorés, groupés par catégorie.
  Widget _buildCarte(RestaurantOrder order) {
    final grouped = _menuByCourse;
    final courses = grouped.keys.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    if (courses.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off,
        message: 'Aucun plat ne correspond.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final course in courses) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              course.label.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: _menuGrid,
            itemCount: grouped[course]!.length,
            itemBuilder: (context, i) =>
                _menuTile(order, grouped[course]![i]),
          ),
        ],
      ],
    );
  }

  // Grille commune aux tuiles-plats (photo prominente + nom/desc/prix).
  static const SliverGridDelegateWithMaxCrossAxisExtent _menuGrid =
      SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 180,
    childAspectRatio: 0.72,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
  );

  /// Ajoute un plat au ticket. Sans groupe d'options → ajout direct (qty 1).
  /// Avec groupes → ouvre le sélecteur de modificateurs en DIALOG centré, puis
  /// ajoute la ligne au prix (base + suppléments), les choix consignés dans la
  /// note. Le dédoublonnage existant (productId + note) garde distinctes les
  /// variantes d'un même plat.
  Future<void> _addDish(RestaurantOrder order, MenuItem item) async {
    final cubit = context.read<RestaurantOrdersCubit>();
    final messenger = ScaffoldMessenger.of(context);

    double unitPrice = item.priceCdf;
    String? note;

    if (item.modifierGroups.isNotEmpty) {
      final result = await showDialog<_ModifierResult>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ModifierPickerDialog(item: item),
      );
      if (result == null) return; // Annulé.
      unitPrice = item.priceCdf + result.priceDelta;
      note = result.note.isEmpty ? null : result.note;
    }

    cubit.addLine(
      order.id,
      RestaurantOrderLine(
        productId: item.id,
        productName: item.name,
        unitPriceCdf: unitPrice,
        quantity: 1,
        note: note,
      ),
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 700),
          content: Text('${item.name} ajouté'),
        ),
      );
  }

  Widget _menuTile(RestaurantOrder order, MenuItem item) {
    final theme = Theme.of(context);
    final description = item.description?.trim() ?? '';
    final soldOut = !item.available;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: soldOut ? null : () => _addDish(order, item),
      child: Opacity(
        opacity: soldOut ? 0.5 : 1,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image du plat, bien visible (réseau ou locale, cover). Repli sur
              // l'icône « plat » quand aucune image n'est définie, avec badge de
              // catégorie en surimpression et badge « Épuisé » si indisponible.
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SmartImage(
                      imageUrl: item.photoUrl,
                      imagePath: item.photoPath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholderIcon: Icons.restaurant,
                      placeholderColor:
                          theme.colorScheme.surfaceContainerHighest,
                      placeholderIconSize: 34,
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _CourseBadge(label: item.course.label),
                    ),
                    if (soldOut)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Épuisé',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(item.priceCdf, 'CDF'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Colonne 2 : Ticket ───────────────────────────────────────────────────
  Widget _buildTicket(RestaurantOrder order) {
    final cubit = context.read<RestaurantOrdersCubit>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  order.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              if (order.status == RestaurantOrderStatus.open)
                TextButton.icon(
                  onPressed: order.isEmpty
                      ? null
                      : () => cubit.updateStatus(
                          order.id, RestaurantOrderStatus.sent),
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Cuisine'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: order.isEmpty
              ? const EmptyStateView(
                  icon: Icons.receipt_long,
                  message: 'Ajoutez des articles depuis le menu.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: order.lines.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final line = order.lines[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(line.productName),
                      subtitle: Text(
                        (line.note != null && line.note!.isNotEmpty)
                            ? '${formatCurrency(line.unitPriceCdf, 'CDF')} · ${line.note}'
                            : formatCurrency(line.unitPriceCdf, 'CDF'),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => cubit.setQuantity(
                                order.id, i, line.quantity - 1),
                          ),
                          Text('${line.quantity}'),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => cubit.setQuantity(
                                order.id, i, line.quantity + 1),
                          ),
                          SizedBox(
                            width: 84,
                            child: Text(
                              formatCurrency(line.totalCdf, 'CDF'),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Colonne 3 : Caisse (encaissement) ──────────────────────────────────
  // Le règlement lui-même (méthodes de paiement, montant reçu/monnaie, devise
  // de transaction, ticket/facture) est délégué à la facturation UNIFIÉE
  // [AddSaleScreen] — MÊME page que la boutique et l'atelier — via
  // [openRestaurantInvoice]. Cette colonne n'affiche donc que le total et le
  // bouton d'encaissement.
  Widget _buildCheckout(RestaurantOrder order) {
    final theme = Theme.of(context);
    final total = order.totalCdf;

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.all(16),
      child: Column(
        // min + SizedBox (pas de Spacer) : fonctionne aussi bien en colonne
        // pleine hauteur (large) qu'empilé sous le ticket (compact).
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: theme.textTheme.titleMedium),
              Text(
                formatCurrency(total, 'CDF'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: order.isEmpty ? null : () => _settleViaInvoice(order),
            icon: const Icon(Icons.point_of_sale),
            label: Text('Encaisser · ${formatCurrency(total, 'CDF')}'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// Encaissement via la facturation UNIFIÉE ([AddSaleScreen]) pré-remplie avec
  /// le ticket. La commande est marquée réglée à la création de la vente
  /// ([openRestaurantInvoice]) ; on désélectionne ensuite (elle quitte la liste
  /// des commandes actives).
  Future<void> _settleViaInvoice(RestaurantOrder order) async {
    await openRestaurantInvoice(
      context,
      context.read<RestaurantOrdersCubit>(),
      order,
    );
    if (mounted) setState(() => _selectedOrderId = null);
  }

  Future<void> _promptNewOrder() async {
    final cubit = context.read<RestaurantOrdersCubit>();
    // Charge les clients existants pour proposer des suggestions dans le champ
    // « Table / client » (autocomplétion desktop), tout en laissant saisir
    // librement un libellé de table (« Table 4 », « Emporter »…).
    final customerBloc = context.read<CustomerBloc>()..add(const LoadCustomers());
    // Valeur courante saisie (suggestion sélectionnée OU texte libre).
    String typed = '';
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                      labelText: 'Table / client',
                      hintText: 'Ex. Table 4, Emporter, ou un client existant…',
                    ),
                    onChanged: (v) => typed = v,
                    onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
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
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(typed),
            child: const Text('Ouvrir'),
          ),
        ],
      ),
    );
    if (label == null) return;
    final order = await cubit.openOrder(label);
    if (!mounted) return;
    setState(() => _selectedOrderId = order.id);
  }
}

/// Résultat du sélecteur de modificateurs : surcoût total (somme des deltas) et
/// note lisible listant les choix (ex. « Bien cuit · +Fromage »).
class _ModifierResult {
  final double priceDelta;
  final String note;
  const _ModifierResult({required this.priceDelta, required this.note});
}

/// Sélecteur de modificateurs présenté en DIALOG centré (convention desktop),
/// affiché à la commande d'un plat qui EN a. Rend chaque groupe : choix unique
/// obligatoire = radios ; multiple = cases à cocher, bornées par min/max.
/// Calcule le surcoût et consigne les choix.
class _ModifierPickerDialog extends StatefulWidget {
  final MenuItem item;
  const _ModifierPickerDialog({required this.item});

  @override
  State<_ModifierPickerDialog> createState() => _ModifierPickerDialogState();
}

class _ModifierPickerDialogState extends State<_ModifierPickerDialog> {
  /// Options sélectionnées par groupe : {indexGroupe: {indexOption…}}.
  late final Map<int, Set<int>> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {
      for (int i = 0; i < widget.item.modifierGroups.length; i++) i: <int>{},
    };
  }

  /// Plancher de choix requis pour un groupe (obligatoire → au moins 1).
  int _minFor(ModifierGroup g) => g.minSelect ?? (g.required ? 1 : 0);

  /// Le groupe satisfait-il sa contrainte de sélection ?
  bool _groupSatisfied(int gi, ModifierGroup g) =>
      _selected[gi]!.length >= _minFor(g);

  /// Tous les groupes sont-ils satisfaits (bouton d'ajout actif) ?
  bool get _allSatisfied {
    for (int i = 0; i < widget.item.modifierGroups.length; i++) {
      if (!_groupSatisfied(i, widget.item.modifierGroups[i])) return false;
    }
    return true;
  }

  double get _totalDelta {
    double d = 0;
    widget.item.modifierGroups.asMap().forEach((gi, g) {
      for (final oi in _selected[gi]!) {
        d += g.options[oi].priceDeltaCdf;
      }
    });
    return d;
  }

  void _toggleSingle(int gi, int oi) {
    setState(() => _selected[gi] = {oi});
  }

  void _toggleMulti(int gi, int oi, ModifierGroup g) {
    final set = _selected[gi]!;
    setState(() {
      if (set.contains(oi)) {
        set.remove(oi);
      } else {
        // Respect du maximum : au-delà, on n'ajoute pas.
        if (g.maxSelect != null && set.length >= g.maxSelect!) return;
        set.add(oi);
      }
    });
  }

  void _confirm() {
    // Construit la note : « Bien cuit · +Fromage » (les options à surcoût
    // sont préfixées d'un « + »).
    final tokens = <String>[];
    double delta = 0;
    widget.item.modifierGroups.asMap().forEach((gi, g) {
      for (final oi in _selected[gi]!) {
        final opt = g.options[oi];
        delta += opt.priceDeltaCdf;
        tokens.add(opt.priceDeltaCdf > 0 ? '+${opt.name}' : opt.name);
      }
    });
    Navigator.pop(
      context,
      _ModifierResult(priceDelta: delta, note: tokens.join(' · ')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = widget.item.modifierGroups;
    final totalPrice = widget.item.priceCdf + _totalDelta;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.item.name,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(formatCurrency(widget.item.priceCdf, 'CDF'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                shrinkWrap: true,
                children: [
                  for (int gi = 0; gi < groups.length; gi++)
                    _buildGroup(theme, gi, groups[gi]),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _allSatisfied ? _confirm : null,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text(
                          'Ajouter · ${formatCurrency(totalPrice, 'CDF')}'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(ThemeData theme, int gi, ModifierGroup g) {
    final satisfied = _groupSatisfied(gi, g);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(g.name,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (g.required && !satisfied
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                g.required ? 'Obligatoire' : 'Facultatif',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: g.required && !satisfied
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        if (!g.isSingleChoice && g.maxSelect != null)
          Text('Jusqu\'à ${g.maxSelect} choix',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        for (int oi = 0; oi < g.options.length; oi++)
          _buildOption(theme, gi, oi, g),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildOption(ThemeData theme, int gi, int oi, ModifierGroup g) {
    final opt = g.options[oi];
    final selected = _selected[gi]!.contains(oi);
    final delta = opt.priceDeltaCdf;
    final trailing = delta > 0
        ? Text('+${formatCurrency(delta, 'CDF')}',
            style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600))
        : null;
    if (g.isSingleChoice) {
      return RadioListTile<int>(
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: oi,
        groupValue: _selected[gi]!.isEmpty ? null : _selected[gi]!.first,
        onChanged: (_) => _toggleSingle(gi, oi),
        title: Text(opt.name),
        secondary: trailing,
      );
    }
    // Choix multiple : désactive les cases non cochées une fois le max atteint.
    final atMax = g.maxSelect != null && _selected[gi]!.length >= g.maxSelect!;
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: selected,
      onChanged:
          (!selected && atMax) ? null : (_) => _toggleMulti(gi, oi, g),
      title: Text(opt.name),
      secondary: trailing,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
