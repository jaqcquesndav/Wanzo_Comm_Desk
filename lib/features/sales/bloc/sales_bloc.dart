// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\sales\bloc\sales_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart'; // Pour debugPrint
import '../models/sale.dart';
import '../models/sale_item.dart'; // Ensure SaleItem and SaleItemType are imported
import '../repositories/sales_repository.dart';
import '../services/sale_dto.dart';
import '../../../core/models/operation_payment.dart';
import '../../dashboard/models/operation_journal_entry.dart';
import '../../dashboard/bloc/operation_journal_bloc.dart'; // Imports events too
import '../../dashboard/repositories/operation_journal_repository.dart'; // Pour accéder au repository directement
import '../../inventory/repositories/inventory_repository.dart'; // Ajout pour la gestion du stock
import '../../inventory/models/stock_transaction.dart'; // Ajout pour les transactions de stock
import 'package:uuid/uuid.dart';
import 'package:wanzo/features/cash_session/cash_session_hooks.dart';

part 'sales_event.dart';
part 'sales_state.dart';

/// État chargé : ventes actives (seules comptées dans le total) et ventes
/// annulées à part.
@visibleForTesting
SalesLoaded salesLoadedFrom(Iterable<Sale> all) {
  final active = <Sale>[];
  final cancelled = <Sale>[];
  for (final s in all) {
    (s.isCancelled ? cancelled : active).add(s);
  }
  return SalesLoaded(
    sales: active,
    totalAmountInCdf: active.fold(0.0, (t, s) => t + s.totalAmountInCdf),
    cancelledSales: cancelled,
  );
}

