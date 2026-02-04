// filepath: lib/features/users/services/user_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wanzo/config/environment.dart';
import 'package:wanzo/features/auth/services/auth0_service.dart';
import '../models/app_user.dart';

/// Service API pour la gestion des utilisateurs
/// Conformité: Aligné avec users API (gestion_commerciale_service)
class UserApiService {
  final String _baseUrl = Environment.commerceApiBaseUrl;
  final Auth0Service _auth0Service;

  UserApiService({required Auth0Service auth0Service})
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

  // ============= PROFIL UTILISATEUR COURANT =============

  /// Récupère le profil de l'utilisateur authentifié
  /// GET /commerce/api/v1/users/me
  Future<AppUser> getCurrentUser() async {
    final uri = Uri.parse('$_baseUrl/users/me');
    final response = await http.get(uri, headers: await _authHeaders);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AppUser.fromJson(data['data']);
    } else {
      throw Exception(
        'Erreur lors de la récupération du profil: ${response.statusCode}',
      );
    }
  }

  /// Met à jour le profil de l'utilisateur authentifié
  /// PUT /commerce/api/v1/users/me
  Future<AppUser> updateCurrentUserProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? profilePictureUrl,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/me');
    final body = <String, dynamic>{};

    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (profilePictureUrl != null) {
      body['profilePictureUrl'] = profilePictureUrl;
    }

    final response = await http.put(
      uri,
      headers: await _authHeaders,
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AppUser.fromJson(data['data']);
    } else {
      throw Exception(
        'Erreur lors de la mise à jour du profil: ${response.statusCode}',
      );
    }
  }

  /// Met à jour les paramètres de l'utilisateur authentifié
  /// PUT /commerce/api/v1/users/me/settings
  Future<Map<String, dynamic>> updateCurrentUserSettings({
    String? theme,
    String? language,
    bool? emailNotifications,
    bool? pushNotifications,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/me/settings');
    final body = <String, dynamic>{};

    if (theme != null) body['theme'] = theme;
    if (language != null) body['language'] = language;
    if (emailNotifications != null || pushNotifications != null) {
      body['notifications'] = {
        if (emailNotifications != null) 'email': emailNotifications,
        if (pushNotifications != null) 'push': pushNotifications,
      };
    }

    final response = await http.put(
      uri,
      headers: await _authHeaders,
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data']['settings'] as Map<String, dynamic>;
    } else {
      throw Exception(
        'Erreur lors de la mise à jour des paramètres: ${response.statusCode}',
      );
    }
  }

  /// Change l'unité d'affaires courante de l'utilisateur
  /// POST /commerce/api/v1/users/switch-unit
  /// Conformé avec la documentation API
  Future<Map<String, dynamic>> switchBusinessUnit(
    String businessUnitCode,
  ) async {
    final uri = Uri.parse('$_baseUrl/users/switch-unit');
    final body = {'code': businessUnitCode};

    final response = await http.post(
      uri,
      headers: await _authHeaders,
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      throw Exception(
        "Code d'unité \"$businessUnitCode\" non trouvé. Vérifiez le code communiqué par votre administrateur.",
      );
    } else if (response.statusCode == 400) {
      final data = json.decode(response.body);
      throw Exception(data['message'] ?? "L'unité n'est pas active");
    } else if (response.statusCode == 403) {
      throw Exception("Vous n'avez pas accès à cette unité d'affaires");
    } else {
      throw Exception(
        "Erreur lors du changement d'unité: ${response.statusCode}",
      );
    }
  }

  /// Réinitialise l'utilisateur vers l'Entreprise Générale (niveau company)
  /// POST /commerce/api/v1/users/reset-to-company
  Future<Map<String, dynamic>> resetToCompany() async {
    final uri = Uri.parse('$_baseUrl/users/reset-to-company');

    final response = await http.post(
      uri,
      headers: await _authHeaders,
      body: json.encode({}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] as Map<String, dynamic>;
    } else {
      throw Exception(
        "Erreur lors de la réinitialisation: ${response.statusCode}",
      );
    }
  }

  /// Récupère l'unité d'affaires actuellement active pour l'utilisateur
  /// GET /commerce/api/v1/users/current-unit
  Future<Map<String, dynamic>> getCurrentUnit() async {
    final uri = Uri.parse('$_baseUrl/users/current-unit');

    final response = await http.get(uri, headers: await _authHeaders);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] as Map<String, dynamic>;
    } else {
      throw Exception(
        "Erreur lors de la récupération de l'unité courante: ${response.statusCode}",
      );
    }
  }

  /// Liste les unités d'affaires accessibles à l'utilisateur
  /// GET /commerce/api/v1/users/accessible-units
  Future<List<Map<String, dynamic>>> getAccessibleUnits() async {
    final uri = Uri.parse('$_baseUrl/users/accessible-units');

    final response = await http.get(uri, headers: await _authHeaders);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> units = data['data'] ?? [];
      return units.cast<Map<String, dynamic>>();
    } else {
      throw Exception(
        "Erreur lors de la récupération des unités accessibles: ${response.statusCode}",
      );
    }
  }

  // ============= GESTION DES UTILISATEURS (ADMIN) =============

  /// Récupère la liste des utilisateurs (Admin uniquement)
  /// GET /commerce/api/v1/users
  Future<UsersListResponse> getUsers({
    int page = 1,
    int limit = 10,
    String? role,
    bool? isActive,
    String? businessUnitId,
    String? search,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (role != null) queryParams['role'] = role;
    if (isActive != null) queryParams['isActive'] = isActive.toString();
    if (businessUnitId != null) queryParams['businessUnitId'] = businessUnitId;
    if (search != null) queryParams['search'] = search;

    final uri = Uri.parse(
      '$_baseUrl/users',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: await _authHeaders);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return UsersListResponse.fromJson(data['data']);
    } else if (response.statusCode == 403) {
      throw Exception('Accès non autorisé. Droits administrateur requis.');
    } else {
      throw Exception(
        'Erreur lors de la récupération des utilisateurs: ${response.statusCode}',
      );
    }
  }

  /// Crée un nouvel utilisateur (Admin uniquement)
  /// POST /commerce/api/v1/users
  Future<AppUser> createUser({
    required String email,
    required String firstName,
    String? lastName,
    String? phoneNumber,
    required String role,
    String? businessUnitCode,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/users');
    final body = {
      'email': email,
      'firstName': firstName,
      'role': role,
      'password': password,
      if (lastName != null) 'lastName': lastName,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (businessUnitCode != null) 'businessUnitCode': businessUnitCode,
    };

    final response = await http.post(
      uri,
      headers: await _authHeaders,
      body: json.encode(body),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return AppUser.fromJson(data['data']);
    } else if (response.statusCode == 409) {
      throw Exception("Un utilisateur avec cet email existe déjà");
    } else if (response.statusCode == 403) {
      throw Exception('Accès non autorisé. Droits administrateur requis.');
    } else {
      throw Exception(
        "Erreur lors de la création de l'utilisateur: ${response.statusCode}",
      );
    }
  }

  /// Met à jour un utilisateur (Admin uniquement)
  /// PUT /commerce/api/v1/users/:id
  Future<AppUser> updateUser(
    String userId, {
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? role,
    bool? isActive,
    String? businessUnitCode,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/$userId');
    final body = <String, dynamic>{};

    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (role != null) body['role'] = role;
    if (isActive != null) body['isActive'] = isActive;
    if (businessUnitCode != null) body['businessUnitCode'] = businessUnitCode;

    final response = await http.put(
      uri,
      headers: await _authHeaders,
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AppUser.fromJson(data['data']);
    } else if (response.statusCode == 403) {
      throw Exception('Accès non autorisé. Droits administrateur requis.');
    } else if (response.statusCode == 404) {
      throw Exception('Utilisateur non trouvé');
    } else {
      throw Exception(
        "Erreur lors de la mise à jour de l'utilisateur: ${response.statusCode}",
      );
    }
  }

  /// Désactive un utilisateur (soft delete) (Admin uniquement)
  /// DELETE /commerce/api/v1/users/:id
  Future<void> deactivateUser(String userId) async {
    final uri = Uri.parse('$_baseUrl/users/$userId');
    final response = await http.delete(uri, headers: await _authHeaders);

    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 403) {
      throw Exception('Accès non autorisé. Droits administrateur requis.');
    } else if (response.statusCode == 404) {
      throw Exception('Utilisateur non trouvé');
    } else {
      throw Exception(
        "Erreur lors de la désactivation de l'utilisateur: ${response.statusCode}",
      );
    }
  }
}

/// Réponse paginée de la liste des utilisateurs
class UsersListResponse {
  final List<AppUser> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  UsersListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory UsersListResponse.fromJson(Map<String, dynamic> json) {
    return UsersListResponse(
      items:
          (json['items'] as List)
              .map((item) => AppUser.fromJson(item as Map<String, dynamic>))
              .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}
