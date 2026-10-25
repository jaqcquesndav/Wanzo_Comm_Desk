// filepath: lib/features/business_unit/services/business_unit_api_service.dart
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/features/auth/services/auth0_service.dart';
import '../models/business_unit.dart';

/// Service API pour la gestion des unités d'affaires.
///
/// Passe par [ApiClient] (jeton, disjoncteur, file hors ligne) : l'ancien
/// service appelait `http` directement, une création ou une modification
/// d'unité faite hors ligne était perdue sans le dire.
class BusinessUnitApiService {
  final ApiClient _api;

  BusinessUnitApiService({Auth0Service? auth0Service, ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();

  static dynamic _data(dynamic res) {
    dynamic d = res is Map ? res['data'] ?? res : res;
    return d;
  }

  static List<BusinessUnit> _list(dynamic res) {
    dynamic d = _data(res);
    if (d is Map && d['data'] is List) d = d['data'];
    if (d is Map && d['items'] is List) d = d['items'];
    return (d is List ? d : const [])
        .whereType<Map>()
        .map((e) => BusinessUnit.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static BusinessUnit _one(dynamic res) =>
      BusinessUnit.fromJson(Map<String, dynamic>.from(_data(res) as Map));

  /// Récupère toutes les unités d'affaires
  ///
  /// [type] - Filtrer par type: company, branch, pos
  /// [parentId] - Filtrer par ID de l'unité parente
  /// [search] - Recherche par nom ou code
  /// [status] - Filtrer par statut
  /// [includeInactive] - Inclure les unités inactives
  Future<List<BusinessUnit>> getBusinessUnits({
    String? type,
    String? parentId,
    String? search,
    String? status,
    bool includeInactive = false,
  }) async {
    final queryParams = <String, String>{};
    if (type != null) queryParams['type'] = type;
    if (parentId != null) queryParams['parentId'] = parentId;
    if (search != null) queryParams['search'] = search;
    if (status != null) queryParams['status'] = status;
    if (includeInactive) queryParams['includeInactive'] = 'true';

    final res = await _api.get(
      'business-units',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
      requiresAuth: true,
    );
    return _list(res);
  }

  /// Récupère la hiérarchie complète de l'entreprise
  Future<BusinessUnitHierarchy> getHierarchy() async {
    final res = await _api.get('business-units/hierarchy', requiresAuth: true);
    return BusinessUnitHierarchy.fromJson(
      Map<String, dynamic>.from(_data(res) as Map),
    );
  }

  /// Récupère l'unité courante de l'utilisateur
  Future<BusinessUnit> getCurrentBusinessUnit() async {
    return _one(await _api.get('business-units/current', requiresAuth: true));
  }

  /// Récupère une unité par son ID
  Future<BusinessUnit> getBusinessUnitById(String id) async {
    return _one(await _api.get('business-units/$id', requiresAuth: true));
  }

  /// Récupère une unité par son code
  Future<BusinessUnit> getBusinessUnitByCode(String code) async {
    return _one(
      await _api.get('business-units/code/$code', requiresAuth: true),
    );
  }

  /// Crée une nouvelle unité d'affaires
  Future<BusinessUnit> createBusinessUnit({
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
    final body = {
      'code': code,
      'name': name,
      'type': type,
      if (parentId != null) 'parentId': parentId,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (province != null) 'province': province,
      if (country != null) 'country': country,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (manager != null) 'manager': manager,
      if (managerId != null) 'managerId': managerId,
      if (currency != null) 'currency': currency,
      if (settings != null) 'settings': settings,
      if (metadata != null) 'metadata': metadata,
    };

    // Hors ligne : mise en file par le client (OfflineQueuedException).
    return _one(
      await _api.post('business-units', body: body, requiresAuth: true),
    );
  }

  /// Met à jour une unité d'affaires
  Future<BusinessUnit> updateBusinessUnit(
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
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (status != null) body['status'] = status;
    if (address != null) body['address'] = address;
    if (city != null) body['city'] = city;
    if (province != null) body['province'] = province;
    if (country != null) body['country'] = country;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (manager != null) body['manager'] = manager;
    if (managerId != null) body['managerId'] = managerId;
    if (currency != null) body['currency'] = currency;
    if (settings != null) body['settings'] = settings;
    if (metadata != null) body['metadata'] = metadata;

    return _one(
      await _api.put('business-units/$id', body: body, requiresAuth: true),
    );
  }

  /// Supprime une unité d'affaires (soft delete)
  Future<void> deleteBusinessUnit(String id) async {
    await _api.delete('business-units/$id', requiresAuth: true);
  }

  /// Récupère les unités enfants d'une unité
  Future<List<BusinessUnit>> getChildren(String parentId) async {
    return _list(
      await _api.get('business-units/$parentId/children', requiresAuth: true),
    );
  }

  /// Récupère le chemin vers l'entreprise
  Future<List<BusinessUnit>> getPathToCompany(String unitId) async {
    return _list(
      await _api.get(
        'business-units/$unitId/path-to-company',
        requiresAuth: true,
      ),
    );
  }
}
