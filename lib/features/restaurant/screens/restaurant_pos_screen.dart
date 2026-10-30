import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/quick_actions/desktop_quick_actions.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/services/currency_display_service.dart';
import 'package:wanzo/core/shared_widgets/empty_state_view.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/models/currency_settings_model.dart';
import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/models/payment_method_code.dart';
import 'package:wanzo/core/services/currency_service.dart';
import 'package:wanzo/core/shared_widgets/payment_details_fields.dart';
import 'package:wanzo/core/widgets/operator_logo.dart';
import 'package:wanzo/core/widgets/dish_thumb_grid.dart';
import 'package:wanzo/core/widgets/smart_image.dart';
import 'package:wanzo/core/shared_widgets/payment_method_selector.dart';
import 'package:wanzo/features/settings/presentation/cubit/currency_settings_cubit.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/utils/price_plausibility.dart';
import 'package:wanzo/features/customer/widgets/customer_picker_field.dart';
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
import '../services/restaurant_folio_service.dart';
import '../widgets/new_order_dialog.dart';
import '../widgets/orders_auto_refresh.dart';
import '../widgets/web_orders_inbox.dart';
import '../models/menu_course.dart';
import '../models/menu_item.dart';
import '../models/restaurant_order.dart';
import '../widgets/order_type_badge.dart';
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
///
/// Facturation croisée (même modèle que la caisse resto de l'app Assets) :
///  - Espèces et Mobile Money sont ENCAISSÉS (vente réglée) ;
///  - « Compte client » : vente à crédit portée par un client RÉEL, obligatoire
///    (jamais de dette sur un client fabriqué, impossible à encaisser) ;
///  - « Sur une réservation » : la commande rejoint le folio d'une chambre ou
///    d'une salle (gestion `POST reservations/:id/folio`) et figurera sur LA
///    facture du séjour ou de la location. Aucune vente séparée ici.
enum _PayMethod { cash, mobileMoney, credit, room }

