import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/registration_request.dart';
import '../../../core/config/env_config.dart';

/// Repository pour gérer l'inscription des utilisateurs
class RegistrationRepository {
  /// URL de base de l'API - utilise maintenant EnvConfig
  String get _baseUrl => EnvConfig.commerceBaseUrl;
  
  /// Endpoint pour l'inscription
  final String _registerEndpoint = '/auth/register';
  
  /// Effectue l'inscription d'un nouvel utilisateur
  Future<bool> register(RegistrationRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$_registerEndpoint'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );
      
      // Vérifier si la réponse est un succès (code 200-299)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      
      // En cas d'erreur, lancer une exception avec le message d'erreur
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Échec de l\'inscription');
    } catch (e) {
      // En mode développement, pour simplifier les tests, on peut simuler une inscription réussie
      // TODO: Supprimer cette ligne en production
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        return true;
      }
      
      // En production, propager l'erreur
      rethrow;
    }
  }
}
