import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/services/currency_display_service.dart';
import 'package:wanzo/core/shared_widgets/empty_state_view.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/widgets/dish_thumb_grid.dart';
import 'package:wanzo/core/widgets/smart_image.dart';
import 'package:wanzo/core/shared_widgets/payment_method_selector.dart';
import 'package:wanzo/features/settings/presentation/cubit/currency_settings_cubit.dart';
import 'package:wanzo/features/customer/bloc/customer_bloc.dart';
import 'package:wanzo/features/customer/bloc/customer_event.dart';
import 'package:wanzo/features/customer/bloc/customer_state.dart';
import 'package:wanzo/features/customer/models/customer.dart';
import 'package:wanzo/features/invoice/widgets/post_sale_document_sheet.dart';
import 'package:wanzo/features/sales/bloc/sales_bloc.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/sales/models/sale_item.dart';
import 'package:wanzo/services/receipt_printer_service.dart';
import 'package:wanzo/features/settings/bloc/settings_bloc.dart'
    as old_settings_bloc;
import 'package:wanzo/features/settings/bloc/settings_state.dart'
    as old_settings_state;
import 'package:wanzo/features/settings/models/settings.dart'
    as old_settings_model;

import '../cubit/restaurant_orders_cubit.dart';
import '../models/menu_course.dart';
import '../models/menu_item.dart';
import '../models/restaurant_order.dart';
import '../repositories/menu_repository.dart';
import 'package:wanzo/features/inventory/models/product.dart';
import 'package:wanzo/features/inventory/repositories/inventory_repository.dart';

/// Point de vente restaurant — mise en page desktop dense en 3 colonnes :
/// MENU (la CARTE) | TICKET (commande en cours) | CAISSE (encaissement).
/// Un bandeau supérieur sélectionne la commande active (table/emporter).
///
/// La CARTE est un vrai catalogue de plats ([MenuItem]) authorés directement,
/// PAS une surcouche du stock. La vente directe de produits stockables se fait
/// via l'action « Vente directe » du tableau de bord (facturation boutique).
///
/// L'encaissement se fait dans la 3e colonne (caisse restaurant dédiée :
/// règlement, monnaie, validation), qui crée une `Sale` (même chaîne
/// vente/synchro que la boutique), auto-imprime le ticket espèces puis ouvre la
/// feuille d'options post-vente PARTAGÉE ([showPostSaleDocumentSheet]) — MÊMES
/// widgets de facturation que la boutique, le salon et l'app Assets.
///
/// Ce n'est PAS le mobile étiré : tout est visible d'un coup, adapté au comptoir.
enum _PayMethod { cash, mobileMoney, credit }

extension _PayMethodX on _PayMethod {
  String get label => switch (this) {
        _PayMethod.cash => 'Espèces',
        _PayMethod.mobileMoney => 'Mobile Money',
        _PayMethod.credit => 'Crédit',
      };
  String get apiValue => switch (this) {
        _PayMethod.cash => 'cash',
        _PayMethod.mobileMoney => 'mobile_money',
        _PayMethod.credit => 'credit',
      };
  IconData get icon => switch (this) {
        _PayMethod.cash => Icons.payments,
        _PayMethod.mobileMoney => Icons.smartphone,
        _PayMethod.credit => Icons.schedule,
      };
}

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