extension _PayMethodX on _PayMethod {
  String get label => switch (this) {
        _PayMethod.cash => 'Espèces',
        _PayMethod.mobileMoney => 'Mobile Money',
        _PayMethod.credit => 'Compte client',
        _PayMethod.room => 'Sur une réservation',
      };
  String get apiValue => switch (this) {
        _PayMethod.cash => 'cash',
        _PayMethod.mobileMoney => 'mobile_money',
        _PayMethod.credit => 'credit',
        _PayMethod.room => 'room',
      };
  IconData get icon => switch (this) {
        _PayMethod.cash => Icons.payments,
        _PayMethod.mobileMoney => Icons.smartphone,
        _PayMethod.credit => Icons.account_box_outlined,
        _PayMethod.room => Icons.event_available,
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
  /// Identifiant local de l'encaissement, PAR COMMANDE : réutilisé à chaque
  /// nouvel essai sur la même commande (double clic, reprise après erreur),
  /// oublié une fois la vente enregistrée. Jamais partagé entre deux
  /// commandes, sinon le serveur prendrait l'une pour l'autre.
  final Map<String, String> _saleLocalIds = {};
  final MenuRepository _menuRepo = MenuRepository();
  List<MenuItem> _dishes = [];
  List<Product> _products = const [];
  _PickSource _source = _PickSource.carte;
  bool _menuLoading = true;
  String? _selectedOrderId;
  String _search = '';

  _PayMethod _method = _PayMethod.cash;
  // Mobile Money : opérateur et référence obligatoires ; compte client :
  // échéance (J+30 par défaut, modifiable).
  OperatorBrand? _mobileOperator;
  final _paymentRefController = TextEditingController();
  DateTime? _dueDate;
  final _cashController = TextEditingController();
  bool _submitting = false;

  /// Commande en cours d'encaissement, figée au clic sur « Valider » : la
  /// sélection du bandeau peut changer pendant l'enregistrement, et c'est
  /// CETTE commande (pas la sélection courante) qui doit passer réglée.
  String? _payingOrderId;

  /// Mode retenu pour la commande en cours d'encaissement (consigné sur la
  /// commande au moment de la clôture).
  _PayMethod? _payingMethod;

  /// Client qui porte la vente « Compte client » (locataire, habitué,
  /// entreprise). Jamais de dette sans client réel.
  Customer? _clientCompte;

  /// Réservation retenue pour « Sur une réservation ».
  FolioReservation? _sejour;

  final RestaurantFolioService _folio = RestaurantFolioService();

  /// Réservations ouvertes connues (chambre ou salle). L'option « Sur une
  /// réservation » n'apparaît qu'en mode hôtel ou quand l'entreprise en a :
  /// un restaurant sans hébergement ni salle n'a pas à la voir.
  List<FolioReservation> _reservations = const [];

  /// Affichage double devise (CDF + USD) : préférence utilisateur partagée avec
  /// les tableaux de bord. Le primaire reste CDF (devise système) ; l'USD est un
  /// simple repère converti au taux central (jamais inventé).
  bool _dualCurrency = CurrencyDisplayService.instance.dualCurrency.value;

  /// Vente soumise au SalesBloc, conservée pour générer la pièce post-vente
  /// (reçu / facture) une fois l'enregistrement confirmé.
  Sale? _pendingSale;

  // Devise REELLEMENT encaissee. La carte est libellee en CDF (devise de base
  // de la plateforme) ; le reglement, lui, peut se faire en devise, et doit
  // etre enregistre comme tel : sinon un encaissement en dollars disparait de
  // la comptabilite et le suivi de change est faux. Meme montage qu'au salon.
  Currency _defaultCurrency = Currency.CDF;
  Currency? _selectedTransactionCurrency;
  double _transactionExchangeRate = 1.0; // devise choisie -> CDF
  Map<Currency, double> _exchangeRates = const {};
  List<Currency> _availableCurrencies = const [Currency.CDF];

  @override
  void initState() {
    super.initState();
    // Pré-sélection depuis le plan de salle (query param `orderId`).
    _selectedOrderId = widget.initialOrderId;
    // « Nouvelle commande » depuis le dock d'actions rapides.
    if (QuickActionIntents.take(QuickActionIntents.restaurantNewOrder)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _promptNewOrder();
      });
    }
    _appliquerSejourDeLaCommande();
    _loadMenu();
    _chargerReservations(silencieux: true);
    CurrencyDisplayService.instance.dualCurrency.addListener(_onDualChanged);
    final cubit = context.read<CurrencySettingsCubit>();
    if (cubit.state.status == CurrencySettingsStatus.loaded) {
      _initialiserDevises(cubit.state.settings);
    } else {
      cubit.loadSettings();
    }
  }

  /// Devise active de la societe et taux de change, meme source de verite que
  /// la boutique et le salon : Settings pour la devise active, CurrencySettings
  /// pour les taux. Aucun taux n'est invente.
  void _initialiserDevises(CurrencySettings settings) {
    final active = _deviseActiveSociete(settings);
    if (!mounted) return;
    setState(() {
      _defaultCurrency = active;
      _exchangeRates = {
        Currency.USD: settings.usdToCdfRate,
        Currency.FCFA: settings.fcfaToCdfRate,
        Currency.CDF: 1.0,
      };
      _availableCurrencies = _exchangeRates.keys
          .where((k) => (_exchangeRates[k] ?? 0) > 0)
          .toList();
      if (!_availableCurrencies.contains(active)) {
        _availableCurrencies.add(active);
      }
      _selectedTransactionCurrency = _availableCurrencies.contains(active)
          ? active
          : _availableCurrencies.first;
      // Sans taux : 0, jamais 1 (le règlement en devise est alors refusé).
      _transactionExchangeRate =
          _exchangeRates[_selectedTransactionCurrency!] ?? 0;
    });
  }

  Currency _deviseActiveSociete(CurrencySettings repli) {
    final st = context.read<old_settings_bloc.SettingsBloc>().state;
    if (st is old_settings_state.SettingsLoaded) {
      return st.settings.activeCurrency;
    } else if (st is old_settings_state.SettingsUpdated) {
      return st.settings.activeCurrency;
    }
    return repli.activeCurrency;
  }

  /// Convertit un montant de base (CDF) vers la devise de reglement.
  double _versDevise(double cdf) =>
      _transactionExchangeRate <= 0 ? cdf : cdf / _transactionExchangeRate;

  /// Convertit un montant saisi dans la devise de reglement vers la base CDF.
  double _versCdf(double montant) =>
      _transactionExchangeRate <= 0 ? montant : montant * _transactionExchangeRate;

  /// Code affiché : celui de la devise choisie seulement si son taux est
  /// connu. Sans taux, les montants restent en CDF (jamais un montant CDF
  /// sous le code USD).
  String get _codeDevise {
    final code = _selectedTransactionCurrency?.code ?? _defaultCurrency.code;
    if (code != 'CDF' && _transactionExchangeRate <= 0) return 'CDF';
    return code;
  }

  /// Devise choisie sans taux exploitable : règlement refusé.
  bool get _tauxManquant {
    final code = _selectedTransactionCurrency?.code ?? _defaultCurrency.code;
    return code != 'CDF' && _transactionExchangeRate <= 0;
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
    _paymentRefController.dispose();
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

  /// « Sur une réservation » est proposé quand l'entreprise a des
  /// réservations ouvertes (chambre ou salle gérées dans Wanzo Assets).
  bool get _reservationsProposees =>
      _reservations.isNotEmpty ||
      _method == _PayMethod.room;

  List<_PayMethod> get _modesProposes => [
        _PayMethod.cash,
        _PayMethod.mobileMoney,
        _PayMethod.credit,
        if (_reservationsProposees) _PayMethod.room,
      ];

  /// Relit les réservations ouvertes. [silencieux] : au montage, un échec
  /// (hors ligne, droits) ne dérange personne ; à la demande, on l'explique.
  Future<bool> _chargerReservations({bool silencieux = false}) async {
    try {
      final liste = await _folio.reservationsOuvertes();
      if (!mounted) return false;
      setState(() => _reservations = liste);
      return true;
    } catch (_) {
      if (!silencieux && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réservations indisponibles. Vérifiez la connexion.'),
          ),
        );
      }
      return false;
    }
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
    // La caisse reste ouverte tout le service : elle relit seule les
    // commandes ouvertes, completees ou reglees sur les autres postes.
    return RestaurantOrdersAutoRefresh(
      child: WanzoScaffold(
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
                // Commandes passées par les clients depuis le lien de table :
                // la caisse reste ouverte tout le service, elle doit les voir.
                const WebOrdersInbox(),
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
                        onSelected: (_) => _selectionner(o.id),
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
                      formatCurrency(item.prixSaisi, item.deviseSaisie),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    // Où part la commande : table, à emporter, chambre, salle.
                    OrderTypeBadge.of(order, compact: true),
                  ],
                ),
              ),
              if (!order.isEmpty)
                IconButton(
                  tooltip: 'Facture proforma',
                  icon: const Icon(Icons.request_quote_outlined),
                  onPressed: () => proformaDeCommande(context, order),
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
    // Espece SAISIE dans la devise de reglement puis ramenee en base CDF :
    // sans cette conversion, 20 dollars poses sur le comptoir etaient lus
    // comme 20 francs.
    final cashGiven = _versCdf(
      double.tryParse(_cashController.text.replaceAll(' ', '')) ?? 0,
    );
    final change = cashGiven - total;
    final totalUsd = _usdHint(total);
    final changeUsd = _usdHint(change.abs());

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
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
          // Devise du REGLEMENT. Masquee tant qu'une seule devise a un taux
          // reel : on ne propose pas un choix qui n'en est pas un.
          if (_availableCurrencies.length > 1) ...[
            Text('Devise du règlement', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<Currency>(
              segments: [
                for (final c in _availableCurrencies)
                  ButtonSegment<Currency>(value: c, label: Text(c.code)),
              ],
              selected: {
                _selectedTransactionCurrency ?? _defaultCurrency,
              },
              showSelectedIcon: false,
              onSelectionChanged: (choix) {
                final c = choix.first;
                setState(() {
                  _selectedTransactionCurrency = c;
                  _transactionExchangeRate = _exchangeRates[c] ?? 0;
                  _cashController.clear();
                });
              },
            ),
            const SizedBox(height: 12),
          ],
          Text('Règlement', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          PaymentMethodSelector<_PayMethod>(
            methods: _modesProposes,
            selected: _method,
            labelOf: (m) => m.label,
            iconOf: (m) => m.icon,
            onChanged: (m) {
              setState(() {
                _method = m;
                if (m == _PayMethod.credit) _dueDate ??= defaultCreditDueDate();
              });
              if (m == _PayMethod.room && _sejour == null) _choisirSejour();
              if (m == _PayMethod.credit && _compteId(order) == null) {
                _choisirClient(order);
              }
            },
          ),
          const SizedBox(height: 12),
          if (_method == _PayMethod.room)
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.event_available),
                title: Text(_sejour == null
                    ? 'Choisir la réservation'
                    : (_sejour!.spaceName ?? 'Réservation')),
                subtitle: Text(_sejour == null
                    ? 'Chambre ou salle : la commande rejoint sa facture.'
                    : '${_sejour!.customerName ?? 'Client'} · ajoutée à sa facture'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _choisirSejour,
              ),
            ),
          if (_method == _PayMethod.credit)
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.account_box_outlined),
                title: Text(_compteNom(order) ?? 'Choisir le client'),
                subtitle: Text(_compteId(order) == null
                    ? 'Client obligatoire : la dette lui est rattachée.'
                    : 'À encaisser plus tard, visible dans son historique'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _choisirClient(order),
              ),
            ),
          if (_method == _PayMethod.mobileMoney) ...[
            Text(
              'Paiement reçu sur le compte Mobile Money : la vente est réglée.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_method == _PayMethod.mobileMoney ||
              _method == _PayMethod.credit)
            PaymentDetailsFields(
              method: _method.apiValue,
              operator: _mobileOperator,
              onOperatorChanged: (b) => setState(() => _mobileOperator = b),
              referenceController: _paymentRefController,
              dueDate: _dueDate,
              onDueDateChanged: (d) => setState(() => _dueDate = d),
            ),
          if (_tauxManquant)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                CurrencyService.missingRateMessage(
                  _selectedTransactionCurrency!.code,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (_method == _PayMethod.cash) ...[
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Montant reçu ($_codeDevise)',
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
                    ? 'Monnaie : '
                        '${formatCurrency(_versDevise(change), _codeDevise)}'
                    : 'Manque : '
                        '${formatCurrency(_versDevise(-change), _codeDevise)}',
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
                    (_method == _PayMethod.cash && change < 0) ||
                    (_method == _PayMethod.room && _sejour == null) ||
                    (_method == _PayMethod.credit && _compteId(order) == null)
                ? null
                : () => _method == _PayMethod.room
                    ? _reporterSurReservation(order)
                    : _confirm(order),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(
              _method == _PayMethod.room
                  ? 'Ajouter à la réservation · ${formatCurrency(total, 'CDF')}'
                  : 'Valider · ${formatCurrency(_versDevise(total), _codeDevise)}',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// Client du compte : celui choisi à la caisse, sinon celui déjà rattaché à
  /// la commande (à emporter nommé).
  String? _compteId(RestaurantOrder order) =>
      _clientCompte?.id ?? order.customerId;

  String? _compteNom(RestaurantOrder order) =>
      _clientCompte?.name ?? order.customerName;

  /// Change de commande dans le bandeau : le client du compte et la
  /// réservation valaient pour la précédente.
  void _selectionner(String orderId) {
    if (orderId == _selectedOrderId) return;
    setState(() {
      _selectedOrderId = orderId;
      _clientCompte = null;
      _sejour = null;
      _cashController.clear();
      if (_method == _PayMethod.room || _method == _PayMethod.credit) {
        _method = _PayMethod.cash;
      }
      _appliquerSejourDeLaCommande();
    });
  }

  /// Commande sur réservation (chambre, salle) : « Sur une réservation » d'office, avec sa
  /// réservation (le caissier peut encore choisir un autre mode).
  void _appliquerSejourDeLaCommande() {
    final commande = context
        .read<RestaurantOrdersCubit>()
        .state
        .byId(_selectedOrderId ?? '');
    final sejour = commande == null ? null : sejourDeLaCommande(commande);
    if (sejour == null) return;
    _method = _PayMethod.room;
    _sejour = sejour;
  }

  /// Choisit le client qui porte la vente « Compte client ». Sélecteur
  /// partagé ([CustomerPickerField]) : recherche locale et serveur, création
  /// en ligne d'une fiche manquante. Le client est aussi rattaché à la
  /// commande (historique, créance).
  Future<void> _choisirClient(RestaurantOrder order) async {
    final cubit = context.read<RestaurantOrdersCubit>();
    final controller = TextEditingController(text: order.customerName ?? '');
    Customer? choisi;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Row(
            children: [
              const Expanded(child: Text('Sur le compte de quel client ?')),
              IconButton(
                tooltip: 'Fermer',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomerPickerField(
                  controller: controller,
                  label: 'Client',
                  hint: 'Locataire, habitué ou entreprise',
                  onSelected: (c) => setD(() => choisi = c),
                ),
                const SizedBox(height: 8),
                Text(
                  'Une vente sur compte exige une fiche client : la dette '
                  'lui est rattachée et se retrouve dans « À encaisser ».',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: choisi == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Retenir ce client'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    final client = choisi;
    if (ok != true || client == null || !mounted) return;
    setState(() => _clientCompte = client);
    await cubit.setCustomer(
      order.id,
      customerId: client.id,
      customerName: client.name,
    );
  }

  /// Réservations ouvertes (chambre ou salle) : en cours, ou qui commencent
  /// dans les 7 prochains jours (un traiteur se commande souvent avant
  /// l'événement). Relues à chaque ouverture : une réservation créée dans
  /// l'app Assets apparaît sans redémarrer la caisse.
  Future<void> _choisirSejour() async {
    final ok = await _chargerReservations();
    if (!ok || !mounted) return;
    final sejours = _reservations;
    final choix = await showDialog<FolioReservation>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Ajouter à quelle réservation ?'),
        children: sejours.isEmpty
            ? const [
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Text(
                    'Aucune réservation en cours ou prévue cette semaine. '
                    "Créez d'abord celle du client (chambre ou salle) dans "
                    "l'app Assets, puis revenez ici.",
                  ),
                ),
              ]
            : [
                for (final r in sejours)
                  ListTile(
                    leading: const Icon(Icons.event_available),
                    title: Text(r.spaceName ?? 'Réservation'),
                    subtitle: Text(
                      '${r.customerName ?? 'Client'} · '
                      '${_jourHeure(r.startAt)} au ${_jourHeure(r.endAt)}',
                    ),
                    trailing: Text(r.statusLabel),
                    onTap: () => Navigator.pop(ctx, r),
                  ),
              ],
      ),
    );
    if (choix != null && mounted) setState(() => _sejour = choix);
  }

  static String _jourHeure(DateTime d) {
    String deux(int v) => v.toString().padLeft(2, '0');
    return '${deux(d.day)}/${deux(d.month)} ${deux(d.hour)}:${deux(d.minute)}';
  }

  /// Ajoute la commande au folio de la réservation, puis la clôt (mode
  /// `room`). La facture sera émise UNE fois par le serveur, au départ du
  /// client, avec le séjour ou la location : aucune vente ici, donc aucun
  /// décrément de stock ici (l'article du stock sort à cette facturation).
  /// Hors ligne, l'envoi part en file et le serveur ignore un second envoi de
  /// la même commande (`sourceId`) : ni perte ni doublon.
  Future<void> _reporterSurReservation(RestaurantOrder order) async {
    final sejour = _sejour;
    if (sejour == null) return;
    final cubit = context.read<RestaurantOrdersCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final erreur = Theme.of(context).colorScheme.error;
    setState(() => _submitting = true);
    bool differe;
    try {
      differe = !await _folio.reporterSurReservation(sejour.id, order);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is ApiException && e.message.isNotEmpty
              ? 'Ajout à la réservation impossible : ${e.message}'
              : 'Ajout à la réservation impossible. Réessayez.'),
          backgroundColor: erreur,
        ),
      );
      return;
    }
    await cubit.markPaid(order.id, method: _PayMethod.room.apiValue);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _selectedOrderId = null;
      _sejour = null;
      _clientCompte = null;
      _method = _PayMethod.cash;
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(differe
            ? 'Hors ligne : ajout à ${sejour.spaceName ?? 'la réservation'} '
                'envoyé au retour du réseau.'
            : 'Ajouté à la facture de ${sejour.spaceName ?? 'la réservation'}.'),
        backgroundColor: differe ? Colors.orange : Colors.green,
      ),
    );
  }

  /// Garde-fou avant encaissement, même règle que la vente boutique : un
  /// article du stock à un prix anormalement bas (dollars saisis en francs)
  /// ou un montant reçu disproportionné demande confirmation.
  Future<bool> _verifierVraisemblance(RestaurantOrder order) async {
    for (final l in order.lines) {
      // Un plat se contrôle à sa saisie dans la carte ; ici, le stock.
      if (!l.fromStock || !prixAnormalementBas(l.unitPriceCdf, 'CDF')) continue;
      if (!mounted) return false;
      final choix = await confirmerPrixVenteBas(
        context,
        article: l.productName,
        prix: l.unitPriceCdf,
        codeDevise: 'CDF',
        peutCorriger: false,
      );
      if (choix != ChoixPrixVente.continuer || !mounted) return false;
    }
    final totalDevise = _versDevise(order.totalCdf);
    if (_codeDevise != 'CDF' && prixAnormalementBas(totalDevise, _codeDevise)) {
      if (!mounted) return false;
      final choix = await confirmerPrixVenteBas(
        context,
        article: 'le total de la commande',
        prix: totalDevise,
        codeDevise: _codeDevise,
        peutCorriger: false,
      );
      if (choix != ChoixPrixVente.continuer || !mounted) return false;
    }
    if (_method == _PayMethod.cash) {
      final recu =
          double.tryParse(_cashController.text.replaceAll(' ', '')) ?? 0;
      if (encaissementDisproportionne(recu: recu, total: totalDevise)) {
        if (!mounted) return false;
        return confirmerEncaissementDisproportionne(
          context,
          recu: recu,
          total: totalDevise,
          codeDevise: _codeDevise,
        );
      }
    }
    return true;
  }

  Future<void> _confirm(RestaurantOrder order) async {
    // Double clic : un seul envoi.
    if (_submitting) return;
    // Devise sans taux : refus, jamais un taux 1 silencieux.
    if (_tauxManquant) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CurrencyService.missingRateMessage(
              _selectedTransactionCurrency!.code,
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final detailsError = paymentDetailsError(
      method: _method.apiValue,
      operator: _mobileOperator,
      reference: _paymentRefController.text,
      dueDate: _method == _PayMethod.credit
          ? (_dueDate ?? defaultCreditDueDate())
          : null,
    );
    if (detailsError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detailsError), backgroundColor: Colors.red),
      );
      return;
    }
    if (!await _verifierVraisemblance(order) || !mounted) return;
    final total = order.totalCdf;
    // Espèces et Mobile Money sont ENCAISSÉS ; seul le compte client reste dû.
    // (Mobile Money tombait dans « À encaisser » alors que l'argent est reçu.)
    final completed = _method != _PayMethod.credit;
    final paid = completed ? total : 0.0;
    final compteId = _compteId(order);
    if (_method == _PayMethod.credit && compteId == null) return;

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
      localId: _saleLocalIds.putIfAbsent(order.id, () => const Uuid().v4()),
      date: DateTime.now(),
      // Client RÉEL quand la commande en connaît un (à emporter nommé) :
      // sans cela la vente restait rattachée à un client fabriqué, invisible
      // dans l'historique du client et dans le journal des opérations.
      // Sans client rattaché : client de passage, comme la vente boutique
      // (aucun identifiant fabriqué, qui donnait une dette sans débiteur).
      customerId: _method == _PayMethod.credit ? compteId : order.customerId,
      // Un libellé de table n'est pas un client ; le nom d'un client à
      // emporter l'est.
      customerName: _method == _PayMethod.credit
          ? (_compteNom(order) ?? order.label)
          : (order.customerName ??
              (order.type == RestaurantOrderType.takeaway &&
                      !RestaurantOrderTypeX.labelLooksTakeaway(order.label)
                  ? order.label
                  : 'Inconnu')),
      items: items,
      totalAmountInCdf: total,
      paidAmountInCdf: paid,
      // La vente porte la devise REELLEMENT encaissee, avec le taux central
      // fige au moment du reglement. Elle etait auparavant forcee en CDF, si
      // bien qu'un encaissement en devise n'existait nulle part en aval :
      // ni dans le chiffre par devise, ni en comptabilite.
      transactionCurrencyCode: _codeDevise,
      transactionExchangeRate: _transactionExchangeRate,
      totalAmountInTransactionCurrency: _versDevise(total),
      paidAmountInTransactionCurrency: _versDevise(paid),
      discountPercentage: 0,
      paymentMethod: paymentMethodCode(_method.apiValue),
      paymentReference: _method == _PayMethod.mobileMoney
          ? _paymentRefController.text.trim()
          : null,
      dueDate: _method == _PayMethod.credit
          ? (_dueDate ?? defaultCreditDueDate())
          : null,
      status: completed ? SaleStatus.completed : SaleStatus.pending,
      notes: [
        'Commande restaurant ${order.label}',
        if (_method == _PayMethod.mobileMoney) mobileMoneyNote(_mobileOperator),
      ].join(' · '),
    );

    _pendingSale = sale;
    setState(() {
      _submitting = true;
      _payingOrderId = order.id;
      _payingMethod = _method;
    });
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
      // La commande payée est celle figée au clic, pas la sélection courante.
      final id = _payingOrderId;
      // Vente enregistrée : son identifiant local ne sert plus.
      if (id != null) _saleLocalIds.remove(id);
      if (id != null) {
        await context
            .read<RestaurantOrdersCubit>()
            .markPaid(id, method: _payingMethod?.apiValue);
      }
      if (!mounted) return;
      await _showPostSaleActions();
    } else if (state is SalesError) {
      setState(() {
        _submitting = false;
        _payingOrderId = null;
        _payingMethod = null;
      });
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
      // Ne désélectionne que si l'on est resté sur la commande réglée.
      if (_selectedOrderId == _payingOrderId) _selectedOrderId = null;
      _payingOrderId = null;
      _payingMethod = null;
      _cashController.clear();
      // Le client du compte valait pour CETTE commande seulement.
      _clientCompte = null;
      _sejour = null;
      _method = _PayMethod.cash;
      _mobileOperator = null;
      _paymentRefController.clear();
      _dueDate = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paiement enregistré'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Nouvelle commande par le parcours commun du desktop (sur place ou à
  /// emporter avec choix du client), sélectionnée aussitôt dans la caisse.
  Future<void> _promptNewOrder() async {
    final order = await showNewRestaurantOrderDialog(
      context,
      context.read<RestaurantOrdersCubit>(),
    );
    if (order == null || !mounted) return;
    _selectionner(order.id);
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
                        Text(formatCurrency(widget.item.prixSaisi, widget.item.deviseSaisie),
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
