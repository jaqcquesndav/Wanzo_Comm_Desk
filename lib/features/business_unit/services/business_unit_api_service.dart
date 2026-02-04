// filepath: lib/features/business_unit/services/business_unit_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wanzo/config/environment.dart';
import 'package:wanzo/features/auth/services/auth0_service.dart';
import '../models/business_unit.dart';

/// Service API pour la gestion des unités d'affaires
class BusinessUnitApiService {
  final String _baseUrl = Environment.commerceApiBaseUrl;
  final Auth0Service _auth0Service;

  BusinessUnitApiService({required Auth0Service auth0Service})
    : _auth0Service = auth0Service;

  /// Headers avec authentification
  Future<Map<String, String>> get _authHeaders async {
    final token = await _auth0Service.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

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

    final uri = Uri.parse(
      '$_baseUrl/business-units',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(uri, headers: await _authHeaders);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> items = data['data'] ?? [];
      return items.map((item) => BusinessUnit.fromJson(item)).toList();
    } else {
      throw Exception(
        'Erreur lors de la récupération des unités: ${response.statusCode}',
      );
    }
  }

  /// Récupère la hiérarchie complète de l'entreprise
  Future<BusinessUnitHierarchy> getHierarchy() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/business-units/hierarchy'),
      headers: await _authHeaders,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return BusinessUnitHierarchy.fromJson(data['data']);
    } else {
      throw Exception(
        'Erreur lors de la récupération de la hiérarchie: ${response.statusCode}',
      );
    }
  }

  /// Récupère l'unité courante de l'utilisateur
  Future<BusinessUnit> getCurrentBusinessUnit() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/business-units/current'),
      headers: await _authHeaders,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return BusinessUnit.fromJson(data['data']);
    } else {
      throw Exception(
        'Erreur lors de la récupération de l\'unité courante: ${response.statusCode}',
      );
    }
  }

  /// Récupère une unité par son ID
  Future<BusinessUnit> getBusinessUnitById(String id) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/business-units/$id'),
      headers: await _authHeaders,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return BusinessUnit.fromJson(data['data']);
    } else if (response.statusCode == 404) {
      throw Exception('Unité d\'affaires non trouvée');
    } else {
      throw Exception(
        'Erreur lors de la récupération de l\'unité: ${response.statusCode}',
      );
    }
  }

  /// Récupère une unité par son code
  Future<BusinessUnit> getBusinessUnitByCode(String code) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/business-units/code/$code'),
      headers: await _authHeaders,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return BusinessUnit.fromJson(data['data']);
    } else if (response.statusCode == 404) {
      throw Exception('Unité d\'affaires avec le code $code non trouvée');
    } else {
      throw Exception(
        'Erreur lors de la récupération de l\'unité: ${response.statusCode}',
      );
    }
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

    final response = await http.post(
      Uri.parse('$_baseUrl/business-units'),
      headers: await _authHeaders,
      body: json.encode(body),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return BusinessUnit.fromJson(data['data']);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['message'] ?? 'Erreur lors de la création de l\'unité',
      );
    }
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

    final response = await http.put(
      Uri.parse('$_baseUrl/business-units/$id'),
      headers: await _authHeaders,
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return BusinessUnit.fromJson(data['data']);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['message'] ?? 'Erreur lors de la mise à jour de l\'unité',
      );
    }
  }

  /// Supprime une unité d'affaires (soft delete)
  Future<void> deleteBusinessUnit(String id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/business-units/$id'),
      headers: await _authHeaders,
    );

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['message'] ?? 'Erreur lors de la suppression de l\'unité',
      );
    }
  }

  /// Récupère les unités enfants d'une unité
  Future<List<BusinessUnit>> getChildren(String parentId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/business-units/$parentId/children'),
      headers: await _authHeaders,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> items = data['data'] ?? [];
      return items.map((item) => BusinessUnit.fromJson(item)).toList();
    } else {
      throw Exception(
        'Erreur lors de la récupération des unités enfants: ${response.statusCode}',
      );
    }
  }

  /// Récupère le chemin vers l'entreprise
  Future<List<BusinessUnit>> getPathToCompany(String unitId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/business-units/$unitId/path-to-company'),
      headers: await _authHeaders,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> items = data['data'] ?? [];
      return items.map((item) => BusinessUnit.fromJson(item)).toList();
    } else {
      throw Exception(
        'Erreur lors de la récupération du chemin: ${response.statusCode}',
      );
    }
  }
}
