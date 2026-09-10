import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../constants/spacing.dart';
import '../../../constants/typography.dart';
import '../../../core/services/catalog_enhancer.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';
import '../bloc/inventory_state.dart';
import '../models/product.dart';
import '../models/stock_transaction.dart';
import 'package:wanzo/features/settings/bloc/settings_bloc.dart';
import 'package:wanzo/features/settings/bloc/settings_state.dart';
import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/core/utils/currency_formatter.dart'
    as currency_util; // Added import for currency_formatter

/// Écran de détails d'un produit
class ProductDetailsScreen extends StatefulWidget {
  /// ID du produit
  final String productId;

  /// Produit (optionnel, peut être obtenu à partir de l'ID)
  final Product? product;

  /// Constante pour le breakpoint desktop
  static const double desktopBreakpoint = 900.0;

  const ProductDetailsScreen({
    super.key,
    required this.productId,
    this.product,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final CatalogEnhancer _enhancer = CatalogEnhancer();
  bool _enhancing = false;
  bool _enhancePending = false;

  /// Version locale du produit apres amelioration (rafraichit l'UI meme quand
  /// le produit vient de `widget.product` et non du bloc).
  Product? _localProduct;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Charger les détails du produit si non fournis
    if (widget.product == null) {
      context.read<InventoryBloc>().add(LoadProduct(widget.productId));
    } else {
      // Charger les transactions pour ce produit
      context.read<InventoryBloc>().add(
        LoadProductTransactions(widget.productId),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InventoryBloc, InventoryState>(
      listener: (context, state) {
        if (state is InventoryOperationSuccess) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is InventoryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        if (state is InventoryLoading && widget.product == null) {
          return const WanzoScaffold(
            currentIndex: 2, // Stock a l'index 2
            title: 'Chargement...',
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final product =
            _localProduct ??
            widget.product ??
            (state is ProductLoaded ? state.product : null);

        if (product == null) {
          return WanzoScaffold(
            currentIndex: 2, // Stock a l'index 2
            title: 'Détails du produit',
            onBackPressed: () => context.pop(),
            body: const Center(child: Text('Produit non trouvé')),
          );
        }
        final transactions = state is ProductLoaded ? state.transactions : [];

        return WanzoScaffold(
          currentIndex: 2, // Stock a l'index 2
          title: 'Détails: ${product.name}',
          onBackPressed: () => context.pop(),
          appBarActions: [
            // Bouton pour modifier le produit
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _navigateToEditProduct(context, product),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Supprimer',
              onPressed: () => _showDeleteProductConfirmation(context, product),
            ),
          ],
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop =
                  constraints.maxWidth >=
                  ProductDetailsScreen.desktopBreakpoint;

              return Column(
                children: [
                  // TabBar pour les onglets information/historique
                  Material(
                    color: Theme.of(context).primaryColor,
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Informations'),
                        Tab(text: 'Historique'),
                      ],
                    ),
                  ),
                  // TabBarView pour le contenu des onglets
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Onglet "Informations"
                        isDesktop
                            ? _buildDesktopProductDetails(context, product)
                            : SingleChildScrollView(
                              padding: const EdgeInsets.all(WanzoSpacing.md),
                              child: _buildProductDetails(context, product),
                            ),

                        // Onglet "Historique"
                        _buildTransactionsHistory(context, transactions),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          floatingActionButton:
              _tabController.index == 1
                  ? FloatingActionButton(
                    onPressed:
                        () => _showAddTransactionDialog(context, product),
                    tooltip: 'Ajouter une transaction',
                    backgroundColor: WanzoColors.primary,
                    child: const Icon(Icons.add),
                  )
                  : null,
        );
      },
    );
  }

  /// Construire les détails du produit
  Widget _buildProductDetails(BuildContext context, Product product) {
    final settingsState = context.watch<SettingsBloc>().state;
    Currency currency =
        Currency.USD; // Changed CurrencyType to Currency and default value

    if (settingsState is SettingsLoaded) {
      currency =
          settingsState.settings.activeCurrency; // Changed to activeCurrency
    } else if (settingsState is SettingsUpdated) {
      currency =
          settingsState.settings.activeCurrency; // Changed to activeCurrency
    }
    // If settings are not loaded, it will use the default USD.
    // Consider showing a loading indicator or an error if settings are crucial and not loaded.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo du produit (avec bouton d'amelioration si non amelioree)
        _buildProductImage(context, product),

        // En-tête avec statut et quantité
        _buildStockStatusCard(context, product),
        const SizedBox(height: WanzoSpacing.lg),

        // Informations générales
        _buildSectionCard(
          context,
          title: 'Informations générales',
          icon: Icons.info,
          content: Column(
            children: [
              _buildInfoRow(context, label: 'Nom', value: product.name),
              if (product.description.isNotEmpty) ...[
                const Divider(),
                _buildInfoRow(
                  context,
                  label: 'Description',
                  value: product.description,
                ),
              ],
              if (product.barcode.isNotEmpty) ...[
                const Divider(),
                _buildInfoRow(
                  context,
                  label: 'Code-barres / Référence',
                  value: product.barcode,
                ),
              ],
              const Divider(),
              _buildInfoRow(
                context,
                label: 'Catégorie',
                value: _getCategoryName(product.category),
              ),
              const Divider(),
              _buildInfoRow(
                context,
                label: 'Unité de mesure',
                value: _getUnitName(product.unit),
              ),
            ],
          ),
        ),
        const SizedBox(height: WanzoSpacing.lg),

        // Informations de prix
        _buildSectionCard(
          context,
          title: 'Prix',
          icon: Icons.attach_money,
          content: Column(
            children: [
              _buildInfoRow(
                context,
                label: 'Prix d\'achat',
                value: currency_util.formatCurrency(
                  product.costPriceInCdf,
                  currency.code,
                ),
              ),
              const Divider(),
              _buildInfoRow(
                context,
                label: 'Prix de vente',
                value: currency_util.formatCurrency(
                  product.sellingPriceInCdf,
                  currency.code,
                ),
              ),
              const Divider(),
              _buildInfoRow(
                context,
                label: 'Marge bénéficiaire',
                value: currency_util.formatCurrency(
                  product.profitMarginInCdf,
                  currency.code,
                ),
                valueColor:
                    product.profitMarginInCdf > 0 ? Colors.green : Colors.red,
              ),
              const Divider(),
              _buildInfoRow(
                context,
                label: 'Marge (%)',
                value:
                    '${product.profitPercentageInCdf.toStringAsFixed(2)}%', // Corrected field name
                valueColor:
                    product.profitPercentageInCdf > 0
                        ? Colors.green
                        : Colors.red, // Corrected field name
              ),
            ],
          ),
        ),
        const SizedBox(height: WanzoSpacing.lg),

        // Informations de stock
        _buildSectionCard(
          context,
          title: 'Stock',
          icon: Icons.inventory_2,
          content: Column(
            children: [
              _buildInfoRow(
                context,
                label: 'Quantité en stock',
                value:
                    '${product.stockQuantity.toStringAsFixed(product.stockQuantity.truncateToDouble() == product.stockQuantity ? 0 : 2)} ${_getUnitName(product.unit)}',
                valueColor:
                    product.isLowStock
                        ? Colors.orange
                        : (product.stockQuantity <= 0 ? Colors.red : null),
              ),
              const Divider(),
              _buildInfoRow(
                context,
                label: 'Seuil d\'alerte',
                value:
                    '${product.alertThreshold.toStringAsFixed(product.alertThreshold.truncateToDouble() == product.alertThreshold ? 0 : 2)} ${_getUnitName(product.unit)}',
              ),
              // Expiration date (conditional)
              if (product.hasExpirationDate) ...[
                const Divider(),
                _buildInfoRow(
                  context,
                  label: 'Date d\'expiration',
                  value: DateFormat(
                    'dd/MM/yyyy',
                  ).format(product.expirationDate!),
                  valueColor:
                      product.isExpired
                          ? Colors.red
                          : product.isExpiringVerySoon
                          ? Colors.orange
                          : product.isExpiringSoon
                          ? Colors.amber.shade700
                          : null,
                  icon:
                      product.isExpired || product.isExpiringVerySoon
                          ? Icon(
                            product.isExpired ? Icons.error : Icons.warning,
                            size: 16,
                            color:
                                product.isExpired ? Colors.red : Colors.orange,
                          )
                          : null,
                ),
              ],
              const Divider(),
              _buildInfoRow(
                context,
                label: 'Valeur du stock',
                value: currency_util.formatCurrency(
                  product.stockValueInCdf,
                  currency.code,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: WanzoSpacing.lg),

        // Dates
        _buildSectionCard(
          context,
          title: 'Dates',
          icon: Icons.calendar_today,
          content: Column(
            children: [
              _buildInfoRow(
                context,
                label: 'Date d\'ajout',
                value: DateFormat('dd/MM/yyyy HH:mm').format(product.createdAt),
              ),
              const Divider(),
              _buildInfoRow(
                context,
                label: 'Dernière mise à jour',
                value: DateFormat('dd/MM/yyyy HH:mm').format(product.updatedAt),
              ),
            ],
          ),
        ),
        const SizedBox(height: WanzoSpacing.lg),

        // Bouton de suppression du produit
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showDeleteProductConfirmation(context, product),
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            label: const Text('Supprimer ce produit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
        const SizedBox(height: WanzoSpacing.lg),
      ],
    );
  }

  /// Construire les détails du produit pour desktop (2 colonnes)
  Widget _buildDesktopProductDetails(BuildContext context, Product product) {
    final settingsState = context.watch<SettingsBloc>().state;
    Currency currency = Currency.USD;

    if (settingsState is SettingsLoaded) {
      currency = settingsState.settings.activeCurrency;
    } else if (settingsState is SettingsUpdated) {
      currency = settingsState.settings.activeCurrency;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(WanzoSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colonne principale (informations générales + prix)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo du produit (avec bouton d'amelioration si non amelioree)
                _buildProductImage(context, product),

                // En-tête avec statut stock
                _buildStockStatusCard(context, product),
                const SizedBox(height: WanzoSpacing.lg),

                // Informations générales
                _buildSectionCard(
                  context,
                  title: 'Informations générales',
                  icon: Icons.info,
                  content: Column(
                    children: [
                      _buildInfoRow(context, label: 'Nom', value: product.name),
                      if (product.description.isNotEmpty) ...[
                        const Divider(),
                        _buildInfoRow(
                          context,
                          label: 'Description',
                          value: product.description,
                        ),
                      ],
                      if (product.barcode.isNotEmpty) ...[
                        const Divider(),
                        _buildInfoRow(
                          context,
                          label: 'Code-barres / Référence',
                          value: product.barcode,
                        ),
                      ],
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Catégorie',
                        value: _getCategoryName(product.category),
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Unité de mesure',
                        value: _getUnitName(product.unit),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: WanzoSpacing.lg),

                // Informations de prix
                _buildSectionCard(
                  context,
                  title: 'Prix',
                  icon: Icons.attach_money,
                  content: Column(
                    children: [
                      _buildInfoRow(
                        context,
                        label: 'Prix d\'achat',
                        value: currency_util.formatCurrency(
                          product.costPriceInCdf,
                          currency.code,
                        ),
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Prix de vente',
                        value: currency_util.formatCurrency(
                          product.sellingPriceInCdf,
                          currency.code,
                        ),
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Marge bénéficiaire',
                        value: currency_util.formatCurrency(
                          product.profitMarginInCdf,
                          currency.code,
                        ),
                        valueColor:
                            product.profitMarginInCdf > 0
                                ? Colors.green
                                : Colors.red,
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Marge (%)',
                        value:
                            '${product.profitPercentageInCdf.toStringAsFixed(2)}%',
                        valueColor:
                            product.profitPercentageInCdf > 0
                                ? Colors.green
                                : Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: WanzoSpacing.lg),
          // Sidebar (stock + dates + actions)
          SizedBox(
            width: 350,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informations de stock
                _buildSectionCard(
                  context,
                  title: 'Stock',
                  icon: Icons.inventory_2,
                  content: Column(
                    children: [
                      _buildInfoRow(
                        context,
                        label: 'Quantité en stock',
                        value:
                            '${product.stockQuantity.toStringAsFixed(product.stockQuantity.truncateToDouble() == product.stockQuantity ? 0 : 2)} ${_getUnitName(product.unit)}',
                        valueColor:
                            product.isLowStock
                                ? Colors.orange
                                : (product.stockQuantity <= 0
                                    ? Colors.red
                                    : null),
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Seuil d\'alerte',
                        value:
                            '${product.alertThreshold.toStringAsFixed(product.alertThreshold.truncateToDouble() == product.alertThreshold ? 0 : 2)} ${_getUnitName(product.unit)}',
                      ),
                      if (product.hasExpirationDate) ...[
                        const Divider(),
                        _buildInfoRow(
                          context,
                          label: 'Date d\'expiration',
                          value: DateFormat(
                            'dd/MM/yyyy',
                          ).format(product.expirationDate!),
                          valueColor:
                              product.isExpired
                                  ? Colors.red
                                  : product.isExpiringVerySoon
                                  ? Colors.orange
                                  : product.isExpiringSoon
                                  ? Colors.amber.shade700
                                  : null,
                          icon:
                              product.isExpired || product.isExpiringVerySoon
                                  ? Icon(
                                    product.isExpired
                                        ? Icons.error
                                        : Icons.warning,
                                    size: 16,
                                    color:
                                        product.isExpired
                                            ? Colors.red
                                            : Colors.orange,
                                  )
                                  : null,
                        ),
                      ],
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Valeur du stock',
                        value: currency_util.formatCurrency(
                          product.stockValueInCdf,
                          currency.code,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: WanzoSpacing.lg),

                // Dates
                _buildSectionCard(
                  context,
                  title: 'Dates',
                  icon: Icons.calendar_today,
                  content: Column(
                    children: [
                      _buildInfoRow(
                        context,
                        label: 'Date d\'ajout',
                        value: DateFormat(
                          'dd/MM/yyyy HH:mm',
                        ).format(product.createdAt),
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Dernière mise à jour',
                        value: DateFormat(
                          'dd/MM/yyyy HH:mm',
                        ).format(product.updatedAt),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: WanzoSpacing.lg),

                // Actions rapides
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(WanzoSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.flash_on,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: WanzoSpacing.sm),
                            Text(
                              'Actions rapides',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(),
                        ElevatedButton.icon(
                          onPressed:
                              () => _showQuickStockAdjustmentDialog(
                                context,
                                product,
                                true,
                              ),
                          icon: const Icon(Icons.add_circle),
                          label: const Text('Ajouter du stock'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                        const SizedBox(height: WanzoSpacing.sm),
                        OutlinedButton.icon(
                          onPressed:
                              product.stockQuantity > 0
                                  ? () => _showQuickStockAdjustmentDialog(
                                    context,
                                    product,
                                    false,
                                  )
                                  : null,
                          icon: const Icon(Icons.remove_circle),
                          label: const Text('Retirer du stock'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Vrai si l'image principale du produit est deja amelioree (dans le
  /// catalogue public). Critere « non amelioree » = negation de ceci.
  bool _isPrimaryEnhanced(Product product) =>
      product.images.isNotEmpty && product.images.first.enhanced;

  /// Image affichee (URL publique en priorite, sinon fichier local).
  Widget? _productThumb(Product product) {
    final url = product.primaryImageUrl;
    if (url != null && url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: 200,
        fit: BoxFit.contain,
        placeholder: (_, __) => const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    final local = product.imagePath;
    if (local != null && local.isNotEmpty && !local.startsWith('http')) {
      final file = File(local);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: double.infinity,
          height: 200,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      }
    }
    return null;
  }

  /// Photo du produit avec un bouton « Améliorer » clairement visible tant que
  /// l'image n'est pas encore amelioree. Une fois amelioree, etat discret.
  Widget _buildProductImage(BuildContext context, Product product) {
    final theme = Theme.of(context);
    final thumb = _productThumb(product);
    if (thumb == null) return const SizedBox.shrink();

    final enhanced = _isPrimaryEnhanced(product);
    final url = product.primaryImageUrl;
    // L'amelioration s'applique a une image publique (URL http).
    final canEnhance =
        !enhanced && url != null && url.startsWith('http') && !_enhancing;

    Widget? overlay;
    if (_enhancing) {
      overlay = _enhanceStatusChip(
        theme,
        label: 'Amélioration...',
        loading: true,
        background: theme.colorScheme.primary,
        foreground: theme.colorScheme.onPrimary,
      );
    } else if (canEnhance) {
      overlay = _enhanceActionButton(theme, product);
    } else if (_enhancePending) {
      overlay = _enhanceStatusChip(
        theme,
        label: 'Amélioration en attente',
        icon: Icons.hourglass_empty,
        background: theme.colorScheme.surface.withValues(alpha: 0.92),
        foreground: theme.colorScheme.onSurfaceVariant,
      );
    } else if (enhanced) {
      overlay = _enhanceStatusChip(
        theme,
        label: 'Amélioré',
        icon: Icons.auto_awesome,
        background: theme.colorScheme.surface.withValues(alpha: 0.92),
        foreground: theme.colorScheme.primary,
      );
    }

    return Container(
      width: double.infinity,
      height: 200,
      margin: const EdgeInsets.only(bottom: WanzoSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: thumb,
            ),
          ),
          if (overlay != null)
            Positioned(right: 12, bottom: 12, child: overlay),
        ],
      ),
    );
  }

  /// Bouton d'action « Améliorer » (icone + texte), bien visible.
  Widget _enhanceActionButton(ThemeData theme, Product product) {
    return Material(
      color: theme.colorScheme.primary,
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _enhanceProductImage(product),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_fix_high,
                  size: 18, color: theme.colorScheme.onPrimary),
              const SizedBox(width: 6),
              Text(
                'Améliorer',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Indicateur d'etat discret (chargement / en attente / deja amelioree).
  Widget _enhanceStatusChip(
    ThemeData theme, {
    required String label,
    IconData? icon,
    bool loading = false,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: foreground),
            )
          else if (icon != null)
            Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Ameliore l'image du produit puis persiste via le repository (UpdateProduct).
  /// `ok` => remplace l'image + remplit la description si vide ; `pending` =>
  /// indicateur discret « en attente » (aucune erreur ni message de credit).
  Future<void> _enhanceProductImage(Product product) async {
    if (_enhancing) return;
    final url = product.primaryImageUrl;
    if (url == null || !url.startsWith('http')) return;
    setState(() {
      _enhancing = true;
      _enhancePending = false;
    });
    try {
      final r = await _enhancer.enhance(
        imageUrl: url,
        barcode: product.barcode.trim().isEmpty ? null : product.barcode.trim(),
        name: product.name.trim().isEmpty ? null : product.name.trim(),
      );
      if (!mounted) return;
      if (r.ok && r.imageUrl != null && r.imageUrl!.isNotEmpty) {
        final newUrl = r.imageUrl!;
        final List<ProductImage> newImages = product.images.isNotEmpty
            ? [
                ProductImage(
                  url: newUrl,
                  publicId: r.publicId ?? product.images.first.publicId,
                  enhanced: true,
                ),
                ...product.images.skip(1),
              ]
            : [ProductImage(url: newUrl, publicId: r.publicId, enhanced: true)];
        final desc = (product.description.trim().isEmpty &&
                r.description != null &&
                r.description!.trim().isNotEmpty)
            ? r.description!.trim()
            : product.description;
        final updated = product.copyWith(
          imageUrl: newUrl,
          images: newImages,
          description: desc,
          updatedAt: DateTime.now(),
        );
        setState(() {
          _localProduct = updated;
          _enhancing = false;
          _enhancePending = false;
        });
        context.read<InventoryBloc>().add(UpdateProduct(updated));
      } else {
        // pending : on garde l'image d'origine, indicateur discret.
        setState(() {
          _enhancing = false;
          _enhancePending = true;
        });
      }
    } catch (_) {
      // Hors-ligne / erreur reseau : silencieux, on garde l'image telle quelle.
      if (mounted) setState(() => _enhancing = false);
    }
  }

  /// Construire la carte de statut de stock
  Widget _buildStockStatusCard(BuildContext context, Product product) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (product.stockQuantity <= 0) {
      statusColor = Colors.red;
      statusText = 'Rupture de stock';
      statusIcon = Icons.error;
    } else if (product.isLowStock) {
      statusColor = Colors.orange;
      statusText = 'Stock bas';
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.green;
      statusText = 'En stock';
      statusIcon = Icons.check_circle;
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(WanzoSpacing.md),
        child: Row(
          children: [
            // Icône de statut
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(
                  (255 * 0.1).round(),
                ), // Used withAlpha instead of withOpacity
                borderRadius: BorderRadius.circular(35),
                border: Border.all(color: statusColor),
              ),
              child: Icon(statusIcon, color: statusColor, size: 40),
            ),
            const SizedBox(width: WanzoSpacing.md),

            // Informations de stock
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: WanzoSpacing.xs),
                  Text(
                    'Quantité: ${product.stockQuantity.toStringAsFixed(product.stockQuantity.truncateToDouble() == product.stockQuantity ? 0 : 2)} ${_getUnitName(product.unit)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (product.isLowStock && product.stockQuantity > 0) ...[
                    const SizedBox(height: WanzoSpacing.xs),
                    Text(
                      'Seuil d\'alerte: ${product.alertThreshold}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),

            // Bouton pour ajouter du stock
            IconButton(
              icon: const Icon(Icons.add_circle),
              color: Theme.of(context).primaryColor,
              onPressed:
                  () => _showQuickStockAdjustmentDialog(context, product, true),
              tooltip: 'Ajouter du stock',
            ),

            // Bouton pour retirer du stock
            IconButton(
              icon: const Icon(Icons.remove_circle),
              color: Colors.redAccent,
              onPressed:
                  product.stockQuantity > 0
                      ? () => _showQuickStockAdjustmentDialog(
                        context,
                        product,
                        false,
                      )
                      : null,
              tooltip: 'Retirer du stock',
            ),
          ],
        ),
      ),
    );
  }

  /// Construire une section dans une carte
  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(WanzoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: WanzoSpacing.sm),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            content,
          ],
        ),
      ),
    );
  }

  /// Construire une ligne d'information
  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
    Widget? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WanzoSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon, const SizedBox(width: 4)],
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construire l'historique des transactions
  Widget _buildTransactionsHistory(
    BuildContext context,
    List<dynamic> transactions,
  ) {
    // Si aucune transaction n'est disponible
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: WanzoSpacing.md),
            const Text(
              'Aucune transaction pour ce produit',
              style: TextStyle(
                fontSize: 18,
                fontWeight: WanzoTypography.fontWeightMedium,
              ),
            ),
            const SizedBox(height: WanzoSpacing.md),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.info),
              label: const Text('Voir les informations du produit'),
            ),
          ],
        ),
      );
    }

    // Temporairement, utilisez une approche compatible jusqu'à ce que StockTransaction soit correctement implémenté
    return ListView(
      padding: const EdgeInsets.all(WanzoSpacing.md),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(WanzoSpacing.md),
            child: Text(
              'L\'historique des transactions sera disponible prochainement',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  /// Afficher le dialogue d'ajustement rapide du stock
  void _showQuickStockAdjustmentDialog(
    BuildContext context,
    Product product,
    bool isAddition,
  ) {
    final TextEditingController quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isAddition ? 'Ajouter du stock' : 'Retirer du stock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAddition
                    ? 'Combien d\'unités souhaitez-vous ajouter au stock ?'
                    : 'Combien d\'unités souhaitez-vous retirer du stock ?',
              ),
              const SizedBox(height: WanzoSpacing.md),
              TextField(
                controller: quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantité',
                  border: const OutlineInputBorder(),
                  suffixText: _getUnitName(product.unit),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = double.tryParse(quantityController.text);

                if (quantity != null && quantity > 0) {
                  final adjustedQuantity = isAddition ? quantity : -quantity;

                  if (!isAddition && product.stockQuantity < quantity) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Quantité insuffisante en stock'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  // Créer la transaction
                  final transaction = StockTransaction(
                    id: '', // Sera généré par le repository
                    productId: product.id,
                    type:
                        isAddition
                            ? StockTransactionType.purchase
                            : StockTransactionType.sale,
                    quantity: adjustedQuantity,
                    date: DateTime.now(),
                    notes:
                        isAddition
                            ? 'Ajout manuel de stock'
                            : 'Retrait manuel de stock',
                    unitCostInCdf:
                        product.costPriceInCdf, // Added required parameter
                    totalValueInCdf:
                        product.costPriceInCdf *
                        adjustedQuantity, // Added required parameter
                  );

                  context.read<InventoryBloc>().add(
                    AddStockTransaction(transaction),
                  );
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );
  }

  /// Afficher le dialogue d'ajout de transaction
  void _showAddTransactionDialog(BuildContext context, Product product) {
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController notesController = TextEditingController();

    StockTransactionType transactionType = StockTransactionType.purchase;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Ajouter une transaction'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type de transaction
                    const Text(
                      'Type de transaction',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: WanzoSpacing.xs),
                    DropdownButtonFormField<StockTransactionType>(
                      value: transactionType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items:
                          StockTransactionType.values.map((type) {
                            return DropdownMenuItem<StockTransactionType>(
                              value: type,
                              child: Text(_getTransactionTypeName(type)),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            transactionType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: WanzoSpacing.md),

                    // Quantité
                    const Text(
                      'Quantité',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: WanzoSpacing.xs),
                    TextField(
                      controller: quantityController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        suffixText: _getUnitName(product.unit),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: WanzoSpacing.md),

                    // Notes
                    const Text(
                      'Notes (optionnel)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: WanzoSpacing.xs),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Ajouter des notes...',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final quantity = double.tryParse(quantityController.text);

                    if (quantity == null || quantity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Veuillez entrer une quantité valide'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context);

                    // Déterminer si c'est une entrée ou une sortie
                    double adjustedQuantity = quantity;
                    if (transactionType == StockTransactionType.sale ||
                        transactionType == StockTransactionType.transferOut ||
                        transactionType == StockTransactionType.damaged ||
                        transactionType == StockTransactionType.lost) {
                      adjustedQuantity = -quantity;
                    }

                    // Vérifier s'il y a assez de stock pour les sorties
                    if (adjustedQuantity < 0 &&
                        product.stockQuantity < quantity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Quantité insuffisante en stock'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Créer la transaction
                    final transaction = StockTransaction(
                      id: '', // Sera généré par le repository
                      productId: product.id,
                      type: transactionType,
                      quantity: adjustedQuantity,
                      date: DateTime.now(),
                      notes: notesController.text,
                      unitCostInCdf:
                          product.costPriceInCdf, // Added required parameter
                      totalValueInCdf:
                          product.costPriceInCdf *
                          adjustedQuantity, // Added required parameter
                    );

                    context.read<InventoryBloc>().add(
                      AddStockTransaction(transaction),
                    );
                  },
                  child: const Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Naviguer vers l'écran de modification du produit
  void _navigateToEditProduct(BuildContext context, Product product) {
    context.push('/inventory/edit/${product.id}', extra: product);
  }

  /// Obtenir le nom de la catégorie
  String _getCategoryName(ProductCategory category) {
    switch (category) {
      case ProductCategory.food:
        return 'Alimentation';
      case ProductCategory.drink:
        return 'Boissons';
      case ProductCategory.electronics:
        return 'Électronique';
      case ProductCategory.clothing:
        return 'Vêtements';
      case ProductCategory.household:
        return 'Articles ménagers';
      case ProductCategory.hygiene:
        return 'Hygiène et beauté';
      case ProductCategory.office:
        return 'Fournitures de bureau';
      case ProductCategory.cosmetics:
        return 'Produits cosmétiques';
      case ProductCategory.pharmaceuticals:
        return 'Produits pharmaceutiques';
      case ProductCategory.bakery:
        return 'Boulangerie';
      case ProductCategory.dairy:
        return 'Produits laitiers';
      case ProductCategory.meat:
        return 'Viande';
      case ProductCategory.vegetables:
        return 'Légumes';
      case ProductCategory.fruits:
        return 'Fruits';
      case ProductCategory.other:
        return 'Autres';
    }
  }

  /// Obtenir le nom de l'unité
  String _getUnitName(ProductUnit unit) {
    switch (unit) {
      case ProductUnit.piece:
        return 'pièce(s)';
      case ProductUnit.kg:
        return 'kg';
      case ProductUnit.g:
        return 'g';
      case ProductUnit.l:
        return 'L';
      case ProductUnit.ml:
        return 'mL';
      case ProductUnit.package:
        return 'paquet(s)';
      case ProductUnit.box:
        return 'boîte(s)';
      case ProductUnit.other:
        return 'unité(s)';
    }
  }

  /// Obtenir le nom du type de transaction
  String _getTransactionTypeName(StockTransactionType type) {
    switch (type) {
      case StockTransactionType.purchase:
        return 'Achat (Entrée)';
      case StockTransactionType.sale:
        return 'Vente (Sortie)';
      case StockTransactionType.adjustment:
        return 'Ajustement';
      case StockTransactionType.transferIn:
        return 'Transfert (Entrée)';
      case StockTransactionType.transferOut:
        return 'Transfert (Sortie)';
      case StockTransactionType.returned:
        return 'Retour client (Entrée)';
      case StockTransactionType.damaged:
        return 'Endommagé (Sortie)';
      case StockTransactionType.lost:
        return 'Perdu (Sortie)';
      case StockTransactionType.initialStock:
        return 'Stock initial';
    }
  }

  /// Affiche une boîte de dialogue pour confirmer la suppression du produit
  void _showDeleteProductConfirmation(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Êtes-vous sûr de vouloir supprimer ce produit ? Cette action est irréversible.',
                ),
                const SizedBox(height: WanzoSpacing.md),
                Text(
                  'Produit: ${product.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (product.stockQuantity > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      'Attention: Ce produit a ${product.stockQuantity} ${_getUnitName(product.unit)} en stock.',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Supprimer le produit
                  context.read<InventoryBloc>().add(DeleteProduct(product.id));
                  // Fermer la boîte de dialogue
                  Navigator.pop(context);
                  // Retourner à l'écran précédent
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
  }
}
