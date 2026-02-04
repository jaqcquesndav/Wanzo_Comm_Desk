// filepath: lib/features/business_unit/bloc/business_unit_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/business_unit_repository.dart';
import '../models/business_unit.dart';
import 'business_unit_event.dart';
import 'business_unit_state.dart';

/// BLoC pour gérer les unités d'affaires
class BusinessUnitBloc extends Bloc<BusinessUnitEvent, BusinessUnitState> {
  final BusinessUnitRepository _repository;

  /// Unité courante mise en cache
  BusinessUnit? _currentUnit;

  BusinessUnitBloc({required BusinessUnitRepository repository})
    : _repository = repository,
      super(const BusinessUnitInitial()) {
    on<LoadBusinessUnits>(_onLoadBusinessUnits);
    on<LoadBusinessUnitHierarchy>(_onLoadHierarchy);
    on<LoadCurrentBusinessUnit>(_onLoadCurrentUnit);
    on<SelectBusinessUnit>(_onSelectBusinessUnit);
    on<ConfigureBusinessUnitByCode>(_onConfigureByCode);
    on<LoadBusinessUnitById>(_onLoadById);
    on<CreateBusinessUnit>(_onCreateBusinessUnit);
    on<UpdateBusinessUnit>(_onUpdateBusinessUnit);
    on<DeleteBusinessUnit>(_onDeleteBusinessUnit);
    on<LoadBusinessUnitChildren>(_onLoadChildren);
    on<ResetToDefaultBusinessUnit>(_onResetToDefault);
    on<SyncBusinessUnits>(_onSyncBusinessUnits);
  }

  /// Getter pour l'unité courante
  BusinessUnit? get currentUnit => _currentUnit;

  /// Charge les business units
  Future<void> _onLoadBusinessUnits(
    LoadBusinessUnits event,
    Emitter<BusinessUnitState> emit,
  ) async {
    emit(const BusinessUnitLoading());

    try {
      final units = await _repository.fetchAndSyncBusinessUnits(
        type: event.type,
        parentId: event.parentId,
        search: event.search,
        includeInactive: event.includeInactive,
      );

      emit(BusinessUnitsLoaded(units: units, currentUnit: _currentUnit));
    } catch (e) {
      emit(BusinessUnitError(message: 'Erreur lors du chargement: $e'));
    }
  }

  /// Charge la hiérarchie complète
  Future<void> _onLoadHierarchy(
    LoadBusinessUnitHierarchy event,
    Emitter<BusinessUnitState> emit,
  ) async {
    emit(const BusinessUnitLoading());

    try {
      final hierarchy = await _repository.fetchHierarchy();

      if (hierarchy != null) {
        emit(
          BusinessUnitHierarchyLoaded(
            hierarchy: hierarchy,
            currentUnit: _currentUnit,
          ),
        );
      } else {
        emit(
          const BusinessUnitError(
            message: 'Impossible de charger la hiérarchie',
          ),
        );
      }
    } catch (e) {
      emit(
        BusinessUnitError(
          message: 'Erreur lors du chargement de la hiérarchie: $e',
        ),
      );
    }
  }

  /// Charge l'unité courante de l'utilisateur
  Future<void> _onLoadCurrentUnit(
    LoadCurrentBusinessUnit event,
    Emitter<BusinessUnitState> emit,
  ) async {
    emit(const BusinessUnitLoading());

    try {
      final unit = await _repository.fetchCurrentBusinessUnit();

      if (unit != null) {
        _currentUnit = unit;
        await _repository.setCurrentBusinessUnitLocal(unit);

        emit(
          CurrentBusinessUnitLoaded(
            currentUnit: unit,
            isDefault: unit.isCompany,
          ),
        );
      } else {
        // Fallback sur l'unité locale
        final localUnit = await _repository.getCurrentBusinessUnitLocal();
        if (localUnit != null) {
          _currentUnit = localUnit;
          emit(
            CurrentBusinessUnitLoaded(
              currentUnit: localUnit,
              isDefault: localUnit.isCompany,
            ),
          );
        } else {
          emit(
            const BusinessUnitError(message: 'Aucune unité courante trouvée'),
          );
        }
      }
    } catch (e) {
      emit(BusinessUnitError(message: 'Erreur: $e'));
    }
  }

