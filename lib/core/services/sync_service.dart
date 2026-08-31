// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\core\services\sync_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/utils/connectivity_service.dart';
import 'package:wanzo/core/services/api_service.dart';
import 'package:wanzo/core/services/database_service.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/services/customer_api_service.dart';
import 'package:wanzo/core/services/sale_api_service.dart';
import 'package:wanzo/core/services/product_api_service.dart';
// Ajout des imports pour les autres services API
import 'package:wanzo/features/expenses/services/expense_api_service.dart';
import 'package:wanzo/features/transactions/services/financial_transaction_api_service.dart';
import 'package:wanzo/features/supplier/services/supplier_api_service.dart';
import 'package:wanzo/features/settings/services/financial_account_api_service.dart';
import 'package:wanzo/features/dashboard/repositories/operation_journal_repository.dart';
import 'package:wanzo/features/inventory/models/product.dart';
import 'package:wanzo/features/customer/models/customer.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/features/supplier/models/supplier.dart';
import 'package:wanzo/features/transactions/models/financial_transaction.dart';
import 'package:wanzo/features/settings/models/financial_account.dart';

/// Statut de la synchronisation
enum SyncStatus {
  /// Synchronisation en cours
  syncing,

  /// Synchronisation terminée avec succès
  completed,

  /// Synchronisation échouée
  failed,
}

/// Types d'entités pour la synchronisation
enum SyncEntityType {
  products,
  customers,
  sales,
  expenses,
  suppliers,
  financialTransactions,
  financialAccounts,
  operationJournal, // AJOUTÉ: Pour le journal des opérations
  all, // Pour synchroniser toutes les entités
}

/// Service pour gérer la synchronisation des données entre le stockage local et l'API
class SyncService {
  final ProductApiService _productApiService;
  final CustomerApiService _customerApiService;
  final SaleApiService _saleApiService;
  final Box<String> _syncStatusBox;

  // Services API additionnels pour la synchronisation complète
  final ExpenseApiService? _expenseApiService;
  final FinancialTransactionApiService? _financialTransactionApiService;
  final SupplierApiService? _supplierApiService;
  final FinancialAccountApiService? _financialAccountApiService;
  final OperationJournalRepository? _operationJournalRepository;

  // Callback pour notifier les blocs de la synchronisation
  final void Function()? onSyncCompleted;

  SyncService({
    required ProductApiService productApiService,
    required CustomerApiService customerApiService,
    required SaleApiService saleApiService,
    required Box<String> syncStatusBox,
    // Services optionnels (peuvent être injectés selon les besoins)
    ExpenseApiService? expenseApiService,
    FinancialTransactionApiService? financialTransactionApiService,
    SupplierApiService? supplierApiService,
    FinancialAccountApiService? financialAccountApiService,
    OperationJournalRepository? operationJournalRepository,
    this.onSyncCompleted,
  }) : _productApiService = productApiService,
       _customerApiService = customerApiService,
       _saleApiService = saleApiService,
       _syncStatusBox = syncStatusBox,
       _expenseApiService = expenseApiService,
       _financialTransactionApiService = financialTransactionApiService,
       _supplierApiService = supplierApiService,
       _financialAccountApiService = financialAccountApiService,
       _operationJournalRepository = operationJournalRepository;

  final DatabaseService _databaseService = DatabaseService();
  final ApiService _apiService = ApiService();
  final ConnectivityService _connectivityService = ConnectivityService();

  Timer? _syncTimer;
  Timer? _connectivityDebounceTimer;
  bool _isSyncing = false;
  DateTime? _lastSyncAttempt;
  static const Duration _syncDebounce = Duration(seconds: 5);
  static const Duration _minTimeBetweenSyncs = Duration(seconds: 30);

  // Constantes pour le full sync journalier automatique
  static const String _lastFullSyncKey = 'last_full_sync_date';
  static const Duration _fullSyncInterval = Duration(hours: 24);

  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();

  /// Stream qui émet l'état de la synchronisation
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  /// Vérifie si un full sync est nécessaire (dernier full sync > 24h)
  /// Retourne true si le full sync doit être déclenché
  bool _shouldForceFullSync() {
    if (!_syncStatusBox.containsKey(_lastFullSyncKey)) {
      debugPrint('📅 Premier full sync requis (pas de date précédente)');
      return true;
    }

    try {
      final lastFullSyncStr = _syncStatusBox.get(_lastFullSyncKey)!;
      final lastFullSync = DateTime.parse(lastFullSyncStr);
      final timeSinceLastFullSync = DateTime.now().difference(lastFullSync);

      if (timeSinceLastFullSync >= _fullSyncInterval) {
        debugPrint(
          '📅 Full sync requis: dernier full sync il y a ${timeSinceLastFullSync.inHours}h',
        );
        return true;
      }

      debugPrint(
        '📅 Sync incrémental: dernier full sync il y a ${timeSinceLastFullSync.inHours}h',
      );
      return false;
    } catch (e) {
      debugPrint('⚠️ Erreur parsing date full sync, forçant full sync: $e');
      return true;
    }
  }

  /// Met à jour la date du dernier full sync
  Future<void> _updateLastFullSyncDate() async {
    await _syncStatusBox.put(
      _lastFullSyncKey,
      DateTime.now().toIso8601String(),
    );
    debugPrint('✅ Date du dernier full sync mise à jour');
  }

  /// Initialise le service de synchronisation
  Future<void> init() async {
    // Planifier une synchronisation régulière
    _setupPeriodicSync();
    // Écouter les changements de connectivité via le service de connectivité
    _connectivityService.connectionStatus.addListener(() {
      if (_connectivityService.isConnected && !_isSyncing) {
        // Utiliser un debounce pour éviter les syncs multiples lors de connexions instables
        _debouncedSync();
      }
    });
  }

