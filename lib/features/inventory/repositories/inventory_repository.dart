import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/stock_transaction.dart'; // Import StockTransaction
import '../services/inventory_api_service.dart';

/// Repository pour gérer l'inventaire et les transactions de stock
class InventoryRepository {
  static const _productsBoxName = 'products';
  static const _transactionsBoxName = 'stock_transactions';

  late final Box<Product> _productsBox;
  late final Box<StockTransaction> _transactionsBox;
  final _uuid = const Uuid();
  final InventoryApiService? _apiService;

  InventoryRepository({InventoryApiService? apiService})
    : _apiService = apiService;

  /// Initialiser les boxes Hive
  Future<void> init() async {
    _productsBox = await Hive.openBox<Product>(_productsBoxName);
    _transactionsBox = await Hive.openBox<StockTransaction>(
      _transactionsBoxName,
    );
  }

  /// Fermer les boxes Hive
  Future<void> close() async {
    await _productsBox.close();
    await _transactionsBox.close();
  }

  /// Obtenir tous les produits
  List<Product> getAllProducts() {
    return _productsBox.values.toList();
  }

  /// Obtenir un produit par son ID
  Product? getProductById(String id) {
    try {
      return _productsBox.values.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Rechercher des produits
  List<Product> searchProducts(String query) {
    final normalizedQuery = query.toLowerCase().trim();

    if (normalizedQuery.isEmpty) {
      return getAllProducts();
    }

    return _productsBox.values.where((product) {
      return product.name.toLowerCase().contains(normalizedQuery) ||
          product.description.toLowerCase().contains(normalizedQuery) ||
          product.barcode.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  /// Filtrer les produits par catégorie
  List<Product> getProductsByCategory(ProductCategory category) {
    return _productsBox.values
        .where((product) => product.category == category)
        .toList();
  }

  /// Obtenir les produits avec stock bas
  List<Product> getLowStockProducts() {
    return _productsBox.values.where((product) => product.isLowStock).toList();
  }

  /// Obtenir les produits expirés
  List<Product> getExpiredProducts() {
    return _productsBox.values.where((product) => product.isExpired).toList();
  }

  /// Obtenir les produits qui expirent bientôt (dans les 30 jours)
  List<Product> getExpiringSoonProducts() {
    return _productsBox.values
        .where(
          (product) => product.isExpiringSoon || product.isExpiringVerySoon,
        )
        .toList();
  }

  /// Obtenir les produits qui expirent très bientôt (dans les 7 jours)
  List<Product> getExpiringVerySoonProducts() {
    return _productsBox.values
        .where((product) => product.isExpiringVerySoon)
        .toList();
  }

  /// Obtenir tous les produits avec problèmes (stock bas ou expiration)
  List<Product> getProblematicProducts() {
    return _productsBox.values
        .where(
          (product) =>
              product.isLowStock || product.isExpired || product.isExpiringSoon,
        )
        .toList();
  }

  /// Ajouter un nouveau produit
  Future<Product> addProduct(Product product) async {
    final newProductId = _uuid.v4();
    final newProduct = Product(
      id: newProductId,
      name: product.name,
      description: product.description,
      barcode: product.barcode,
      category: product.category,
      costPriceInCdf: product.costPriceInCdf,
      sellingPriceInCdf: product.sellingPriceInCdf,
      stockQuantity:
          product
              .stockQuantity, // Utiliser la quantité saisie par l'utilisateur
      unit: product.unit,
      alertThreshold: product.alertThreshold,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      imagePath: product.imagePath,
      inputCurrencyCode: product.inputCurrencyCode,
      inputExchangeRate: product.inputExchangeRate,
      costPriceInInputCurrency: product.costPriceInInputCurrency,
      sellingPriceInInputCurrency: product.sellingPriceInInputCurrency,
      syncStatus: 'pending', // Mark as pending sync
    );

    // 1. Save locally first (offline-first)
    await _productsBox.put(newProduct.id, newProduct);
    debugPrint('💾 Produit sauvegardé localement avec ID: ${newProduct.id}');

    // Enregistrer une transaction initiale si la quantité est > 0
    if (product.stockQuantity > 0) {
      await addStockTransaction(
        StockTransaction(
          id: _uuid.v4(),
          productId: newProduct.id,
          type: StockTransactionType.initialStock,
          quantity: product.stockQuantity,
          date: DateTime.now(),
          notes: 'Stock initial lors de la création du produit',
          unitCostInCdf: newProduct.costPriceInCdf,
          totalValueInCdf: newProduct.costPriceInCdf * product.stockQuantity,
        ),
      );
    }

    // 2. Try to sync with API
    if (_apiService != null) {
      try {
        debugPrint('🌐 Tentative de synchronisation du produit avec l\'API...');
        final apiResponse = await _apiService
            .createProduct(newProduct)
            .timeout(const Duration(seconds: 10));

        if (apiResponse.success && apiResponse.data != null) {
          final createdProductFromApi = apiResponse.data!;
          debugPrint(
            '✅ Produit synchronisé avec l\'API. Server ID: ${createdProductFromApi.id}',
          );

          // Update local record with server ID and mark as synced
          final syncedProduct = createdProductFromApi.copyWith(
            syncStatus: 'synced',
            stockQuantity: newProduct.stockQuantity + product.stockQuantity,
          );

          // Replace local entry with synced version using server ID
          await _productsBox.put(createdProductFromApi.id, syncedProduct);
          if (newProductId != createdProductFromApi.id) {
            await _productsBox.delete(newProductId);
          }

          return syncedProduct;
        } else {
          debugPrint(
            '⚠️ API sync failed: ${apiResponse.message}. Produit reste en local.',
          );
        }
      } catch (e) {
        debugPrint(
          '❌ Erreur sync API (addProduct): $e - Produit reste en local',
        );
      }
    } else {
      debugPrint(
        'ℹ️ API service non disponible, produit sauvegardé localement',
      );
    }

    // Retourner le produit avec la quantité correcte après la transaction
    return getProductById(newProduct.id) ?? newProduct;
  }

  /// Mettre à jour un produit existant
  Future<Product> updateProduct(Product product) async {
    final existingProduct = getProductById(product.id);

    if (existingProduct == null) {
      throw Exception('Produit non trouvé');
    }

    final updatedProduct = product.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: 'pending',
    );

    // 1. Update locally first
    await _productsBox.put(product.id, updatedProduct);
    debugPrint('💾 Produit mis à jour localement: ${product.id}');

    // 2. Try to sync with API
    if (_apiService != null) {
      try {
        final apiResponse = await _apiService
            .updateProduct(product.id, product)
            .timeout(const Duration(seconds: 10));

        if (apiResponse.success && apiResponse.data != null) {
          final updatedProductFromApi = apiResponse.data!;
          final syncedProduct = updatedProductFromApi.copyWith(
            syncStatus: 'synced',
            stockQuantity:
                updatedProduct.stockQuantity, // Keep local stock quantity
          );
          await _productsBox.put(product.id, syncedProduct);
          debugPrint('✅ Mise à jour synchronisée avec l\'API: ${product.id}');
          return syncedProduct;
        } else {
          debugPrint('⚠️ API sync failed for update: ${apiResponse.message}');
        }
      } catch (e) {
        debugPrint('❌ Erreur sync API (updateProduct): $e');
      }
    }

    return updatedProduct;
  }

  /// Supprimer un produit
  Future<void> deleteProduct(String id) async {
    // 1. Delete locally first
    await _productsBox.delete(id);

    // Supprimer également toutes les transactions associées
    final transactions =
        _transactionsBox.values.where((t) => t.productId == id).toList();
    for (final transaction in transactions) {
      await _transactionsBox.delete(transaction.id);
    }
    debugPrint('💾 Produit supprimé localement: $id');

    // 2. Try to delete from API
    if (_apiService != null) {
      try {
        final apiResponse = await _apiService
            .deleteProduct(id)
            .timeout(const Duration(seconds: 10));

        if (apiResponse.success) {
          debugPrint('✅ Suppression synchronisée avec l\'API: $id');
        } else {
          debugPrint('⚠️ API sync failed for delete: ${apiResponse.message}');
        }
      } catch (e) {
        debugPrint('❌ Erreur sync API (deleteProduct): $e');
      }
    }
  }

  /// Ajouter une nouvelle transaction de stock
  /// [pushToApi] : pousser la transaction vers le backend. À `false` pour les
  /// mouvements DÉCLENCHÉS PAR UNE VENTE : le backend décrémente déjà le stock à
  /// la création de la vente (sales.service), donc pousser en plus une
  /// transaction de stock = DOUBLE décrément. Dans ce cas on ne fait que le
  /// décrément LOCAL (UI offline) ; le stock backend fait foi et se réconcilie.
  Future<StockTransaction> addStockTransaction(
    StockTransaction transaction, {
    bool pushToApi = true,
  }) async {
    final product = getProductById(transaction.productId);

    if (product == null) {
      throw Exception('Produit non trouvé');
    }

    final newTransaction = StockTransaction(
      id: transaction.id.isEmpty ? _uuid.v4() : transaction.id,
      productId: transaction.productId,
      type: transaction.type,
      quantity: transaction.quantity,
      date: transaction.date,
      referenceId: transaction.referenceId,
      notes: transaction.notes,
      unitCostInCdf: transaction.unitCostInCdf,
      totalValueInCdf: transaction.totalValueInCdf,
      // === Champs Business Unit pour l'isolation multi-tenant ===
      companyId: transaction.companyId ?? product.companyId,
      businessUnitId: transaction.businessUnitId ?? product.businessUnitId,
      businessUnitCode:
          transaction.businessUnitCode ?? product.businessUnitCode,
      businessUnitType:
          transaction.businessUnitType ?? product.businessUnitType,
      // Autres champs optionnels
      currencyCode: transaction.currencyCode,
      createdBy: transaction.createdBy,
      locationId: transaction.locationId,
    );

    // 1. Sauvegarder la transaction localement
    await _transactionsBox.put(newTransaction.id, newTransaction);

    // 2. Mettre à jour la quantité en stock du produit localement
    final newQuantity = product.stockQuantity + transaction.quantity;
    if (newQuantity < 0 && transaction.type != StockTransactionType.sale) {
      throw Exception('Stock insuffisant pour cette opération.');
    }

    // Update product stock quantity
    // Mouvement de vente (pushToApi=false) : ne PAS forcer le re-push du produit
    // (le stock backend est dérivé de la vente) ; sinon marquer en attente.
    final updatedProduct = product.copyWith(
      stockQuantity: newQuantity,
      updatedAt: DateTime.now(),
      syncStatus: pushToApi ? 'pending' : product.syncStatus,
    );

    await _productsBox.put(product.id, updatedProduct);
    debugPrint(
      '💾 Stock mis à jour localement: ${product.name} → $newQuantity',
    );

    // 3. Synchroniser la transaction et le stock avec l'API (sauf mouvement de vente)
    if (pushToApi && _apiService != null) {
      try {
        // Envoyer la transaction au serveur
        final apiResponse = await _apiService
            .createStockTransaction(newTransaction)
            .timeout(const Duration(seconds: 10));

        if (apiResponse.success) {
          debugPrint('✅ Transaction de stock synchronisée avec l\'API');

          // Mettre à jour le produit pour refléter le sync
          final syncedProduct = updatedProduct.copyWith(syncStatus: 'synced');
          await _productsBox.put(product.id, syncedProduct);
        } else {
          debugPrint('⚠️ Échec sync transaction stock: ${apiResponse.message}');
        }
      } catch (e) {
        debugPrint('❌ Erreur sync transaction stock: $e - Restera en local');
        // La transaction reste en local pour synchronisation ultérieure
      }
    }

    return newTransaction;
  }

  /// Obtenir toutes les transactions
  List<StockTransaction> getAllTransactions() {
    return _transactionsBox.values.toList();
  }

  /// Obtenir les transactions pour un produit spécifique
  List<StockTransaction> getTransactionsByProduct(String productId) {
    return _transactionsBox.values
        .where((transaction) => transaction.productId == productId)
        .toList();
  }

  /// Obtenir les transactions entre deux dates
  List<StockTransaction> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return _transactionsBox.values
        .where(
          (transaction) =>
              transaction.date.isAfter(startDate) &&
              transaction.date.isBefore(endDate.add(const Duration(days: 1))),
        )
        .toList();
  }

  /// Annuler une transaction
  Future<void> reverseTransaction(String transactionId) async {
    final transaction = _transactionsBox.values.firstWhere(
      (t) => t.id == transactionId,
    );

    // Créer une transaction inverse
    final reverseTransaction = StockTransaction(
      id: _uuid.v4(),
      productId: transaction.productId,
      type: transaction.type, // Type remains the same, but quantity is reversed
      quantity: -transaction.quantity, // Quantité négative pour annuler
      date: DateTime.now(),
      referenceId: transaction.referenceId,
      notes: 'Annulation de la transaction ${transaction.id}',
      unitCostInCdf:
          transaction.unitCostInCdf, // Use the original transaction's unit cost
      totalValueInCdf: -transaction.totalValueInCdf, // Reverse the total value
    );

    await addStockTransaction(reverseTransaction);
  }

  /// Obtenir la valeur totale de l'inventaire en CDF
  double getTotalInventoryValue() {
    return _productsBox.values.fold(
      0,
      (total, product) => total + product.stockValueInCdf,
    );
  }

  /// Obtenir le nombre total de produits
  int getTotalProductCount() {
    return _productsBox.length;
  }

  /// Vider le cache local de l'inventaire (à utiliser lors du changement de business unit)
  Future<void> clearLocalCache() async {
    await _productsBox.clear();
    await _transactionsBox.clear();
    debugPrint(
      "Cache local de l'inventaire vidé (produits et transactions de stock)",
    );
  }
}
