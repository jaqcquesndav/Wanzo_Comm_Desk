import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../services/customer_api_service.dart';
import '../../sales/repositories/sales_repository.dart';
import '../../../core/utils/logger.dart';

/// Repository pour la gestion des clients (API-First + Offline Fallback)
class CustomerRepository {
  static const _customersBoxName = 'customers';
  late Box<Customer> _customersBox;
  final _uuid = const Uuid();
  final CustomerApiService? _apiService;

  CustomerRepository({CustomerApiService? apiService})
    : _apiService = apiService;

  /// Initialise le repository
  Future<void> init() async {
    _customersBox = await Hive.openBox<Customer>(_customersBoxName);
    // Note: Plus de données mock - on utilise uniquement les vraies données API
  }

  /// Récupère tous les clients (API-First avec fallback local)
  Future<List<Customer>> getCustomers({bool forceLocal = false}) async {
    // Si forceLocal, retourner uniquement les données locales
    if (forceLocal) {
      return _customersBox.values.toList();
    }

    // Essayer d'abord l'API
    if (_apiService != null) {
      try {
        final apiResponse = await _apiService.getCustomers().timeout(
          const Duration(seconds: 10),
        );

        if (apiResponse.success &&
            apiResponse.data != null &&
            apiResponse.data!.isNotEmpty) {
          Logger.info(
            '📦 [CustomerRepository] API: ${apiResponse.data!.length} clients récupérés',
          );
          // Fusionner avec le cache local
          await _mergeCustomers(apiResponse.data!);
          return apiResponse.data!;
        }
      } catch (e) {
        Logger.error(
          '⚠️ [CustomerRepository] Erreur API, fallback sur cache local',
          error: e,
        );
      }
    }

    // Fallback sur données locales
    final localCustomers = _customersBox.values.toList();
    Logger.info(
      '📦 [CustomerRepository] Cache local: ${localCustomers.length} clients',
    );
    return localCustomers;
  }

  /// Récupère un client spécifique
  Future<Customer?> getCustomer(String id) async {
    // D'abord vérifier le cache local
    final localCustomer = _customersBox.get(id);

    // Essayer l'API pour avoir les données les plus récentes
    if (_apiService != null) {
      try {
        final apiResponse = await _apiService
            .getCustomerById(id)
            .timeout(const Duration(seconds: 5));
        if (apiResponse.success && apiResponse.data != null) {
          // Mettre à jour le cache
          await _customersBox.put(id, apiResponse.data!);
          return apiResponse.data;
        }
      } catch (e) {
        Logger.error(
          '⚠️ [CustomerRepository] Erreur API getCustomer',
          error: e,
        );
      }
    }

    return localCustomer;
  }

  /// Ajoute un nouveau client (API + Local)
  Future<Customer> addCustomer(Customer customer) async {
    final newCustomer = customer.copyWith(
      id: customer.id.isEmpty ? _uuid.v4() : customer.id,
      createdAt: DateTime.now(),
    );

    // Essayer d'abord l'API
    if (_apiService != null) {
      try {
        final apiResponse = await _apiService
            .createCustomer(newCustomer)
            .timeout(const Duration(seconds: 10));
        if (apiResponse.success && apiResponse.data != null) {
          // Sauvegarder la version serveur localement
          await _customersBox.put(apiResponse.data!.id, apiResponse.data!);
          Logger.info(
            '✅ [CustomerRepository] Client créé via API: ${apiResponse.data!.id}',
          );
          return apiResponse.data!;
        }
      } catch (e) {
        Logger.error(
          '⚠️ [CustomerRepository] Erreur API create, sauvegarde locale',
          error: e,
        );
      }
    }

    // Fallback: Sauvegarder localement
    await _customersBox.put(newCustomer.id, newCustomer);
    return newCustomer;
  }

  /// Met à jour un client existant (API + Local)
  Future<Customer> updateCustomer(Customer customer) async {
    // Essayer d'abord l'API
    if (_apiService != null) {
      try {
        final apiResponse = await _apiService
            .updateCustomer(customer.id, customer)
            .timeout(const Duration(seconds: 10));
        if (apiResponse.success && apiResponse.data != null) {
          await _customersBox.put(apiResponse.data!.id, apiResponse.data!);
          Logger.info(
            '✅ [CustomerRepository] Client mis à jour via API: ${apiResponse.data!.id}',
          );
          return apiResponse.data!;
        }
      } catch (e) {
        Logger.error(
          '⚠️ [CustomerRepository] Erreur API update, sauvegarde locale',
          error: e,
        );
      }
    }

    // Fallback: Sauvegarder localement
    await _customersBox.put(customer.id, customer);
    return customer;
  }

