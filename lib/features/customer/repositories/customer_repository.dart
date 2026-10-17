import 'package:wanzo/core/exceptions/api_exceptions.dart' as api;
import 'dart:async';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../services/customer_api_service.dart';
import '../../sales/repositories/sales_repository.dart';
import '../../../core/utils/logger.dart';

/// Repository pour la gestion des clients (API-First + Offline Fallback)
class CustomerRepository {
  // 'customers' (le mobile utilise 'customersBox') : nom propre au desktop,
  // partagé avec hive_setup et sync_service. Ne pas le renommer, ce serait
  // perdre les fiches déjà enregistrées sur les postes.
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
        // Le serveur ne renvoie que 10 clients par défaut : sans pagination la
        // liste s'arrêtait aux 10 derniers créés dès qu'on était en ligne.
        final fromApi = await _fetchAllPages();
        if (fromApi.isNotEmpty) {
          Logger.info(
            '📦 [CustomerRepository] API: ${fromApi.length} clients récupérés',
          );
          // Fusionner avec le cache local (sans écraser une saisie en attente).
          await _mergeCustomers(fromApi);
          // Les fiches créées hors ligne, pas encore connues du serveur,
          // restent visibles (sinon elles disparaissaient de la liste).
          final ids = fromApi.map((c) => c.id).toSet();
          final pendingLocal = _customersBox.values
              .where((c) => c.syncStatus == 'pending' && !ids.contains(c.id))
              .toList();
          // Après fusion, le cache porte la bonne version : modification
          // locale pas encore envoyée, ou copie serveur avec la photo locale.
          final shown = fromApi.map((c) => _customersBox.get(c.id) ?? c);
          return [...pendingLocal, ...shown];
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
          // Une modification locale pas encore envoyée prime.
          if (localCustomer != null && _isPendingSync(localCustomer)) {
            return localCustomer;
          }
          final fresh = _withLocalPhoto(apiResponse.data!, localCustomer);
          await _customersBox.put(id, fresh);
          return fresh;
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
          // Sauvegarder la version serveur localement (photo locale gardée).
          final created = _withLocalPhoto(apiResponse.data!, newCustomer);
          await _customersBox.put(created.id, created);
          Logger.info(
            '✅ [CustomerRepository] Client créé via API: ${created.id}',
          );
          return created;
        }
      } catch (e) {
        // Refus du serveur (validation, droits) : on le dit. Avant, toute
        // erreur finissait en copie locale marquée « synchronisée » : succès
        // affiché, fiche jamais envoyée ni rejouée.
        if (!isConnectivityFailure(e)) throw Exception(describeFailure(e));
        Logger.error(
          '⚠️ [CustomerRepository] Hors ligne, client conservé pour la synchro',
          error: e,
        );
      }
    }

    // Hors ligne : conservé sur l'appareil, envoyé par la synchro (« pending »).
    final pending = newCustomer.copyWith(syncStatus: 'pending');
    await _customersBox.put(pending.id, pending);
    return pending;
  }

  /// Met à jour un client existant (API + Local)
  Future<Customer> updateCustomer(Customer customer) async {
    final local = _customersBox.get(customer.id);
    // Fiche jamais envoyée : le serveur ne la connaît pas (PATCH = 404). On
    // modifie la copie locale, la synchro l'enverra en création.
    if (local?.syncStatus == 'pending') {
      final pending = customer.copyWith(syncStatus: 'pending');
      await _customersBox.put(pending.id, pending);
      return pending;
    }
    if (_apiService != null) {
      try {
        final apiResponse = await _apiService
            .updateCustomer(customer.id, customer)
            .timeout(const Duration(seconds: 10));
        if (apiResponse.success && apiResponse.data != null) {
          final updated = _withLocalPhoto(apiResponse.data!, customer);
          await _customersBox.put(updated.id, updated);
          Logger.info(
            '✅ [CustomerRepository] Client mis à jour via API: ${updated.id}',
          );
          return updated;
        }
      } on api.OfflineQueuedException {
        // La modification est dans la file HTTP et sera rejouée : la copie
        // locale la reflète, sans la marquer à renvoyer une seconde fois.
        final queued = customer.copyWith(syncStatus: local?.syncStatus ?? 'synced');
        await _customersBox.put(queued.id, queued);
        return queued;
      } catch (e) {
        if (!isConnectivityFailure(e)) throw Exception(describeFailure(e));
        Logger.error(
          '⚠️ [CustomerRepository] Hors ligne, modification conservée',
          error: e,
        );
      }
    }

    // Hors ligne : modification conservée, renvoyée par la synchro.
    final pending = customer.copyWith(syncStatus: 'pending_update');
    await _customersBox.put(pending.id, pending);
    return pending;
  }

  /// Vrai quand l'échec vient du réseau (rien n'a été refusé par le serveur).
  static bool isConnectivityFailure(Object e) {
    if (e is TimeoutException) return true;
    if (e is api.NetworkException) return true;
    if (e is api.ApiException) {
      final code = e.statusCode;
      return code == null || code == 408 || code == 429 || code >= 500;
    }
    return false;
  }

  /// Message lisible d'un refus serveur.
  static String describeFailure(Object e) =>
      e is api.ApiException ? e.message : '$e'.replaceFirst('Exception: ', '');

  /// La photo d'un client reste sur l'appareil (jamais envoyée) : la copie
  /// serveur, sans photo, ne doit pas l'effacer du cache.
  static Customer _withLocalPhoto(Customer server, Customer? local) {
    final serverPhoto = server.profilePicture ?? '';
    final localPhoto = local?.profilePicture ?? '';
    if (serverPhoto.isEmpty && localPhoto.isNotEmpty) {
      return server.copyWith(profilePicture: localPhoto);
    }
    return server;
  }

  static bool _isPendingSync(Customer c) =>
      c.syncStatus == 'pending' || c.syncStatus == 'pending_update';

  /// Liste complète des clients, page par page (le serveur en sert 10 par
  /// défaut). Une page en erreur interrompt sans rien perdre de ce qui précède.
  Future<List<Customer>> _fetchAllPages() async {
    const pageSize = 200;
    const maxPages = 50;
    final all = <Customer>[];
    for (var page = 1; page <= maxPages; page++) {
      final response = await _apiService!
          .getCustomers(page: page, limit: pageSize)
          .timeout(const Duration(seconds: 10));
      final data = response.data;
      if (!response.success || data == null) break;
      all.addAll(data);
      if (data.length < pageSize) break;
    }
    return all;
  }

  /// Supprime un client (API + Local)
  Future<void> deleteCustomer(String id) async {
    // Fiche créée hors ligne et jamais envoyée : rien à demander au serveur.
    if (_customersBox.get(id)?.syncStatus == 'pending') {
      await _customersBox.delete(id);
      return;
    }
    // Le serveur D'ABORD : un refus (historique de ventes ou de dépenses) ou
    // une coupure doit être dit à l'utilisateur. Avant, l'erreur était avalée
    // et la fiche supprimée localement réapparaissait au prochain sync.
    if (_apiService != null) {
      try {
        await _apiService.deleteCustomer(id).timeout(const Duration(seconds: 10));
      } on api.ApiException catch (e) {
        // 404 : fiche jamais envoyée au serveur (créée hors ligne).
        if (e.statusCode != 404) {
          if (e is api.NetworkException || e is api.TimeoutException || e.statusCode == null) {
            throw Exception('Connexion requise pour supprimer un client.');
          }
          throw Exception(e.message);
        }
      } on TimeoutException {
        throw Exception('Connexion requise pour supprimer un client.');
      }
    }
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
      // Une modification locale en attente d'envoi n'est pas écrasée.
      final local = _customersBox.get(apiCustomer.id);
      if (local != null && _isPendingSync(local)) continue;
      await _customersBox.put(apiCustomer.id, _withLocalPhoto(apiCustomer, local));
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
