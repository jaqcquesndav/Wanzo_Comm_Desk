import 'package:flutter/foundation.dart';

import 'package:wanzo/features/sales/repositories/sales_repository.dart';
import 'package:wanzo/features/expenses/repositories/expense_repository.dart';
import 'package:wanzo/features/inventory/repositories/inventory_repository.dart';
import 'package:wanzo/features/customer/repositories/customer_repository.dart';
import 'package:wanzo/features/supplier/repositories/supplier_repository.dart';
import 'package:wanzo/features/transactions/repositories/transaction_repository.dart';
import 'package:wanzo/features/dashboard/repositories/operation_journal_repository.dart';

/// Service centralisé pour gérer les caches locaux de l'application.
///
/// Ce service coordonne le nettoyage de tous les caches Hive lors du
/// changement de business unit pour éviter l'affichage de données obsolètes.
class CacheManagementService {
  static CacheManagementService? _instance;

  SalesRepository? _salesRepository;
  ExpenseRepository? _expenseRepository;
  InventoryRepository? _inventoryRepository;
  CustomerRepository? _customerRepository;
  SupplierRepository? _supplierRepository;
  TransactionRepository? _transactionRepository;
  OperationJournalRepository? _operationJournalRepository;

  bool _isInitialized = false;

  CacheManagementService._();

  /// Singleton instance du service
  static CacheManagementService get instance {
    _instance ??= CacheManagementService._();
    return _instance!;
  }

  /// Initialise le service avec les repositories
  void initialize({
    required SalesRepository salesRepository,
    required ExpenseRepository expenseRepository,
    required InventoryRepository inventoryRepository,
    required CustomerRepository customerRepository,
    required SupplierRepository supplierRepository,
    required TransactionRepository transactionRepository,
    required OperationJournalRepository operationJournalRepository,
  }) {
    _salesRepository = salesRepository;
    _expenseRepository = expenseRepository;
    _inventoryRepository = inventoryRepository;
    _customerRepository = customerRepository;
    _supplierRepository = supplierRepository;
    _transactionRepository = transactionRepository;
    _operationJournalRepository = operationJournalRepository;
    _isInitialized = true;

    debugPrint(
      'CacheManagementService initialisé avec $_repositoryCount repositories',
    );
  }

  int get _repositoryCount {
    int count = 0;
    if (_salesRepository != null) count++;
    if (_expenseRepository != null) count++;
    if (_inventoryRepository != null) count++;
    if (_customerRepository != null) count++;
    if (_supplierRepository != null) count++;
    if (_transactionRepository != null) count++;
    if (_operationJournalRepository != null) count++;
    return count;
  }

  /// Vérifie si le service est initialisé
  bool get isInitialized => _isInitialized;

  /// Vide tous les caches locaux liés aux données de business unit.
  ///
  /// Cette méthode doit être appelée lors du changement de business unit
  /// pour éviter d'afficher les données de l'ancien business unit.
  Future<void> clearAllBusinessUnitData() async {
    if (!_isInitialized) {
      debugPrint(
        '⚠️ CacheManagementService: Tentative de clear sans initialisation',
      );
      return;
    }

    debugPrint('🧹 CacheManagementService: Début du nettoyage des caches...');

    final List<Future<void>> clearOperations = [];

    try {
      // Ventes
      if (_salesRepository != null) {
        clearOperations.add(
          _salesRepository!.clearLocalCache().catchError((e) {
            debugPrint('Erreur lors du clear SalesRepository: $e');
          }),
        );
      }

      // Dépenses
      if (_expenseRepository != null) {
        clearOperations.add(
          _expenseRepository!.clearLocalCache().catchError((e) {
            debugPrint('Erreur lors du clear ExpenseRepository: $e');
          }),
        );
      }

      // Inventaire
      if (_inventoryRepository != null) {
        clearOperations.add(
          _inventoryRepository!.clearLocalCache().catchError((e) {
            debugPrint('Erreur lors du clear InventoryRepository: $e');
          }),
        );
      }

      // Clients
      if (_customerRepository != null) {
        clearOperations.add(
          _customerRepository!.clearLocalCache().catchError((e) {
            debugPrint('Erreur lors du clear CustomerRepository: $e');
          }),
        );
      }

      // Fournisseurs
      if (_supplierRepository != null) {
        clearOperations.add(
          _supplierRepository!.clearLocalCache().catchError((e) {
            debugPrint('Erreur lors du clear SupplierRepository: $e');
          }),
        );
      }

      // Transactions
      if (_transactionRepository != null) {
        clearOperations.add(
          _transactionRepository!.clearLocalCache().catchError((e) {
            debugPrint('Erreur lors du clear TransactionRepository: $e');
          }),
        );
      }

      // Journal des opérations
      if (_operationJournalRepository != null) {
        clearOperations.add(
          _operationJournalRepository!.clearLocalCache().catchError((e) {
            debugPrint('Erreur lors du clear OperationJournalRepository: $e');
          }),
        );
      }

      // Exécuter toutes les opérations de nettoyage en parallèle
      await Future.wait(clearOperations);

      debugPrint('✅ CacheManagementService: Tous les caches ont été vidés');
    } catch (e) {
      debugPrint(
        '❌ CacheManagementService: Erreur critique lors du nettoyage: $e',
      );
      rethrow;
    }
  }

  /// Méthodes individuelles pour nettoyage ciblé
  Future<void> clearSalesCache() async {
    if (_salesRepository != null) {
      await _salesRepository!.clearLocalCache();
    }
  }

  Future<void> clearExpensesCache() async {
    if (_expenseRepository != null) {
      await _expenseRepository!.clearLocalCache();
    }
  }

  Future<void> clearInventoryCache() async {
    if (_inventoryRepository != null) {
      await _inventoryRepository!.clearLocalCache();
    }
  }

  Future<void> clearCustomersCache() async {
    if (_customerRepository != null) {
      await _customerRepository!.clearLocalCache();
    }
  }

  Future<void> clearSuppliersCache() async {
    if (_supplierRepository != null) {
      await _supplierRepository!.clearLocalCache();
    }
  }

  Future<void> clearTransactionsCache() async {
    if (_transactionRepository != null) {
      await _transactionRepository!.clearLocalCache();
    }
  }

  Future<void> clearOperationJournalCache() async {
    if (_operationJournalRepository != null) {
      await _operationJournalRepository!.clearLocalCache();
    }
  }

  /// Réinitialise le service (utile pour les tests)
  @visibleForTesting
  void reset() {
    _salesRepository = null;
    _expenseRepository = null;
    _inventoryRepository = null;
    _customerRepository = null;
    _supplierRepository = null;
    _transactionRepository = null;
    _operationJournalRepository = null;
    _isInitialized = false;
  }
}
