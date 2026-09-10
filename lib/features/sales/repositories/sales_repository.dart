// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\sales\repositories\sales_repository.dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/sale.dart';
import '../services/sales_api_service.dart';
import '../../../core/models/operation_payment.dart';
import '../../../core/utils/logger.dart';
// Import SaleItem and SaleItemType

/// Résultat d'un règlement enregistré sur une vente.
class SalePaymentOutcome {
  /// Vente à jour (version serveur si synchronisée, sinon version locale).
  final Sale sale;

  /// `true` si le serveur a bien appliqué la tranche.
  final bool synced;

  /// Message à afficher à l'utilisateur.
  final String message;

  const SalePaymentOutcome({
    required this.sale,
    required this.synced,
    required this.message,
  });
}

/// Repository pour la gestion des ventes (Offline-First + API Sync)
class SalesRepository {
  static const _salesBoxName = 'sales';

  /// File d'attente des règlements saisis hors ligne. `sales/sync` ignore les
  /// ventes déjà connues du serveur : une tranche saisie hors ligne sur une
  /// vente déjà synchronisée ne partirait donc jamais sans cette file.
  static const _pendingPaymentsBoxName = 'pendingSalePayments';

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
        // Les règlements saisis hors ligne partent AVANT la relecture, sinon
        // la réponse serveur écraserait le cache optimiste local.
        await flushPendingPayments();
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
    try {
      return _salesBox.values.firstWhere((sale) => sale.id == id);
    } catch (_) {
      return null;
    }
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
      // Propager le telephone pour l'auto-creation du client (fidelite).
      customerPhoneNumber: sale.customerPhoneNumber,
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

