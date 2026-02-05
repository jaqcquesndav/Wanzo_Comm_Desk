import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
// import 'package:intl/intl.dart'; // Replaced with currency_formatter
import 'dart:io'; // Added for File support
import 'package:uuid/uuid.dart'; // Added for Uuid
import '../../../constants/spacing.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';
import '../bloc/inventory_state.dart';
import '../models/product.dart';
import '../models/stock_transaction.dart'; // Added import
import 'package:wanzo/core/utils/currency_formatter.dart'; // Added
import 'package:wanzo/core/enums/currency_enum.dart'; // Added
import 'package:wanzo/features/settings/presentation/cubit/currency_settings_cubit.dart'; // Changed
import 'package:wanzo/core/services/currency_service.dart'; // Added
import 'package:wanzo/l10n/app_localizations.dart'; // Updated import

/// Écran principal de gestion de l'inventaire
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Chargement initial des produits
    context.read<InventoryBloc>().add(const LoadProducts());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Listen to currency setting changes
    context.watch<CurrencySettingsCubit>();

    return WanzoScaffold(
      currentIndex: 2, // Stock a l'index 2
      title: l10n.inventoryScreenTitle,
      appBarActions: [
        // Bouton de recherche
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => _showSearchDialog(context, l10n),
        ),
        // Filtrer par catégorie
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () => _showFilterDialog(context, l10n),
        ),
      ],
      body: Column(
        children: [
          // TabBar avec style uniforme comme la page Opérations
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: l10n.allProductsTabLabel),
              Tab(text: l10n.lowStockTabLabel),
              Tab(text: l10n.transactionsTabLabel),
            ],
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            onTap: (index) {
              if (index == 0) {
                context.read<InventoryBloc>().add(const LoadProducts());
              } else if (index == 1) {
                context.read<InventoryBloc>().add(const LoadLowStockProducts());
              } else if (index == 2) {
                context.read<InventoryBloc>().add(const LoadAllTransactions());
              }
            },
          ),
          // TabBarView remplit le reste de l'espace
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Onglet "Tous les produits"
                BlocBuilder<InventoryBloc, InventoryState>(
                  builder: (context, state) {
                    if (state is InventoryLoading) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (state is ProductsLoaded) {
                      return _buildProductsList(context, state, l10n);
                    } else if (state is InventoryError) {
                      return _buildErrorWidget(context, state.message, l10n);
                    } else {
                      return Center(
                        child: Text(l10n.noProductsAvailableMessage),
                      );
                    }
                  },
                ),
                // Onglet "Stock faible"
                BlocBuilder<InventoryBloc, InventoryState>(
                  builder: (context, state) {
                    if (state is InventoryLoading) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (state is ProductsLoaded) {
                      return _buildProductsList(
                        context,
                        state,
                        l10n,
                        lowStockOnly: true,
                      );
                    } else if (state is InventoryError) {
                      return _buildErrorWidget(context, state.message, l10n);
                    } else {
                      return Center(
                        child: Text(l10n.noLowStockProductsMessage),
                      );
                    }
                  },
                ),
                // Onglet "Transactions"
                BlocBuilder<InventoryBloc, InventoryState>(
                  builder: (context, state) {
                    if (state is InventoryLoading) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (state is TransactionsLoaded) {
                      return _buildTransactionsList(
                        context,
                        state.transactions,
                        l10n,
                      );
                    } else if (state is InventoryError) {
                      return _buildErrorWidget(context, state.message, l10n);
                    } else {
                      return Center(
                        child: Text(l10n.noTransactionsAvailableMessage),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton:
          _tabController.index != 2
              ? FloatingActionButton(
                onPressed: () {
                  context.push('/inventory/add').then((_) {
                    // Recharger les produits après retour de l'écran d'ajout
                    if (mounted) {
                      context.read<InventoryBloc>().add(const LoadProducts());
                    }
                  });
                },
                backgroundColor:
                    Theme.of(context).colorScheme.primary, // Use theme color
                child: Icon(
                  Icons.add,
                  color: Theme.of(context).colorScheme.onPrimary,
                ), // Use theme color for icon
              )
              : null,
    );
  }

  /// Afficher la boîte de dialogue de recherche
  void _showSearchDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.searchProductDialogTitle),
          content: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchProductHintText,
              prefixIcon: const Icon(Icons.search),
            ),
            onSubmitted: (value) {
              Navigator.pop(context);
              if (value.isNotEmpty) {
                context.read<InventoryBloc>().add(SearchProducts(value));
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancelButtonLabel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (_searchController.text.isNotEmpty) {
                  context.read<InventoryBloc>().add(
                    SearchProducts(_searchController.text),
                  );
                }
              },
              child: Text(l10n.searchButtonLabel),
            ),
          ],
        );
      },
    );
  }

  /// Afficher la boîte de dialogue de filtre
  void _showFilterDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.filterByCategoryDialogTitle),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: BlocBuilder<InventoryBloc, InventoryState>(
              builder: (context, state) {
                // Attempt to get categories from ProductsLoaded state
                List<ProductCategory> categories = [];
                if (state is ProductsLoaded) {
                  categories =
                      state.products.map((p) => p.category).toSet().toList();
                } else {
                  // If not ProductsLoaded, try to get all products to extract categories
                  // This is a fallback, ideally the BLoC would provide categories directly or via a separate event/state
                  final allProductsState =
                      context
                          .watch<InventoryBloc>()
                          .state; // Be cautious with watch here
                  if (allProductsState is ProductsLoaded) {
                    categories =
                        allProductsState.products
                            .map((p) => p.category)
                            .toSet()
                            .toList();
                  }
                }

                if (categories.isEmpty) {
                  return Center(child: Text(l10n.noCategoriesAvailableMessage));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return ListTile(
                      title: Text(
                        _getCategoryName(category, l10n),
                      ), // Use localized category name
                      onTap: () {
                        Navigator.pop(context);
                        context.read<InventoryBloc>().add(
                          LoadProductsByCategory(category),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancelButtonLabel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<InventoryBloc>().add(
                  const LoadProducts(),
                ); // Réinitialiser le filtre
              },
              child: Text(l10n.showAllButtonLabel),
            ),
          ],
        );
      },
    );
  }

  /// Construire la liste des produits
  Widget _buildProductsList(
    BuildContext context,
    ProductsLoaded state,
    AppLocalizations l10n, {
    bool lowStockOnly = false,
  }) {
    final products =
        lowStockOnly
            ? state.products
                .where((p) => p.stockQuantity <= p.alertThreshold)
                .toList()
            : state.products;

    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                lowStockOnly ? Icons.check_circle : Icons.inventory_2,
                size: 64,
                color:
                    lowStockOnly
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha((0.4 * 255).round()),
              ),
              const SizedBox(height: 16),
              Text(
                lowStockOnly
                    ? l10n.noLowStockProductsMessage
                    : l10n.noProductsInInventoryMessage,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (!lowStockOnly)
                ElevatedButton.icon(
                  onPressed: () => context.push('/inventory/add'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addProductButton),
                ),
            ],
          ),
        ),
      );
    }

    final currencyService = context.read<CurrencyService>();
    final currencySettingsState = context.watch<CurrencySettingsCubit>().state;

    Currency appActiveDisplayCurrency = Currency.CDF; // Default
    if (currencySettingsState.status == CurrencySettingsStatus.loaded) {
      appActiveDisplayCurrency = currencySettingsState.settings.activeCurrency;
    } else if (currencySettingsState.status == CurrencySettingsStatus.initial) {
      appActiveDisplayCurrency = currencySettingsState.settings.activeCurrency;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculer le nombre de colonnes selon la largeur
        final crossAxisCount =
            constraints.maxWidth < 400
                ? 2
                : constraints.maxWidth < 700
                ? 3
                : constraints.maxWidth < 1000
                ? 4
                : 5;

        return GridView.builder(
          padding: const EdgeInsets.all(WanzoSpacing.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.75,
            crossAxisSpacing: WanzoSpacing.sm,
            mainAxisSpacing: WanzoSpacing.sm,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final isLowStock = product.stockQuantity <= product.alertThreshold;

            final displayCurrencyCode = appActiveDisplayCurrency.code;
            final sellingPriceCdf = product.sellingPriceInCdf;
            final displaySellingPrice = currencyService.convertFromCdf(
              sellingPriceCdf,
              appActiveDisplayCurrency,
            );

            return _ProductGridCard(
              product: product,
              isLowStock: isLowStock,
              displaySellingPrice: displaySellingPrice,
              displayCurrencyCode: displayCurrencyCode,
              l10n: l10n,
              onTap: () {
                context
                    .push('/inventory/product/${product.id}', extra: product)
                    .then((_) {
                      if (mounted) {
                        context.read<InventoryBloc>().add(const LoadProducts());
                      }
                    });
              },
              onEdit: () {
                context
                    .push('/inventory/edit/${product.id}', extra: product)
                    .then((_) {
                      if (mounted) {
                        context.read<InventoryBloc>().add(const LoadProducts());
                      }
                    });
              },
              onAddStock: () => _showAddStockDialog(context, product, l10n),
            );
          },
        );
      },
    );
  }

  /// Construire la liste des transactions
  Widget _buildTransactionsList(
    BuildContext context,
    List<StockTransaction> transactions,
    AppLocalizations l10n,
  ) {
    if (transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((0.4 * 255).round()),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noTransactionsAvailableMessage,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final currencyService = context.read<CurrencyService>();
    final currencySettingsState = context.watch<CurrencySettingsCubit>().state;
    Currency appActiveDisplayCurrency = Currency.CDF; // Default

    if (currencySettingsState.status == CurrencySettingsStatus.loaded) {
      appActiveDisplayCurrency = currencySettingsState.settings.activeCurrency;
    } else if (currencySettingsState.status == CurrencySettingsStatus.initial) {
      appActiveDisplayCurrency = currencySettingsState.settings.activeCurrency;
    }

    return ListView.builder(
      padding: const EdgeInsets.all(WanzoSpacing.md),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final product = context
            .read<InventoryBloc>()
            .inventoryRepository
            .getProductById(transaction.productId);

        // Convert transaction total value to active display currency
        final displayValue = currencyService.convertFromCdf(
          transaction.totalValueInCdf,
          appActiveDisplayCurrency,
        );
        final displayCurrencyCode = appActiveDisplayCurrency.code;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: WanzoSpacing.xs),
          child: ListTile(
            title: Text(
              "${_getTransactionTypeName(transaction.type, l10n)}: ${product?.name ?? l10n.unknownProductLabel}",
            ),
            subtitle: Text(
              "${l10n.quantityLabel}: ${transaction.quantity}, ${l10n.dateLabel}: ${formatDate(transaction.date, l10n)}\\n${l10n.valueLabel}: ${formatCurrency(displayValue, displayCurrencyCode)} (${formatCurrency(transaction.totalValueInCdf, Currency.CDF.code)})",
            ),
            leading: Icon(
              transaction.quantity > 0
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              color: transaction.quantity > 0 ? Colors.green : Colors.red,
            ),
          ),
        );
      },
    );
  }

  /// Construire le widget d'erreur
  Widget _buildErrorWidget(
    BuildContext context,
    String message,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error, // Use theme color
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Relancer le chargement en fonction de l'onglet actif
              final currentIndex = _tabController.index;
              if (currentIndex == 0) {
                context.read<InventoryBloc>().add(const LoadProducts());
              } else if (currentIndex == 1) {
                context.read<InventoryBloc>().add(const LoadLowStockProducts());
              } else if (currentIndex == 2) {
                context.read<InventoryBloc>().add(const LoadAllTransactions());
              }
            },
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retryButtonLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Theme.of(
                    context,
                  ).colorScheme.errorContainer, // Use theme color
              foregroundColor:
                  Theme.of(
                    context,
                  ).colorScheme.onErrorContainer, // Use theme color
            ),
          ),
        ],
      ),
    );
  }

  /// Afficher la boîte de dialogue pour ajouter du stock
  void _showAddStockDialog(
    BuildContext context,
    Product product,
    AppLocalizations l10n,
  ) {
    final quantityController = TextEditingController();
    final notesController = TextEditingController(); // For optional notes
    final formKey = GlobalKey<FormState>();
    // Default to purchase, could add a dropdown to select type if needed
    StockTransactionType transactionType = StockTransactionType.purchase;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.addStockDialogTitle(product.name)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${l10n.currentStockLabel}: ${product.stockQuantity} ${_getUnitName(product.unit, l10n)}",
                ),
                TextFormField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.quantityToAddLabel,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.quantityValidationError;
                    }
                    if (double.tryParse(value) == null) {
                      return l10n.invalidNumberValidationError;
                    }
                    // For purchase, quantity should be positive. For other types, it might vary.
                    if (transactionType == StockTransactionType.purchase &&
                        double.parse(value) <= 0) {
                      return l10n.positiveQuantityValidationError;
                    }
                    return null;
                  },
                ), // Added closing parenthesis for the first TextFormField
                TextFormField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: l10n.notesLabelOptional,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancelButtonLabel),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final quantity = double.parse(quantityController.text);
                  final notes = notesController.text;

                  // Cost for this transaction is the product's current cost price in CDF
                  final unitCostInCdf = product.costPriceInCdf;
                  final totalValueInCdf = unitCostInCdf * quantity;

                  final transaction = StockTransaction(
                    id: const Uuid().v4(), // Generate a unique ID
                    productId: product.id,
                    type: transactionType,
                    quantity: quantity,
                    date: DateTime.now(),
                    notes:
                        notes.isNotEmpty
                            ? notes
                            : l10n.stockAdjustmentDefaultNote,
                    unitCostInCdf: unitCostInCdf,
                    totalValueInCdf: totalValueInCdf,
                  );
                  context.read<InventoryBloc>().add(
                    AddStockTransaction(transaction),
                  );
                  Navigator.pop(dialogContext);
                }
              },
              child: Text(l10n.addButtonLabel),
            ),
          ],
        );
      },
    );
  }

  String _getCategoryName(ProductCategory category, AppLocalizations l10n) {
    switch (category) {
      case ProductCategory.food:
        return l10n.productCategoryFood;
      case ProductCategory.drink:
        return l10n.productCategoryDrink;
      case ProductCategory.electronics:
        return l10n.productCategoryElectronics;
      case ProductCategory.clothing:
        return l10n.productCategoryClothing;
      case ProductCategory.household:
        return l10n.productCategoryHousehold;
      case ProductCategory.hygiene:
        return l10n.productCategoryHygiene;
      case ProductCategory.office:
        return l10n.productCategoryOffice;
      case ProductCategory.cosmetics:
        return 'Cosmetics';
      case ProductCategory.pharmaceuticals:
        return 'Pharmaceuticals';
      case ProductCategory.bakery:
        return 'Bakery';
      case ProductCategory.dairy:
        return 'Dairy';
      case ProductCategory.meat:
        return 'Meat';
      case ProductCategory.vegetables:
        return 'Vegetables';
      case ProductCategory.fruits:
        return 'Fruits';
      case ProductCategory.other:
        return l10n.productCategoryOther;
    }
  }

  String _getUnitName(ProductUnit unit, AppLocalizations l10n) {
    switch (unit) {
      case ProductUnit.piece:
        return l10n.productUnitPiece;
      case ProductUnit.kg:
        return l10n.productUnitKg;
      case ProductUnit.g:
        return l10n.productUnitG;
      case ProductUnit.l:
        return l10n.productUnitL;
      case ProductUnit.ml:
        return l10n.productUnitMl;
      case ProductUnit.package:
        return l10n.productUnitPackage;
      case ProductUnit.box:
        return l10n.productUnitBox;
      case ProductUnit.other:
        return l10n.productUnitOther;
      // default case removed as all enum members should be covered
      // If ProductUnit enum expands, this switch must be updated.
    }
  }

  String _getTransactionTypeName(
    StockTransactionType type,
    AppLocalizations l10n,
  ) {
    switch (type) {
      case StockTransactionType.purchase:
        return l10n.stockTransactionTypePurchase;
      case StockTransactionType.sale:
        return l10n.stockTransactionTypeSale;
      case StockTransactionType.adjustment:
        return l10n.stockTransactionTypeAdjustment;
      // ... other cases ...
      default:
        return l10n.stockTransactionTypeOther;
    }
  }

  String formatDate(DateTime date, AppLocalizations l10n) {
    // Simple date formatting, can be expanded with intl package for more complex needs
    return "${date.day}/${date.month}/${date.year}";
  }
}

