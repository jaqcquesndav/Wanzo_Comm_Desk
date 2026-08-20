import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/shared_widgets/empty_state_view.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/widgets/smart_image.dart';
import 'package:wanzo/features/inventory/models/product.dart';
import 'package:wanzo/features/inventory/repositories/inventory_repository.dart';
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
import '../models/restaurant_order.dart';
import '../repositories/menu_config_repository.dart';

/// Point de vente restaurant — mise en page desktop dense en 3 colonnes :
/// MENU (grille catalogue) | TICKET (commande en cours) | CAISSE (règlement).
/// Un bandeau supérieur sélectionne la commande active (table/emporter).
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

class RestaurantPosScreen extends StatefulWidget {
  const RestaurantPosScreen({super.key});

  @override
  State<RestaurantPosScreen> createState() => _RestaurantPosScreenState();
}

class _RestaurantPosScreenState extends State<RestaurantPosScreen> {
  late final List<Product> _products;
  final MenuConfigRepository _menuRepo = MenuConfigRepository();
  Map<String, MenuCourse> _menuConfig = {};
  bool _menuLoading = true;
  String? _selectedOrderId;
  String _search = '';

  _PayMethod _method = _PayMethod.cash;
  final _cashController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _products = context.read<InventoryRepository>().getAllProducts();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    final config = await _menuRepo.loadAll();
    if (!mounted) return;
    setState(() {
      _menuConfig = config;
      _menuLoading = false;
    });
  }

  /// Produits à la carte, filtrés par recherche, groupés et triés par catégorie.
  Map<MenuCourse, List<Product>> get _menuByCourse {
    final q = _search.toLowerCase();
    final grouped = <MenuCourse, List<Product>>{};
    for (final p in _products) {
      final course = _menuConfig[p.id];
      if (course == null) continue;
      if (q.isNotEmpty && !p.name.toLowerCase().contains(q)) continue;
      grouped.putIfAbsent(course, () => []).add(p);
    }
    return grouped;
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
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
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.menu_book),
          tooltip: 'Composer la carte',
          onPressed: () => context.push('/restaurant/menu').then((_) => _loadMenu()),
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

  void _onSalesState(BuildContext context, SalesState state) async {
    if (!_submitting) return;
    if (state is SalesOperationSuccess) {
      final id = _selectedOrderId;
      if (id != null) {
        await context.read<RestaurantOrdersCubit>().markPaid(id);
      }
      if (!context.mounted) return;
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

  // ── Colonne 1 : Menu (carte) ─────────────────────────────────────────────
  Widget _buildMenu(RestaurantOrder order) {
    if (_menuLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_menuConfig.isEmpty) {
      return EmptyStateView(
        icon: Icons.restaurant_menu,
        message: 'La carte est vide.\nDésignez vos plats parmi vos produits.',
        actionLabel: 'Composer la carte',
        actionIcon: Icons.edit,
        onAction: () => context.push('/restaurant/menu').then((_) => _loadMenu()),
      );
    }

    final grouped = _menuByCourse;
    final courses = grouped.keys.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher un plat…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: courses.isEmpty
              ? const EmptyStateView(
                  icon: Icons.search_off,
                  message: 'Aucun plat ne correspond.',
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final course in courses) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                        child: Text(
                          course.label.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          // Tuiles plus hautes : place à une vraie image de plat
                          // (le resto a besoin de bien voir le visuel du menu).
                          maxCrossAxisExtent: 180,
                          childAspectRatio: 0.82,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: grouped[course]!.length,
                        itemBuilder: (context, i) =>
                            _menuTile(order, grouped[course]![i]),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _menuTile(RestaurantOrder order, Product product) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.read<RestaurantOrdersCubit>().addLine(
            order.id,
            RestaurantOrderLine(
              productId: product.id,
              productName: product.name,
              unitPriceCdf: product.sellingPriceInCdf,
              quantity: 1,
            ),
          ),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image du plat, bien visible (réseau ou locale, cover). Repli sur
            // l'icône de catégorie quand aucune image n'est définie.
            Expanded(
              child: SmartImage(
                imageUrl: product.imageUrl,
                imagePath: product.imagePath,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholderIcon: product.category.icon,
                placeholderColor: theme.colorScheme.surfaceContainerHighest,
                placeholderIconSize: 34,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatCurrency(product.sellingPriceInCdf, 'CDF'),
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
                      subtitle:
                          Text(formatCurrency(line.unitPriceCdf, 'CDF')),
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

  // ── Colonne 3 : Caisse ─────────────────────────────────────────────────
  Widget _buildCheckout(RestaurantOrder order) {
    final theme = Theme.of(context);
    final total = order.totalCdf;
    final cashGiven =
        double.tryParse(_cashController.text.replaceAll(' ', '')) ?? 0;
    final change = cashGiven - total;

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
          const SizedBox(height: 16),
          Text('Règlement', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final m in _PayMethod.values)
                ChoiceChip(
                  avatar: Icon(m.icon, size: 16),
                  label: Text(m.label),
                  selected: _method == m,
                  onSelected: (_) => setState(() => _method = m),
                ),
            ],
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
            if (_cashController.text.isNotEmpty)
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

  Future<void> _promptNewOrder() async {
    final controller = TextEditingController();
    final cubit = context.read<RestaurantOrdersCubit>();
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nouvelle commande'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Table / client',
            hintText: 'Ex. Table 4, Emporter…',
          ),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
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
            itemType: SaleItemType.product,
          ),
        )
        .toList();

    final sale = Sale(
      id: '',
      date: DateTime.now(),
      customerId: 'resto_${order.id}',
      customerName: order.label,
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
      // Capturer les paramètres AVANT tout await (pas d'accès à context ensuite).
      old_settings_model.Settings? settings;
      final st = context.read<old_settings_bloc.SettingsBloc>().state;
      if (st is old_settings_state.SettingsLoaded) {
        settings = st.settings;
      } else if (st is old_settings_state.SettingsUpdated) {
        settings = st.settings;
      }
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
}
