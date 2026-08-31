import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/shared_widgets/empty_state_view.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
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

import '../cubit/salon_cubit.dart';
import '../models/salon_service.dart';
import '../models/stylist.dart';

/// Modes de règlement à la caisse (identiques au reste de l'app).
enum _PayMethod { cash, mobileMoney, credit }

extension _PayMethodX on _PayMethod {
  String get label {
    switch (this) {
      case _PayMethod.cash:
        return 'Espèces';
      case _PayMethod.mobileMoney:
        return 'Mobile Money';
      case _PayMethod.credit:
        return 'Crédit';
    }
  }

  String get apiValue {
    switch (this) {
      case _PayMethod.cash:
        return 'cash';
      case _PayMethod.mobileMoney:
        return 'mobile_money';
      case _PayMethod.credit:
        return 'credit';
    }
  }

  IconData get icon {
    switch (this) {
      case _PayMethod.cash:
        return Icons.payments;
      case _PayMethod.mobileMoney:
        return Icons.smartphone;
      case _PayMethod.credit:
        return Icons.schedule;
    }
  }
}

/// Sélecteur de source du picker gauche : la CARTE (prestations) ou le STOCK
/// (produits de détail).
enum _PickerMode { services, products }

/// Une ligne du ticket salon : une prestation OU un produit de détail, avec le
/// coiffeur qui l'a exécutée/vendue et le taux de commission résolu.
class _TicketLine {
  final bool isService;
  final String refId; // id prestation (carte) ou id produit (stock)
  final String name;
  final double unitPriceCdf;
  int quantity = 1;
  Stylist? stylist;

  /// Override de commission propre à la prestation (null pour un produit).
  final double? serviceCommissionOverridePct;

  _TicketLine({
    required this.isService,
    required this.refId,
    required this.name,
    required this.unitPriceCdf,
    this.serviceCommissionOverridePct,
  });

  double get totalCdf => unitPriceCdf * quantity;

  /// Taux de commission applicable : override prestation, sinon taux du
  /// coiffeur (prestations vs produits). 0 si pas de coiffeur.
  double get commissionRate {
    if (isService) {
      if (serviceCommissionOverridePct != null) {
        return serviceCommissionOverridePct!;
      }
      return stylist?.serviceCommissionPct ?? 0;
    }
    return stylist?.retailCommissionPct ?? 0;
  }

  double get commissionAmount => totalCdf * commissionRate / 100;
}

/// TICKET / POS du salon (mise en page DESKTOP en 2 colonnes) : à gauche la
/// CARTE des prestations (et, en bascule, les produits de détail) ; à droite le
/// ticket, chaque ligne se voyant attribuer un coiffeur (sa commission figée),
/// puis le règlement. Le règlement construit une `List<SaleItem>` et passe par
/// la chaîne de vente EXISTANTE via `SalesBloc.AddSale` — aucun nouveau moteur
/// de facturation. Miroir de la caisse restaurant.
class SalonSaleScreen extends StatefulWidget {
  const SalonSaleScreen({super.key});

  @override
  State<SalonSaleScreen> createState() => _SalonSaleScreenState();
}

class _SalonSaleScreenState extends State<SalonSaleScreen> {
  final List<_TicketLine> _lines = [];
  final _customerController = TextEditingController();
  final _cashController = TextEditingController();
  _PickerMode _pickerMode = _PickerMode.services;
  String _search = '';
  _PayMethod _method = _PayMethod.cash;
  bool _submitting = false;

