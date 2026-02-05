// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\sales\bloc\sales_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart'; // Pour debugPrint
import '../models/sale.dart';
import '../models/sale_item.dart'; // Ensure SaleItem and SaleItemType are imported
import '../repositories/sales_repository.dart';
import '../../dashboard/models/operation_journal_entry.dart';
import '../../dashboard/bloc/operation_journal_bloc.dart'; // Imports events too
import '../../dashboard/repositories/operation_journal_repository.dart'; // Pour accéder au repository directement
import '../../inventory/repositories/inventory_repository.dart'; // Ajout pour la gestion du stock
import '../../inventory/models/stock_transaction.dart'; // Ajout pour les transactions de stock
import 'package:uuid/uuid.dart';

part 'sales_event.dart';
part 'sales_state.dart';

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
    on<DeleteSale>(_onDeleteSale);
  }

  /// Charger toutes les ventes
  Future<void> _onLoadSales(LoadSales event, Emitter<SalesState> emit) async {
    emit(const SalesLoading());
    try {
      final sales = await _salesRepository.getAllSales();
      final totalAmountInCdf = sales.fold(
        0.0,
        (total, sale) => total + sale.totalAmountInCdf,
      );
      emit(SalesLoaded(sales: sales, totalAmountInCdf: totalAmountInCdf));
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
      final totalAmountInCdf = sales.fold(
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
  Future<void> _onAddSale(AddSale event, Emitter<SalesState> emit) async {
    try {
      // 1. D'abord, enregistrer la vente
      final Sale savedSale = await _salesRepository.addSale(event.sale);

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

      // Déterminer la devise de la vente
      String currencyCode = savedSale.currencyCode;

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
          currencyCode: currencyCode,
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
      if (savedSale.paidAmountInCdf > 0 &&
          saleType != OperationType.saleCredit) {
        journalEntries.add(
          OperationJournalEntry(
            id: _uuid.v4(),
            date: savedSale.date,
            description:
                'Encaissement - Vente #${savedSale.id.substring(0, 6)}',
            type: OperationType.cashIn,
            amount: savedSale.paidAmountInCdf, // Montant encaissé UNIQUEMENT
            relatedDocumentId: savedSale.id,
            currencyCode: currencyCode,
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
                  currencyCode: savedSale.currencyCode,
                  isDebit: true, // COGS = charge (débit)
                  isCredit: false,
                  balanceAfter: 0, // Sera calculé par le repository
                ),
              );

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

              // Ajouter la transaction au repository d'inventaire
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

  /// Supprimer une vente
  Future<void> _onDeleteSale(DeleteSale event, Emitter<SalesState> emit) async {
    emit(const SalesLoading());
    try {
      // Récupérer les détails de la vente avant de la supprimer pour restaurer l'inventaire
      final saleToDelete = await _salesRepository.getSaleById(event.id);

      if (saleToDelete == null) {
        emit(SalesError('Vente introuvable'));
        return;
      }

      // Restaurer l'inventaire des produits vendus
      if (saleToDelete.items.isNotEmpty) {
        for (final item in saleToDelete.items) {
          // Skip items without a productId
          if (item.productId == null) continue;
          final productId = item.productId!;
          try {
            // Créer une transaction d'ajustement pour remettre les produits en stock
            final stockTransaction = StockTransaction(
              id: const Uuid().v4(),
              productId: productId,
              type: StockTransactionType.adjustment,
              quantity: item.quantity.toDouble(), // Convertir en double
              date: DateTime.now(),
              notes:
                  'Stock restauré suite à suppression de la vente #${saleToDelete.id.substring(0, 8)}',
              unitCostInCdf:
                  item.unitPriceInCdf, // Utiliser le prix de vente comme référence
              totalValueInCdf: item.unitPriceInCdf * item.quantity,
            );

            await _inventoryRepository.addStockTransaction(stockTransaction);
          } catch (e) {
            if (kDebugMode) {
              print(
                'Erreur lors de la restauration du stock pour ${item.productId}: $e',
              );
            }
            // Continuer avec les autres produits même si une erreur se produit
          }
        }
      }

      // Supprimer la vente
      await _salesRepository.deleteSale(event.id);

      emit(
        const SalesOperationSuccess(
          'Vente supprimée avec succès et stock restauré',
        ),
      );
      add(const LoadSales());
    } catch (e) {
      emit(SalesError(e.toString()));
    }
  }

  /// Mettre à jour le statut d'une vente
  Future<void> _onUpdateSaleStatus(
    UpdateSaleStatus event,
    Emitter<SalesState> emit,
  ) async {
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
