import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/supplier_repository.dart';
import 'supplier_event.dart';
import 'supplier_state.dart';

/// BLoC pour gérer les opérations sur les fournisseurs
class SupplierBloc extends Bloc<SupplierEvent, SupplierState> {
  /// Repository pour accéder aux données des fournisseurs
  final SupplierRepository supplierRepository;

  SupplierBloc({required this.supplierRepository})
    : super(const SupplierInitial()) {
    on<LoadSuppliers>(_onLoadSuppliers);
    on<LoadSupplier>(_onLoadSupplier);
    on<AddSupplier>(_onAddSupplier);
    on<UpdateSupplier>(_onUpdateSupplier);
    on<DeleteSupplier>(_onDeleteSupplier);
    on<SearchSuppliers>(_onSearchSuppliers);
    on<LoadTopSuppliers>(_onLoadTopSuppliers);
    on<LoadRecentSuppliers>(_onLoadRecentSuppliers);
    on<UpdateSupplierPurchaseTotal>(_onUpdateSupplierPurchaseTotal);
    on<LoadSupplierPurchases>(_onLoadSupplierPurchases);
    on<FilterSuppliersByCategoryEvent>(_onFilterSuppliersByCategory);
  }

  /// Gère le chargement de tous les fournisseurs
  Future<void> _onLoadSuppliers(
    LoadSuppliers event,
    Emitter<SupplierState> emit,
  ) async {
    emit(const SupplierLoading());

    try {
      final suppliers = await supplierRepository.getSuppliers();
      emit(SuppliersLoaded(suppliers));
    } catch (e) {
      emit(SupplierError('Erreur lors du chargement des fournisseurs: $e'));
    }
  }

  /// Gère le chargement d'un fournisseur spécifique
  Future<void> _onLoadSupplier(
    LoadSupplier event,
    Emitter<SupplierState> emit,
  ) async {
    emit(const SupplierLoading());

    try {
      final supplier = await supplierRepository.getSupplier(event.supplierId);
      if (supplier != null) {
        emit(SupplierLoaded(supplier));
      } else {
        emit(const SupplierError('Fournisseur non trouvé'));
      }
    } catch (e) {
      emit(SupplierError('Erreur lors du chargement du fournisseur: $e'));
    }
  }

  /// Gère l'ajout d'un nouveau fournisseur
  Future<void> _onAddSupplier(
    AddSupplier event,
    Emitter<SupplierState> emit,
  ) async {
    emit(const SupplierLoading());

    try {
      final newSupplier = await supplierRepository.addSupplier(event.supplier);
      emit(
        SupplierOperationSuccess(
          message: 'Fournisseur ajouté avec succès',
          supplier: newSupplier,
        ),
      );

      // Recharge la liste des fournisseurs après ajout
      add(const LoadSuppliers());
    } catch (e) {
      emit(SupplierError('Erreur lors de l\'ajout du fournisseur: $e'));
    }
  }

  /// Gère la mise à jour d'un fournisseur existant
  Future<void> _onUpdateSupplier(
    UpdateSupplier event,
    Emitter<SupplierState> emit,
  ) async {
    emit(const SupplierLoading());

    try {
      final updatedSupplier = await supplierRepository.updateSupplier(
        event.supplier,
      );
      emit(
        SupplierOperationSuccess(
          message: 'Fournisseur mis à jour avec succès',
          supplier: updatedSupplier,
        ),
      );

      // Recharge la liste des fournisseurs après mise à jour
      add(const LoadSuppliers());
    } catch (e) {
      emit(SupplierError('Erreur lors de la mise à jour du fournisseur: $e'));
    }
  }

  /// Gère la suppression d'un fournisseur
  Future<void> _onDeleteSupplier(
    DeleteSupplier event,
    Emitter<SupplierState> emit,
  ) async {
    emit(const SupplierLoading());

    try {
      await supplierRepository.deleteSupplier(event.supplierId);
      emit(
        const SupplierOperationSuccess(
          message: 'Fournisseur supprimé avec succès',
        ),
      );

      // Recharge la liste des fournisseurs après suppression
      add(const LoadSuppliers());
    } catch (e) {
      emit(SupplierError('Erreur lors de la suppression du fournisseur: $e'));
    }
  }

