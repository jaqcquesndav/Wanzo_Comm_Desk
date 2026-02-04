// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';

/// DEPRECATED: Ce service est obsolète. Utiliser lib/core/services/api_client.dart
/// ou lib/core/services/api_service.dart pour les nouvelles implémentations.
///
/// Note: Ce service utilise maintenant commerceApiBaseUrl qui inclut le préfixe
/// /commerce/api/v1 pour accéder correctement au backend via l'API Gateway.
class ApiService {
  // IMPORTANT: Utiliser commerceApiBaseUrl pour accéder via API Gateway avec préfixe
  final String baseUrl = Environment.commerceApiBaseUrl;
  String? _token;

  // Setter pour le token après authentification Auth0
  set token(String value) {
    _token = value;
  }

  // Headers avec authentification
  Map<String, String> get _authHeaders {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  // Exemple de méthode pour récupérer le profil utilisateur
  Future<Map<String, dynamic>> getUserProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/profile'),
      headers: _authHeaders,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load profile: ${response.statusCode}');
    }
  }

  // Méthode pour envoyer les données d'authentification au backend
  Future<Map<String, dynamic>> sendAuthDataToBackend(
    String accessToken,
    Map<String, dynamic> userData,
  ) async {
    // Assurez-vous que le token Auth0 est défini pour l'authentification
    _token = accessToken;

    final response = await http.post(
      Uri.parse('$baseUrl/auth/sync'),
      headers: _authHeaders,
      body: json.encode({'auth0Data': userData}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception(
        'Failed to synchronize authentication data: ${response.statusCode}',
      );
    }
  }

  // Méthode pour récupérer la liste des portefeuilles
  Future<List<dynamic>> getPortfolios() async {
    final response = await http.get(
      Uri.parse('$baseUrl/portfolios'),
      headers: _authHeaders,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] as List<dynamic>;
    } else {
      throw Exception('Failed to load portfolios: ${response.statusCode}');
    }
  }

  // Méthode pour récupérer les détails de l'entreprise
  Future<Map<String, dynamic>> getCompanyDetails() async {
    final response = await http.get(
      Uri.parse('$baseUrl/company/details'),
      headers: _authHeaders,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load company details: ${response.statusCode}');
    }
  }
}