  /// Supprime un client (API + Local)
  Future<void> deleteCustomer(String id) async {
    // Essayer d'abord l'API
    if (_apiService != null) {
      try {
        final apiResponse = await _apiService
            .deleteCustomer(id)
            .timeout(const Duration(seconds: 10));
        if (apiResponse.success) {
          Logger.info('✅ [CustomerRepository] Client supprimé via API: $id');
        }
      } catch (e) {
        Logger.error('⚠️ [CustomerRepository] Erreur API delete', error: e);
      }
    }

    // Toujours supprimer localement
    await _customersBox.delete(id);
  }

  /// Recherche des clients (API + Local)
  Future<List<Customer>> searchCustomers(String searchTerm) async {
    // Essayer d'abord l'API
    if (_apiService != null && searchTerm.length >= 2) {
      try {
        final apiResponse = await _apiService
            .getCustomers(search: searchTerm)
            .timeout(const Duration(seconds: 5));

        if (apiResponse.success && apiResponse.data != null) {
          Logger.info(
            '🔍 [CustomerRepository] Recherche API: ${apiResponse.data!.length} résultats',
          );
          return apiResponse.data!;
        }
      } catch (e) {
        Logger.error(
          '⚠️ [CustomerRepository] Erreur recherche API, fallback local',
          error: e,
        );
      }
    }

    // Fallback sur recherche locale
    final lowerCaseSearchTerm = searchTerm.toLowerCase();
    return _customersBox.values
        .where(
          (customer) =>
              customer.name.toLowerCase().contains(lowerCaseSearchTerm) ||
              (customer.email?.toLowerCase().contains(lowerCaseSearchTerm) ??
                  false) ||
              customer.phoneNumber.toLowerCase().contains(lowerCaseSearchTerm),
        )
        .toList();
  }

  /// Récupère les meilleurs clients (ceux avec le total d'achats le plus élevé)
  Future<List<Customer>> getTopCustomers({int limit = 5}) async {
    final customers = _customersBox.values.toList();
    customers.sort((a, b) => b.totalPurchases.compareTo(a.totalPurchases));
    return customers.take(limit).toList();
  }

  /// Récupère les clients les plus récents (ceux avec la date d'achat la plus récente)
  Future<List<Customer>> getRecentCustomers({int limit = 5}) async {
    final customers = _customersBox.values.toList();
    customers.sort((a, b) {
      if (a.lastPurchaseDate == null && b.lastPurchaseDate == null) return 0;
      if (a.lastPurchaseDate == null) return 1; // b comes first
      if (b.lastPurchaseDate == null) return -1; // a comes first
      return b.lastPurchaseDate!.compareTo(a.lastPurchaseDate!);
    });
    return customers.take(limit).toList();
  }

  /// Met à jour le total des achats d'un client
  Future<Customer> updateCustomerPurchaseTotal(
    String customerId,
    double amount,
  ) async {
    final customer = await getCustomer(customerId);
    if (customer == null) {
      throw Exception(
        'Client non trouvé pour la mise à jour du total des achats',
      );
    }
    final updatedCustomer = customer.copyWith(
      totalPurchases: customer.totalPurchases + amount,
      lastPurchaseDate: DateTime.now(),
    );
    await _customersBox.put(customerId, updatedCustomer);
    return updatedCustomer;
  }