  /// Gère la recherche de fournisseurs
  Future<void> _onSearchSuppliers(
    SearchSuppliers event,
    Emitter<SupplierState> emit,
  ) async {
    emit(const SupplierLoading());

    try {
      if (event.searchTerm.isEmpty) {
        final allSuppliers = await supplierRepository.getSuppliers();
        emit(SuppliersLoaded(allSuppliers));
      } else {
        final searchResults = await supplierRepository.searchSuppliers(
          event.searchTerm,
        );
        emit(
          SupplierSearchResults(
            suppliers: searchResults,
            searchTerm: event.searchTerm,
          ),
        );
      }
    } catch (e) {
      emit(SupplierError('Erreur lors de la recherche de fournisseurs: $e'));
    }
  }

  /// Gère le chargement des principaux fournisseurs
  Future<void> _onLoadTopSuppliers(
    LoadTopSuppliers event,
    Emitter<SupplierState> emit,
  ) async {
    emit(const SupplierLoading());

    try {
      final topSuppliers = await supplierRepository.getTopSuppliers(
        limit: event.limit,
      );
      emit(TopSuppliersLoaded(topSuppliers));
    } catch (e) {
      emit(
        SupplierError(
          'Erreur lors du chargement des principaux fournisseurs: $e',
        ),
      );
    }
  }

  /// Gère le chargement des fournisseurs récents
  Future<void> _onLoadRecentSuppliers(
    LoadRecentSuppliers event,
    Emitter<SupplierState> emit,
  ) async {
    emit(const SupplierLoading());

    try {
      final recentSuppliers = await supplierRepository.getRecentSuppliers(
        limit: event.limit,
      );
      emit(RecentSuppliersLoaded(recentSuppliers));
    } catch (e) {
      emit(
        SupplierError('Erreur lors du chargement des fournisseurs récents: $e'),
      );
    }
  }

  /// Gère la mise à jour du total des achats auprès d'un fournisseur
  Future<void> _onUpdateSupplierPurchaseTotal(
    UpdateSupplierPurchaseTotal event,
    Emitter<SupplierState> emit,
  ) async {
    emit(const SupplierLoading());

    try {
      final updatedSupplier = await supplierRepository
          .updateSupplierPurchaseTotal(event.supplierId, event.amount);

      emit(
        SupplierOperationSuccess(
          message: 'Total des achats mis à jour avec succès',
          supplier: updatedSupplier,
        ),
      );
    } catch (e) {
      emit(
        SupplierError('Erreur lors de la mise à jour du total des achats: $e'),
      );
    }
  }

  /// Gère le chargement de l'historique des achats d'un fournisseur
  Future<void> _onLoadSupplierPurchases(
    LoadSupplierPurchases event,
    Emitter<SupplierState> emit,
  ) async {
    emit(const SupplierLoading());

    try {
      final purchases = await supplierRepository.getSupplierPurchases(
        event.supplierId,
      );
      emit(
        SupplierPurchasesLoaded(
          supplierId: event.supplierId,
          purchases: purchases,
        ),
      );
    } catch (e) {
      emit(SupplierError('Erreur lors du chargement de l\'historique: $e'));
    }
  }

  /// Gère le filtrage des fournisseurs par catégorie
  Future<void> _onFilterSuppliersByCategory(
    FilterSuppliersByCategoryEvent event,
    Emitter<SupplierState> emit,
  ) async {
    emit(const SupplierLoading());

    try {
      final allSuppliers = await supplierRepository.getSuppliers();
      final filteredSuppliers =
          allSuppliers
              .where((supplier) => supplier.category == event.category)
              .toList();
      emit(
        SupplierFilteredByCategory(
          suppliers: filteredSuppliers,
          category: event.category,
        ),
      );
    } catch (e) {
      emit(SupplierError('Erreur lors du filtrage par catégorie: $e'));
    }
  }
}