/// Source de sélection à la caisse : carte du jour ou stock.
enum _PickSource { carte, stock }

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
  List<Product> _products = const [];
  _PickSource _source = _PickSource.carte;
  bool _menuLoading = true;
  String? _selectedOrderId;
  String _search = '';

  _PayMethod _method = _PayMethod.cash;
  final _cashController = TextEditingController();
  bool _submitting = false;

  /// Affichage double devise (CDF + USD) : préférence utilisateur partagée avec
  /// les tableaux de bord. Le primaire reste CDF (devise système) ; l'USD est un
  /// simple repère converti au taux central (jamais inventé).
  bool _dualCurrency = CurrencyDisplayService.instance.dualCurrency.value;

  /// Vente soumise au SalesBloc, conservée pour générer la pièce post-vente
  /// (reçu / facture) une fois l'enregistrement confirmé.
  Sale? _pendingSale;

  @override
  void initState() {
    super.initState();
    // Pré-sélection depuis le plan de salle (query param `orderId`).
    _selectedOrderId = widget.initialOrderId;
    _loadMenu();
    CurrencyDisplayService.instance.dualCurrency.addListener(_onDualChanged);
    final cubit = context.read<CurrencySettingsCubit>();
    if (cubit.state.status != CurrencySettingsStatus.loaded) {
      cubit.loadSettings();
    }
  }

  void _onDualChanged() {
    if (!mounted) return;
    setState(() =>
        _dualCurrency = CurrencyDisplayService.instance.dualCurrency.value);
  }

  @override
  void dispose() {
    CurrencyDisplayService.instance.dualCurrency.removeListener(_onDualChanged);
    _cashController.dispose();
    super.dispose();
  }

  /// Taux central USD→CDF (autorité comptable, exposée via `CurrencySettings`),
  /// `null` si indisponible : on n'affiche alors AUCUNE conversion.
  double? _usdRate() {
    try {
      final st = context.read<CurrencySettingsCubit>().state;
      if (st.status == CurrencySettingsStatus.loaded ||
          st.status == CurrencySettingsStatus.saved) {
        final r = st.settings.usdToCdfRate;
        if (r > 0) return r;
      }
    } catch (_) {
      // Cubit indisponible : pas de conversion.
    }
    return null;
  }

  /// Équivalent USD subtil d'un montant CDF, ou `null` si l'affichage double
  /// devise est désactivé ou qu'aucun taux réel n'existe.
  String? _usdHint(double cdf) {
    if (!_dualCurrency) return null;
    final rate = _usdRate();
    if (rate == null) return null;
    return '≈ ${formatCurrency(cdf / rate, 'USD')}';
  }

  Future<void> _loadMenu() async {
    // Stock lu AVANT l'attente (pas de contexte traversé par un `await`) : il
    // vient du cache Hive, donc disponible même hors ligne.
    List<Product> products = const [];
    try {
      products = context.read<InventoryRepository>().getAllProducts();
    } catch (_) {
      // Dépôt indisponible : la carte seule, plutôt qu'un écran bloqué.
    }
    final dishes = await _menuRepo.loadAllSynced();
    if (!mounted) return;
    setState(() {
      _dishes = dishes;
      _products = products;
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
      body: BlocListener<SalesBloc, SalesState>(
        listener: _onSalesState,
        child: BlocBuilder<RestaurantOrdersCubit, RestaurantOrdersState>(
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

  // D'où vient l'article : la CARTE (plat préparé) ou le STOCK (boisson).
  // Seul un article du stock décrémente le stock à l'encaissement.
  // ── Colonne 1 : Menu (la carte) ──────────────────────────────────────────
  Widget _buildMenu(RestaurantOrder order) {
    if (_menuLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Carte vide ET stock vide → inviter à composer la carte. Avec du stock
    // (boissons), on laisse la caisse ouvrir sur l'onglet Stock.
    if (_dishes.isEmpty && _products.isEmpty) {
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
        if (_products.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SegmentedButton<_PickSource>(
              segments: const [
                ButtonSegment(
                  value: _PickSource.carte,
                  icon: Icon(Icons.restaurant_menu, size: 18),
                  label: Text('Carte'),
                ),
                ButtonSegment(
                  value: _PickSource.stock,
                  icon: Icon(Icons.local_bar_outlined, size: 18),
                  label: Text('Stock'),
                ),
              ],
              selected: {_source},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _source = v.first),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: _source == _PickSource.stock
                  ? 'Rechercher un article…'
                  : 'Rechercher un plat…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: _source == _PickSource.stock
              ? _buildStock(order)
              : _buildCarte(order),
        ),
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

  /// Articles du stock filtrés par la recherche, les épuisés en dernier.
  List<Product> get _stockMatches {
    final q = _search.trim().toLowerCase();
    final list = _products
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();
    list.sort((a, b) {
      final ao = a.stockQuantity <= 0 ? 1 : 0;
      final bo = b.stockQuantity <= 0 ? 1 : 0;
      if (ao != bo) return ao - bo;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  // Stock : articles vendus tels quels (boissons, bouteilles).
  Widget _buildStock(RestaurantOrder order) {
    final items = _stockMatches;
    if (items.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off,
        message: 'Aucun article ne correspond.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: _menuGrid,
      itemCount: items.length,
      itemBuilder: (context, i) => _stockTile(order, items[i]),
    );
  }

  /// Tuile d'un article du stock : même mise en page que la tuile-plat, plus le
  /// stock restant, qui compte sur une bouteille et pas sur un plat.
  Widget _stockTile(RestaurantOrder order, Product product) {
    final theme = Theme.of(context);
    final bool outOfStock = product.stockQuantity <= 0;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: outOfStock
          ? null
          : () => context.read<RestaurantOrdersCubit>().addLine(
                order.id,
                RestaurantOrderLine(
                  productId: product.id,
                  productName: product.name,
                  unitPriceCdf: product.sellingPriceInCdf,
                  quantity: 1,
                  // Article du stock : le stock doit bouger à l'encaissement.
                  fromStock: true,
                ),
              ),
      child: Opacity(
        opacity: outOfStock ? 0.5 : 1,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SmartImage(
                      imageUrl: product.imageUrl,
                      imagePath: product.imagePath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholderIcon: Icons.local_bar,
                      placeholderColor:
                          theme.colorScheme.surfaceContainerHighest,
                      placeholderIconSize: 34,
                    ),
                    if (outOfStock)
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
                    Text(product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('Reste ${product.stockQuantity.toStringAsFixed(0)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      formatCurrency(product.sellingPriceInCdf, 'CDF'),
                      style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
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

  /// Résout le plat de la carte correspondant à une ligne de commande pour en
  /// afficher la PHOTO côté client : `productId` d'abord (id du MenuItem), repli
  /// par nom normalisé si l'id ne matche pas (même logique que la caisse mobile).
  MenuItem? _dishFor(RestaurantOrderLine line) {
    for (final d in _dishes) {
      if (d.id == line.productId) return d;
    }
    final key = line.productName.trim().toLowerCase();
    for (final d in _dishes) {
      if (d.name.trim().toLowerCase() == key) return d;
    }
    return null;
  }

  // ── Colonne 2 : Ticket (récapitulatif client, avec photos) ───────────────
  // Chaque ligne porte la PHOTO du plat (résolue via la carte) — le ticket sert
  // aussi de récapitulatif visuel tourné vers le client, comme la caisse mobile.
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
                    final dish = _dishFor(line);
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: DishThumbGrid(
                        thumbs: [
                          if (dish != null)
                            DishThumb(
                              photoUrl: dish.photoUrl,
                              photoPath: dish.photoPath,
                            ),
                        ],
                        size: 44,
                        radius: 8,
                      ),
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
  // Caisse « maison » restaurant : choix du règlement, montant reçu / monnaie
  // rendue, validation. Le règlement crée une `Sale` (réutilise toute la chaîne
  // vente/synchro), auto-imprime le ticket espèces, puis ouvre la feuille
  // d'options post-vente PARTAGÉE ([showPostSaleDocumentSheet]) — MÊMES widgets
  // de facturation que la boutique et le salon. Montants en CDF (base monétaire).
  Widget _buildCheckout(RestaurantOrder order) {
    final theme = Theme.of(context);
    final total = order.totalCdf;
    final cashGiven =
        double.tryParse(_cashController.text.replaceAll(' ', '')) ?? 0;
    final change = cashGiven - total;
    final totalUsd = _usdHint(total);
    final changeUsd = _usdHint(change.abs());

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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Total', style: theme.textTheme.titleMedium),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(total, 'CDF'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  // Équivalent USD subtil (double devise + taux central).
                  if (totalUsd != null)
                    Text(
                      totalUsd,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Règlement', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          PaymentMethodSelector<_PayMethod>(
            methods: _PayMethod.values,
            selected: _method,
            labelOf: (m) => m.label,
            iconOf: (m) => m.icon,
            onChanged: (m) => setState(() => _method = m),
          ),
          const SizedBox(height: 12),
          if (_method == _PayMethod.cash) ...[
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Montant reçu (CDF)',
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            if (_cashController.text.isNotEmpty) ...[
              Text(
                change >= 0
                    ? 'Monnaie : ${formatCurrency(change, 'CDF')}'
                    : 'Manque : ${formatCurrency(-change, 'CDF')}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: change >= 0
                      ? Colors.green.shade700
                      : theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Équivalent USD subtil (double devise + taux central).
              if (changeUsd != null)
                Text(
                  changeUsd,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: order.isEmpty ||
                    _submitting ||
                    (_method == _PayMethod.cash && change < 0)
                ? null
                : () => _confirm(order),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text('Valider · ${formatCurrency(total, 'CDF')}'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _confirm(RestaurantOrder order) {
    final total = order.totalCdf;
    final completed = _method == _PayMethod.cash;
    final paid = completed ? total : 0.0;

    final items = order.lines
        .map(
          (l) => SaleItem(
            productId: l.productId,
            productName: l.productName,
            quantity: l.quantity,
            unitPrice: l.unitPriceCdf,
            totalPrice: l.totalCdf,
            currencyCode: 'CDF',
            exchangeRate: 1.0,
            unitPriceInCdf: l.unitPriceCdf,
            totalPriceInCdf: l.totalCdf,
            // Un plat de la carte est une PRESTATION de cuisine : son id est
            // celui d'un MenuItem, pas d'un Product, donc aucun décrément de
            // stock. Un article pris au stock (jus, bière) est au contraire une
            // vente d'article, et le stock doit bouger.
            itemType:
                l.fromStock ? SaleItemType.product : SaleItemType.service,
          ),
        )
        .toList();

    final sale = Sale(
      id: '',
      date: DateTime.now(),
      // Client RÉEL quand la commande en connaît un (à emporter nommé) :
      // sans cela la vente restait rattachée à un client fabriqué, invisible
      // dans l'historique du client et dans le journal des opérations.
      customerId: order.customerId ?? 'resto_${order.id}',
      customerName: order.customerName ?? order.label,
      items: items,
      totalAmountInCdf: total,
      paidAmountInCdf: paid,
      transactionCurrencyCode: 'CDF',
      transactionExchangeRate: 1.0,
      totalAmountInTransactionCurrency: total,
      paidAmountInTransactionCurrency: paid,
      discountPercentage: 0,
      paymentMethod: _method.apiValue,
      status: completed ? SaleStatus.completed : SaleStatus.pending,
      notes: 'Commande restaurant ${order.label}',
    );

    _pendingSale = sale;
    setState(() => _submitting = true);
    context.read<SalesBloc>().add(AddSale(sale));

    // Auto-impression du ticket de caisse (ventes espèces) — même câblage que
    // la boutique/atelier (AddSaleScreen). Fire-and-forget.
    _autoPrintCashTicket(sale);
  }

  /// Imprime automatiquement le ticket de caisse pour un règlement espèces si
  /// l'option est activée. Réutilise le même `ReceiptPrinterService` que les
  /// autres modes (boutique, atelier).
  Future<void> _autoPrintCashTicket(Sale sale) async {
    // ROBUSTESSE : l'impression ne doit JAMAIS bloquer ni faire planter
    // l'encaissement (imprimante absente/hors-ligne, service indisponible…).
    try {
      if (!ReceiptPrinterService.isCashPayment(sale.paymentMethod)) return;
      final settings = _currentSettings();
      if (settings == null) return;
      final printerService = ReceiptPrinterService();
      if (!await printerService.getAutoPrintOnCashSale()) return;
      final ok = await printerService.printCashReceipt(sale, settings);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impression automatique échouée. Vérifiez la connexion de l\'imprimante.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (_) {
      // Silencieux : la vente est déjà enregistrée, l'impression est accessoire.
    }
  }

  void _onSalesState(BuildContext context, SalesState state) async {
    if (!_submitting) return;
    if (state is SalesOperationSuccess) {
      final id = _selectedOrderId;
      if (id != null) {
        await context.read<RestaurantOrdersCubit>().markPaid(id);
      }
      if (!mounted) return;
      await _showPostSaleActions();
    } else if (state is SalesError) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Échec : ${state.message}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Paramètres de facturation courants (source unique pour la génération des
  /// pièces). `null` si le bloc n'est pas encore chargé.
  old_settings_model.Settings? _currentSettings() {
    final st = context.read<old_settings_bloc.SettingsBloc>().state;
    if (st is old_settings_state.SettingsLoaded) return st.settings;
    if (st is old_settings_state.SettingsUpdated) return st.settings;
    return null;
  }

  /// Ouvre la feuille d'options post-vente PARTAGÉE une fois la vente
  /// enregistrée (aperçu / impression / ticket thermique / partage PDF) —
  /// exactement la même que la boutique et le salon. Repli silencieux vers la
  /// clôture si les paramètres ou la pièce ne sont pas disponibles.
  Future<void> _showPostSaleActions() async {
    final sale = _pendingSale;
    final settings = _currentSettings();
    if (sale == null || settings == null) {
      _finishSale();
      return;
    }
    PostSaleDocument? doc;
    try {
      doc = await generatePostSaleDocument(sale, settings);
    } catch (_) {
      doc = null;
    }
    if (!mounted) return;
    if (doc == null) {
      _finishSale();
      return;
    }
    showPostSaleDocumentSheet(
      context: context,
      pdfPath: doc.pdfPath,
      documentType: doc.documentType,
      sale: sale,
      settings: settings,
      onClose: _finishSale,
    );
  }

  /// Clôt l'encaissement : réinitialise la caisse et désélectionne la commande
  /// réglée (elle quitte la liste des commandes actives).
  void _finishSale() {
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _selectedOrderId = null;
      _cashController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paiement enregistré'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _promptNewOrder() async {
    final cubit = context.read<RestaurantOrdersCubit>();
    // Charge les clients existants pour proposer des suggestions dans le champ
    // « Table / client » (autocomplétion desktop), tout en laissant saisir
    // librement un libellé de table (« Table 4 », « Emporter »…).
    final customerBloc = context.read<CustomerBloc>()..add(const LoadCustomers());
    // Valeur courante saisie (suggestion sélectionnée OU texte libre).
    String typed = '';
    // Nature du service choisie à la création : une commande à emporter
    // n'occupera pas le plan de salle.
    RestaurantOrderType type = RestaurantOrderType.dineIn;
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
        title: const Text('Nouvelle commande'),
        content: SizedBox(
          width: 360,
          child: Column(
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
              BlocBuilder<CustomerBloc, CustomerState>(
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
            ],
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
      ),
    );
    if (label == null) return;
    final order = await cubit.openOrder(label, type: type);
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
