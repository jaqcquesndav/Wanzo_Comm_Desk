// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\sales\repositories\sales_repository.dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/sale.dart';
import '../services/sales_api_service.dart';
import '../../../core/utils/logger.dart';
// Import SaleItem and SaleItemType

/// Repository pour la gestion des ventes (Offline-First + API Sync)
class SalesRepository {
  static const _salesBoxName = 'sales';
  late final Box<Sale> _salesBox;
  final _uuid = const Uuid();
  final SalesApiService? _apiService;

  SalesRepository({SalesApiService? apiService}) : _apiService = apiService;

  /// Initialisation du repository
  Future<void> init() async {
    _salesBox = await Hive.openBox<Sale>(_salesBoxName);
  }

  /// Récupérer toutes les ventes (Offline-First)
  Future<List<Sale>> getAllSales({bool syncWithApi = false}) async {
    // 1. Lire les données locales d'abord
    final localSales = _salesBox.values.toList();

    // 2. Si sync activé et API disponible, fusionner avec les données API
    if (syncWithApi && _apiService != null) {
      try {
        final apiResponse = await _apiService.getSales().timeout(
          const Duration(seconds: 5),
        );
        if (apiResponse.success && apiResponse.data != null) {
          // Fusionner les données API avec local
          await _mergeSales(apiResponse.data!);
          return _salesBox.values.toList();
        }
      } catch (e) {
        // Fallback sur données locales en cas d'erreur réseau
        Logger.error(
          'Erreur sync API (getAllSales) - Utilisation des données locales',
          error: e,
        );
      }
    }

    return localSales;
  }

  /// Récupérer les ventes filtrées par statut
  Future<List<Sale>> getSalesByStatus(SaleStatus status) async {
    return _salesBox.values.where((sale) => sale.status == status).toList();
  }

  /// Récupérer une vente par son ID
  Future<Sale?> getSaleById(String id) async {
    return _salesBox.values.firstWhere((sale) => sale.id == id);
  }

  /// Récupérer les ventes d'un client
  Future<List<Sale>> getSalesByCustomer(String customerId) async {
    return _salesBox.values
        .where((sale) => sale.customerId == customerId)
        .toList();
  }