/// Carte produit pour l'affichage en grille
class _ProductGridCard extends StatelessWidget {
  final Product product;
  final bool isLowStock;
  final double displaySellingPrice;
  final String displayCurrencyCode;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onAddStock;

  const _ProductGridCard({
    required this.product,
    required this.isLowStock,
    required this.displaySellingPrice,
    required this.displayCurrencyCode,
    required this.l10n,
    required this.onTap,
    required this.onEdit,
    required this.onAddStock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            isLowStock
                ? BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                  width: 2,
                )
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image du produit
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildProductImage(context),
                  // Badge stock faible
                  if (isLowStock)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Stock bas',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Actions rapides
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionButton(
                          context,
                          Icons.edit,
                          onEdit,
                          theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        _buildActionButton(
                          context,
                          Icons.add_box,
                          onAddStock,
                          Colors.green,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Informations du produit
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom du produit
                    Text(
                      product.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Prix
                    Text(
                      formatCurrency(displaySellingPrice, displayCurrencyCode),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Stock
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 14,
                          color:
                              isLowStock
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${product.stockQuantity} ${_getShortUnitName(product.unit)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  isLowStock
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                              fontWeight:
                                  isLowStock
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(BuildContext context) {
    final theme = Theme.of(context);

    if (product.imagePath != null && product.imagePath!.isNotEmpty) {
      return Image.file(
        File(product.imagePath!),
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) => _buildPlaceholderImage(theme),
      );
    }
    return _buildPlaceholderImage(theme);
  }

  Widget _buildPlaceholderImage(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.inventory_2,
          size: 48,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed,
    Color color,
  ) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  String _getShortUnitName(ProductUnit unit) {
    switch (unit) {
      case ProductUnit.piece:
        return 'pcs';
      case ProductUnit.kg:
        return 'kg';
      case ProductUnit.g:
        return 'g';
      case ProductUnit.l:
        return 'L';
      case ProductUnit.ml:
        return 'ml';
      case ProductUnit.box:
        return 'bte';
      case ProductUnit.package:
        return 'paq';
      case ProductUnit.other:
        return '';
    }
  }
}