  @override
  void dispose() {
    _customerController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  double get _total => _lines.fold(0, (sum, l) => sum + l.totalCdf);
  double get _totalCommission =>
      _lines.fold(0, (sum, l) => sum + l.commissionAmount);

  double _cashGiven() =>
      double.tryParse(_cashController.text.replaceAll(' ', '')) ?? 0;

  List<Product> _products() {
    try {
      return context.read<InventoryRepository>().getAllProducts();
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = BusinessContextService();
    final index = ModuleRegistry.indexOfSidebarRoute(
      ctx.activityMode,
      ctx.currentContext?.userRole,
      '/salon/sale',
    );
    return BlocListener<SalesBloc, SalesState>(
      listener: _onSalesState,
      child: WanzoScaffold(
        currentIndex: index < 0 ? 0 : index,
        title: 'Nouveau ticket',
        onBackPressed: () =>
            context.canPop() ? context.pop() : context.go('/dashboard'),
        body: BlocBuilder<SalonCubit, SalonState>(
          builder: (context, state) {
            return LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                final picker = _buildPicker(state);
                final ticket = _buildTicketColumn(state);
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: picker),
                      const VerticalDivider(width: 1),
                      SizedBox(width: 420, child: ticket),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: picker),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 2, child: ticket),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _onSalesState(BuildContext context, SalesState state) {
    if (!_submitting) return;
    if (state is SalesOperationSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vente enregistrée'),
          backgroundColor: Colors.green,
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/dashboard');
      }
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

  // ── Colonne gauche : picker (carte / produits) ───────────────────────────
  Widget _buildPicker(SalonState state) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              SegmentedButton<_PickerMode>(
                segments: const [
                  ButtonSegment(
                    value: _PickerMode.services,
                    label: Text('Prestations'),
                    icon: Icon(Icons.content_cut),
                  ),
                  ButtonSegment(
                    value: _PickerMode.products,
                    label: Text('Produits'),
                    icon: Icon(Icons.shopping_bag_outlined),
                  ),
                ],
                selected: {_pickerMode},
                onSelectionChanged: (s) =>
                    setState(() => _pickerMode = s.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: _pickerMode == _PickerMode.services
                        ? 'Rechercher une prestation…'
                        : 'Rechercher un produit…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _pickerMode == _PickerMode.services
              ? _buildServicesGrid(state)
              : _buildProductsGrid(),
        ),
      ],
    );
  }

  Widget _buildServicesGrid(SalonState state) {
    final q = _search.trim().toLowerCase();
    final services = state.activeServices
        .where((s) => q.isEmpty || s.name.toLowerCase().contains(q))
        .toList();
    if (state.activeServices.isEmpty) {
      return EmptyStateView(
        icon: Icons.content_cut,
        message: 'Aucune prestation. Composez d\'abord la carte.',
        actionLabel: 'Composer la carte',
        actionIcon: Icons.edit,
        onAction: () => context.push('/salon/prestations'),
      );
    }
    if (services.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off,
        message: 'Aucune prestation ne correspond.',
      );
    }
    final grouped = <SalonServiceCategory, List<SalonService>>{};
    for (final s in services) {
      grouped.putIfAbsent(s.category, () => []).add(s);
    }
    final categories = grouped.keys.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final cat in categories) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              cat.label.toUpperCase(),
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
            gridDelegate: _grid,
            itemCount: grouped[cat]!.length,
            itemBuilder: (context, i) => _serviceTile(grouped[cat]![i]),
          ),
        ],
      ],
    );
  }

  Widget _buildProductsGrid() {
    final q = _search.trim().toLowerCase();
    final products = _products()
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();
    if (products.isEmpty) {
      return EmptyStateView(
        icon: Icons.inventory_2_outlined,
        message: q.isEmpty
            ? 'Aucun produit en stock.'
            : 'Aucun produit ne correspond.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: _grid,
      itemCount: products.length,
      itemBuilder: (context, i) => _productTile(products[i]),
    );
  }

  static const SliverGridDelegateWithMaxCrossAxisExtent _grid =
      SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 200,
    childAspectRatio: 1.6,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
  );

  Widget _serviceTile(SalonService s) {
    final theme = Theme.of(context);
    return _PickTile(
      icon: Icons.content_cut,
      name: s.name,
      priceLabel: formatCurrency(s.priceCdf, 'CDF'),
      subtitle: s.durationMinutes != null && s.durationMinutes! > 0
          ? '${s.durationMinutes} min'
          : null,
      color: theme.colorScheme.primary,
      onTap: () => setState(() {
        _lines.add(_TicketLine(
          isService: true,
          refId: s.id,
          name: s.name,
          unitPriceCdf: s.priceCdf,
          serviceCommissionOverridePct: s.serviceCommissionPct,
        ));
      }),
    );
  }

  Widget _productTile(Product p) {
    final theme = Theme.of(context);
    return _PickTile(
      icon: Icons.shopping_bag_outlined,
      name: p.name,
      priceLabel: formatCurrency(p.sellingPriceInCdf, 'CDF'),
      subtitle: 'Stock : ${p.stockQuantity.toStringAsFixed(0)}',
      color: theme.colorScheme.tertiary,
      onTap: () => setState(() {
        _lines.add(_TicketLine(
          isService: false,
          refId: p.id,
          name: p.name,
          unitPriceCdf: p.sellingPriceInCdf,
        ));
      }),
    );
  }

  // ── Colonne droite : ticket + caisse ─────────────────────────────────────
  Widget _buildTicketColumn(SalonState state) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _customerController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Client (optionnel)',
                hintText: 'Client comptoir',
                isDense: true,
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _lines.isEmpty
                ? const EmptyStateView(
                    icon: Icons.receipt_long,
                    message:
                        'Ajoutez une prestation ou un produit au ticket.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: _lines.length,
                    itemBuilder: (context, i) =>
                        _lineCard(i, _lines[i], state.activeStylists),
                  ),
          ),
          if (_lines.isNotEmpty) _buildCheckout(theme),
        ],
      ),
    );
  }

  Widget _lineCard(int index, _TicketLine line, List<Stylist> stylists) {
    final theme = Theme.of(context);
    // Valeur sûre pour le Dropdown : le coiffeur de la ligne doit figurer dans
    // la liste active (sinon assertion). Retombe sur null si retiré/inactif.
    final dropdownValue =
        (line.stylist != null && stylists.contains(line.stylist))
            ? line.stylist
            : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  line.isService
                      ? Icons.content_cut
                      : Icons.shopping_bag_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(line.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  tooltip: 'Retirer',
                  icon: Icon(Icons.close, color: theme.colorScheme.error),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _lines.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _QtyStepper(
                  quantity: line.quantity,
                  onChanged: (q) => setState(() => line.quantity = q),
                ),
                const Spacer(),
                Text(formatCurrency(line.totalCdf, 'CDF'),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Stylist?>(
                    value: dropdownValue,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Coiffeur',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined, size: 18),
                    ),
                    items: [
                      const DropdownMenuItem<Stylist?>(
                        value: null,
                        child: Text('—'),
                      ),
                      for (final s in stylists)
                        DropdownMenuItem<Stylist?>(
                          value: s,
                          child:
                              Text(s.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (s) => setState(() => line.stylist = s),
                  ),
                ),
                const SizedBox(width: 8),
                if (line.stylist != null)
                  Text(
                    'Comm. ${formatCurrency(line.commissionAmount, 'CDF')}',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckout(ThemeData theme) {
    final total = _total;
    final change = _cashGiven() - total;
    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
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
            if (_totalCommission > 0)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Commissions ${formatCurrency(_totalCommission, 'CDF')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final m in _PayMethod.values)
                  ChoiceChip(
                    avatar: Icon(m.icon, size: 18),
                    label: Text(m.label),
                    selected: _method == m,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),
            if (_method == _PayMethod.cash) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Montant reçu (CDF)',
                  isDense: true,
                  prefixIcon: const Icon(Icons.payments),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_cashController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    change >= 0
                        ? 'Monnaie à rendre : ${formatCurrency(change, 'CDF')}'
                        : 'Manque : ${formatCurrency(-change, 'CDF')}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: change >= 0
                          ? Colors.green.shade700
                          : theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  _submitting || (_method == _PayMethod.cash && change < 0)
                      ? null
                      : _confirm,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text('Encaisser · ${formatCurrency(total, 'CDF')}'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Règlement ───────────────────────────────────────────────────────────
  void _confirm() {
    final total = _total;
    final bool completed = _method == _PayMethod.cash;
    final paid = completed ? total : 0.0;

    // Construction des SaleItem : lignes de prestation (service) avec exécutant
    // + commission figée ; lignes produit (product) avec commission de détail
    // éventuelle. On réutilise `withCalculatedTotal` qui calcule le montant de
    // commission à partir du taux.
    final items = <SaleItem>[
      for (final l in _lines)
        SaleItem.withCalculatedTotal(
          productId: l.refId,
          productName: l.name,
          quantity: l.quantity,
          unitPrice: l.unitPriceCdf,
          currencyCode: 'CDF',
          exchangeRate: 1.0,
          itemType: l.isService ? SaleItemType.service : SaleItemType.product,
          performerId: l.stylist?.id,
          performerName: l.stylist?.name,
          commissionRate: l.stylist != null ? l.commissionRate : null,
        ),
    ];

    final customerName = _customerController.text.trim().isEmpty
        ? 'Client comptoir'
        : _customerController.text.trim();

    final sale = Sale(
      id: '',
      date: DateTime.now(),
      customerName: customerName,
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
      notes: 'Ticket salon',
    );

    setState(() => _submitting = true);
    context.read<SalesBloc>().add(AddSale(sale));
    _autoPrintCashTicket(sale);
  }

  /// Auto-impression du ticket espèces (même câblage que boutique/restaurant).
  /// Fire-and-forget : n'empêche jamais la navigation post-vente.
  Future<void> _autoPrintCashTicket(Sale sale) async {
    try {
      if (!ReceiptPrinterService.isCashPayment(sale.paymentMethod)) return;
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
      await printerService.printCashReceipt(sale, settings);
    } catch (_) {
      // Silencieux : la vente est déjà enregistrée, l'impression est accessoire.
    }
  }
}

/// Tuile compacte du picker (prestation ou produit) : icône, nom, sous-titre,
/// prix. Un tap l'ajoute au ticket.
class _PickTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String priceLabel;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  const _PickTile({
    required this.icon,
    required this.name,
    required this.priceLabel,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const Spacer(),
              Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (subtitle != null)
                Text(subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(priceLabel,
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Incrémenteur de quantité compact.
class _QtyStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;
  const _QtyStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          visualDensity: VisualDensity.compact,
          onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
        ),
        Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w700)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(quantity + 1),
        ),
      ],
    );
  }
}