  /// Sélectionne une unité comme unité active
  Future<void> _onSelectBusinessUnit(
    SelectBusinessUnit event,
    Emitter<BusinessUnitState> emit,
  ) async {
    try {
      _currentUnit = event.unit;
      await _repository.setCurrentBusinessUnitLocal(event.unit);

      emit(
        BusinessUnitSelected(
          unit: event.unit,
          message: 'Unité "${event.unit.name}" sélectionnée',
        ),
      );

      emit(
        CurrentBusinessUnitLoaded(
          currentUnit: event.unit,
          isDefault: event.unit.isCompany,
        ),
      );
    } catch (e) {
      emit(BusinessUnitError(message: 'Erreur lors de la sélection: $e'));
    }
  }

  /// Configure une unité via son code
  Future<void> _onConfigureByCode(
    ConfigureBusinessUnitByCode event,
    Emitter<BusinessUnitState> emit,
  ) async {
    emit(const BusinessUnitLoading());

    try {
      final unit = await _repository.fetchBusinessUnitByCode(event.code);

      if (unit != null) {
        _currentUnit = unit;
        await _repository.setCurrentBusinessUnitLocal(unit);

        emit(
          BusinessUnitConfiguredByCode(
            unit: unit,
            message: 'Configuration réussie pour ${unit.name}',
          ),
        );

        emit(CurrentBusinessUnitLoaded(currentUnit: unit, isDefault: false));
      } else {
        emit(
          BusinessUnitError(
            message: 'Code "${event.code}" non trouvé',
            errorCode: 'NOT_FOUND',
          ),
        );
      }
    } catch (e) {
      emit(BusinessUnitError(message: 'Erreur de configuration: $e'));
    }
  }

  /// Charge une unité par son ID
  Future<void> _onLoadById(
    LoadBusinessUnitById event,
    Emitter<BusinessUnitState> emit,
  ) async {
    emit(const BusinessUnitLoading());

    try {
      final unit = await _repository.fetchBusinessUnitById(event.id);

      if (unit != null) {
        emit(BusinessUnitsLoaded(units: [unit], currentUnit: _currentUnit));
      } else {
        emit(const BusinessUnitError(message: 'Unité non trouvée'));
      }
    } catch (e) {
      emit(BusinessUnitError(message: 'Erreur: $e'));
    }
  }

  /// Crée une nouvelle unité
  Future<void> _onCreateBusinessUnit(
    CreateBusinessUnit event,
    Emitter<BusinessUnitState> emit,
  ) async {
    emit(const BusinessUnitLoading());

    try {
      final unit = await _repository.createBusinessUnit(
        code: event.code,
        name: event.name,
        type: event.type,
        parentId: event.parentId,
        address: event.address,
        city: event.city,
        province: event.province,
        country: event.country,
        phone: event.phone,
        email: event.email,
        manager: event.manager,
        managerId: event.managerId,
        currency: event.currency,
        settings: event.settings,
        metadata: event.metadata,
      );

      if (unit != null) {
        emit(
          BusinessUnitCreated(
            unit: unit,
            message: 'Unité "${unit.name}" créée avec succès',
          ),
        );
      } else {
        emit(const BusinessUnitError(message: 'Échec de la création'));
      }
    } catch (e) {
      emit(BusinessUnitError(message: 'Erreur lors de la création: $e'));
    }
  }

