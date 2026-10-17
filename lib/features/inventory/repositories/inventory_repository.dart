import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart'
    show OfflineQueuedException;
import '../models/product.dart';
import '../models/stock_transaction.dart'; // Import StockTransaction
import '../services/inventory_api_service.dart';
import '../services/restock_awaiting_expense.dart';

/// Refus définitif du serveur (4xx) sur un mouvement de stock : rien n'a été
/// enregistré sur l'appareil. [toString] donne le motif lisible.
class StockRefusedException implements Exception {
  final String message;
  const StockRefusedException(this.message);

  @override
  String toString() => message;
}

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

  /// Rafraîchit le cache local depuis le serveur (stock tenu par le serveur,
  /// mouvements des autres caisses), puis renvoie la liste locale. Hors ligne
  /// ou en cas d'erreur : la dernière liste connue. Une fiche modifiée ici et
  /// pas encore envoyée (`pending`, `pending_update`) n'est jamais écrasée.
  Future<List<Product>> syncProductsFromApi() async {
    final api = _apiService;
    if (api == null) return getAllProducts();
    try {
      // Toutes les pages (le serveur renvoie 10 articles par défaut) ; une
      // page incomplète marque la fin.
      const taille = 200;
      final serveur = <Product>[];
      var complet = false;
      for (var page = 1; page <= 100; page++) {
        final response = await api
            .getProducts(page: page, limit: taille)
            .timeout(const Duration(seconds: 15));
        final lot = response.data;
        if (!response.success || lot == null) break;
        serveur.addAll(lot);
        if (lot.length < taille) {
          complet = true;
          break;
        }
      }
      final enAttente = _productsBox.values
          .where(
            (p) =>
                p.syncStatus == 'pending' || p.syncStatus == 'pending_update',
          )
          .map((p) => p.id)
          .toSet();
      for (final product in serveur) {
        if (!enAttente.contains(product.id)) {
          await _productsBox.put(
            product.id,
            product.copyWith(syncStatus: 'synced'),
          );
        }
      }
      // Purge des articles supprimés côté serveur, seulement après une
      // lecture COMPLÈTE et non vide (une coupure ne vide jamais le stock).
      // Les fiches pas encore envoyées sont gardées.
      if (complet && serveur.isNotEmpty) {
        final ids = serveur.map((p) => p.id).toSet();
        final absents = _productsBox.values
            .where((p) => !ids.contains(p.id) && !enAttente.contains(p.id))
            .map((p) => p.id)
            .toList();
        for (final id in absents) {
          await _productsBox.delete(id);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Rafraîchissement des articles impossible : $e');
    }
    return getAllProducts();
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
    // Copie COMPLÈTE de ce que l'utilisateur a saisi : la reconstruction
    // champ par champ oubliait la TVA, l'option catalogue, l'unité
    // d'affaires, le type de stock, la sous-catégorie, l'expiration, le SKU,
    // les fournisseurs (TVA à 0 % sur facture, case catalogue décochée,
    // produit invisible aux autres unités).
    final now = DateTime.now();
    final newProduct = product.copyWith(
      id: newProductId,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending', // Mark as pending sync
    );

    // 1. Save locally first (offline-first)
    await _productsBox.put(newProduct.id, newProduct);
    debugPrint('💾 Produit sauvegardé localement avec ID: ${newProduct.id}');

    // Historique : mouvement « stock initial ». La fiche porte DÉJÀ la
    // quantité saisie : passer par addStockTransaction l'ajoutait une seconde
    // fois (stock doublé hors ligne, puis envoyé doublé par la synchro).
    if (product.stockQuantity > 0) {
      final initial = StockTransaction(
        id: _uuid.v4(),
        productId: newProduct.id,
        type: StockTransactionType.initialStock,
        quantity: product.stockQuantity,
        date: now,
        notes: 'Stock initial lors de la création du produit',
        unitCostInCdf: newProduct.costPriceInCdf,
        totalValueInCdf: newProduct.costPriceInCdf * product.stockQuantity,
        currencyCode: 'CDF',
        companyId: newProduct.companyId,
        businessUnitId: newProduct.businessUnitId,
        businessUnitCode: newProduct.businessUnitCode,
        businessUnitType: newProduct.businessUnitType,
      );
      await _transactionsBox.put(initial.id, initial);
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
            // Le stock initial n'est compté qu'une fois (il était doublé).
            stockQuantity: newProduct.stockQuantity,
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

  /// Statut de synchronisation a poser lors d'une modification LOCALE.
  ///
  /// Le service de synchronisation traite `pending` comme « entite a CREER » et
  /// `pending_update` comme « entite a METTRE A JOUR ». Remettre en `pending`
  /// une entite deja transmise au backend provoquait donc la creation d'un
  /// DOUBLON a la prochaine synchronisation. Seule une entite jamais transmise
  /// reste en `pending`.
  String _pendingStatusFor(String? currentStatus) =>
      currentStatus == 'pending' ? 'pending' : 'pending_update';

  /// Mettre à jour un produit existant
  Future<Product> updateProduct(Product product) async {
    final existingProduct = getProductById(product.id);

    if (existingProduct == null) {
      throw Exception('Produit non trouvé');
    }

    final updatedProduct = product.copyWith(
      updatedAt: DateTime.now(),
      // Un produit deja synchronise repart en `pending_update`, jamais en
      // `pending` : sinon la synchronisation le RECREE cote backend.
      syncStatus: _pendingStatusFor(existingProduct.syncStatus),
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

  /// Mouvement de stock MANUEL (retrait, perte, ajustement, réapprovision-
  /// nement) : le serveur fait foi, par la voie unique `POST
  /// stock-transactions` (stock par emplacement, historique, comptabilité).
  ///
  /// - Accepté (ou mis en file hors ligne par le client HTTP) : appliqué ici.
  /// - Refusé (4xx : stock insuffisant, droits, article inconnu) : RIEN n'est
  ///   enregistré sur l'appareil et l'exception porte le motif lisible
  ///   (avant, le stock local bougeait quand même et divergeait du serveur).
  /// - Serveur indisponible (5xx, délai) : appliqué ici, la fiche repart en
  ///   `pending_update` pour que la synchronisation renvoie sa quantité.
  ///
  /// [expenseId] : dépense d'achat (déjà sur le serveur) qui porte un
  /// réapprovisionnement : le serveur ne passe que 311 / 6031 (achat compté
  /// une fois). [awaitingExpenseId] : dépense pas encore envoyée ; le
  /// mouvement est appliqué ici et gardé ([RestockAwaitingExpense]) jusqu'à
  /// son identifiant serveur.
  Future<StockTransaction> recordStockMovement(
    StockTransaction transaction, {
    String? expenseId,
    String? awaitingExpenseId,
  }) async {
    final product = getProductById(transaction.productId);
    if (product == null) {
      throw Exception('Produit non trouvé');
    }
    final pret = transaction.id.isEmpty
        ? transaction.copyWith(id: _uuid.v4())
        : transaction;
    if (product.stockQuantity + pret.stockDelta < 0) {
      throw Exception('Stock insuffisant pour cette opération.');
    }

    if (awaitingExpenseId != null) {
      return addStockTransaction(pret, awaitingExpenseId: awaitingExpenseId);
    }
    // Article jamais envoyé : sa création portera la quantité.
    if (_apiService == null || product.syncStatus == 'pending') {
      return addStockTransaction(pret);
    }

    var serveurIndisponible = false;
    var envoye = pret;
    try {
      final reponse = await _apiService
          .createStockTransaction(pret, expenseId: expenseId)
          .timeout(const Duration(seconds: 20));
      if (reponse.success) {
        envoye = reponse.data ?? pret;
      } else if (reponse.error is! OfflineQueuedException) {
        final code = reponse.statusCode ?? 500;
        if (code >= 400 && code < 500) {
          throw StockRefusedException(
            stockRefusalMessage(code, reponse.message ?? ''),
          );
        }
        serveurIndisponible = true;
        debugPrint('⚠️ Mouvement de stock non transmis : ${reponse.message}');
      }
    } on TimeoutException {
      serveurIndisponible = true;
    }

    final enregistre = await addStockTransaction(envoye);
    if (serveurIndisponible) {
      final p = getProductById(product.id);
      if (p != null) {
        await _productsBox.put(
          p.id,
          p.copyWith(syncStatus: _pendingStatusFor(p.syncStatus)),
        );
      }
    }
    return enregistre;
  }

  /// Enregistre un mouvement de stock SUR L'APPAREIL SEULEMENT (transaction +
  /// quantité du produit), sans envoi. Sert aux mouvements déclenchés par une
  /// vente (le serveur décrémente déjà le stock à sa création) ; un mouvement
  /// manuel passe par [recordStockMovement].
  /// [awaitingExpenseId] : réapprovisionnement dont la dépense attend encore
  /// son id serveur ; le mouvement est gardé jusqu'à son envoi.
  Future<StockTransaction> addStockTransaction(
    StockTransaction transaction, {
    String? awaitingExpenseId,
  }) async {
    final product = getProductById(transaction.productId);

    if (product == null) {
      throw Exception('Produit non trouvé');
    }

    // Même règle de sens que le serveur : seul l'ajustement garde son signe,
    // sinon le type décide (un « endommagé » saisi en positif faisait MONTER
    // le stock local).
    final newQuantity = product.stockQuantity + transaction.stockDelta;
    if (newQuantity < 0 && transaction.type != StockTransactionType.sale) {
      throw Exception('Stock insuffisant pour cette opération.');
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

    await _transactionsBox.put(newTransaction.id, newTransaction);
    if (awaitingExpenseId != null) {
      await RestockAwaitingExpense.remember(awaitingExpenseId, newTransaction);
    }

    // Le produit n'est pas marqué « à renvoyer » : le stock serveur suit les
    // mouvements, renvoyer la fiche réécrirait sa quantité.
    await _productsBox.put(
      product.id,
      product.copyWith(stockQuantity: newQuantity, updatedAt: DateTime.now()),
    );
    debugPrint(
      '💾 Stock mis à jour localement: ${product.name} → $newQuantity',
    );

    return newTransaction;
  }

  /// Message lisible d'un refus serveur sur un mouvement de stock.
  static String stockRefusalMessage(int statusCode, String serverMessage) {
    final brut = serverMessage.replaceFirst('Exception: ', '').trim();
    if (brut.contains('Insufficient stock')) {
      return 'Stock insuffisant sur le serveur pour cet article.';
    }
    switch (statusCode) {
      case 401:
        return 'Session expirée, reconnectez-vous puis réessayez.';
      case 403:
        return 'Votre rôle ne permet pas de modifier le stock.';
      case 404:
        return "Cet article n'existe pas encore sur le serveur. "
            'Synchronisez puis réessayez.';
    }
    if (brut.contains('not found')) {
      return "Cet article n'existe pas encore sur le serveur. "
          'Synchronisez puis réessayez.';
    }
    return brut.isEmpty
        ? 'Le serveur a refusé le mouvement de stock.'
        : 'Le serveur a refusé le mouvement de stock : $brut';
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
