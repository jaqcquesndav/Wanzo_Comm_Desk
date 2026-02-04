import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wanzo/core/utils/connectivity_service.dart';

/// Service d'amélioration de l'accès hors ligne aux ressources
class EnhancedOfflineService {
  static EnhancedOfflineService? _instance;
  static EnhancedOfflineService get instance => _instance ??= EnhancedOfflineService._();

  EnhancedOfflineService._();

  final ConnectivityService _connectivityService = ConnectivityService();
  
  // Boxes Hive pour le cache local
  late Box<Map> _productsBox;
  late Box<Map> _salesBox;
  late Box<Map> _customersBox;
  late Box<Map> _settingsBox;
  late Box<Map> _transactionsBox;
  late Box<String> _cacheMetadataBox;
  
  bool _isInitialized = false;
  final ValueNotifier<bool> _offlineDataAvailable = ValueNotifier<bool>(false);

  /// Notificateur de disponibilité des données hors ligne
  ValueListenable<bool> get offlineDataAvailable => _offlineDataAvailable;

  /// Vérifie si des données hors ligne sont disponibles
  bool get hasOfflineData => _offlineDataAvailable.value;

  /// Initialise le service d'accès hors ligne amélioré
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialiser les boxes Hive pour le cache
      await _initializeHiveBoxes();
      
      // Vérifier la disponibilité des données hors ligne
      await _checkOfflineDataAvailability();
      
      // Écouter les changements de connectivité
      _connectivityService.connectionStatus.addListener(_onConnectivityChangedCallback);
      