/// Bloc gérant l'état des ventes
class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final SalesRepository _salesRepository;
  final OperationJournalBloc _operationJournalBloc;
  final OperationJournalRepository
  _journalRepository; // Accès direct au repository journal
  final InventoryRepository
  _inventoryRepository; // Ajout du repository d'inventaire
  final _uuid =
      const Uuid(); // Pour générer des IDs pour les entrées de journal

  SalesBloc({
    required SalesRepository salesRepository,
    required OperationJournalBloc operationJournalBloc,
    required OperationJournalRepository journalRepository,
    required InventoryRepository inventoryRepository, // Nouveau paramètre
  }) : _salesRepository = salesRepository,
       _operationJournalBloc = operationJournalBloc,
       _journalRepository = journalRepository,
       _inventoryRepository = inventoryRepository,
       super(const SalesInitial()) {
    on<LoadSales>(_onLoadSales);
    on<LoadSalesByStatus>(_onLoadSalesByStatus);
    on<LoadSalesByCustomer>(_onLoadSalesByCustomer);
    on<LoadSalesByDateRange>(_onLoadSalesByDateRange);
    on<AddSale>(_onAddSale);
    on<UpdateSale>(_onUpdateSale);
    on<UpdateSaleStatus>(_onUpdateSaleStatus);
    on<RecordSalePayment>(_onRecordSalePayment);
    on<CancelSale>(_onCancelSale);
    on<RestoreSale>(_onRestoreSale);
  }

  /// Enregistrer une tranche de règlement sur une créance client.
  Future<void> _onRecordSalePayment(
    RecordSalePayment event,
    Emitter<SalesState> emit,
  ) async {
    emit(const SalesLoading());
    try {
      final outcome = await _salesRepository.recordPayment(
        event.sale,
        event.payment,
      );
      await CashSessionHooks.onSalePayment(event.sale, event.payment);

      // Encaissement au journal des opérations : seule la tranche réellement
      // encaissée impacte la trésorerie (le chiffre d'affaires a déjà été
      // enregistré à la création de la vente).
      try {
        final shortId = event.sale.id.substring(
          0,
          event.sale.id.length >= 6 ? 6 : event.sale.id.length,
        );
        await _journalRepository.addOperation(
          OperationJournalEntry(
            id: _uuid.v4(),
            date: event.payment.paidAt,
            description: 'Encaissement - Vente #$shortId',
            type: OperationType.cashIn,
            amount: event.payment.amountInCdf,
            relatedDocumentId: event.sale.id,
            paymentMethod: event.payment.method,
            currencyCode: 'CDF', // montant en CDF
            isDebit: true,
            isCredit: false,
            balanceAfter: 0,
            customerId: event.sale.customerId,
            customerName: event.sale.customerName,
          ),
        );
        _operationJournalBloc.add(const RefreshJournal());
      } catch (journalError) {
        debugPrint('ERREUR journal (encaissement vente): $journalError');
      }

      emit(
        SalePaymentRecorded(
          sale: outcome.sale,
          synced: outcome.synced,
          message: outcome.message,
        ),
      );
      add(const LoadSales());
    } catch (e) {
      emit(
        SalesError(
          'Le paiement n\'a pas pu être enregistré: '
          '${e is StateError ? e.message : e.toString()}',
        ),
      );
    }
  }

  /// Charger toutes les ventes
  Future<void> _onLoadSales(LoadSales event, Emitter<SalesState> emit) async {
    emit(const SalesLoading());
    try {
      final all = await _salesRepository.getAllSales(
        syncWithApi: true,
        includeCancelled: true,
      );
      emit(salesLoadedFrom(all));
    } catch (e) {
      emit(SalesError(e.toString()));
    }
  }

  /// Charger les ventes par statut
  Future<void> _onLoadSalesByStatus(
    LoadSalesByStatus event,
    Emitter<SalesState> emit,
  ) async {
    emit(const SalesLoading());
    try {
      final sales = await _salesRepository.getSalesByStatus(event.status);
      // Filtre « Annulées » : la liste les montre, leur total ne compte pas.
      final totalAmountInCdf = SalesRepository.activeOnly(sales).fold(
        0.0,
        (total, sale) => total + sale.totalAmountInCdf,
      );
      emit(SalesLoaded(sales: sales, totalAmountInCdf: totalAmountInCdf));
    } catch (e) {
      emit(SalesError(e.toString()));
    }
  }

  /// Charger les ventes d'un client
  Future<void> _onLoadSalesByCustomer(
    LoadSalesByCustomer event,
    Emitter<SalesState> emit,
  ) async {
    emit(const SalesLoading());
    try {
      final sales = await _salesRepository.getSalesByCustomer(event.customerId);
      final totalAmountInCdf = sales.fold(
        0.0,
        (total, sale) => total + sale.totalAmountInCdf,
      );
      emit(SalesLoaded(sales: sales, totalAmountInCdf: totalAmountInCdf));
    } catch (e) {
      emit(SalesError(e.toString()));
    }
  }

  /// Charger les ventes par période
  Future<void> _onLoadSalesByDateRange(
    LoadSalesByDateRange event,
    Emitter<SalesState> emit,
  ) async {
    debugPrint('🔄 SalesBloc: LoadSalesByDateRange appelé');
    debugPrint('📅 Période: ${event.startDate} → ${event.endDate}');
    emit(const SalesLoading());
    try {
      final sales = await _salesRepository.getSalesByDateRange(
        event.startDate,
        event.endDate,
      );
      debugPrint(
        '📊 SalesBloc: ${sales.length} ventes récupérées du repository',
      );
      final totalAmountInCdf = sales.fold(
        0.0,
        (total, sale) => total + sale.totalAmountInCdf,
      );
      debugPrint('💰 SalesBloc: Total = $totalAmountInCdf CDF');
      emit(SalesLoaded(sales: sales, totalAmountInCdf: totalAmountInCdf));
    } catch (e) {
      debugPrint('❌ SalesBloc: Erreur - $e');
      emit(SalesError(e.toString()));
    }
  }

  /// Ajouter une nouvelle vente
  /// Ventes en cours d'enregistrement, par localId : un second AddSale de la
  /// même vente (double appui) est ignoré.
  final Set<String> _addingLocalIds = {};

  Future<void> _onAddSale(AddSale event, Emitter<SalesState> emit) async {
    final localId = event.sale.localId;
    if (localId != null && localId.isNotEmpty) {
      if (!_addingLocalIds.add(localId)) {
        debugPrint("Vente $localId déjà en cours d'envoi, second appui ignoré");
        return;
      }
    }
    try {
      await _addSale(event, emit);
    } finally {
      if (localId != null) _addingLocalIds.remove(localId);
    }
  }

  Future<void> _addSale(AddSale event, Emitter<SalesState> emit) async {
    try {
      // 1. D'abord, enregistrer la vente
      // Le moyen de l'acompte voyage avec la vente (envoyé au serveur).
      final Sale savedSale = await _salesRepository.addSale(
        saleWithDownPaymentMethod(event.sale, event.downPaymentMethod),
      );
      // Caisse ouverte : la vente y est rattachée (rien si elle est fermée).
      await CashSessionHooks.onSale(
        savedSale,
        downPaymentMethod: event.downPaymentMethod,
      );

      // 2. Préparer les entrées du journal d'opérations
      final List<OperationJournalEntry> journalEntries = [];

      // Construire une description détaillée avec les noms des produits
      final itemNames = savedSale.items
          .map((i) => "${i.quantity}x ${i.productName}")
          .join(", ");
      String saleDescription =
          'Vente #${savedSale.id.substring(0, 6)} - ${savedSale.customerName}';
      if (itemNames.isNotEmpty) {
        saleDescription += " ($itemNames)";
      }

      debugPrint(
        'Préparation des entrées du journal pour la vente: ${savedSale.id}',
      );

      // Déterminer le type d'opération de vente
      OperationType saleType;
      if (savedSale.paymentMethod?.toLowerCase().contains('crédit') ?? false) {
        saleType = OperationType.saleCredit;
      } else if (savedSale.paymentMethod?.toLowerCase().contains('échelonné') ??
          false) {
        saleType = OperationType.saleInstallment;
      } else {
        saleType = OperationType.saleCash;
      }

      // === ENREGISTREMENT DE LA VENTE (Chiffre d'affaires) ===
      // Cette opération enregistre le revenu de la vente dans le journal des ventes
      // Elle N'IMPACTE PAS la trésorerie directement
      journalEntries.add(
        OperationJournalEntry(
          id: _uuid.v4(),
          date: savedSale.date,
          description: saleDescription,
          type: saleType,
          amount: savedSale.totalAmountInCdf, // Montant de la vente
          relatedDocumentId: savedSale.id,
          currencyCode: 'CDF', // montant en CDF : la devise doit suivre
          isDebit: false, // Revenus = crédit en comptabilité
          isCredit: true,
          balanceAfter: 0, // Sera calculé par le repository
          customerId: savedSale.customerId,
          customerName: savedSale.customerName,
        ),
      );

      // === ENCAISSEMENT (Impact trésorerie uniquement) ===
      // SEULEMENT si un paiement est effectué (comptant ou partiel)
      // Pour les ventes à crédit pur, il n'y a PAS d'encaissement immédiat
      if (savedSale.paidAmountInCdf > 0) {
        // Acompte d'une vente à crédit compris, avec son propre moyen.
        final encaisse = saleCashJournalAmount(savedSale);
        journalEntries.add(
          OperationJournalEntry(
            id: _uuid.v4(),
            date: savedSale.date,
            description:
                'Encaissement - Vente #${savedSale.id.substring(0, 6)}',
            type: OperationType.cashIn,
            // Montant réellement encaissé, dans la devise remise (10 USD
            // restent 10 USD dans la vue Caisse, pas 28 000 CDF).
            amount: encaisse.amount,
            // Moyen réel : la vue Caisse du journal ne retient que les
            // espèces. L'acompte d'une vente à crédit suit le moyen saisi
            // pour l'acompte (espèces par défaut).
            paymentMethod:
                saleType == OperationType.saleCash
                    ? savedSale.paymentMethod
                    : cashMethodOfSale(
                      savedSale,
                      downPaymentMethod: event.downPaymentMethod,
                    ),
            relatedDocumentId: savedSale.id,
            currencyCode: encaisse.currency,
            isDebit: true, // Caisse = actif donc débit pour augmentation
            isCredit: false,
            balanceAfter: 0, // Sera calculé par le repository
            customerId: savedSale.customerId,
            customerName: savedSale.customerName,
          ),
        );
      }

      // Enregistrer les sorties de stock pour chaque article vendu
      for (var item in savedSale.items) {
        // Traiter uniquement les produits (pas les services) avec un productId valide
        if (item.itemType == SaleItemType.product && item.productId != null) {
          final productId = item.productId!;
          // 1. Récupérer le produit pour obtenir le coût unitaire
          try {
            final product = _inventoryRepository.getProductById(productId);
            if (product != null) {
              // === SORTIE DE STOCK (Coût des marchandises vendues - COGS) ===
              // Cette opération enregistre la diminution de la valeur du stock
              // Elle N'IMPACTE PAS la trésorerie (c'est un mouvement de stock)
              final cogsAmount = product.costPriceInCdf * item.quantity;

              // Ne créer l'écriture COGS que si le prix d'achat est connu.
              // Sinon `costPriceInCdf == 0` produisait une opération à montant 0
              // par article dans le journal (parité mobile).
              if (cogsAmount > 0) {
                journalEntries.add(
                  OperationJournalEntry(
                    id: _uuid.v4(),
                    date: savedSale.date,
                    description:
                        'Sortie stock: ${item.quantity} x ${item.productName} (Vente #${savedSale.id.substring(0, 6)})',
                    type: OperationType.stockOut,
                    amount:
                        -cogsAmount, // Négatif = diminution de la valeur du stock
                    relatedDocumentId: savedSale.id,
                    quantity: item.quantity.toDouble(),
                    productId: productId,
                    productName: item.productName,
                    // Montant = costPriceInCdf x quantité : il est en CDF.
                    currencyCode: 'CDF',
                    isDebit: true, // COGS = charge (débit)
                    isCredit: false,
                    balanceAfter: 0, // Sera calculé par le repository
                  ),
                );
              }

              // 2. Mise à jour du stock dans l'inventaire
              // Créer une transaction de stock négative (sortie de stock)
              final stockTransaction = StockTransaction(
                id: _uuid.v4(),
                productId: productId,
                type: StockTransactionType.sale, // Type de transaction = vente
                quantity:
                    -item.quantity
                        .toDouble(), // Quantité négative car c'est une sortie (convertie en double)
                date: savedSale.date,
                referenceId: savedSale.id, // Référence à la vente
                notes:
                    'Vente #${savedSale.id.substring(0, 6)} - ${savedSale.customerName}',
                unitCostInCdf:
                    product.costPriceInCdf, // Coût unitaire du produit
                totalValueInCdf:
                    product.costPriceInCdf *
                    item.quantity.toDouble(), // Valeur totale
              );

              // Décrément LOCAL uniquement : le backend décrémente déjà le stock
              // à la création de la vente (évite le DOUBLE décrément).
              await _inventoryRepository.addStockTransaction(stockTransaction);
              debugPrint(
                'Stock mis à jour pour le produit $productId: -${item.quantity}',
              );
            } else {
              debugPrint('⚠️ Produit non trouvé: ${item.productId}');
            }
          } catch (e) {
            debugPrint('⚠️ Erreur lors de la mise à jour du stock: $e');
            // Ne pas bloquer le processus de vente si la mise à jour du stock échoue
            // On considère que la vente est prioritaire sur la cohérence du stock
          }
        }
      }

      // 3. Envoyer les entrées au journal d'opérations et attendre que le traitement soit terminé
      debugPrint(
        'Ajout de ${journalEntries.length} entrées au journal des opérations',
      );
      try {
        // Première tentative : utilisation directe du repository via le bloc
        await _operationJournalBloc.repository.addOperationEntries(
          journalEntries,
        );
        debugPrint('Entrées ajoutées au journal avec succès');

        // Ensuite, notifier le bloc du journal pour qu'il rafraîchisse son état
        _operationJournalBloc.add(const RefreshJournal());

        // 4. Enfin, émettre l'état de succès et rafraîchir la liste des ventes
        emit(
          SalesOperationSuccess(
            'Vente ajoutée avec succès et enregistrée dans le journal des opérations',
            saleId: savedSale.id,
            possibleDuplicateOf: savedSale.possibleDuplicateOf,
          ),
        );
        add(const LoadSales());
      } catch (journalError) {
        debugPrint(
          'ERREUR lors de l\'ajout au journal des opérations via bloc: $journalError',
        );

        // Deuxième tentative : utilisation du repository injecté directement
        try {
          await _journalRepository.addOperationEntries(journalEntries);
          debugPrint(
            'Entrées ajoutées au journal avec succès (méthode de secours)',
          );

          // Toujours essayer de rafraîchir le bloc
          _operationJournalBloc.add(const RefreshJournal());

          emit(
            SalesOperationSuccess(
              'Vente ajoutée avec succès et enregistrée dans le journal des opérations',
              saleId: savedSale.id,
              possibleDuplicateOf: savedSale.possibleDuplicateOf,
            ),
          );
        } catch (secondError) {
          debugPrint(
            'ERREUR CRITIQUE: Impossible d\'ajouter au journal: $secondError',
          );
          // Même en cas d'erreur du journal, on considère la vente comme réussie
          // mais on informe l'utilisateur du problème
          emit(
            SalesOperationSuccess(
              'Vente ajoutée avec succès, mais problème d\'enregistrement dans le journal des opérations',
              saleId: savedSale.id,
              possibleDuplicateOf: savedSale.possibleDuplicateOf,
            ),
          );
        }

        add(const LoadSales());
      }
    } catch (e) {
      emit(SalesError('Erreur lors de l\'ajout de la vente: ${e.toString()}'));
    }
  }

  /// Mettre à jour une vente
  Future<void> _onUpdateSale(UpdateSale event, Emitter<SalesState> emit) async {
    emit(const SalesLoading());
    try {
      await _salesRepository.updateSale(event.sale);
      emit(const SalesOperationSuccess('Vente mise à jour avec succès'));
      add(const LoadSales());
    } catch (e) {
      emit(SalesError(e.toString()));
    }
  }

  /// Annuler une vente : elle est conservée au statut annulé, jamais effacée.
  ///
  /// Le serveur rétablit le stock et les règlements et informe la
  /// comptabilité. Sur l'appareil, à la PREMIÈRE annulation seulement : stock
  /// local rendu, encaissement contre-passé dans sa caisse (même clôturée),
  /// écritures du journal contre-passées.
  Future<void> _onCancelSale(CancelSale event, Emitter<SalesState> emit) async {
    try {
      final before =
          await _salesRepository.getSaleById(event.sale.id) ?? event.sale;
      final wasCancelled = before.isCancelled;
      final outcome = await _salesRepository.cancelSale(
        before,
        event.reason,
        actorName: event.actorName,
        actorId: event.actorId,
      );
      if (!wasCancelled) {
        await _adjustLocalStock(before, restock: true);
        await cashSessionOnSaleCancelled(before);
        await _reverseJournal(before);
      }
      emit(
        SaleCancellationDone(
          sale: outcome.document,
          synced: outcome.synced,
          message: outcome.message,
        ),
      );
      add(const LoadSales());
    } catch (e) {
      emit(SalesError(e is StateError ? e.message : e.toString()));
    }
  }

  /// Rétablir une vente annulée : le stock local est de nouveau sorti et les
  /// écritures du journal reprises. La caisse n'est pas retouchée : le
  /// serveur fait foi pour la trésorerie.
  Future<void> _onRestoreSale(
    RestoreSale event,
    Emitter<SalesState> emit,
  ) async {
    try {
      final before =
          await _salesRepository.getSaleById(event.sale.id) ?? event.sale;
      final outcome = await _salesRepository.restoreSale(
        before,
        reason: event.reason,
      );
      var message = outcome.message;
      if (before.isCancelled) {
        await _adjustLocalStock(before, restock: false);
        // Encaissement repris dans la caisse ouverte, sinon signalé.
        final enCaisse = await cashSessionOnSaleRestored(outcome.document);
        if (!enCaisse) {
          message = '$message Encaissement à reprendre en caisse.';
        }
        try {
          await _journalRepository.reinstateDocument({
            before.id,
            before.localId,
          });
          _operationJournalBloc.add(const RefreshJournal());
        } catch (e) {
          debugPrint('⚠️ Journal non repris pour la vente rétablie: $e');
        }
      }
      emit(
        SaleCancellationDone(
          sale: outcome.document,
          synced: outcome.synced,
          message: message,
          restored: true,
        ),
      );
      add(const LoadSales());
    } catch (e) {
      emit(SalesError(e is StateError ? e.message : e.toString()));
    }
  }

  /// Stock LOCAL des produits de la vente : rendu à l'annulation, de nouveau
  /// sorti au rétablissement (cache local seulement). Le serveur fait le même
  /// mouvement de son côté.
  Future<void> _adjustLocalStock(Sale sale, {required bool restock}) async {
    final shortId = sale.id.length >= 8 ? sale.id.substring(0, 8) : sale.id;
    for (final item in sale.items) {
      final productId = item.productId;
      if (productId == null || item.itemType != SaleItemType.product) continue;
      try {
        await _inventoryRepository.addStockTransaction(
          StockTransaction(
            id: _uuid.v4(),
            productId: productId,
            type:
                restock
                    ? StockTransactionType.adjustment
                    : StockTransactionType.sale,
            quantity:
                restock
                    ? item.quantity.toDouble()
                    : -item.quantity.toDouble(),
            date: DateTime.now(),
            referenceId: sale.id,
            notes:
                restock
                    ? 'Stock rendu, vente annulée #$shortId'
                    : 'Vente rétablie #$shortId',
            unitCostInCdf: item.unitPriceInCdf,
            totalValueInCdf: item.unitPriceInCdf * item.quantity,
          ),
        );
      } catch (e) {
        debugPrint('⚠️ Stock local non ajusté pour ${item.productId}: $e');
      }
    }
  }

  /// Contre-passe au journal les écritures de la vente (chiffre d'affaires,
  /// encaissement, sortie de stock) : elles sortent de tous les totaux.
  Future<void> _reverseJournal(Sale sale) async {
    try {
      await _journalRepository.reverseDocument({sale.id, sale.localId});
      _operationJournalBloc.add(const RefreshJournal());
    } catch (e) {
      debugPrint('⚠️ Journal non contre-passé pour la vente annulée: $e');
    }
  }

  /// Mettre à jour le statut d'une vente
  Future<void> _onUpdateSaleStatus(
    UpdateSaleStatus event,
    Emitter<SalesState> emit,
  ) async {
    // Une annulation passe par CancelSale : motif, trace et contre-passations.
    if (event.status == SaleStatus.cancelled) {
      emit(
        const SalesError(
          'Pour annuler une vente, utilisez « Annuler la vente » avec son motif.',
        ),
      );
      return;
    }
    emit(const SalesLoading());
    try {
      final sale = await _salesRepository.getSaleById(event.id);
      if (sale != null) {
        final updatedSale = sale.copyWith(status: event.status);

        await _salesRepository.updateSale(updatedSale);
        emit(
          const SalesOperationSuccess(
            'Statut de la vente mis à jour avec succès',
          ),
        );
        add(const LoadSales());
      } else {
        emit(const SalesError('Vente introuvable'));
      }
    } catch (e) {
      emit(SalesError(e.toString()));
    }
  }
}
