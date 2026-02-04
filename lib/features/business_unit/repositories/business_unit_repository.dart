// filepath: lib/features/business_unit/repositories/business_unit_repository.dart
import 'package:hive/hive.dart';
import '../models/business_unit.dart';
import '../services/business_unit_api_service.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';

/// Repository pour gérer les unités d'affaires (local + API)
class BusinessUnitRepository {
  static const _businessUnitsBoxName = 'businessUnitsBox';
  static const _currentUnitKey = 'current_business_unit';

  late Box<BusinessUnit> _businessUnitsBox;
  final BusinessUnitApiService? _apiService;

  BusinessUnitRepository({BusinessUnitApiService? apiService})
    : _apiService = apiService;

  /// Initialise le repository
  Future<void> init() async {
    _businessUnitsBox = await Hive.openBox<BusinessUnit>(_businessUnitsBoxName);
  }

  // ============= LOCAL STORAGE =============

  /// Sauvegarde une business unit localement
  Future<void> saveBusinessUnit(BusinessUnit unit) async {
    await _businessUnitsBox.put(unit.id, unit);
  }

  /// Récupère une business unit locale par ID
  Future<BusinessUnit?> getLocalBusinessUnit(String id) async {
    return _businessUnitsBox.get(id);
  }

  /// Récupère toutes les business units locales
  Future<List<BusinessUnit>> getAllLocalBusinessUnits() async {
    return _businessUnitsBox.values.toList();
  }

  /// Récupère l'unité courante stockée localement
  Future<BusinessUnit?> getCurrentBusinessUnitLocal() async {
    return _businessUnitsBox.get(_currentUnitKey);
  }

  /// Définit l'unité courante localement
  Future<void> setCurrentBusinessUnitLocal(BusinessUnit unit) async {
    await _businessUnitsBox.put(_currentUnitKey, unit);
  }

  /// Supprime une business unit locale
  Future<void> deleteLocalBusinessUnit(String id) async {
    await _businessUnitsBox.delete(id);
  }

  /// Efface toutes les business units locales
  Future<void> clearAllLocalBusinessUnits() async {
    await _businessUnitsBox.clear();
  }

  /// Sauvegarde plusieurs business units localement
  Future<void> saveAllBusinessUnits(List<BusinessUnit> units) async {
    final Map<String, BusinessUnit> unitMap = {
      for (var unit in units) unit.id: unit,
    };
    await _businessUnitsBox.putAll(unitMap);
  }

  /// Filtre les business units locales par type
  Future<List<BusinessUnit>> getLocalBusinessUnitsByType(
    BusinessUnitType type,
  ) async {
    return _businessUnitsBox.values.where((unit) => unit.type == type).toList();
  }

  /// Récupère les enfants d'une unité localement
  Future<List<BusinessUnit>> getLocalChildren(String parentId) async {
    return _businessUnitsBox.values
        .where((unit) => unit.parentId == parentId)
        .toList();
  }

  // ============= API OPERATIONS =============

  /// Récupère les business units depuis l'API et les synchronise localement
  Future<List<BusinessUnit>> fetchAndSyncBusinessUnits({
    String? type,
    String? parentId,
    String? search,
    String? status,
    bool includeInactive = false,
  }) async {
    final apiService = _apiService;
    if (apiService == null) {
      return getAllLocalBusinessUnits();
    }

    try {
      final units = await apiService.getBusinessUnits(
        type: type,
        parentId: parentId,
        search: search,
        status: status,
        includeInactive: includeInactive,
      );

      // Synchronise avec le stockage local
      await saveAllBusinessUnits(units);

      return units;
    } catch (e) {
      // En cas d'erreur, retourne les données locales
      return getAllLocalBusinessUnits();
    }
  }

  /// Récupère la hiérarchie complète depuis l'API
  Future<BusinessUnitHierarchy?> fetchHierarchy() async {
    final apiService = _apiService;
    if (apiService == null) return null;

    try {
      final hierarchy = await apiService.getHierarchy();
      // Synchronise toutes les unités de la hiérarchie
      await _syncHierarchyUnits(hierarchy);
      return hierarchy;
    } catch (e) {
      return null;
    }
  }

  /// Synchronise récursivement les unités de la hiérarchie
  Future<void> _syncHierarchyUnits(BusinessUnitHierarchy hierarchy) async {
    await saveBusinessUnit(hierarchy.unit);
    for (final child in hierarchy.children) {
      await _syncHierarchyUnits(child);
    }
  }

