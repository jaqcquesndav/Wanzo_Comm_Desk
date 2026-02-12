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

  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();

  /// Stream qui émet l'état de la synchronisation
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

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
  Future<bool> syncData({
    SyncEntityType entityType = SyncEntityType.all,
  }) async {
    if (_isSyncing) return false;

    _isSyncing = true;
    _lastSyncAttempt = DateTime.now();
    _syncStatusController.add(SyncStatus.syncing);
    debugPrint('Démarrage de la synchronisation des données...');

    try {
      // Si on synchronise toutes les entités ou des entités spécifiques
      if (entityType == SyncEntityType.all ||
          entityType == SyncEntityType.products) {
        await _syncProducts();
      }

      if (entityType == SyncEntityType.all ||
          entityType == SyncEntityType.customers) {
        await _syncCustomers();
      }

      if (entityType == SyncEntityType.all ||
          entityType == SyncEntityType.sales) {
        await _syncSales();
      }

      // Synchronisation des entités additionnelles si les services sont disponibles
      if ((entityType == SyncEntityType.all ||
              entityType == SyncEntityType.expenses) &&
          _expenseApiService != null) {
        await _syncExpenses();
      }

      if ((entityType == SyncEntityType.all ||
              entityType == SyncEntityType.suppliers) &&
          _supplierApiService != null) {
        await _syncSuppliers();
      }

      if ((entityType == SyncEntityType.all ||
              entityType == SyncEntityType.financialTransactions) &&
          _financialTransactionApiService != null) {
        await _syncFinancialTransactions();
      }

      if ((entityType == SyncEntityType.all ||
              entityType == SyncEntityType.financialAccounts) &&
          _financialAccountApiService != null) {
        await _syncFinancialAccounts();
      }

      // AJOUTÉ: Synchronisation du journal des opérations
      if ((entityType == SyncEntityType.all ||
              entityType == SyncEntityType.operationJournal) &&
          _operationJournalRepository != null) {
        await _syncOperationJournal();
      }

      // Récupérer toutes les opérations en attente (génériques)
      final pendingOperations = await _databaseService.getPendingOperations();
      debugPrint(
        '${pendingOperations.length} opérations en attente de synchronisation',
      );

      // Synchroniser chaque opération générique
      for (final operation in pendingOperations) {
        if (!_connectivityService.isConnected) {
          debugPrint('Synchronisation interrompue : connexion perdue');
          _isSyncing = false;
          _syncStatusController.add(SyncStatus.failed);
          return false;
        }

        try {
          final endpoint = operation['endpoint'] as String;
          final method = operation['method'] as String;
          final body = operation['body'] as Map<String, dynamic>?;
          final id = operation['id'] as String;

          // Exécuter l'opération sur l'API
          await _executeApiOperation(method, endpoint, body);

          // Marquer l'opération comme synchronisée
          await _databaseService.markOperationAsSynchronized(id);

          debugPrint('Opération $id synchronisée avec succès');
        } catch (e) {
          debugPrint('Erreur lors de la synchronisation d\'une opération: $e');
          // Continuer avec la prochaine opération, celle-ci sera retentée plus tard
        }
      }

      // Nettoyer les opérations synchronisées anciennes
      await _databaseService.cleanupSynchronizedOperations();

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

  /// Synchronise les produits
  Future<void> _syncProducts({bool forceFullSync = false}) async {
    debugPrint('Synchronisation des produits...');
    try {
      // IMPORTANT: Utiliser le même nom de box que InventoryRepository ('products')
      if (!Hive.isBoxOpen('products')) {
        debugPrint('⚠️ productsBox non ouverte, tentative d\'ouverture...');
        await Hive.openBox<Product>('products');
      }
      final productBox = Hive.box<Product>('products');
      debugPrint(
        '✅ productsBox ouverte avec ${productBox.length} produits existants',
      );

      // ═══════════════════════════════════════════════════════════════════
      // ÉTAPE 1: UPLOAD - Envoyer les produits locaux en attente au backend
      // ═══════════════════════════════════════════════════════════════════
      final pendingProducts =
          productBox.values.where((p) => p.syncStatus == 'pending').toList();

      if (pendingProducts.isNotEmpty) {
        debugPrint(
          '📤 ${pendingProducts.length} produits en attente de synchronisation vers le backend',
        );

        for (var pendingProduct in pendingProducts) {
          try {
            final apiResponse = await _productApiService
                .createProduct(pendingProduct)
                .timeout(const Duration(seconds: 10));

            if (apiResponse.success && apiResponse.data != null) {
              final serverProduct = apiResponse.data!;
              // Mettre à jour avec l'ID serveur et marquer comme synchronisé
              final syncedProduct = serverProduct.copyWith(
                stockQuantity:
                    pendingProduct.stockQuantity, // Préserver stock local
                syncStatus: 'synced',
              );

              // Si l'ID a changé, supprimer l'ancien et ajouter le nouveau
              if (pendingProduct.id != serverProduct.id) {
                await productBox.delete(pendingProduct.id);
              }
              await productBox.put(serverProduct.id, syncedProduct);

              debugPrint(
                '✅ Produit uploadé: ${pendingProduct.name} → ID serveur: ${serverProduct.id}',
              );
            } else {
              debugPrint(
                '⚠️ Échec upload produit ${pendingProduct.name}: ${apiResponse.message}',
              );
            }
          } catch (e) {
            debugPrint('❌ Erreur upload produit ${pendingProduct.name}: $e');
            // Continuer avec le produit suivant
          }
        }
      }

      // ═══════════════════════════════════════════════════════════════════
      // ÉTAPE 2: DOWNLOAD - Récupérer les produits du backend
      // ═══════════════════════════════════════════════════════════════════
      debugPrint('🔄 Appel API getProducts (sync complet)...');
      final apiResponse = await _productApiService.getProducts();

      if (apiResponse.success && apiResponse.data != null) {
        debugPrint('✅ ${apiResponse.data!.length} produits reçus de l\'API');

        // Créer un ensemble d'IDs des produits reçus de l'API
        final apiProductIds = apiResponse.data!.map((p) => p.id).toSet();

        for (var apiProduct in apiResponse.data!) {
          // Vérifier si le produit existe localement
          final localProduct = productBox.get(apiProduct.id);

          if (localProduct != null) {
            // Le produit existe localement - préserver le stock local si différent
            // car le stock local peut avoir été modifié par des ventes/achats
            final mergedProduct = apiProduct.copyWith(
              stockQuantity:
                  localProduct.stockQuantity, // Préserver le stock local
              syncStatus: 'synced',
            );
            await productBox.put(apiProduct.id, mergedProduct);
            debugPrint(
              '🔄 Produit ${apiProduct.name}: stock local préservé (${localProduct.stockQuantity})',
            );
          } else {
            // Nouveau produit de l'API - utiliser le stock de l'API
            final syncedProduct = apiProduct.copyWith(syncStatus: 'synced');
            await productBox.put(apiProduct.id, syncedProduct);
            debugPrint(
              '➕ Nouveau produit de l\'API: ${apiProduct.name} (stock: ${apiProduct.stockQuantity})',
            );
          }
        }

        // Gérer les produits locaux en attente qui n'existent pas encore sur le serveur
        for (var pendingProduct in pendingProducts) {
          if (!apiProductIds.contains(pendingProduct.id)) {
            // Le produit n'existe pas sur le serveur - le conserver en local
            debugPrint(
              '📦 Produit local conservé (pending): ${pendingProduct.name}',
            );
          }
        }

        debugPrint(
          '✅ Produits synchronisés avec succès (${productBox.length} total en local)',
        );
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
  Future<void> _syncCustomers({bool forceFullSync = false}) async {
    debugPrint('Synchronisation des clients...');
    try {
      // IMPORTANT: Utiliser le même nom de box que CustomerRepository ('customers')
      final customerBox = Hive.box<Customer>('customers');
      // Note: L'API backend ne supporte pas le paramètre updated_after
      // Nous faisons donc une synchronisation complète à chaque fois
      debugPrint('🔄 Appel API getCustomers (sync complet)...');
      final apiResponse = await _customerApiService.getCustomers();
      if (apiResponse.success && apiResponse.data != null) {
        for (var customer in apiResponse.data!) {
          await customerBox.put(customer.id, customer);
        }
        debugPrint(
          '✅ ${apiResponse.data!.length} clients synchronisés avec succès',
        );
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
  Future<void> _syncSales({bool forceFullSync = false}) async {
    debugPrint('Synchronisation des ventes...');
    try {
      // IMPORTANT: Utiliser le même nom de box que SalesRepository ('sales')
      // Vérifier si la box est ouverte, sinon l'ouvrir
      if (!Hive.isBoxOpen('sales')) {
        debugPrint('⚠️ Box "sales" non ouverte, tentative d\'ouverture...');
        await Hive.openBox<Sale>('sales');
      }
      final saleBox = Hive.box<Sale>('sales');
      debugPrint('📦 Box "sales" contient ${saleBox.length} ventes AVANT sync');

      // ═══════════════════════════════════════════════════════════════════
      // ÉTAPE 1: UPLOAD - Envoyer les ventes locales en attente au backend
      // ═══════════════════════════════════════════════════════════════════
      final pendingSales =
          saleBox.values.where((s) => s.syncStatus == 'pending').toList();

      if (pendingSales.isNotEmpty) {
        debugPrint(
          '📤 ${pendingSales.length} ventes en attente de synchronisation vers le backend',
        );

        for (var pendingSale in pendingSales) {
          try {
            final apiResponse = await _saleApiService
                .createSale(pendingSale)
                .timeout(const Duration(seconds: 10));

            if (apiResponse.success && apiResponse.data != null) {
              final serverSale = apiResponse.data!;
              // Mettre à jour avec l'ID serveur et marquer comme synchronisé
              final syncedSale = serverSale.copyWith(syncStatus: 'synced');

              // Si l'ID a changé, supprimer l'ancien et ajouter le nouveau
              if (pendingSale.id != serverSale.id) {
                await saleBox.delete(pendingSale.id);
              }
              await saleBox.put(serverSale.id, syncedSale);

              debugPrint(
                '✅ Vente uploadée: ${pendingSale.id} → ID serveur: ${serverSale.id}',
              );
            } else {
              debugPrint(
                '⚠️ Échec upload vente ${pendingSale.id}: ${apiResponse.message}',
              );
            }
          } catch (e) {
            debugPrint('❌ Erreur upload vente ${pendingSale.id}: $e');
            // Continuer avec la vente suivante
          }
        }
      }

      // ═══════════════════════════════════════════════════════════════════
      // ÉTAPE 2: DOWNLOAD - Récupérer les ventes du backend
      // ═══════════════════════════════════════════════════════════════════
      debugPrint('🔄 Appel API getSales (sync complet)...');
      final apiResponse = await _saleApiService.getSales();
      if (apiResponse.success && apiResponse.data != null) {
        debugPrint('📥 Reçu ${apiResponse.data!.length} ventes de l\'API');
        for (var sale in apiResponse.data!) {
          await saleBox.put(sale.id, sale);
        }
        debugPrint(
          '📦 Box "sales" contient maintenant ${saleBox.length} ventes APRÈS sync',
        );

        // Log quelques IDs et dates pour débug
        final sampleSales = saleBox.values.take(3).toList();
        for (var s in sampleSales) {
          debugPrint(
            '📋 Vente stockée: id=${s.id}, date=${s.date}, montant=${s.totalAmountInCdf}',
          );
        }

        debugPrint(
          '✅ ${apiResponse.data!.length} ventes synchronisées avec succès',
        );
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
  Future<void> _syncExpenses({bool forceFullSync = false}) async {
    if (_expenseApiService == null) {
      debugPrint('⚠️ ExpenseApiService non disponible - skip sync dépenses');
      return;
    }

    debugPrint('Synchronisation des dépenses...');
    try {
      // IMPORTANT: Utiliser le même nom de box que ExpenseRepository ('expenses')
      if (!Hive.isBoxOpen('expenses')) {
        debugPrint('⚠️ Box "expenses" non ouverte, tentative d\'ouverture...');
        await Hive.openBox<Expense>('expenses');
      }
      final expenseBox = Hive.box<Expense>('expenses');
      debugPrint(
        '📦 Box "expenses" contient ${expenseBox.length} dépenses AVANT sync',
      );

      // ═══════════════════════════════════════════════════════════════════
      // ÉTAPE 1: UPLOAD - Envoyer les dépenses locales en attente au backend
      // ═══════════════════════════════════════════════════════════════════
      final pendingExpenses =
          expenseBox.values.where((e) => e.syncStatus == 'pending').toList();

      if (pendingExpenses.isNotEmpty) {
        debugPrint(
          '📤 ${pendingExpenses.length} dépenses en attente de synchronisation vers le backend',
        );

        for (var pendingExpense in pendingExpenses) {
          try {
            // Convertir les chemins locaux en fichiers pour l'upload Cloudinary
            List<File>? attachmentFiles;
            if (pendingExpense.localAttachmentPaths != null &&
                pendingExpense.localAttachmentPaths!.isNotEmpty) {
              attachmentFiles = [];
              for (final path in pendingExpense.localAttachmentPaths!) {
                final file = File(path);
                if (await file.exists()) {
                  attachmentFiles.add(file);
                }
              }
              if (attachmentFiles.isEmpty) attachmentFiles = null;
            }

            // Passer les fichiers au service qui fera l'upload vers Cloudinary
            final apiResponse = await _expenseApiService
                .createExpense(
                  pendingExpense.date,
                  pendingExpense.amount,
                  pendingExpense.motif,
                  pendingExpense.category.name,
                  pendingExpense.paymentMethod,
                  pendingExpense.supplierId,
                  attachments:
                      attachmentFiles, // Les fichiers seront uploadés vers Cloudinary
                  paidAmount: pendingExpense.paidAmount,
                  paymentStatus: pendingExpense.paymentStatus?.name,
                  supplierName: pendingExpense.supplierName,
                  currencyCode: pendingExpense.currencyCode,
                  exchangeRate: pendingExpense.exchangeRate,
                )
                .timeout(
                  const Duration(seconds: 30),
                ); // Timeout plus long pour upload

            if (apiResponse.success && apiResponse.data != null) {
              final serverExpense = apiResponse.data!;
              // Mettre à jour avec l'ID serveur et marquer comme synchronisé
              final syncedExpense = serverExpense.copyWith(
                syncStatus: 'synced',
              );

              // Supprimer l'ancien enregistrement local et ajouter le nouveau
              final oldKey = pendingExpense.localId ?? pendingExpense.id;
              if (oldKey != serverExpense.id) {
                await expenseBox.delete(oldKey);
              }
              await expenseBox.put(serverExpense.id, syncedExpense);

              debugPrint(
                '✅ Dépense uploadée: ${pendingExpense.motif} → ID serveur: ${serverExpense.id}',
              );
            } else {
              debugPrint(
                '⚠️ Échec upload dépense ${pendingExpense.motif}: ${apiResponse.message}',
              );
            }
          } catch (e) {
            debugPrint('❌ Erreur upload dépense ${pendingExpense.motif}: $e');
            // Continuer avec la dépense suivante
          }
        }
      }

      // ═══════════════════════════════════════════════════════════════════
      // ÉTAPE 2: DOWNLOAD - Récupérer les dépenses du backend
      // ═══════════════════════════════════════════════════════════════════
      final String lastSyncKey = 'expense_last_sync';
      Map<String, String> queryParams = {};

      if (!forceFullSync && _syncStatusBox.containsKey(lastSyncKey)) {
        final lastSyncDate = _syncStatusBox.get(lastSyncKey)!;
        queryParams['dateFrom'] = lastSyncDate;
      }

      debugPrint('🔄 Appel API getExpenses...');
      final apiResponse = await _expenseApiService.getExpenses(
        dateFrom:
            queryParams.containsKey('dateFrom')
                ? queryParams['dateFrom']
                : null,
      );

      if (apiResponse.success && apiResponse.data != null) {
        debugPrint('📥 Reçu ${apiResponse.data!.length} dépenses de l\'API');
        for (var expense in apiResponse.data!) {
          await expenseBox.put(expense.id, expense);
        }
        await _syncStatusBox.put(lastSyncKey, DateTime.now().toIso8601String());
        debugPrint(
          '📦 Box "expenses" contient maintenant ${expenseBox.length} dépenses APRÈS sync',
        );
        debugPrint(
          '✅ ${apiResponse.data!.length} dépenses synchronisées avec succès',
        );
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
  Future<void> _syncSuppliers({bool forceFullSync = false}) async {
    if (_supplierApiService == null) return;

    debugPrint('Synchronisation des fournisseurs...');
    try {
      final supplierBox = await Hive.openBox<Supplier>('suppliersBox');
      // Note: L'API backend ne supporte pas le paramètre updated_after
      // Nous faisons donc une synchronisation complète à chaque fois
      debugPrint('🔄 Appel API getSuppliers (sync complet)...');
      final apiResponse = await _supplierApiService.getSuppliers();

      if (apiResponse.success && apiResponse.data != null) {
        for (var supplier in apiResponse.data!) {
          await supplierBox.put(supplier.id, supplier);
        }
        debugPrint(
          '✅ ${apiResponse.data!.length} fournisseurs synchronisés avec succès',
        );
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
      final success = await repo.syncLocalOperationsToBackend();

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

  /// Force une synchronisation immédiate
  Future<bool> forceSyncNow() async {
    if (_isSyncing) return false;

    return await syncData();
  }

  /// Synchronise toutes les données
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