  /// Met à jour une unité
  Future<void> _onUpdateBusinessUnit(
    UpdateBusinessUnit event,
    Emitter<BusinessUnitState> emit,
  ) async {
    emit(const BusinessUnitLoading());

    try {
      final unit = await _repository.updateBusinessUnit(
        event.id,
        name: event.name,
        status: event.status,
        address: event.address,
        city: event.city,
        province: event.province,
        country: event.country,
        phone: event.phone,
        email: event.email,
        manager: event.manager,
        managerId: event.managerId,
        currency: event.currency,
        settings: event.settings,
        metadata: event.metadata,
      );

      if (unit != null) {
        // Mettre à jour l'unité courante si c'est la même
        if (_currentUnit?.id == unit.id) {
          _currentUnit = unit;
          await _repository.setCurrentBusinessUnitLocal(unit);
        }

        emit(
          BusinessUnitUpdated(
            unit: unit,
            message: 'Unité mise à jour avec succès',
          ),
        );
      } else {
        emit(const BusinessUnitError(message: 'Échec de la mise à jour'));
      }
    } catch (e) {
      emit(BusinessUnitError(message: 'Erreur lors de la mise à jour: $e'));
    }
  }

  /// Supprime une unité
  Future<void> _onDeleteBusinessUnit(
    DeleteBusinessUnit event,
    Emitter<BusinessUnitState> emit,
  ) async {
    emit(const BusinessUnitLoading());

    try {
      await _repository.deleteBusinessUnit(event.id);

      // Si c'était l'unité courante, revenir à l'entreprise par défaut
      if (_currentUnit?.id == event.id) {
        _currentUnit = null;
        add(const LoadCurrentBusinessUnit());
      }

      emit(
        BusinessUnitDeleted(
          unitId: event.id,
          message: 'Unité supprimée avec succès',
        ),
      );
    } catch (e) {
      emit(BusinessUnitError(message: 'Erreur lors de la suppression: $e'));
    }
  }

  /// Charge les enfants d'une unité
  Future<void> _onLoadChildren(
    LoadBusinessUnitChildren event,
    Emitter<BusinessUnitState> emit,
  ) async {
    emit(const BusinessUnitLoading());

    try {
      final children = await _repository.fetchChildren(event.parentId);

      emit(
        BusinessUnitChildrenLoaded(
          parentId: event.parentId,
          children: children,
        ),
      );
    } catch (e) {
      emit(
        BusinessUnitError(message: 'Erreur lors du chargement des enfants: $e'),
      );
    }
  }

  /// Réinitialise à l'unité entreprise par défaut
  Future<void> _onResetToDefault(
    ResetToDefaultBusinessUnit event,
    Emitter<BusinessUnitState> emit,
  ) async {
    emit(const BusinessUnitLoading());

    try {
      // Cherche l'entreprise principale (niveau 0)
      final units = await _repository.getAllLocalBusinessUnits();
      final companyUnit = units.firstWhere(
        (unit) => unit.isCompany,
        orElse: () => units.first,
      );

      _currentUnit = companyUnit;
      await _repository.setCurrentBusinessUnitLocal(companyUnit);

      emit(
        CurrentBusinessUnitLoaded(currentUnit: companyUnit, isDefault: true),
      );
    } catch (e) {
      emit(
        BusinessUnitError(message: 'Erreur lors de la réinitialisation: $e'),
      );
    }
  }

  /// Synchronise les business units avec le serveur
  Future<void> _onSyncBusinessUnits(
    SyncBusinessUnits event,
    Emitter<BusinessUnitState> emit,
  ) async {
    emit(const BusinessUnitSyncing());

    try {
      final units = await _repository.fetchAndSyncBusinessUnits();

      emit(
        BusinessUnitSynced(
          syncedCount: units.length,
          message: '${units.length} unités synchronisées',
        ),
      );

      emit(BusinessUnitsLoaded(units: units, currentUnit: _currentUnit));
    } catch (e) {
      emit(BusinessUnitError(message: 'Erreur de synchronisation: $e'));
    }
  }
}