  /// Récupérer les ventes d'une période donnée
  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end) async {
    final allSales = _salesBox.values.toList();
    Logger.info(
      '📊 getSalesByDateRange: Total dans la box: ${allSales.length}',
    );
    Logger.info('📊 getSalesByDateRange: Période demandée: $start à $end');

    if (allSales.isEmpty) {
      Logger.warning('⚠️ getSalesByDateRange: La box "sales" est VIDE!');
    } else {
      // Log quelques dates de ventes pour débug
      final sampleDates =
          allSales.take(5).map((s) => s.date.toString()).toList();
      Logger.info('📊 Exemples de dates de ventes: $sampleDates');
    }

    final filteredSales =
        allSales
            .where(
              (sale) =>
                  sale.date.isAfter(start) &&
                  sale.date.isBefore(end.add(const Duration(days: 1))),
            )
            .toList();

    Logger.info(
      '📊 getSalesByDateRange: ${filteredSales.length} ventes après filtrage',
    );
    return filteredSales;
  }

  /// Ajouter une nouvelle vente
  Future<Sale> addSale(Sale sale) async {
    final newSaleId = _uuid.v4();
    final newSale = Sale(
      id: newSaleId, // Use the generated ID
      localId: newSaleId, // Track as local ID for sync
      date: sale.date,
      customerId: sale.customerId,
      customerName: sale.customerName,
      items:
          sale.items.map((item) {
            // La mise à jour du stock est maintenant gérée dans le SalesBloc
            return item;
          }).toList(),
      totalAmountInCdf: sale.totalAmountInCdf,
      paidAmountInCdf: sale.paidAmountInCdf,
      paymentMethod: sale.paymentMethod,
      status: sale.status,
      notes: sale.notes,
      transactionCurrencyCode: sale.transactionCurrencyCode,
      transactionExchangeRate: sale.transactionExchangeRate,
      totalAmountInTransactionCurrency: sale.totalAmountInTransactionCurrency,
      paidAmountInTransactionCurrency: sale.paidAmountInTransactionCurrency,
      syncStatus: 'pending', // Mark as pending sync
    );

    // 1. Save locally first (offline-first)
    await _salesBox.put(newSale.id, newSale);
    Logger.info('💾 Vente sauvegardée localement avec ID: ${newSale.id}');

    // 2. Try to sync with API
    if (_apiService != null) {
      try {
        Logger.info(
          '🌐 Tentative de synchronisation de la vente avec l\'API...',
        );
        final apiResponse = await _apiService
            .createSale(newSale)
            .timeout(const Duration(seconds: 10));

        if (apiResponse.success && apiResponse.data != null) {
          final createdSaleFromApi = apiResponse.data!;
          Logger.info(
            '✅ Vente synchronisée avec l\'API. Server ID: ${createdSaleFromApi.id}',
          );

          // Update local record with server ID and mark as synced
          final syncedSale = newSale.copyWith(
            id: createdSaleFromApi.id,
            syncStatus: 'synced',
          );

          // Replace local entry with synced version using server ID
          await _salesBox.put(createdSaleFromApi.id, syncedSale);
          if (newSaleId != createdSaleFromApi.id) {
            // Remove the entry with local ID if different
            await _salesBox.delete(newSaleId);
          }

          return syncedSale;
        } else {
          Logger.warning(
            '⚠️ API sync failed: ${apiResponse.message}. Sale remains local.',
          );
        }
      } catch (e) {
        Logger.error(
          '❌ Erreur sync API (addSale) - Vente reste en local',
          error: e,
        );
      }
    } else {
      Logger.info(
        'ℹ️ API service non disponible, vente sauvegardée localement',
      );
    }

    return newSale;
  }

  /// Mettre à jour une vente existante
  Future<void> updateSale(Sale sale) async {
    // 1. Update locally first
    final saleToSave = sale.copyWith(syncStatus: 'pending');
    await _salesBox.put(sale.id, saleToSave);
    Logger.info('💾 Vente mise à jour localement: ${sale.id}');

    // 2. Try to sync with API
    if (_apiService != null) {
      try {
        final apiResponse = await _apiService
            .updateSale(sale.id, sale)
            .timeout(const Duration(seconds: 10));

        if (apiResponse.success && apiResponse.data != null) {
          final updatedSaleFromApi = apiResponse.data!;
          final syncedSale = updatedSaleFromApi.copyWith(syncStatus: 'synced');
          await _salesBox.put(sale.id, syncedSale);
          Logger.info('✅ Mise à jour synchronisée avec l\'API: ${sale.id}');
        } else {
          Logger.warning(
            '⚠️ API sync failed for update: ${apiResponse.message}',
          );
        }
      } catch (e) {
        Logger.error('❌ Erreur sync API (updateSale)', error: e);
      }
    }
  }

  /// Supprimer une vente
  Future<void> deleteSale(String id) async {
    // 1. Delete locally first
    await _salesBox.delete(id);
    Logger.info('💾 Vente supprimée localement: $id');

    // 2. Try to delete from API
    if (_apiService != null) {
      try {
        final apiResponse = await _apiService
            .deleteSale(id)
            .timeout(const Duration(seconds: 10));

        if (apiResponse.success) {
          Logger.info('✅ Suppression synchronisée avec l\'API: $id');
        } else {
          Logger.warning(
            '⚠️ API sync failed for delete: ${apiResponse.message}',
          );
        }
      } catch (e) {
        Logger.error('❌ Erreur sync API (deleteSale)', error: e);
      }
    }
  }

  /// Calculer le total des ventes d'une période
  Future<double> calculateTotalSales(DateTime start, DateTime end) async {
    final sales = await getSalesByDateRange(start, end);
    return sales.fold<double>(
      0,
      (total, sale) => total + sale.totalAmountInCdf,
    ); // Use CDF field
  }

  /// Calculer le nombre de ventes
  Future<int> getSalesCount() async {
    return _salesBox.length;
  }

  /// Calculer le total des montants à recevoir (ventes non entièrement payées)
  Future<double> getTotalReceivables() async {
    final sales = _salesBox.values.where(
      (sale) =>
          sale.status == SaleStatus.pending ||
          (sale.status == SaleStatus.partiallyPaid &&
              sale.paidAmountInCdf < sale.totalAmountInCdf), // Use CDF fields
    );
    return sales.fold<double>(
      0,
      (total, sale) => total + (sale.totalAmountInCdf - sale.paidAmountInCdf),
    ); // Use CDF fields
  }

  /// Synchronise les ventes locales avec le backend
  Future<void> syncLocalSalesToBackend() async {
    if (_apiService == null) {
      Logger.info('API service non disponible pour la synchronisation');
      return;
    }

    try {
      final localSales = _salesBox.values.toList();
      if (localSales.isEmpty) return;

      final apiResponse = await _apiService
          .syncSales(localSales)
          .timeout(const Duration(seconds: 10));

      if (apiResponse.success && apiResponse.data != null) {
        Logger.info(
          'Synchronisation réussie: ${apiResponse.data!.length} ventes synchronisées',
        );
        // Mettre à jour les ventes locales avec les données du serveur
        await _mergeSales(apiResponse.data!);
      }
    } catch (e) {
      Logger.error('Erreur lors de la synchronisation des ventes', error: e);
    }
  }

  /// Récupère les statistiques de ventes depuis l'API
  Future<Map<String, dynamic>?> getSalesStats({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    if (_apiService == null) return null;

    try {
      final apiResponse = await _apiService
          .getSalesStats(dateFrom: dateFrom, dateTo: dateTo)
          .timeout(const Duration(seconds: 5));

      if (apiResponse.success && apiResponse.data != null) {
        return apiResponse.data;
      }
    } catch (e) {
      Logger.error('Erreur lors de la récupération des statistiques', error: e);
    }

    return null;
  }

  /// Méthode helper pour fusionner les ventes API avec local
  Future<void> _mergeSales(List<Sale> apiSales) async {
    for (final apiSale in apiSales) {
      // Vérifier si la vente existe déjà localement
      final existingIndex = _salesBox.values.toList().indexWhere(
        (s) => s.id == apiSale.id,
      );

      if (existingIndex >= 0) {
        // Mettre à jour la vente existante
        await _salesBox.put(apiSale.id, apiSale);
      } else {
        // Ajouter la nouvelle vente du backend
        await _salesBox.put(apiSale.id, apiSale);
      }
    }

    // Forcer la persistance immédiate
    await _salesBox.flush();
  }

  /// Vider le cache local des ventes (à utiliser lors du changement de business unit)
  Future<void> clearLocalCache() async {
    await _salesBox.clear();
    Logger.info('Cache local des ventes vidé');
  }
}
