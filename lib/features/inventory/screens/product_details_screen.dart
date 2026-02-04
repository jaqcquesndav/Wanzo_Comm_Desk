import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../constants/spacing.dart';
import '../../../constants/typography.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';
import '../bloc/inventory_state.dart';
import '../models/product.dart';
import '../models/stock_transaction.dart';
import 'package:wanzo/features/settings/bloc/settings_bloc.dart';
import 'package:wanzo/features/settings/bloc/settings_state.dart';
import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/core/utils/currency_formatter.dart' as currency_util; // Added import for currency_formatter

/// Écran de détails d'un produit
class ProductDetailsScreen extends StatefulWidget {
  /// ID du produit
  final String productId;

  /// Produit (optionnel, peut être obtenu à partir de l'ID)
  final Product? product;

  const ProductDetailsScreen({
    super.key,
    required this.productId,
    this.product,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Charger les détails du produit si non fournis
    if (widget.product == null) {
      context.read<InventoryBloc>().add(LoadProduct(widget.productId));
    } else {
      // Charger les transactions pour ce produit
      context.read<InventoryBloc>().add(LoadProductTransactions(widget.productId));
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is InventoryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
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

        final product = widget.product ??
            (state is ProductLoaded ? state.product : null);

        if (product == null) {
          return WanzoScaffold(
            currentIndex: 2, // Stock a l'index 2
            title: 'Détails du produit',
            onBackPressed: () => context.pop(),
            body: const Center(
              child: Text('Produit non trouvé'),
            ),
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
          ],
          body: Column(
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
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(WanzoSpacing.md),
                      child: _buildProductDetails(context, product),
                    ),

                    // Onglet "Historique"
                    _buildTransactionsHistory(context, transactions),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: _tabController.index == 1
              ? FloatingActionButton(
                  onPressed: () => _showAddTransactionDialog(context, product),
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
    Currency currency = Currency.USD; // Changed CurrencyType to Currency and default value

    if (settingsState is SettingsLoaded) {
      currency = settingsState.settings.activeCurrency; // Changed to activeCurrency
    } else if (settingsState is SettingsUpdated) {
      currency = settingsState.settings.activeCurrency; // Changed to activeCurrency
    }
    // If settings are not loaded, it will use the default USD.
    // Consider showing a loading indicator or an error if settings are crucial and not loaded.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              _buildInfoRow(
                context,
                label: 'Nom',
                value: product.name,
              ),
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
                value: currency_util.formatCurrency(product.costPriceInCdf, currency.code),
              ),
              const Divider(),
              _buildInfoRow(
                context,
                label: 'Prix de vente',
                value: currency_util.formatCurrency(product.sellingPriceInCdf, currency.code),
              ),
              const Divider(),
              _buildInfoRow(
                context,
                label: 'Marge bénéficiaire',
                value: currency_util.formatCurrency(product.profitMarginInCdf, currency.code),
                valueColor: product.profitMarginInCdf > 0 ? Colors.green : Colors.red,
              ),
              const Divider(),
              _buildInfoRow(
                context,
                label: 'Marge (%)',
                value: '${product.profitPercentageInCdf.toStringAsFixed(2)}%', // Corrected field name
                valueColor: product.profitPercentageInCdf > 0 ? Colors.green : Colors.red, // Corrected field name
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
                value: '${product.stockQuantity.toStringAsFixed(product.stockQuantity.truncateToDouble() == product.stockQuantity ? 0 : 2)} ${_getUnitName(product.unit)}',
                valueColor: product.isLowStock ? Colors.orange : (product.stockQuantity <= 0 ? Colors.red : null),
              ),
              const Divider(),
              _buildInfoRow(
                context,
                label: 'Seuil d\'alerte',
                value: '${product.alertThreshold.toStringAsFixed(product.alertThreshold.truncateToDouble() == product.alertThreshold ? 0 : 2)} ${_getUnitName(product.unit)}',
              ),
              const Divider(),
              _buildInfoRow(
                context,
                label: 'Valeur du stock',
                value: currency_util.formatCurrency(product.stockValueInCdf, currency.code),
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
                color: statusColor.withAlpha((255 * 0.1).round()), // Used withAlpha instead of withOpacity
                borderRadius: BorderRadius.circular(35),
                border: Border.all(color: statusColor),
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 40,
              ),
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
              onPressed: () => _showQuickStockAdjustmentDialog(context, product, true),
              tooltip: 'Ajouter du stock',
            ),

            // Bouton pour retirer du stock
            IconButton(
              icon: const Icon(Icons.remove_circle),
              color: Colors.redAccent,
              onPressed: product.stockQuantity > 0
                  ? () => _showQuickStockAdjustmentDialog(context, product, false)
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WanzoSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Construire l'historique des transactions
  Widget _buildTransactionsHistory(BuildContext context, List<dynamic> transactions) {
    // Si aucune transaction n'est disponible
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey.shade300,
            ),
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
  void _showQuickStockAdjustmentDialog(BuildContext context, Product product, bool isAddition) {
    final TextEditingController quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isAddition ? 'Ajouter du stock' : 'Retirer du stock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isAddition
                  ? 'Combien d\'unités souhaitez-vous ajouter au stock ?'
                  : 'Combien d\'unités souhaitez-vous retirer du stock ?'),
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
                    type: isAddition
                        ? StockTransactionType.purchase
                        : StockTransactionType.sale,
                    quantity: adjustedQuantity,
                    date: DateTime.now(),
                    notes: isAddition
                        ? 'Ajout manuel de stock'
                        : 'Retrait manuel de stock',
                    unitCostInCdf: product.costPriceInCdf, // Added required parameter
                    totalValueInCdf: product.costPriceInCdf * adjustedQuantity, // Added required parameter
                  );

                  context.read<InventoryBloc>().add(AddStockTransaction(transaction));
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
                      items: StockTransactionType.values.map((type) {
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
                    if (adjustedQuantity < 0 && product.stockQuantity < quantity) {
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
                      unitCostInCdf: product.costPriceInCdf, // Added required parameter
                      totalValueInCdf: product.costPriceInCdf * adjustedQuantity, // Added required parameter
                    );

                    context.read<InventoryBloc>().add(AddStockTransaction(transaction));
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
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Êtes-vous sûr de vouloir supprimer ce produit ? Cette action est irréversible.'),
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
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