      _isInitialized = true;
      debugPrint('EnhancedOfflineService: Initialized successfully');
    } catch (e) {
      debugPrint('EnhancedOfflineService: Initialization error: $e');
      rethrow;
    }
  }

  /// Initialise les boxes Hive pour le cache local
  Future<void> _initializeHiveBoxes() async {
    try {
      _productsBox = await Hive.openBox<Map>('offline_products');
      _salesBox = await Hive.openBox<Map>('offline_sales');
      _customersBox = await Hive.openBox<Map>('offline_customers');
      _settingsBox = await Hive.openBox<Map>('offline_settings');
      _transactionsBox = await Hive.openBox<Map>('offline_transactions');
      _cacheMetadataBox = await Hive.openBox<String>('cache_metadata');
      
      debugPrint('EnhancedOfflineService: Hive boxes initialized');
    } catch (e) {
      debugPrint('EnhancedOfflineService: Error initializing Hive boxes: $e');
      rethrow;
    }
  }

  /// Cache les données essentielles pour l'accès hors ligne
  Future<void> cacheEssentialData({
    List<Map<String, dynamic>>? products,
    List<Map<String, dynamic>>? sales,
    List<Map<String, dynamic>>? customers,
    Map<String, dynamic>? settings,
    List<Map<String, dynamic>>? transactions,
  }) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      
      // Cache des produits
      if (products != null) {
        await _cacheDataWithMetadata(_productsBox, products, 'products', timestamp);
      }
      
      // Cache des ventes
      if (sales != null) {
        await _cacheDataWithMetadata(_salesBox, sales, 'sales', timestamp);
      }
      
      // Cache des clients
      if (customers != null) {
        await _cacheDataWithMetadata(_customersBox, customers, 'customers', timestamp);
      }
      
      // Cache des paramètres
      if (settings != null) {
        await _settingsBox.clear();
        await _settingsBox.put('settings', settings);
        await _cacheMetadataBox.put('settings_timestamp', timestamp);
      }
      
      // Cache des transactions
      if (transactions != null) {
        await _cacheDataWithMetadata(_transactionsBox, transactions, 'transactions', timestamp);
      }
      
      // Mettre à jour la disponibilité des données
      await _checkOfflineDataAvailability();
      
      debugPrint('EnhancedOfflineService: Essential data cached');
    } catch (e) {
      debugPrint('EnhancedOfflineService: Error caching data: $e');
    }
  }

  /// Cache une liste de données avec métadonnées
  Future<void> _cacheDataWithMetadata(
    Box<Map> box, 
    List<Map<String, dynamic>> data, 
    String type, 
    String timestamp
  ) async {
    await box.clear();
    for (int i = 0; i < data.length; i++) {
      await box.put(i, data[i]);
    }
    await _cacheMetadataBox.put('${type}_timestamp', timestamp);
    await _cacheMetadataBox.put('${type}_count', data.length.toString());
  }

  /// Récupère les produits depuis le cache hors ligne
  Future<List<Map<String, dynamic>>> getCachedProducts() async {
    try {
      final products = <Map<String, dynamic>>[];
      for (int i = 0; i < _productsBox.length; i++) {
        final product = _productsBox.get(i);
        if (product != null) {
          products.add(Map<String, dynamic>.from(product));
        }
      }
      debugPrint('EnhancedOfflineService: Retrieved ${products.length} cached products');
      return products;
    } catch (e) {
      debugPrint('EnhancedOfflineService: Error getting cached products: $e');
      return [];
    }
  }

  /// Récupère les ventes depuis le cache hors ligne
  Future<List<Map<String, dynamic>>> getCachedSales() async {
    try {
      final sales = <Map<String, dynamic>>[];
      for (int i = 0; i < _salesBox.length; i++) {
        final sale = _salesBox.get(i);
        if (sale != null) {
          sales.add(Map<String, dynamic>.from(sale));
        }
      }
      debugPrint('EnhancedOfflineService: Retrieved ${sales.length} cached sales');
      return sales;
    } catch (e) {
      debugPrint('EnhancedOfflineService: Error getting cached sales: $e');
      return [];
    }
  }

  /// Récupère les clients depuis le cache hors ligne
  Future<List<Map<String, dynamic>>> getCachedCustomers() async {
    try {
      final customers = <Map<String, dynamic>>[];
      for (int i = 0; i < _customersBox.length; i++) {
        final customer = _customersBox.get(i);
        if (customer != null) {
          customers.add(Map<String, dynamic>.from(customer));
        }
      }
      debugPrint('EnhancedOfflineService: Retrieved ${customers.length} cached customers');
      return customers;
    } catch (e) {
      debugPrint('EnhancedOfflineService: Error getting cached customers: $e');
      return [];
    }
  }

  /// Récupère les paramètres depuis le cache hors ligne
  Future<Map<String, dynamic>?> getCachedSettings() async {
    try {
      final settings = _settingsBox.get('settings');
      if (settings != null) {
        debugPrint('EnhancedOfflineService: Retrieved cached settings');
        return Map<String, dynamic>.from(settings);
      }
      return null;
    } catch (e) {
      debugPrint('EnhancedOfflineService: Error getting cached settings: $e');
      return null;
    }
  }

  /// Récupère les transactions depuis le cache hors ligne
  Future<List<Map<String, dynamic>>> getCachedTransactions() async {
    try {
      final transactions = <Map<String, dynamic>>[];
      for (int i = 0; i < _transactionsBox.length; i++) {
        final transaction = _transactionsBox.get(i);
        if (transaction != null) {
          transactions.add(Map<String, dynamic>.from(transaction));
        }
      }
      debugPrint('EnhancedOfflineService: Retrieved ${transactions.length} cached transactions');
      return transactions;
    } catch (e) {
      debugPrint('EnhancedOfflineService: Error getting cached transactions: $e');
      return [];
    }
  }

  /// Sauvegarde une nouvelle vente en mode hors ligne
  Future<bool> saveOfflineSale(Map<String, dynamic> sale) async {
    try {
      // Ajouter un timestamp et un identifiant temporaire
      sale['offline_id'] = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      sale['created_offline'] = true;
      sale['sync_pending'] = true;
      sale['created_at'] = DateTime.now().toIso8601String();
      
      // Sauvegarder dans le cache local
      final currentIndex = _salesBox.length;
      await _salesBox.put(currentIndex, sale);
      
      // Mettre à jour les métadonnées
      final timestamp = DateTime.now().toIso8601String();
      await _cacheMetadataBox.put('sales_timestamp', timestamp);
      await _cacheMetadataBox.put('sales_count', (_salesBox.length).toString());
      
      debugPrint('EnhancedOfflineService: Offline sale saved with ID ${sale['offline_id']}');
      return true;
    } catch (e) {
      debugPrint('EnhancedOfflineService: Error saving offline sale: $e');
      return false;
    }
  }

  /// Sauvegarde un nouveau client en mode hors ligne
  Future<bool> saveOfflineCustomer(Map<String, dynamic> customer) async {
    try {
      // Ajouter un timestamp et un identifiant temporaire
      customer['offline_id'] = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      customer['created_offline'] = true;
      customer['sync_pending'] = true;
      customer['created_at'] = DateTime.now().toIso8601String();
      
      // Sauvegarder dans le cache local
      final currentIndex = _customersBox.length;
      await _customersBox.put(currentIndex, customer);
      
      // Mettre à jour les métadonnées
      final timestamp = DateTime.now().toIso8601String();
      await _cacheMetadataBox.put('customers_timestamp', timestamp);
      await _cacheMetadataBox.put('customers_count', (_customersBox.length).toString());
      
      debugPrint('EnhancedOfflineService: Offline customer saved with ID ${customer['offline_id']}');
      return true;
    } catch (e) {
      debugPrint('EnhancedOfflineService: Error saving offline customer: $e');
      return false;
    }
  }

  /// Récupère les données en attente de synchronisation
  Future<Map<String, List<Map<String, dynamic>>>> getPendingSyncData() async {
    try {
      final pendingData = <String, List<Map<String, dynamic>>>{
        'sales': [],
        'customers': [],
        'transactions': [],
      };
      
      // Récupérer les ventes en attente
      for (int i = 0; i < _salesBox.length; i++) {
        final sale = _salesBox.get(i);
        if (sale != null && sale['sync_pending'] == true) {
          pendingData['sales']!.add(Map<String, dynamic>.from(sale));
        }
      }
      
      // Récupérer les clients en attente
      for (int i = 0; i < _customersBox.length; i++) {
        final customer = _customersBox.get(i);
        if (customer != null && customer['sync_pending'] == true) {
          pendingData['customers']!.add(Map<String, dynamic>.from(customer));
        }
      }
      
      // Récupérer les transactions en attente
      for (int i = 0; i < _transactionsBox.length; i++) {
        final transaction = _transactionsBox.get(i);
        if (transaction != null && transaction['sync_pending'] == true) {
          pendingData['transactions']!.add(Map<String, dynamic>.from(transaction));
        }
      }
      
      final totalPending = pendingData.values.fold(0, (sum, list) => sum + list.length);
      debugPrint('EnhancedOfflineService: Found $totalPending items pending sync');
      
      return pendingData;
    } catch (e) {
      debugPrint('EnhancedOfflineService: Error getting pending sync data: $e');
      return {};
    }
  }

  /// Marque les données comme synchronisées
  Future<void> markAsSynced(String type, String offlineId) async {
    try {
      Box<Map> targetBox;
      switch (type) {
        case 'sales':
          targetBox = _salesBox;
          break;
        case 'customers':
          targetBox = _customersBox;
          break;
        case 'transactions':
          targetBox = _transactionsBox;
          break;
        default:
          debugPrint('EnhancedOfflineService: Unknown type for sync: $type');
          return;
      }
      
      // Trouver et mettre à jour l'élément
      for (int i = 0; i < targetBox.length; i++) {
        final item = targetBox.get(i);
        if (item != null && item['offline_id'] == offlineId) {
          item['sync_pending'] = false;
          item['synced_at'] = DateTime.now().toIso8601String();
          await targetBox.put(i, item);
          debugPrint('EnhancedOfflineService: Marked $type item $offlineId as synced');
          break;
        }
      }
    } catch (e) {
      debugPrint('EnhancedOfflineService: Error marking as synced: $e');
    }
  }

  /// Vérifie la disponibilité des données hors ligne
  Future<void> _checkOfflineDataAvailability() async {
    try {
      final hasProducts = _productsBox.isNotEmpty;
      final hasSettings = _settingsBox.containsKey('settings');
      final hasSales = _salesBox.isNotEmpty;
      
      final isAvailable = hasProducts || hasSettings || hasSales;
      
      if (_offlineDataAvailable.value != isAvailable) {
        _offlineDataAvailable.value = isAvailable;
        debugPrint('EnhancedOfflineService: Offline data availability: $isAvailable');
      }
    } catch (e) {
      debugPrint('EnhancedOfflineService: Error checking offline data availability: $e');
      _offlineDataAvailable.value = false;
    }
  }

  /// Gestionnaire de changement de connectivité (callback)
  void _onConnectivityChangedCallback() {
    final isConnected = _connectivityService.isConnected;
    if (isConnected) {
      debugPrint('EnhancedOfflineService: Connectivity restored - sync opportunity');
      // TODO: Déclencher la synchronisation automatique
    } else {
      debugPrint('EnhancedOfflineService: Connectivity lost - offline mode active');
    }
  }

  /// Obtient les informations sur le cache
  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final info = <String, dynamic>{};
      
      // Informations sur les produits
      info['products'] = {
        'count': _productsBox.length,
        'timestamp': _cacheMetadataBox.get('products_timestamp'),
      };
      
      // Informations sur les ventes
      info['sales'] = {
        'count': _salesBox.length,
        'timestamp': _cacheMetadataBox.get('sales_timestamp'),
      };
      
      // Informations sur les clients
      info['customers'] = {
        'count': _customersBox.length,
        'timestamp': _cacheMetadataBox.get('customers_timestamp'),
      };
      
      // Informations sur les paramètres
      info['settings'] = {
        'available': _settingsBox.containsKey('settings'),
        'timestamp': _cacheMetadataBox.get('settings_timestamp'),
      };
      
      // Informations sur les transactions
      info['transactions'] = {
        'count': _transactionsBox.length,
        'timestamp': _cacheMetadataBox.get('transactions_timestamp'),
      };
      
      return info;
    } catch (e) {
      debugPrint('EnhancedOfflineService: Error getting cache info: $e');
      return {};
    }
  }

  /// Nettoie le cache ancien (plus de 30 jours)
  Future<void> cleanOldCache() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      // Vérifier et nettoyer chaque type de cache
      await _cleanOldCacheForType(_productsBox, 'products', thirtyDaysAgo);
      await _cleanOldCacheForType(_salesBox, 'sales', thirtyDaysAgo);
      await _cleanOldCacheForType(_customersBox, 'customers', thirtyDaysAgo);
      await _cleanOldCacheForType(_transactionsBox, 'transactions', thirtyDaysAgo);
      
      debugPrint('EnhancedOfflineService: Old cache cleaned');
    } catch (e) {
      debugPrint('EnhancedOfflineService: Error cleaning old cache: $e');
    }
  }

  /// Nettoie le cache ancien pour un type spécifique
  Future<void> _cleanOldCacheForType(Box<Map> box, String type, DateTime cutoffDate) async {
    final timestampKey = '${type}_timestamp';
    final timestampStr = _cacheMetadataBox.get(timestampKey);
    
    if (timestampStr != null) {
      final cacheDate = DateTime.tryParse(timestampStr);
      if (cacheDate != null && cacheDate.isBefore(cutoffDate)) {
        await box.clear();
        await _cacheMetadataBox.delete(timestampKey);
        await _cacheMetadataBox.delete('${type}_count');
        debugPrint('EnhancedOfflineService: Cleaned old $type cache');
      }
    }
  }

  /// Dispose des ressources
  void dispose() {
    _offlineDataAvailable.dispose();
    _instance = null;
    debugPrint('EnhancedOfflineService: Disposed');
  }
}