          // Update local record with server ID and mark as synced.
          // On adopte AUSSI les lignes renvoyées par le serveur : sans cela,
          // les `SaleItem.id` restaient des identifiants locaux et le PATCH
          // suivant était rejeté (« SaleItem with ID not found in this sale »).
          final syncedSale = newSale.copyWith(
            id: createdSaleFromApi.id,
            items:
                createdSaleFromApi.items.isNotEmpty
                    ? createdSaleFromApi.items
                    : newSale.items,
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
  ///
  /// [includeItems] à `false` pour une mise à jour d'entête seule (règlement,
  /// statut) : les lignes ne partent pas, le stock n'est pas retouché.
  ///
  /// Lève une exception si le serveur a répondu mais n'a PAS appliqué la mise
  /// à jour : l'appelant doit pouvoir en informer l'utilisateur au lieu de
  /// fermer l'écran comme si tout allait bien. Une simple coupure réseau ne
  /// lève rien : la vente reste en `pending` et repart à la synchronisation.
  Future<void> updateSale(Sale sale, {bool includeItems = true}) async {
    // 1. Update locally first
    final saleToSave = sale.copyWith(syncStatus: _pendingStatusFor(sale));
    await _salesBox.put(sale.id, saleToSave);
    Logger.info('💾 Vente mise à jour localement: ${sale.id}');

    // 2. Try to sync with API
    if (_apiService != null) {
      try {
        final apiResponse = await _apiService
            .updateSale(sale.id, sale, includeItems: includeItems)
            .timeout(const Duration(seconds: 10));

        if (apiResponse.success && apiResponse.data != null) {
          final updatedSaleFromApi = apiResponse.data!;

          // GARDE ANTI-ÉCRASEMENT : si la réponse serveur ne reflète pas le
          // montant réglé qu'on vient d'envoyer, on ne remplace PAS le cache
          // optimiste par cette réponse (sinon le paiement « disparaît » de
          // l'écran alors que l'utilisateur vient de le saisir) et on signale
          // l'échec.
          if (updatedSaleFromApi.paidAmountInCdf + 0.01 <
              sale.paidAmountInCdf) {
            Logger.error(
              '❌ Le serveur n\'a pas appliqué le règlement '
              '(local=${sale.paidAmountInCdf} / serveur=${updatedSaleFromApi.paidAmountInCdf})',
            );
            throw StateError(
              'Le serveur n\'a pas enregistré le montant payé. '
              'La vente reste en attente de synchronisation.',
            );
          }

          final syncedSale = updatedSaleFromApi.copyWith(syncStatus: 'synced');
          await _salesBox.put(sale.id, syncedSale);
          Logger.info('✅ Mise à jour synchronisée avec l\'API: ${sale.id}');
        } else {
          Logger.warning(
            '⚠️ API sync failed for update: ${apiResponse.message}',
          );
          final reason = apiResponse.message ?? '';
          throw StateError(
            reason.isNotEmpty ? reason : 'Mise à jour refusée par le serveur.',
          );
        }
      } on StateError {
        rethrow;
      } catch (e) {
        // Réseau indisponible / timeout : la vente reste locale en `pending`.
        Logger.error('❌ Erreur sync API (updateSale)', error: e);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RÈGLEMENT EN PLUSIEURS TRANCHES
  // ══════════════════════════════════════════════════════════════════════════

  Future<Box> _pendingPaymentsBox() => Hive.openBox(_pendingPaymentsBoxName);

  /// Statut de synchronisation à poser lors d'une modification locale.
  ///
  /// Une vente DÉJÀ synchronisée doit repartir en `pending_update` : le
  /// service de synchronisation traite `pending` comme « à créer » et
  /// recréerait donc un DOUBLON côté backend. Seule une vente jamais
  /// transmise reste en `pending`.
  String _pendingStatusFor(Sale sale) =>
      sale.syncStatus == 'pending' ? 'pending' : 'pending_update';

  /// Enregistre une tranche de règlement sur une vente.
  ///
  /// Chemin nominal : `POST sales/:id/payments`, le serveur recalcule le cumulé
  /// et le statut. Repli si l'endpoint n'est pas disponible : PATCH d'entête
  /// avec le cumul. Repli hors ligne : application locale + mise en file.
  Future<SalePaymentOutcome> recordPayment(
    Sale sale,
    PaymentDraft payment,
  ) async {
    final amountInCdf = payment.amountInCdf;
    final newPaidInCdf = sale.paidAmountInCdf + amountInCdf;
    final newPaidInTxn =
        (sale.paidAmountInTransactionCurrency ?? 0.0) + payment.amount;
    final total = sale.totalAmountInCdf;
    final fullyPaid = newPaidInCdf + 0.01 >= total;

    // 1. Application optimiste locale (offline-first).
    final optimistic = sale.copyWith(
      paidAmountInCdf: newPaidInCdf > total ? total : newPaidInCdf,
      paidAmountInTransactionCurrency: newPaidInTxn,
      paymentMethod: payment.method,
      paymentReference:
          (payment.reference != null && payment.reference!.trim().isNotEmpty)
              ? payment.reference!.trim()
              : sale.paymentReference,
      status: fullyPaid ? SaleStatus.completed : SaleStatus.partiallyPaid,
      syncStatus: _pendingStatusFor(sale),
    );
    await _salesBox.put(sale.id, optimistic);

    if (_apiService == null) {
      await _enqueuePayment(sale.id, payment);
      return SalePaymentOutcome(
        sale: optimistic,
        synced: false,
        message: 'Paiement enregistré hors ligne, il sera synchronisé.',
      );
    }

    // 2. Endpoint dédié aux tranches.
    try {
      final response = await _apiService
          .recordSalePayment(sale.id, payment)
          .timeout(const Duration(seconds: 15));
      if (response.success && response.data != null) {
        final serverSale = response.data!;
        if (serverSale.paidAmountInCdf + 0.01 < newPaidInCdf) {
          // Le serveur a répondu sans appliquer la tranche : on garde la
          // version locale et on remonte l'erreur.
          throw StateError(
            'Le serveur n\'a pas enregistré la tranche de paiement.',
          );
        }
        await _salesBox.put(sale.id, serverSale.copyWith(syncStatus: 'synced'));
        return SalePaymentOutcome(
          sale: serverSale,
          synced: true,
          message: 'Paiement enregistré.',
        );
      }
      final reason = response.message ?? '';
      throw StateError(
        reason.isNotEmpty ? reason : 'Paiement refusé par le serveur.',
      );
    } on StateError {
      rethrow;
    } catch (e) {
      Logger.warning(
        '⚠️ Endpoint sales/:id/payments indisponible ($e) - repli sur PATCH',
      );
    }

    // 3. Repli : PATCH d'entête avec le cumul (sans les lignes).
    await updateSale(optimistic, includeItems: false);
    final stored = await getSaleById(sale.id);
    final result = stored ?? optimistic;
    final synced = result.syncStatus == 'synced';
    if (!synced) {
      await _enqueuePayment(sale.id, payment);
    }
    return SalePaymentOutcome(
      sale: result,
      synced: synced,
      message:
          synced
              ? 'Paiement enregistré.'
              : 'Paiement enregistré hors ligne, il sera synchronisé.',
    );
  }

  /// Liste les tranches de règlement d'une vente (vide si indisponible).
  Future<List<OperationPayment>> getSalePayments(String saleId) async {
    if (_apiService == null) return const <OperationPayment>[];
    try {
      return await _apiService
          .getSalePayments(saleId)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      Logger.warning('⚠️ Historique des règlements indisponible: $e');
      return const <OperationPayment>[];
    }
  }

  Future<void> _enqueuePayment(String saleId, PaymentDraft payment) async {
    try {
      final box = await _pendingPaymentsBox();
      await box.put(_uuid.v4(), <String, dynamic>{
        'saleId': saleId,
        ...payment.toRequestBody(),
      });
      Logger.info('🕓 Règlement mis en file pour la vente $saleId');
    } catch (e) {
      Logger.error('❌ Impossible de mettre le règlement en file', error: e);
    }
  }

  /// Rejoue les règlements saisis hors ligne. Appelé à chaque synchronisation.
  Future<void> flushPendingPayments() async {
    if (_apiService == null) return;
    Box box;
    try {
      box = await _pendingPaymentsBox();
    } catch (e) {
      Logger.error('❌ File des règlements inaccessible', error: e);
      return;
    }
    if (box.isEmpty) return;

    for (final key in box.keys.toList()) {
      final raw = box.get(key);
      if (raw is! Map) {
        await box.delete(key);
        continue;
      }
      final saleId = raw['saleId'] as String?;
      final amount = (raw['amount'] as num?)?.toDouble();
      if (saleId == null || amount == null || amount <= 0) {
        await box.delete(key);
        continue;
      }
      final draft = PaymentDraft(
        amount: amount,
        currencyCode: raw['currencyCode'] as String? ?? 'CDF',
        exchangeRate: (raw['exchangeRate'] as num?)?.toDouble(),
        method: raw['method'] as String? ?? 'Espèces',
        paidAt:
            DateTime.tryParse(raw['paidAt'] as String? ?? '') ?? DateTime.now(),
        reference: raw['reference'] as String?,
      );
      try {
        final response = await _apiService
            .recordSalePayment(saleId, draft)
            .timeout(const Duration(seconds: 15));
        if (response.success && response.data != null) {
          await _salesBox.put(
            saleId,
            response.data!.copyWith(syncStatus: 'synced'),
          );
          await box.delete(key);
          Logger.info('✅ Règlement en file synchronisé pour la vente $saleId');
        }
      } catch (e) {
        Logger.warning(
          '⚠️ Règlement en file non synchronisé (vente $saleId): $e',
        );
        // On garde l'entrée pour la prochaine tentative.
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
      // Règlements saisis hors ligne d'abord : `sales/sync` ignore les ventes
      // déjà connues du serveur, il ne les porterait donc jamais.
      await flushPendingPayments();

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
      final existing = _salesBox.get(apiSale.id);

      // GARDE ANTI-ÉCRASEMENT : un règlement encore en attente de
      // synchronisation ne doit pas être effacé par la version serveur, qui
      // ne le connaît pas encore.
      if (existing != null &&
          existing.syncStatus == 'pending' &&
          existing.paidAmountInCdf > apiSale.paidAmountInCdf + 0.01) {
        Logger.info(
          'ℹ️ Vente ${apiSale.id} conservée en local (règlement non encore synchronisé)',
        );
        continue;
      }

      await _salesBox.put(apiSale.id, apiSale);
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