  /// Synchronisation avec debounce pour éviter les appels multiples
  void _debouncedSync() {
    _connectivityDebounceTimer?.cancel();
    _connectivityDebounceTimer = Timer(_syncDebounce, () async {
      // Vérifier si une sync récente a eu lieu
      if (_lastSyncAttempt != null &&
          DateTime.now().difference(_lastSyncAttempt!) < _minTimeBetweenSyncs) {
        debugPrint(
          '⏳ Sync ignorée: dernière sync il y a ${DateTime.now().difference(_lastSyncAttempt!).inSeconds}s',
        );
        return;
      }

      // Vérifier que la connexion est toujours active après le délai
      if (_connectivityService.isConnected && !_isSyncing) {
        debugPrint('🔄 Sync déclenchée après stabilisation de la connexion');
        await syncData();
      }
    });
  }

  /// Configure la synchronisation périodique
  void _setupPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 15), (timer) async {
      if (_connectivityService.isConnected && !_isSyncing) {
        await syncData();
      }
    });
  }

  /// Vérifie la connectivité
  Future<bool> isConnected() async {
    var connectivityResults = await (Connectivity().checkConnectivity());
    if (connectivityResults.contains(ConnectivityResult.mobile) ||
        connectivityResults.contains(ConnectivityResult.wifi)) {
      return true;
    }
    return false;
  }

  /// Synchronise les données avec l'API
  /// Le full sync automatique est déclenché si le dernier date de plus de 24h
  Future<bool> syncData({
    SyncEntityType entityType = SyncEntityType.all,
  }) async {
    if (_isSyncing) return false;

    _isSyncing = true;
    _lastSyncAttempt = DateTime.now();
    _syncStatusController.add(SyncStatus.syncing);
    debugPrint('Démarrage de la synchronisation des données...');

    try {
      // Déterminer si un full sync est nécessaire (>24h depuis le dernier)
      // Cette vérification est faite UNE SEULE FOIS au début pour éviter les boucles
      final bool forceFullSync = _shouldForceFullSync();

      if (forceFullSync) {
        debugPrint(
          '🔄 Mode FULL SYNC activé (sync complète de toutes les données)',
        );
      } else {
        debugPrint(
          '🔄 Mode INCREMENTAL activé (sync des nouvelles données uniquement)',
        );
      }

      // Si on synchronise toutes les entités ou des entités spécifiques
      if (entityType == SyncEntityType.all ||
          entityType == SyncEntityType.products) {
        await _syncProducts(forceFullSync: forceFullSync);
      }

      if (entityType == SyncEntityType.all ||
          entityType == SyncEntityType.customers) {
        await _syncCustomers(forceFullSync: forceFullSync);
      }

      if (entityType == SyncEntityType.all ||
          entityType == SyncEntityType.sales) {
        await _syncSales(forceFullSync: forceFullSync);
      }

      // Synchronisation des entités additionnelles si les services sont disponibles
      if ((entityType == SyncEntityType.all ||
              entityType == SyncEntityType.expenses) &&
          _expenseApiService != null) {
        await _syncExpenses(forceFullSync: forceFullSync);
      }

      if ((entityType == SyncEntityType.all ||
              entityType == SyncEntityType.suppliers) &&
          _supplierApiService != null) {
        await _syncSuppliers(forceFullSync: forceFullSync);
      }

      if ((entityType == SyncEntityType.all ||
              entityType == SyncEntityType.financialTransactions) &&
          _financialTransactionApiService != null) {
        await _syncFinancialTransactions(forceFullSync: forceFullSync);
      }

      if ((entityType == SyncEntityType.all ||
              entityType == SyncEntityType.financialAccounts) &&
          _financialAccountApiService != null) {
        await _syncFinancialAccounts(forceFullSync: forceFullSync);
      }

      // AJOUTÉ: Synchronisation du journal des opérations
      if ((entityType == SyncEntityType.all ||
              entityType == SyncEntityType.operationJournal) &&
          _operationJournalRepository != null) {
        await _syncOperationJournal();
      }

      // Mettre à jour la date du dernier full sync si on a fait un full sync
      if (forceFullSync && entityType == SyncEntityType.all) {
        await _updateLastFullSyncDate();
      }

      // Rejouer la file d'opérations génériques en attente
      final drained = await _drainPendingOperations();
      if (!drained) {
        // Connexion perdue en cours de route
        _isSyncing = false;
        _syncStatusController.add(SyncStatus.failed);
        return false;
      }

      _isSyncing = false;
      _syncStatusController.add(SyncStatus.completed);
      debugPrint('Synchronisation terminée avec succès');

      // Notifier les blocs que la synchronisation est terminée
      if (onSyncCompleted != null) {
        onSyncCompleted!();
      }

      return true;
    } catch (e) {
      debugPrint('Erreur lors de la synchronisation: $e');
      _isSyncing = false;
      _syncStatusController.add(SyncStatus.failed);
      return false;
    }
  }

  /// Vérifie s'il y a des ventes en attente qui affectent le stock d'un produit donné
  bool _hasPendingSalesForProduct(String productId) {
    try {
      if (!Hive.isBoxOpen('sales')) return false;
      final saleBox = Hive.box<Sale>('sales');
      return saleBox.values.any(
        (sale) =>
            (sale.syncStatus == 'pending' ||
                sale.syncStatus == 'pending_update') &&
            sale.items.any((item) => item.productId == productId),
      );
    } catch (_) {
      // Si la box n'est pas disponible, être conservateur et garder le stock local
      return true;
    }
  }

  /// Supprime les entrées Hive locales absentes du backend (full sync uniquement).
  /// Protège les entrées en attente de synchronisation.
  Future<int> _removeStaleEntries<T>({
    required Box<T> box,
    required Set<String> backendIds,
    bool Function(T)? isPending,
  }) async {
    // BUG #2 (data-loss) : ne JAMAIS vider un cache local non vide sur une
    // réponse backend à 0 ligne. Un backend qui renvoie une liste VIDE (cas
    // connu organizationId NULL / scope BU renvoyant 0) ne prouve pas que les
    // entités ont été supprimées côté serveur : on saute la purge dans ce cas.
    if (backendIds.isEmpty) return 0;

    int staleCount = 0;
    for (final key in box.keys.cast<String>().toList()) {
      if (!backendIds.contains(key)) {
        if (isPending != null) {
          final local = box.get(key);
          if (local != null && isPending(local)) continue;
        }
        await box.delete(key);
        staleCount++;
      }
    }
    return staleCount;
  }

  /// Synchronise les produits
  /// ÉTAPE 1: Upload des pending vers le backend
  /// ÉTAPE 2: Download des données du backend
  Future<void> _syncProducts({bool forceFullSync = false}) async {
    debugPrint('Synchronisation des produits...');
    try {
      // Vérifier si la box est ouverte
      if (!Hive.isBoxOpen('products')) {
        debugPrint('⚠️ productsBox non ouverte, tentative d\'ouverture...');
        await Hive.openBox<Product>('products');
      }
      final productBox = Hive.box<Product>('products');
      debugPrint(
        '✅ productsBox ouverte avec ${productBox.length} produits existants',
      );

      // ========== ÉTAPE 1: UPLOAD des produits pending ==========
      final pendingProducts =
          productBox.values
              .where(
                (p) =>
                    p.syncStatus == 'pending' ||
                    p.syncStatus == 'pending_update',
              )
              .toList();

      if (pendingProducts.isNotEmpty) {
        debugPrint(
          '📤 ${pendingProducts.length} produits en attente d\'upload',
        );

        for (var product in pendingProducts) {
          try {
            if (product.syncStatus == 'pending') {
              // Nouveau produit à créer
              final response = await _productApiService.createProduct(product);
              if (response.success && response.data != null) {
                final syncedProduct = response.data!.copyWith(
                  syncStatus: 'synced',
                );
                // Remplacer avec l'ID serveur
                await productBox.delete(product.id);
                await productBox.put(syncedProduct.id, syncedProduct);
                debugPrint(
                  '✅ Produit uploadé: ${product.name} (ID: ${syncedProduct.id})',
                );
              }
            } else if (product.syncStatus == 'pending_update') {
              // Produit existant à mettre à jour
              final response = await _productApiService.updateProduct(
                product.id,
                product,
              );
              if (response.success && response.data != null) {
                final syncedProduct = response.data!.copyWith(
                  syncStatus: 'synced',
                );
                await productBox.put(product.id, syncedProduct);
                debugPrint('✅ Produit mis à jour: ${product.name}');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Échec upload produit ${product.name}: $e');
            // Continue avec le suivant
          }
        }
      }

      // ========== ÉTAPE 2: DOWNLOAD depuis le backend ==========
      final String lastSyncKey = 'product_last_sync';
      Map<String, String> queryParams = {};

      if (!forceFullSync && _syncStatusBox.containsKey(lastSyncKey)) {
        final lastSyncDate = _syncStatusBox.get(lastSyncKey)!;
        queryParams['updated_after'] = lastSyncDate;
        debugPrint('📅 Sync incrémental depuis: $lastSyncDate');
      } else {
        debugPrint('📅 Sync complet (pas de date précédente)');
      }

      debugPrint('🔄 Appel API getProducts...');
      final apiResponse = await _productApiService.getProducts(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (apiResponse.success && apiResponse.data != null) {
        debugPrint('✅ ${apiResponse.data!.length} produits reçus de l\'API');
        for (var apiProduct in apiResponse.data!) {
          final localProduct = productBox.get(apiProduct.id);
          if (localProduct != null) {
            // Vérifier si des changements locaux non synchronisés affectent le stock
            final hasPendingStockChanges =
                localProduct.syncStatus == 'pending' ||
                localProduct.syncStatus == 'pending_update' ||
                _hasPendingSalesForProduct(apiProduct.id);

            if (hasPendingStockChanges) {
              // Des ventes/changements locaux non synchronisés existent
              // Garder le stock local (déjà déduit par les ventes offline)
              final mergedProduct = apiProduct.copyWith(
                stockQuantity: localProduct.stockQuantity,
                syncStatus:
                    (localProduct.syncStatus == 'pending' ||
                            localProduct.syncStatus == 'pending_update')
                        ? localProduct.syncStatus
                        : 'synced',
              );
              await productBox.put(apiProduct.id, mergedProduct);
              debugPrint(
                '🔀 Produit ${apiProduct.id}: stock local conservé (${localProduct.stockQuantity}) - changements pending',
              );
            } else {
              // Aucun changement local en attente - utiliser le stock du backend (autoritatif)
              await productBox.put(
                apiProduct.id,
                apiProduct.copyWith(syncStatus: 'synced'),
              );
              debugPrint(
                '🔀 Produit ${apiProduct.id}: stock backend utilisé (${apiProduct.stockQuantity})',
              );
            }
          } else {
            // Nouveau produit depuis l'API
            await productBox.put(
              apiProduct.id,
              apiProduct.copyWith(syncStatus: 'synced'),
            );
          }
        }
        // ====== ÉTAPE 3: NETTOYAGE données obsolètes (full sync) ======
        if (forceFullSync) {
          final stale = await _removeStaleEntries(
            box: productBox,
            backendIds: apiResponse.data!.map((p) => p.id).toSet(),
            isPending:
                (p) =>
                    p.syncStatus == 'pending' ||
                    p.syncStatus == 'pending_update',
          );
          if (stale > 0) debugPrint('🗑️ $stale produits obsolètes supprimés');
        }

        await _syncStatusBox.put(lastSyncKey, DateTime.now().toIso8601String());
        debugPrint('✅ Produits synchronisés avec succès (stock intelligent)');
      } else {
        debugPrint('❌ Failed to sync products: ${apiResponse.message}');
      }
    } catch (e, stackTrace) {
      if (e is ApiException) {
        debugPrint('❌ ApiException during product sync: ${e.message}');
      } else {
        debugPrint('❌ Erreur lors de la synchronisation des produits: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Synchronise les clients
  /// ÉTAPE 1: Upload des pending vers le backend
  /// ÉTAPE 2: Download des données du backend
  Future<void> _syncCustomers({bool forceFullSync = false}) async {
    debugPrint('Synchronisation des clients...');
    try {
      final customerBox = Hive.box<Customer>('customers');

      // ========== ÉTAPE 1: UPLOAD des clients pending ==========
      final pendingCustomers =
          customerBox.values
              .where(
                (c) =>
                    c.syncStatus == 'pending' ||
                    c.syncStatus == 'pending_update',
              )
              .toList();

      if (pendingCustomers.isNotEmpty) {
        debugPrint(
          '📤 ${pendingCustomers.length} clients en attente d\'upload',
        );

        for (var customer in pendingCustomers) {
          try {
            if (customer.syncStatus == 'pending') {
              // Nouveau client à créer
              final response = await _customerApiService.createCustomer(
                customer,
              );
              if (response.success && response.data != null) {
                final syncedCustomer = response.data!.copyWith(
                  syncStatus: 'synced',
                );
                // Remplacer avec l'ID serveur
                await customerBox.delete(customer.id);
                await customerBox.put(syncedCustomer.id, syncedCustomer);
                debugPrint(
                  '✅ Client uploadé: ${customer.name} (ID: ${syncedCustomer.id})',
                );
              }
            } else if (customer.syncStatus == 'pending_update') {
              // Client existant à mettre à jour
              final response = await _customerApiService.updateCustomer(
                customer.id,
                customer,
              );
              if (response.success && response.data != null) {
                final syncedCustomer = response.data!.copyWith(
                  syncStatus: 'synced',
                );
                await customerBox.put(customer.id, syncedCustomer);
                debugPrint('✅ Client mis à jour: ${customer.name}');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Échec upload client ${customer.name}: $e');
            // Continue avec le suivant
          }
        }
      }

      // ========== ÉTAPE 2: DOWNLOAD depuis le backend ==========
      final String lastSyncKey = 'customer_last_sync';
      Map<String, String> queryParams = {};

      if (!forceFullSync && _syncStatusBox.containsKey(lastSyncKey)) {
        final lastSyncDate = _syncStatusBox.get(lastSyncKey)!;
        queryParams['updated_after'] = lastSyncDate;
      }

      final apiResponse = await _customerApiService.getCustomers(
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );
      if (apiResponse.success && apiResponse.data != null) {
        debugPrint('✅ ${apiResponse.data!.length} clients reçus de l\'API');
        for (var apiCustomer in apiResponse.data!) {
          // Préserver les clients locaux en attente de sync
          final localCustomer = customerBox.get(apiCustomer.id);
          if (localCustomer != null && localCustomer.syncStatus == 'pending') {
            // Ne pas écraser un client local en attente de synchronisation
            debugPrint(
              '⏳ Client ${apiCustomer.id} ignoré (sync pending local)',
            );
            continue;
          }
          // Fusionner avec syncStatus synced
          await customerBox.put(
            apiCustomer.id,
            apiCustomer.copyWith(syncStatus: 'synced'),
          );
        }
        // ====== NETTOYAGE données obsolètes (full sync) ======
        if (forceFullSync) {
          final stale = await _removeStaleEntries(
            box: customerBox,
            backendIds: apiResponse.data!.map((c) => c.id).toSet(),
            isPending:
                (c) =>
                    c.syncStatus == 'pending' ||
                    c.syncStatus == 'pending_update',
          );
          if (stale > 0) debugPrint('🗑️ $stale clients obsolètes supprimés');
        }

        await _syncStatusBox.put(lastSyncKey, DateTime.now().toIso8601String());
        debugPrint('✅ Clients synchronisés avec succès');
      } else {
        debugPrint('Failed to sync customers: ${apiResponse.message}');
      }
    } catch (e) {
      if (e is ApiException) {
        debugPrint('ApiException during customer sync: ${e.message}');
      } else {
        debugPrint('Erreur lors de la synchronisation des clients: $e');
      }
    }
  }

  /// Synchronise les ventes
  /// ÉTAPE 1: Upload des pending vers le backend
  /// ÉTAPE 2: Download des données du backend
  Future<void> _syncSales({bool forceFullSync = false}) async {
    debugPrint('Synchronisation des ventes...');
    try {
      final saleBox = Hive.box<Sale>('sales');

      // ========== ÉTAPE 1: UPLOAD des ventes pending ==========
      final pendingSales =
          saleBox.values
              .where(
                (s) =>
                    s.syncStatus == 'pending' ||
                    s.syncStatus == 'pending_update',
              )
              .toList();

      if (pendingSales.isNotEmpty) {
        debugPrint('📤 ${pendingSales.length} ventes en attente d\'upload');

        for (var sale in pendingSales) {
          try {
            if (sale.syncStatus == 'pending') {
              // Nouvelle vente à créer
              final response = await _saleApiService.createSale(sale);
              if (response.success && response.data != null) {
                final syncedSale = response.data!.copyWith(
                  syncStatus: 'synced',
                );
                // Remplacer avec l'ID serveur
                await saleBox.delete(sale.id);
                await saleBox.put(syncedSale.id, syncedSale);
                debugPrint(
                  '✅ Vente uploadée: ${sale.customerName} (ID: ${syncedSale.id})',
                );
              }
            } else if (sale.syncStatus == 'pending_update') {
              // Vente existante à mettre à jour
              final response = await _saleApiService.updateSale(sale.id, sale);
              if (response.success && response.data != null) {
                final syncedSale = response.data!.copyWith(
                  syncStatus: 'synced',
                );
                await saleBox.put(sale.id, syncedSale);
                debugPrint('✅ Vente mise à jour: ${sale.customerName}');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Échec upload vente ${sale.id}: $e');
            // Continue avec la suivante
          }
        }
      }

      // ========== ÉTAPE 2: DOWNLOAD depuis le backend ==========
      final String lastSyncKey = 'sale_last_sync';
      Map<String, String> queryParams = {};

      if (!forceFullSync && _syncStatusBox.containsKey(lastSyncKey)) {
        final lastSyncDate = _syncStatusBox.get(lastSyncKey)!;
        queryParams['updated_after'] = lastSyncDate;
      }

      final apiResponse = await _saleApiService.getSales(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (apiResponse.success && apiResponse.data != null) {
        debugPrint('✅ ${apiResponse.data!.length} ventes reçues de l\'API');
        for (var apiSale in apiResponse.data!) {
          // Préserver les ventes locales en attente de sync
          final localSale = saleBox.get(apiSale.id);
          if (localSale != null && localSale.syncStatus == 'pending') {
            // Ne pas écraser une vente locale en attente de synchronisation
            debugPrint('⏳ Vente ${apiSale.id} ignorée (sync pending local)');
            continue;
          }
          // Fusionner avec syncStatus synced
          await saleBox.put(apiSale.id, apiSale.copyWith(syncStatus: 'synced'));
        }
        // ====== NETTOYAGE données obsolètes (full sync) ======
        if (forceFullSync) {
          final stale = await _removeStaleEntries(
            box: saleBox,
            backendIds: apiResponse.data!.map((s) => s.id).toSet(),
            isPending:
                (s) =>
                    s.syncStatus == 'pending' ||
                    s.syncStatus == 'pending_update',
          );
          if (stale > 0) debugPrint('🗑️ $stale ventes obsolètes supprimées');
        }

        await _syncStatusBox.put(lastSyncKey, DateTime.now().toIso8601String());
        debugPrint('✅ Ventes synchronisées avec succès');
      } else {
        debugPrint('Failed to sync sales: ${apiResponse.message}');
      }
    } catch (e) {
      if (e is ApiException) {
        debugPrint('ApiException during sale sync: ${e.message}');
      } else {
        debugPrint('Erreur lors de la synchronisation des ventes: $e');
      }
    }
  }

  /// Synchronise les dépenses
  /// ÉTAPE 1: Upload des pending vers le backend
  /// ÉTAPE 2: Download des données du backend
  Future<void> _syncExpenses({bool forceFullSync = false}) async {
    if (_expenseApiService == null) return;

    debugPrint('Synchronisation des dépenses...');
    try {
      final expenseBox = await Hive.openBox<Expense>('expenses');

      // ========== ÉTAPE 1: UPLOAD des dépenses pending ==========
      final pendingExpenses =
          expenseBox.values
              .where(
                (e) =>
                    e.syncStatus == 'pending' ||
                    e.syncStatus == 'pending_update',
              )
              .toList();

      if (pendingExpenses.isNotEmpty) {
        debugPrint(
          '📤 ${pendingExpenses.length} dépenses en attente d\'upload',
        );

        for (var expense in pendingExpenses) {
          try {
            if (expense.syncStatus == 'pending') {
              // Convertir les chemins locaux en fichiers pour l'upload
              List<File>? attachmentFiles;
              if (expense.localAttachmentPaths != null &&
                  expense.localAttachmentPaths!.isNotEmpty) {
                attachmentFiles = [];
                for (final path in expense.localAttachmentPaths!) {
                  final file = File(path);
                  if (await file.exists()) {
                    attachmentFiles.add(file);
                  } else {
                    debugPrint(
                      '[SyncService] ⚠️ Attachment file not found: $path',
                    );
                  }
                }
                if (attachmentFiles.isEmpty) attachmentFiles = null;
                debugPrint(
                  '[SyncService] 📎 ${attachmentFiles?.length ?? 0} attachments à uploader pour expense ${expense.id}',
                );
              }

              // Nouvelle dépense à créer avec les attachments
              final response = await _expenseApiService.createExpense(
                expense.date,
                expense.amount,
                expense.motif,
                expense.category.name,
                expense.paymentMethod,
                expense.supplierId,
                attachments: attachmentFiles, // Upload des fichiers locaux
                paidAmount: expense.paidAmount,
                paymentStatus: expense.paymentStatus?.name,
                supplierName: expense.supplierName,
                currencyCode: expense.currencyCode,
                exchangeRate: expense.exchangeRate,
              );
              if (response.success && response.data != null) {
                final syncedExpense = response.data!.copyWith(
                  syncStatus: 'synced',
                );
                // Remplacer avec l'ID serveur
                await expenseBox.delete(expense.id);
                await expenseBox.put(syncedExpense.id, syncedExpense);
                debugPrint(
                  '✅ Dépense uploadée: ${expense.motif} (ID: ${syncedExpense.id})',
                );
              }
            } else if (expense.syncStatus == 'pending_update') {
              // Convertir les chemins locaux en fichiers pour l'upload
              List<File>? attachmentFiles;
              if (expense.localAttachmentPaths != null &&
                  expense.localAttachmentPaths!.isNotEmpty) {
                attachmentFiles = [];
                for (final path in expense.localAttachmentPaths!) {
                  final file = File(path);
                  if (await file.exists()) {
                    attachmentFiles.add(file);
                  }
                }
                if (attachmentFiles.isEmpty) attachmentFiles = null;
              }

              // Dépense existante à mettre à jour avec les nouveaux attachments
              final response = await _expenseApiService.updateExpense(
                expense.id,
                expense.date,
                expense.amount,
                expense.motif,
                expense.category.name,
                expense.paymentMethod,
                expense.supplierId,
                newAttachments: attachmentFiles, // Upload des fichiers locaux
              );
              if (response.success && response.data != null) {
                final syncedExpense = response.data!.copyWith(
                  syncStatus: 'synced',
                );
                await expenseBox.put(expense.id, syncedExpense);
                debugPrint('✅ Dépense mise à jour: ${expense.motif}');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Échec upload dépense ${expense.id}: $e');
            // Continue avec la suivante
          }
        }
      }

      // ========== ÉTAPE 2: DOWNLOAD depuis le backend ==========
      final String lastSyncKey = 'expense_last_sync';
      Map<String, String> queryParams = {};

      if (!forceFullSync && _syncStatusBox.containsKey(lastSyncKey)) {
        final lastSyncDate = _syncStatusBox.get(lastSyncKey)!;
        queryParams['dateFrom'] = lastSyncDate;
      }

      final apiResponse = await _expenseApiService.getExpenses(
        dateFrom:
            queryParams.containsKey('dateFrom')
                ? queryParams['dateFrom']
                : null,
      );

      if (apiResponse.success && apiResponse.data != null) {
        debugPrint('✅ ${apiResponse.data!.length} dépenses reçues de l\'API');
        for (var apiExpense in apiResponse.data!) {
          // Préserver les dépenses locales en attente de sync
          final localExpense = expenseBox.get(apiExpense.id);
          if (localExpense != null &&
              (localExpense.syncStatus == 'pending' ||
                  localExpense.syncStatus == 'pending_update')) {
            debugPrint(
              '⏳ Dépense ${apiExpense.id} ignorée (sync pending local)',
            );
            continue;
          }
          // Fusionner avec syncStatus synced
          await expenseBox.put(
            apiExpense.id,
            apiExpense.copyWith(syncStatus: 'synced'),
          );
        }
        // ====== NETTOYAGE données obsolètes (full sync) ======
        if (forceFullSync) {
          final stale = await _removeStaleEntries(
            box: expenseBox,
            backendIds: apiResponse.data!.map((e) => e.id).toSet(),
            isPending:
                (e) =>
                    e.syncStatus == 'pending' ||
                    e.syncStatus == 'pending_update',
          );
          if (stale > 0) debugPrint('🗑️ $stale dépenses obsolètes supprimées');
        }

        await _syncStatusBox.put(lastSyncKey, DateTime.now().toIso8601String());
        debugPrint('✅ Dépenses synchronisées avec succès');
      } else {
        debugPrint('Failed to sync expenses: ${apiResponse.message}');
      }
    } catch (e) {
      if (e is ApiException) {
        debugPrint('ApiException during expense sync: ${e.message}');
      } else {
        debugPrint('Erreur lors de la synchronisation des dépenses: $e');
      }
    }
  }

  /// Synchronise les fournisseurs
  /// ÉTAPE 1: Upload des pending vers le backend
  /// ÉTAPE 2: Download des données du backend
  Future<void> _syncSuppliers({bool forceFullSync = false}) async {
    if (_supplierApiService == null) return;

    debugPrint('Synchronisation des fournisseurs...');
    try {
      final supplierBox = await Hive.openBox<Supplier>('suppliersBox');

      // ========== ÉTAPE 1: UPLOAD des fournisseurs pending ==========
      final pendingSuppliers =
          supplierBox.values
              .where(
                (s) =>
                    s.syncStatus == 'pending' ||
                    s.syncStatus == 'pending_update',
              )
              .toList();

      if (pendingSuppliers.isNotEmpty) {
        debugPrint(
          '📤 ${pendingSuppliers.length} fournisseurs en attente d\'upload',
        );

        for (var supplier in pendingSuppliers) {
          try {
            if (supplier.syncStatus == 'pending') {
              // Nouveau fournisseur à créer
              final response = await _supplierApiService.createSupplier(
                supplier,
              );
              if (response.success && response.data != null) {
                final syncedSupplier = response.data!.copyWith(
                  syncStatus: 'synced',
                );
                // Remplacer avec l'ID serveur
                await supplierBox.delete(supplier.id);
                await supplierBox.put(syncedSupplier.id, syncedSupplier);
                debugPrint(
                  '✅ Fournisseur uploadé: ${supplier.name} (ID: ${syncedSupplier.id})',
                );
              }
            } else if (supplier.syncStatus == 'pending_update') {
              // Fournisseur existant à mettre à jour
              final response = await _supplierApiService.updateSupplier(
                supplier.id,
                supplier,
              );
              if (response.success && response.data != null) {
                final syncedSupplier = response.data!.copyWith(
                  syncStatus: 'synced',
                );
                await supplierBox.put(supplier.id, syncedSupplier);
                debugPrint('✅ Fournisseur mis à jour: ${supplier.name}');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Échec upload fournisseur ${supplier.name}: $e');
            // Continue avec le suivant
          }
        }
      }

      // ========== ÉTAPE 2: DOWNLOAD depuis le backend ==========
      final String lastSyncKey = 'supplier_last_sync';
      Map<String, String> queryParams = {};

      if (!forceFullSync && _syncStatusBox.containsKey(lastSyncKey)) {
        final lastSyncDate = _syncStatusBox.get(lastSyncKey)!;
        queryParams['updated_after'] = lastSyncDate;
      }

      String? searchQuery;
      if (queryParams.containsKey('updated_after')) {
        searchQuery = "updated_after:${queryParams['updated_after']!}";
      }
      final apiResponse = await _supplierApiService.getSuppliers(
        searchQuery: searchQuery,
      );

      if (apiResponse.success && apiResponse.data != null) {
        debugPrint(
          '✅ ${apiResponse.data!.length} fournisseurs reçus de l\'API',
        );
        for (var apiSupplier in apiResponse.data!) {
          // Préserver les fournisseurs locaux en attente de sync
          final localSupplier = supplierBox.get(apiSupplier.id);
          if (localSupplier != null && localSupplier.syncStatus == 'pending') {
            debugPrint(
              '⏳ Fournisseur ${apiSupplier.id} ignoré (sync pending local)',
            );
            continue;
          }
          // Fusionner avec syncStatus synced
          await supplierBox.put(
            apiSupplier.id,
            apiSupplier.copyWith(syncStatus: 'synced'),
          );
        }
        // ====== NETTOYAGE données obsolètes (full sync) ======
        if (forceFullSync) {
          final stale = await _removeStaleEntries(
            box: supplierBox,
            backendIds: apiResponse.data!.map((s) => s.id).toSet(),
            isPending:
                (s) =>
                    s.syncStatus == 'pending' ||
                    s.syncStatus == 'pending_update',
          );
          if (stale > 0) {
            debugPrint('🗑️ $stale fournisseurs obsolètes supprimés');
          }
        }

        await _syncStatusBox.put(lastSyncKey, DateTime.now().toIso8601String());
        debugPrint('✅ Fournisseurs synchronisés avec succès');
      } else {
        debugPrint('Failed to sync suppliers: ${apiResponse.message}');
      }
    } catch (e) {
      if (e is ApiException) {
        debugPrint('ApiException during supplier sync: ${e.message}');
      } else {
        debugPrint('Erreur lors de la synchronisation des fournisseurs: $e');
      }
    }
  }

  /// Synchronise les transactions financières
  Future<void> _syncFinancialTransactions({bool forceFullSync = false}) async {
    if (_financialTransactionApiService == null) return;

    debugPrint('Synchronisation des transactions financières...');
    try {
      final transactionBox = await Hive.openBox<FinancialTransaction>(
        'financialTransactionsBox',
      );
      final String lastSyncKey = 'financial_transaction_last_sync';
      Map<String, String> queryParams = {};

      if (!forceFullSync && _syncStatusBox.containsKey(lastSyncKey)) {
        final lastSyncDate = _syncStatusBox.get(lastSyncKey)!;
        queryParams['dateFrom'] = lastSyncDate;
      }

      final apiResponse = await _financialTransactionApiService
          .getFinancialTransactions(
            dateFrom:
                queryParams.containsKey('dateFrom')
                    ? queryParams['dateFrom']
                    : null,
          );

      if (apiResponse.success && apiResponse.data != null) {
        for (var transaction in apiResponse.data!) {
          await transactionBox.put(transaction.id, transaction);
        }

        // ====== NETTOYAGE données obsolètes (full sync) ======
        if (forceFullSync) {
          final stale = await _removeStaleEntries(
            box: transactionBox,
            backendIds: apiResponse.data!.map((t) => t.id).toSet(),
          );
          if (stale > 0) {
            debugPrint('🗑️ $stale transactions obsolètes supprimées');
          }
        }

        await _syncStatusBox.put(lastSyncKey, DateTime.now().toIso8601String());
        debugPrint(
          '${apiResponse.data!.length} transactions financières synchronisées avec succès',
        );
      } else {
        debugPrint(
          'Failed to sync financial transactions: ${apiResponse.message}',
        );
      }
    } catch (e) {
      if (e is ApiException) {
        debugPrint(
          'ApiException during financial transaction sync: ${e.message}',
        );
      } else {
        debugPrint(
          'Erreur lors de la synchronisation des transactions financières: $e',
        );
      }
    }
  }

  /// Synchronise les comptes financiers
  Future<void> _syncFinancialAccounts({bool forceFullSync = false}) async {
    if (_financialAccountApiService == null) return;

    debugPrint('Synchronisation des comptes financiers...');
    try {
      final accountBox = await Hive.openBox<FinancialAccount>(
        'financialAccountsBox',
      );
      final String lastSyncKey = 'financial_account_last_sync';

      // Pour la pagination et les filtres de date
      final apiResponse =
          await _financialAccountApiService.getFinancialAccounts();

      if (apiResponse.success && apiResponse.data != null) {
        for (var account in apiResponse.data!) {
          await accountBox.put(account.id, account);
        }

        // ====== NETTOYAGE données obsolètes (full sync) ======
        if (forceFullSync) {
          final stale = await _removeStaleEntries(
            box: accountBox,
            backendIds: apiResponse.data!.map((a) => a.id).toSet(),
          );
          if (stale > 0) {
            debugPrint('🗑️ $stale comptes financiers obsolètes supprimés');
          }
        }

        await _syncStatusBox.put(lastSyncKey, DateTime.now().toIso8601String());
        debugPrint(
          '${apiResponse.data!.length} comptes financiers synchronisés avec succès',
        );
      } else {
        debugPrint('Failed to sync financial accounts: ${apiResponse.message}');
      }
    } catch (e) {
      if (e is ApiException) {
        debugPrint('ApiException during financial account sync: ${e.message}');
      } else {
        debugPrint(
          'Erreur lors de la synchronisation des comptes financiers: $e',
        );
      }
    }
  }

  /// Synchronise le journal des opérations (lecture seule depuis le backend)
  /// NOTE: Le journal est GÉNÉRÉ côté serveur à partir des entités synchronisées
  /// (ventes, dépenses, etc.). Cette méthode récupère simplement le journal
  /// du backend pour mettre à jour le cache local.
  Future<void> _syncOperationJournal() async {
    final repo = _operationJournalRepository;
    if (repo == null) return;

    debugPrint(
      '📒 Récupération du journal des opérations depuis le backend...',
    );
    try {
      // Récupérer le journal du backend (pas de POST, uniquement GET)
      final success = await repo.pullJournalFromBackend();

      if (success) {
        debugPrint('✅ Journal des opérations mis à jour depuis le backend');
        await _syncStatusBox.put(
          'operation_journal_last_sync',
          DateTime.now().toIso8601String(),
        );
      } else {
        debugPrint('⚠️ Impossible de récupérer le journal du backend');
      }
    } catch (e) {
      if (e is ApiException) {
        debugPrint('ApiException during operation journal sync: ${e.message}');
      } else {
        debugPrint(
          '❌ Erreur lors de la récupération du journal des opérations: $e',
        );
      }
    }
  }

  /// Rejoue la file générique des opérations en attente (POST/PUT/DELETE
  /// enfilées par `_databaseService`). Idempotent : chaque opération réussie
  /// est marquée synchronisée, les 404/409 sont retirés, les erreurs
  /// transitoires restent en file pour un prochain passage.
  /// Retourne `false` si la connexion a été perdue en cours de route
  /// (l'appelant doit alors signaler l'échec).
  Future<bool> _drainPendingOperations() async {
    final pendingOperations = await _databaseService.getPendingOperations();
    debugPrint(
      '${pendingOperations.length} opérations en attente de synchronisation',
    );

    for (final operation in pendingOperations) {
      if (!_connectivityService.isConnected) {
        debugPrint('Synchronisation interrompue : connexion perdue');
        return false;
      }

      final id = operation['id'] as String;
      try {
        final endpoint = operation['endpoint'] as String;
        final method = operation['method'] as String;
        final body = operation['body'] as Map<String, dynamic>?;

        // Exécuter l'opération sur l'API
        await _executeApiOperation(method, endpoint, body);

        // Marquer l'opération comme synchronisée
        await _databaseService.markOperationAsSynchronized(id);

        debugPrint('Opération $id synchronisée avec succès');
      } catch (e) {
        final msg = e.toString();
        // Ressource supprimée côté serveur → retirer de la file
        if (msg.contains("n'existe pas") ||
            msg.contains('404') ||
            msg.contains('Not Found')) {
          debugPrint('⚠️ Op $id: ressource supprimée, retrait de la file');
          await _databaseService.markOperationAsSynchronized(id);
        }
        // Conflit → version serveur prioritaire
        else if (msg.contains('409') || msg.contains('Conflict')) {
          debugPrint('⚠️ Op $id: conflit, retrait de la file');
          await _databaseService.markOperationAsSynchronized(id);
        }
        // Session expirée → arrêter la sync
        else if (msg.contains('Session expirée') || msg.contains('401')) {
          debugPrint('🔒 Session expirée, arrêt sync');
          break;
        }
        // Erreur transitoire → garder pour retry
        else {
          debugPrint('⏳ Op $id: échec transitoire (retry): $e');
        }
      }
    }

    // Nettoyer les opérations synchronisées anciennes
    await _databaseService.cleanupSynchronizedOperations();
    return true;
  }

  /// Exécute une opération API selon la méthode
  Future<void> _executeApiOperation(
    String method,
    String endpoint,
    Map<String, dynamic>? body,
  ) async {
    switch (method) {
      case 'GET':
        await _apiService.get(endpoint);
        break;
      case 'POST':
        await _apiService.post(endpoint, body: body);
        break;
      case 'PUT':
        await _apiService.put(endpoint, body: body);
        break;
      case 'DELETE':
        await _apiService.delete(endpoint);
        break;
      default:
        throw Exception('Méthode non supportée: $method');
    }
  }

  /// Force une synchronisation immédiate (incrémentale ou full selon le timing)
  Future<bool> forceSyncNow() async {
    if (_isSyncing) return false;

    return await syncData();
  }

  /// Force une synchronisation complète de toutes les données
  /// Utiliser cette méthode depuis l'UI pour permettre à l'utilisateur
  /// de forcer un re-sync complet manuellement
  Future<bool> forceFullSyncNow() async {
    if (_isSyncing) {
      debugPrint('⚠️ Sync déjà en cours, impossible de forcer full sync');
      return false;
    }

    debugPrint('🔄 Full sync forcé par l\'utilisateur');
    _isSyncing = true;
    _lastSyncAttempt = DateTime.now();
    _syncStatusController.add(SyncStatus.syncing);

    try {
      // Appeler directement les méthodes internes sans passer par syncAll
      // pour éviter les conflits de flags _isSyncing
      await _syncProducts(forceFullSync: true);
      await _syncCustomers(forceFullSync: true);
      await _syncSales(forceFullSync: true);

      if (_expenseApiService != null) {
        await _syncExpenses(forceFullSync: true);
      }
      if (_supplierApiService != null) {
        await _syncSuppliers(forceFullSync: true);
      }
      if (_financialTransactionApiService != null) {
        await _syncFinancialTransactions(forceFullSync: true);
      }
      if (_financialAccountApiService != null) {
        await _syncFinancialAccounts(forceFullSync: true);
      }
      if (_operationJournalRepository != null) {
        await _syncOperationJournal();
      }

      // BUG #7 : le full sync manuel doit AUSSI rejouer la file générique des
      // opérations en attente (que `syncData` draine), sinon le bouton Sync
      // laisse des POST/PUT/DELETE hors ligne non envoyés. Idempotent.
      await _drainPendingOperations();

      await _updateLastFullSyncDate();

      _isSyncing = false;
      _syncStatusController.add(SyncStatus.completed);
      debugPrint('✅ Full sync forcé terminé avec succès');

      if (onSyncCompleted != null) {
        onSyncCompleted!();
      }

      return true;
    } catch (e) {
      debugPrint('❌ Erreur lors du full sync forcé: $e');
      _isSyncing = false;
      _syncStatusController.add(SyncStatus.failed);
      return false;
    }
  }

  /// Retourne la date du dernier full sync ou null si jamais fait
  DateTime? getLastFullSyncDate() {
    if (!_syncStatusBox.containsKey(_lastFullSyncKey)) {
      return null;
    }
    try {
      return DateTime.parse(_syncStatusBox.get(_lastFullSyncKey)!);
    } catch (e) {
      return null;
    }
  }

  /// Vérifie si un full sync est requis (>24h depuis le dernier)
  bool isFullSyncRequired() {
    return _shouldForceFullSync();
  }

  /// Synchronise toutes les données (méthode bas niveau)
  /// Préférer syncData() pour le sync automatique ou forceFullSyncNow() pour le sync manuel
  /// Cette méthode gère son propre flag _isSyncing
  Future<void> syncAll({bool forceFullSync = false}) async {
    if (_isSyncing) {
      return;
    }
    _isSyncing = true;

    try {
      // Synchroniser les données en passant forceFullSync à chaque méthode
      await _syncProducts(forceFullSync: forceFullSync);
      await _syncCustomers(forceFullSync: forceFullSync);
      await _syncSales(forceFullSync: forceFullSync);

      // Synchroniser les entités additionnelles si les services sont disponibles
      if (_expenseApiService != null) {
        await _syncExpenses(forceFullSync: forceFullSync);
      }

      if (_supplierApiService != null) {
        await _syncSuppliers(forceFullSync: forceFullSync);
      }

      if (_financialTransactionApiService != null) {
        await _syncFinancialTransactions(forceFullSync: forceFullSync);
      }

      if (_financialAccountApiService != null) {
        await _syncFinancialAccounts(forceFullSync: forceFullSync);
      }

      // AJOUTÉ: Synchroniser le journal des opérations
      if (_operationJournalRepository != null) {
        await _syncOperationJournal();
      }
    } catch (e) {
      debugPrint('Erreur lors de la synchronisation: $e');
      // Consider re-throwing or handling more gracefully
    } finally {
      _isSyncing = false;
    }
  }

  // Les méthodes de synchronisation ont été unifiées et déplacées en haut

  /// Arrête le service de synchronisation
  void dispose() {
    _syncTimer?.cancel();
    _syncStatusController.close();
  }
}