  /// Récupère le nombre de clients uniques pour une période donnée
  Future<int> getUniqueCustomersCountForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Dépendance sur SalesRepository pour récupérer les ventes de la période
    try {
      // Récupérer les ventes de la période via le SalesRepository
      final salesRepo = await _getSalesRepository();
      if (salesRepo != null) {
        final sales = await salesRepo.getSalesByDateRange(startDate, endDate);

        // Extraire les IDs clients uniques des ventes
        final uniqueCustomerIds = <String>{};
        for (final sale in sales) {
          if (sale.customerId != null && sale.customerId!.isNotEmpty) {
            uniqueCustomerIds.add(sale.customerId!);
          }
        }

        return uniqueCustomerIds.length;
      }

      // Fallback: Si pas d'accès au SalesRepository, utiliser lastPurchaseDate des clients
      return _customersBox.values
          .where(
            (customer) =>
                customer.lastPurchaseDate != null &&
                customer.lastPurchaseDate!.isAfter(startDate) &&
                customer.lastPurchaseDate!.isBefore(
                  endDate.add(const Duration(days: 1)),
                ),
          )
          .length;
    } catch (e) {
      Logger.error('Erreur lors du calcul des clients uniques', error: e);
      // Fallback en cas d'erreur: retourner 0 plutôt qu'une valeur incorrecte
      return 0;
    }
  }

  // Méthode helper pour obtenir une instance de SalesRepository
  Future<SalesRepository?> _getSalesRepository() async {
    try {
      // Créer et initialiser une instance du SalesRepository
      final salesRepo = SalesRepository();
      await salesRepo.init();
      return salesRepo;
    } catch (e) {
      Logger.error('Erreur lors de l\'obtention du SalesRepository', error: e);
      return null;
    }
  }

  /// Synchronise les clients locaux avec le backend
  Future<void> syncLocalCustomersToBackend() async {
    if (_apiService == null) {
      Logger.info('API service non disponible pour la synchronisation');
      return;
    }

    try {
      final localCustomers = _customersBox.values.toList();
      if (localCustomers.isEmpty) return;

      final apiResponse = await _apiService
          .syncCustomers(localCustomers)
          .timeout(const Duration(seconds: 10));

      if (apiResponse.success && apiResponse.data != null) {
        Logger.info(
          'Synchronisation réussie: ${apiResponse.data!.length} clients synchronisés',
        );
        // Mettre à jour les clients locaux avec les données du serveur
        await _mergeCustomers(apiResponse.data!);
      }
    } catch (e) {
      Logger.error('Erreur lors de la synchronisation des clients', error: e);
    }
  }

  /// Récupère l'historique des ventes d'un client depuis l'API
  Future<List<dynamic>?> getCustomerSalesHistory(String customerId) async {
    if (_apiService == null) return null;

    try {
      final apiResponse = await _apiService
          .getCustomerSales(customerId)
          .timeout(const Duration(seconds: 5));

      if (apiResponse.success && apiResponse.data != null) {
        return apiResponse.data;
      }
    } catch (e) {
      Logger.error(
        'Erreur lors de la récupération de l\'historique des ventes',
        error: e,
      );
    }

    return null;
  }

  /// Récupère l'historique des paiements d'un client depuis l'API
  Future<List<dynamic>?> getCustomerPaymentsHistory(String customerId) async {
    if (_apiService == null) return null;

    try {
      final apiResponse = await _apiService
          .getCustomerPayments(customerId)
          .timeout(const Duration(seconds: 5));

      if (apiResponse.success && apiResponse.data != null) {
        return apiResponse.data;
      }
    } catch (e) {
      Logger.error(
        'Erreur lors de la récupération de l\'historique des paiements',
        error: e,
      );
    }

    return null;
  }

  /// Récupère les statistiques d'un client depuis l'API
  Future<Map<String, dynamic>?> getCustomerStats(String customerId) async {
    if (_apiService == null) return null;

    try {
      final apiResponse = await _apiService
          .getCustomerStats(customerId)
          .timeout(const Duration(seconds: 5));

      if (apiResponse.success && apiResponse.data != null) {
        return apiResponse.data;
      }
    } catch (e) {
      Logger.error(
        'Erreur lors de la récupération des statistiques client',
        error: e,
      );
    }

    return null;
  }

  /// Méthode helper pour fusionner les clients API avec local
  Future<void> _mergeCustomers(List<Customer> apiCustomers) async {
    for (final apiCustomer in apiCustomers) {
      await _customersBox.put(apiCustomer.id, apiCustomer);
    }

    // Forcer la persistance immédiate
    await _customersBox.flush();
    Logger.info(
      '💾 [CustomerRepository] Cache mis à jour avec ${apiCustomers.length} clients',
    );
  }

  /// Vide le cache local des clients
  Future<void> clearLocalCache() async {
    await _customersBox.clear();
    Logger.info('🗑️ [CustomerRepository] Cache local vidé');
  }
}