  /// Récupère l'unité courante depuis l'API
  Future<BusinessUnit?> fetchCurrentBusinessUnit() async {
    final apiService = _apiService;
    if (apiService == null) {
      return getCurrentBusinessUnitLocal();
    }

    try {
      final unit = await apiService.getCurrentBusinessUnit();
      await setCurrentBusinessUnitLocal(unit);
      await saveBusinessUnit(unit);
      return unit;
    } catch (e) {
      return getCurrentBusinessUnitLocal();
    }
  }

  /// Récupère une unité par ID depuis l'API
  Future<BusinessUnit?> fetchBusinessUnitById(String id) async {
    final apiService = _apiService;
    if (apiService == null) {
      return getLocalBusinessUnit(id);
    }

    try {
      final unit = await apiService.getBusinessUnitById(id);
      await saveBusinessUnit(unit);
      return unit;
    } catch (e) {
      return getLocalBusinessUnit(id);
    }
  }

  /// Récupère une unité par code depuis l'API
  Future<BusinessUnit?> fetchBusinessUnitByCode(String code) async {
    final apiService = _apiService;
    if (apiService == null) {
      // Recherche locale par code
      final units = await getAllLocalBusinessUnits();
      try {
        return units.firstWhere((unit) => unit.code == code);
      } catch (_) {
        return null;
      }
    }

    try {
      final unit = await apiService.getBusinessUnitByCode(code);
      await saveBusinessUnit(unit);
      return unit;
    } catch (e) {
      // Fallback sur recherche locale
      final units = await getAllLocalBusinessUnits();
      try {
        return units.firstWhere((unit) => unit.code == code);
      } catch (_) {
        return null;
      }
    }
  }

  /// Crée une nouvelle unité d'affaires via l'API
  Future<BusinessUnit?> createBusinessUnit({
    required String code,
    required String name,
    required String type,
    String? parentId,
    String? address,
    String? city,
    String? province,
    String? country,
    String? phone,
    String? email,
    String? manager,
    String? managerId,
    String? currency,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? metadata,
  }) async {
    final apiService = _apiService;
    if (apiService == null) {
      throw Exception('API service non disponible');
    }

    final unit = await apiService.createBusinessUnit(
      code: code,
      name: name,
      type: type,
      parentId: parentId,
      address: address,
      city: city,
      province: province,
      country: country,
      phone: phone,
      email: email,
      manager: manager,
      managerId: managerId,
      currency: currency,
      settings: settings,
      metadata: metadata,
    );

    await saveBusinessUnit(unit);
    return unit;
  }

  /// Met à jour une unité d'affaires via l'API
  Future<BusinessUnit?> updateBusinessUnit(
    String id, {
    String? name,
    String? status,
    String? address,
    String? city,
    String? province,
    String? country,
    String? phone,
    String? email,
    String? manager,
    String? managerId,
    String? currency,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? metadata,
  }) async {
    final apiService = _apiService;
    if (apiService == null) {
      throw Exception('API service non disponible');
    }

    final unit = await apiService.updateBusinessUnit(
      id,
      name: name,
      status: status,
      address: address,
      city: city,
      province: province,
      country: country,
      phone: phone,
      email: email,
      manager: manager,
      managerId: managerId,
      currency: currency,
      settings: settings,
      metadata: metadata,
    );

    await saveBusinessUnit(unit);
    return unit;
  }

  /// Supprime une unité d'affaires via l'API
  Future<void> deleteBusinessUnit(String id) async {
    final apiService = _apiService;
    if (apiService == null) {
      throw Exception('API service non disponible');
    }

    await apiService.deleteBusinessUnit(id);
    await deleteLocalBusinessUnit(id);
  }

  /// Récupère les enfants d'une unité depuis l'API
  Future<List<BusinessUnit>> fetchChildren(String parentId) async {
    final apiService = _apiService;
    if (apiService == null) {
      return getLocalChildren(parentId);
    }

    try {
      final children = await apiService.getChildren(parentId);
      await saveAllBusinessUnits(children);
      return children;
    } catch (e) {
      return getLocalChildren(parentId);
    }
  }

  /// Récupère le chemin vers l'entreprise
  Future<List<BusinessUnit>> fetchPathToCompany(String unitId) async {
    final apiService = _apiService;
    if (apiService == null) {
      return [];
    }

    try {
      return await apiService.getPathToCompany(unitId);
    } catch (e) {
      return [];
    }
  }

  // ============= UTILITAIRES =============

  /// Vérifie si une unité existe localement
  Future<bool> hasLocalBusinessUnit(String id) async {
    return _businessUnitsBox.containsKey(id);
  }

  /// Compte le nombre d'unités locales
  Future<int> getLocalBusinessUnitsCount() async {
    return _businessUnitsBox.length;
  }

  /// Vérifie si le repository est vide
  Future<bool> isEmpty() async {
    return _businessUnitsBox.isEmpty;
  }
}
