# Guide de mise à jour Desktop - Synchronisation DTOs et Gestion des Caches

Ce document détaille toutes les modifications effectuées sur l'application mobile pour assurer la compatibilité avec le backend et une meilleure gestion des caches lors du changement de business unit.

---

## Table des matières

1. [FinancingType - Mapping API](#1-financingtype---mapping-api)
2. [BusinessUnitType - Uppercase pour API](#2-businessunittype---uppercase-pour-api)
3. [ExpenseApiService - supplierPhoneNumber](#3-expenseapiservice---supplierphonenumber)
4. [Phone Regex - Harmonisation à 6 chiffres minimum](#4-phone-regex---harmonisation-à-6-chiffres-minimum)
5. [ClearLocalCache dans les Repositories](#5-clearlocalcache-dans-les-repositories)
6. [CacheManagementService - Service centralisé](#6-cachemanagementservice---service-centralisé)
7. [UsersBloc - Hook de nettoyage des caches](#7-usersbloc---hook-de-nettoyage-des-caches)
8. [Adha Chat - Persistance des conversations](#8-adha-chat---persistance-des-conversations)

---

## 1. FinancingType - Mapping API

### Problème
Le backend utilise des valeurs différentes pour les types de financement:
- Backend: `workingCapital`, `businessLoan`, `equipmentLoan`
- Frontend: `cashCredit`, `investmentCredit`, `leasing`

### Fichier: `lib/features/financing/models/financing_request.dart`

### AVANT
```dart
enum FinancingType {
  @HiveField(0)
  cashCredit,
  @HiveField(1)
  investmentCredit,
  @HiveField(2)
  leasing,
}
```

### APRÈS
```dart
enum FinancingType {
  @HiveField(0)
  cashCredit,
  @HiveField(1)
  investmentCredit,
  @HiveField(2)
  leasing,
}

/// Extension pour le mapping API des types de financement
/// Le backend utilise des noms différents pour ces types
extension FinancingTypeExtension on FinancingType {
  /// Retourne la valeur à envoyer à l'API backend
  /// Mapping:
  /// - cashCredit -> workingCapital
  /// - investmentCredit -> businessLoan
  /// - leasing -> equipmentLoan
  String get apiValue {
    switch (this) {
      case FinancingType.cashCredit:
        return 'workingCapital';
      case FinancingType.investmentCredit:
        return 'businessLoan';
      case FinancingType.leasing:
        return 'equipmentLoan';
    }
  }

  /// Crée un FinancingType depuis une valeur API
  static FinancingType fromApiValue(String apiValue) {
    switch (apiValue.toLowerCase()) {
      case 'workingcapital':
      case 'working_capital':
        return FinancingType.cashCredit;
      case 'businessloan':
      case 'business_loan':
        return FinancingType.investmentCredit;
      case 'equipmentloan':
      case 'equipment_loan':
        return FinancingType.leasing;
      default:
        // Fallback: essayer de parser directement
        return FinancingType.values.firstWhere(
          (e) => e.name.toLowerCase() == apiValue.toLowerCase(),
          orElse: () => FinancingType.cashCredit,
        );
    }
  }
}
```

### Modification de toJson()
```dart
// AVANT
Map<String, dynamic> toJson() {
  return {
    // ...
    'type': type.name,
    // ...
  };
}

// APRÈS
Map<String, dynamic> toJson() {
  return {
    // ...
    'type': type.apiValue, // Utilise le mapping API
    // ...
  };
}
```

### Modification de _parseFinancingType()
```dart
// AVANT
static FinancingType _parseFinancingType(dynamic value) {
  if (value == null) return FinancingType.cashCredit;
  if (value is FinancingType) return value;
  final stringValue = value.toString().toLowerCase();
  return FinancingType.values.firstWhere(
    (e) => e.name.toLowerCase() == stringValue,
    orElse: () => FinancingType.cashCredit,
  );
}

// APRÈS  
static FinancingType _parseFinancingType(dynamic value) {
  if (value == null) return FinancingType.cashCredit;
  if (value is FinancingType) return value;
  final stringValue = value.toString();
  // Utiliser le mapping API pour parser les valeurs du backend
  return FinancingTypeExtension.fromApiValue(stringValue);
}
```

---

## 2. BusinessUnitType - Uppercase pour API

### Problème
Le backend attend les valeurs en MAJUSCULES: `COMPANY`, `BRANCH`, `POS`

### Fichier: `lib/features/business_unit/models/business_unit_enums.dart`

### AVANT
```dart
extension BusinessUnitTypeExtension on BusinessUnitType {
  String get apiValue {
    switch (this) {
      case BusinessUnitType.company:
        return 'company';
      case BusinessUnitType.branch:
        return 'branch';
      case BusinessUnitType.pos:
        return 'pos';
    }
  }
}
```

### APRÈS
```dart
extension BusinessUnitTypeExtension on BusinessUnitType {
  String get apiValue {
    switch (this) {
      case BusinessUnitType.company:
        return 'COMPANY';
      case BusinessUnitType.branch:
        return 'BRANCH';
      case BusinessUnitType.pos:
        return 'POS';
    }
  }
}
```

---

## 3. ExpenseApiService - supplierPhoneNumber

### Problème
Le paramètre `supplierPhoneNumber` était manquant dans les méthodes de création/mise à jour de dépenses.

### Fichier: `lib/features/expenses/services/expense_api_service.dart`

### Interface - AVANT
```dart
Future<ApiResponse<Expense>> createExpense(
  Expense expense, {
  List<File>? imageFiles,
});

Future<ApiResponse<Expense>> updateExpense(
  Expense expense, {
  List<File>? newImageFiles,
  List<String>? attachmentUrlsToRemove,
});
```

### Interface - APRÈS
```dart
Future<ApiResponse<Expense>> createExpense(
  Expense expense, {
  List<File>? imageFiles,
  String? supplierPhoneNumber,
});

Future<ApiResponse<Expense>> updateExpense(
  Expense expense, {
  List<File>? newImageFiles,
  List<String>? attachmentUrlsToRemove,
  String? supplierPhoneNumber,
});
```

### Implémentation createExpense - AVANT
```dart
final requestBody = {
  'description': expense.description,
  'amount': expense.amount,
  'currency': expense.currency,
  // ... autres champs
};
```

### Implémentation createExpense - APRÈS
```dart
final requestBody = {
  'description': expense.description,
  'amount': expense.amount,
  'currency': expense.currency,
  // ... autres champs
};

// Ajouter supplierPhoneNumber si fourni
if (supplierPhoneNumber != null && supplierPhoneNumber.isNotEmpty) {
  requestBody['supplierPhoneNumber'] = supplierPhoneNumber;
}
```

### Même modification pour updateExpense

---

## 4. Phone Regex - Harmonisation à 6 chiffres minimum

### Problème
Les regex de validation de téléphone étaient trop restrictives (8 ou 9 chiffres minimum) alors que certains pays ont des numéros à 6 chiffres.

### Fichiers modifiés:
- `lib/features/settings/bloc/financial_account_bloc.dart`
- `lib/features/settings/screens/add_financial_account_screen.dart`
- `lib/screens/edit_profile_screen.dart`

### AVANT
```dart
// Dans financial_account_bloc.dart
final phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');

// Dans add_financial_account_screen.dart
final phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');

// Dans edit_profile_screen.dart
final phoneRegex = RegExp(r'^\+?[0-9]{9,15}$');
```

### APRÈS
```dart
// Dans TOUS les fichiers
final phoneRegex = RegExp(r'^\+?[0-9]{6,15}$');
```

---

## 5. ClearLocalCache dans les Repositories

### Problème
Les données de l'ancien business unit persistaient après un changement car les Hive boxes n'étaient pas vidées.

### Fichiers modifiés et code ajouté:

### `lib/features/sales/repositories/sales_repository.dart`
```dart
// AJOUTÉ à la fin de la classe
/// Vider le cache local des ventes (à utiliser lors du changement de business unit)
Future<void> clearLocalCache() async {
  await _salesBox.clear();
  Logger.info('Cache local des ventes vidé');
}
```

### `lib/features/expenses/repositories/expense_repository.dart`
```dart
// AJOUTÉ à la fin de la classe
/// Vider le cache local des dépenses (à utiliser lors du changement de business unit)
Future<void> clearLocalCache() async {
  await _expensesBox.clear();
  debugPrint("Cache local des dépenses vidé");
}
```

### `lib/features/inventory/repositories/inventory_repository.dart`
```dart
// AJOUTÉ à la fin de la classe
/// Vider le cache local de l'inventaire (à utiliser lors du changement de business unit)
Future<void> clearLocalCache() async {
  await _productsBox.clear();
  await _transactionsBox.clear();
  debugPrint("Cache local de l'inventaire vidé (produits et transactions de stock)");
}
```

### `lib/features/transactions/repositories/transaction_repository.dart`
```dart
// AJOUTÉ à la fin de la classe
/// Vider le cache local des transactions (à utiliser lors du changement de business unit)
Future<void> clearLocalCache() async {
  await _transactionsBox.clear();
  print('Cache local des transactions vidé');
}
```

### `lib/features/financing/repositories/financing_repository.dart`
```dart
// AJOUTÉ à la fin de la classe
/// Vider le cache local des demandes de financement (à utiliser lors du changement de business unit)
Future<void> clearLocalCache() async {
  await _requestsBox.clear();
  _requests.clear(); // Vider aussi le cache mémoire
  Logger.info('Cache local des demandes de financement vidé');
}
```

### `lib/features/dashboard/repositories/operation_journal_repository.dart`
```dart
// AJOUTÉ à la fin de la classe
/// Vider le cache local des entrées de journal (à utiliser lors du changement de business unit)
Future<void> clearLocalCache() async {
  try {
    final box = await _getBox();
    await box.clear();
    debugPrint('Cache local du journal des opérations vidé');
  } catch (e) {
    debugPrint('Erreur lors du vidage du cache du journal: $e');
  }
}
```

**Note:** `CustomerRepository` et `SupplierRepository` avaient déjà `clearLocalCache()`.

---

## 6. CacheManagementService - Service centralisé

### Nouveau fichier: `lib/services/cache_management_service.dart`

```dart
import 'package:flutter/foundation.dart';

import 'package:wanzo/features/sales/repositories/sales_repository.dart';
import 'package:wanzo/features/expenses/repositories/expense_repository.dart';
import 'package:wanzo/features/inventory/repositories/inventory_repository.dart';
import 'package:wanzo/features/customer/repositories/customer_repository.dart';
import 'package:wanzo/features/supplier/repositories/supplier_repository.dart';
import 'package:wanzo/features/transactions/repositories/transaction_repository.dart';
import 'package:wanzo/features/financing/repositories/financing_repository.dart';
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
  FinancingRepository? _financingRepository;
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
    required FinancingRepository financingRepository,
    required OperationJournalRepository operationJournalRepository,
  }) {
    _salesRepository = salesRepository;
    _expenseRepository = expenseRepository;
    _inventoryRepository = inventoryRepository;
    _customerRepository = customerRepository;
    _supplierRepository = supplierRepository;
    _transactionRepository = transactionRepository;
    _financingRepository = financingRepository;
    _operationJournalRepository = operationJournalRepository;
    _isInitialized = true;
    
    debugPrint('CacheManagementService initialisé avec ${_repositoryCount} repositories');
  }

  int get _repositoryCount {
    int count = 0;
    if (_salesRepository != null) count++;
    if (_expenseRepository != null) count++;
    if (_inventoryRepository != null) count++;
    if (_customerRepository != null) count++;
    if (_supplierRepository != null) count++;
    if (_transactionRepository != null) count++;
    if (_financingRepository != null) count++;
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
      debugPrint('⚠️ CacheManagementService: Tentative de clear sans initialisation');
      return;
    }

    debugPrint('🧹 CacheManagementService: Début du nettoyage des caches...');
    
    final List<Future<void>> clearOperations = [];

    try {
      // Ventes
      if (_salesRepository != null) {
        clearOperations.add(_salesRepository!.clearLocalCache().catchError((e) {
          debugPrint('Erreur lors du clear SalesRepository: $e');
        }));
      }

      // Dépenses
      if (_expenseRepository != null) {
        clearOperations.add(_expenseRepository!.clearLocalCache().catchError((e) {
          debugPrint('Erreur lors du clear ExpenseRepository: $e');
        }));
      }

      // Inventaire
      if (_inventoryRepository != null) {
        clearOperations.add(_inventoryRepository!.clearLocalCache().catchError((e) {
          debugPrint('Erreur lors du clear InventoryRepository: $e');
        }));
      }

      // Clients
      if (_customerRepository != null) {
        clearOperations.add(_customerRepository!.clearLocalCache().catchError((e) {
          debugPrint('Erreur lors du clear CustomerRepository: $e');
        }));
      }

      // Fournisseurs
      if (_supplierRepository != null) {
        clearOperations.add(_supplierRepository!.clearLocalCache().catchError((e) {
          debugPrint('Erreur lors du clear SupplierRepository: $e');
        }));
      }

      // Transactions
      if (_transactionRepository != null) {
        clearOperations.add(_transactionRepository!.clearLocalCache().catchError((e) {
          debugPrint('Erreur lors du clear TransactionRepository: $e');
        }));
      }

      // Financements
      if (_financingRepository != null) {
        clearOperations.add(_financingRepository!.clearLocalCache().catchError((e) {
          debugPrint('Erreur lors du clear FinancingRepository: $e');
        }));
      }

      // Journal des opérations
      if (_operationJournalRepository != null) {
        clearOperations.add(_operationJournalRepository!.clearLocalCache().catchError((e) {
          debugPrint('Erreur lors du clear OperationJournalRepository: $e');
        }));
      }

      // Exécuter toutes les opérations de nettoyage en parallèle
      await Future.wait(clearOperations);

      debugPrint('✅ CacheManagementService: Tous les caches ont été vidés');
    } catch (e) {
      debugPrint('❌ CacheManagementService: Erreur critique lors du nettoyage: $e');
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

  Future<void> clearFinancingCache() async {
    if (_financingRepository != null) {
      await _financingRepository!.clearLocalCache();
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
    _financingRepository = null;
    _operationJournalRepository = null;
    _isInitialized = false;
  }
}
```

---

## 7. UsersBloc - Hook de nettoyage des caches

### Fichier: `lib/features/users/bloc/users_bloc.dart`

### Import ajouté
```dart
import 'package:wanzo/services/cache_management_service.dart';
```

### _onSwitchBusinessUnit - AVANT
```dart
Future<void> _onSwitchBusinessUnit(
  SwitchBusinessUnit event,
  Emitter<UsersState> emit,
) async {
  emit(
    state.copyWith(
      status: UsersStatus.switchingBusinessUnit,
      clearError: true,
      clearBusinessUnitSwitch: true,
    ),
  );

  try {
    final switchData = await _userApiService.switchBusinessUnit(
      event.businessUnitCode,
    );

    // Recharger l'utilisateur pour avoir les nouvelles infos d'unité
    final updatedUser = await _userApiService.getCurrentUser();

    emit(
      state.copyWith(
        status: UsersStatus.businessUnitSwitched,
        currentUser: updatedUser,
        businessUnitSwitched: true,
        businessUnitSwitchData: switchData,
      ),
    );
  } catch (e) {
    emit(
      state.copyWith(status: UsersStatus.error, errorMessage: e.toString()),
    );
  }
}
```

### _onSwitchBusinessUnit - APRÈS
```dart
Future<void> _onSwitchBusinessUnit(
  SwitchBusinessUnit event,
  Emitter<UsersState> emit,
) async {
  emit(
    state.copyWith(
      status: UsersStatus.switchingBusinessUnit,
      clearError: true,
      clearBusinessUnitSwitch: true,
    ),
  );

  try {
    final switchData = await _userApiService.switchBusinessUnit(
      event.businessUnitCode,
    );

    // IMPORTANT: Vider tous les caches locaux pour éviter d'afficher
    // les données de l'ancien business unit
    await CacheManagementService.instance.clearAllBusinessUnitData();

    // Recharger l'utilisateur pour avoir les nouvelles infos d'unité
    final updatedUser = await _userApiService.getCurrentUser();

    emit(
      state.copyWith(
        status: UsersStatus.businessUnitSwitched,
        currentUser: updatedUser,
        businessUnitSwitched: true,
        businessUnitSwitchData: switchData,
      ),
    );
  } catch (e) {
    emit(
      state.copyWith(status: UsersStatus.error, errorMessage: e.toString()),
    );
  }
}
```

### Même modification pour _onResetToCompany (ajout de la ligne clearAllBusinessUnitData)

---

## 8. Adha Chat - Persistance des conversations

### Problème
Les conversations Adha disparaissaient quand l'utilisateur naviguait vers d'autres écrans ou fermait l'app.

### Fichier: `lib/features/adha/repositories/adha_repository.dart`

### Variables ajoutées
```dart
// AVANT
class AdhaRepository {
  static const _conversationsBoxNamePrefix = 'adha_conversations';
  Box<AdhaConversation>? _conversationsBox;
  String? _currentUserId;
  final AdhaApiService? apiService;
  // ...
}

// APRÈS
class AdhaRepository {
  static const _conversationsBoxNamePrefix = 'adha_conversations';
  static const _stateBoxName = 'adha_state';
  static const _activeConversationKey = 'activeConversationId';
  
  Box<AdhaConversation>? _conversationsBox;
  Box<String>? _stateBox; // Box pour stocker l'état (activeConversationId, etc.)
  String? _currentUserId;
  final AdhaApiService? apiService;
  // ...
}
```

### init() modifié - retourne maintenant bool
```dart
// AVANT
Future<void> init({String? userId}) async {
  // ...
}

// APRÈS
/// Retourne true si l'utilisateur a changé (nouvelle initialisation), false sinon.
Future<bool> init({String? userId}) async {
  final bool userChanged = _currentUserId != userId;
  
  // Si on change d'utilisateur, fermer l'ancienne box
  if (userChanged && _conversationsBox != null) {
    await _conversationsBox!.close();
    _conversationsBox = null;
    debugPrint(
      '[AdhaRepository] 📦 Fermeture de la box pour changement d\'utilisateur',
    );
  }

  _currentUserId = userId;
  final boxName = _getBoxName(userId);
  
  // ... ouverture de _conversationsBox (code existant)

  // Ouvrir la box d'état (partagée entre tous les utilisateurs)
  try {
    if (_stateBox == null || !_stateBox!.isOpen) {
      _stateBox = await Hive.openBox<String>(_stateBoxName);
      debugPrint('[AdhaRepository] ✅ Box d\'état ouverte');
    }
  } catch (e) {
    debugPrint('[AdhaRepository] ⚠️ Erreur ouverture box état: $e');
    await Hive.deleteBoxFromDisk(_stateBoxName);
    _stateBox = await Hive.openBox<String>(_stateBoxName);
  }

  return userChanged;
}
```

### Nouvelles méthodes ajoutées
```dart
/// Retourne true si le repository est déjà initialisé pour un utilisateur donné
bool isInitializedForUser(String? userId) {
  return _currentUserId == userId && 
         _conversationsBox != null && 
         _conversationsBox!.isOpen;
}

/// Sauvegarde l'ID de la conversation active (persistance entre sessions)
Future<void> saveActiveConversationId(String? conversationId) async {
  if (_stateBox == null || !_stateBox!.isOpen) {
    debugPrint('[AdhaRepository] ⚠️ State box non initialisée');
    return;
  }
  
  final key = '${_activeConversationKey}_${_currentUserId ?? 'default'}';
  if (conversationId == null) {
    await _stateBox!.delete(key);
    debugPrint('[AdhaRepository] 🗑️ Active conversation ID supprimé');
  } else {
    await _stateBox!.put(key, conversationId);
    debugPrint('[AdhaRepository] 💾 Active conversation ID sauvegardé: $conversationId');
  }
}

/// Récupère l'ID de la conversation active depuis le cache
String? getActiveConversationId() {
  if (_stateBox == null || !_stateBox!.isOpen) {
    return null;
  }
  
  final key = '${_activeConversationKey}_${_currentUserId ?? 'default'}';
  final id = _stateBox!.get(key);
  debugPrint('[AdhaRepository] 📖 Active conversation ID lu: $id');
  return id;
}
```

### Fichier: `lib/features/adha/bloc/adha_bloc.dart`

### Helper ajouté pour persister l'ID actif
```dart
/// Sauvegarde l'ID de conversation active (helper interne)
void _setActiveConversation(String? conversationId) {
  _currentlyActiveConversationId = conversationId;
  // Persister pour la prochaine session
  adhaRepository.saveActiveConversationId(conversationId);
}
```

### _onInitializeForUser modifié
```dart
// AVANT - Réinitialisait toujours à AdhaInitial
Future<void> _onInitializeForUser(
  InitializeForUser event,
  Emitter<AdhaState> emit,
) async {
  try {
    _currentlyActiveConversationId = null;
    _accumulatedStreamContent.clear();
    _currentStreamingRequestId = null;
    await adhaRepository.init(userId: event.userId);
    emit(const AdhaInitial());
  } catch (e) {
    emit(AdhaError('Erreur d\'initialisation: $e'));
  }
}

// APRÈS - Vérifie si déjà initialisé et restaure l'état
Future<void> _onInitializeForUser(
  InitializeForUser event,
  Emitter<AdhaState> emit,
) async {
  try {
    debugPrint('[AdhaBloc] Initialisation pour utilisateur: ${event.userId}');

    // Vérifier si on est déjà initialisé pour cet utilisateur
    final alreadyInitialized = adhaRepository.isInitializedForUser(event.userId);

    if (alreadyInitialized) {
      debugPrint('[AdhaBloc] ✅ Déjà initialisé pour cet utilisateur, restauration de l\'état');

      // Restaurer la conversation active depuis le cache
      if (_currentlyActiveConversationId == null) {
        final savedActiveId = adhaRepository.getActiveConversationId();
        if (savedActiveId != null) {
          final conversation = await adhaRepository.getConversation(savedActiveId);
          if (conversation != null) {
            _currentlyActiveConversationId = savedActiveId;
            emit(AdhaConversationActive(conversation: conversation));
            debugPrint('[AdhaBloc] ✅ Conversation restaurée: $savedActiveId');
            return;
          }
        }
      } else {
        // Une conversation est déjà active en mémoire, ne pas la réinitialiser
        debugPrint('[AdhaBloc] ✅ Conversation déjà active, état conservé');
        return;
      }

      emit(const AdhaInitial());
      return;
    }

    // Nouveau utilisateur ou première initialisation
    _accumulatedStreamContent.clear();
    _currentStreamingRequestId = null;

    final userChanged = await adhaRepository.init(userId: event.userId);

    if (userChanged) {
      _currentlyActiveConversationId = null;
      emit(const AdhaInitial());
    } else {
      // Même utilisateur, restaurer la conversation active si elle existe
      final savedActiveId = adhaRepository.getActiveConversationId();
      if (savedActiveId != null) {
        final conversation = await adhaRepository.getConversation(savedActiveId);
        if (conversation != null) {
          _currentlyActiveConversationId = savedActiveId;
          emit(AdhaConversationActive(conversation: conversation));
          return;
        }
      }
      emit(const AdhaInitial());
    }
  } catch (e) {
    debugPrint('[AdhaBloc] ❌ Erreur lors de l\'initialisation: $e');
    emit(AdhaError('Erreur d\'initialisation: $e'));
  }
}
```

### _onClearCurrentConversation modifié
```dart
// AVANT
Future<void> _onClearCurrentConversation(...) async {
  _currentlyActiveConversationId = null;
  _accumulatedStreamContent.clear();
  _currentStreamingRequestId = null;
  emit(const AdhaInitial());
}

// APRÈS
Future<void> _onClearCurrentConversation(...) async {
  _currentlyActiveConversationId = null;
  _accumulatedStreamContent.clear();
  _currentStreamingRequestId = null;

  // Persister le fait qu'il n'y a plus de conversation active
  await adhaRepository.saveActiveConversationId(null);

  emit(const AdhaInitial());
}
```

### Remplacer toutes les occurrences de:
```dart
// AVANT
_currentlyActiveConversationId = someValue;

// APRÈS (utiliser le helper)
_setActiveConversation(someValue);
```

---

## Initialisation dans main.dart

### Import ajouté
```dart
import 'package:wanzo/services/cache_management_service.dart';
```

### Initialisation ajoutée après création des repositories
```dart
// Après: final repositories = await _initializeRepositoriesOptimized(...)

// 9.5. Initialisation du service de gestion des caches
CacheManagementService.instance.initialize(
  salesRepository: repositories['sales'] as SalesRepository,
  expenseRepository: repositories['expense'] as ExpenseRepository,
  inventoryRepository: repositories['inventory'] as InventoryRepository,
  customerRepository: repositories['customer'] as CustomerRepository,
  supplierRepository: repositories['supplier'] as SupplierRepository,
  transactionRepository: repositories['transaction'] as TransactionRepository,
  financingRepository: repositories['financing'] as FinancingRepository,
  operationJournalRepository: repositories['operationJournal'] as OperationJournalRepository,
);

logger.info('CacheManagementService initialized');
```

---

## Résumé des changements par catégorie

### DTOs / Enums
| Fichier | Changement |
|---------|------------|
| `financing_request.dart` | Ajout extension `apiValue` + `fromApiValue()` pour FinancingType |
| `business_unit_enums.dart` | `apiValue` retourne UPPERCASE |

### Services API
| Fichier | Changement |
|---------|------------|
| `expense_api_service.dart` | Ajout paramètre `supplierPhoneNumber` |

### Validation
| Fichier | Changement |
|---------|------------|
| `financial_account_bloc.dart` | Phone regex: `{8,15}` → `{6,15}` |
| `add_financial_account_screen.dart` | Phone regex: `{8,15}` → `{6,15}` |
| `edit_profile_screen.dart` | Phone regex: `{9,15}` → `{6,15}` |

### Repositories
| Fichier | Changement |
|---------|------------|
| `sales_repository.dart` | Ajout `clearLocalCache()` |
| `expense_repository.dart` | Ajout `clearLocalCache()` |
| `inventory_repository.dart` | Ajout `clearLocalCache()` |
| `transaction_repository.dart` | Ajout `clearLocalCache()` |
| `financing_repository.dart` | Ajout `clearLocalCache()` |
| `operation_journal_repository.dart` | Ajout `clearLocalCache()` |
| `adha_repository.dart` | Ajout persistance conversation active |

### Services
| Fichier | Changement |
|---------|------------|
| `cache_management_service.dart` | **NOUVEAU** - Service centralisé |

### BLoCs
| Fichier | Changement |
|---------|------------|
| `users_bloc.dart` | Appel `clearAllBusinessUnitData()` lors switch BU |
| `adha_bloc.dart` | Restauration conversation active, helper `_setActiveConversation()` |

### Initialisation
| Fichier | Changement |
|---------|------------|
| `main.dart` | Initialisation CacheManagementService |
