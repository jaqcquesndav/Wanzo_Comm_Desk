import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/registration_request.dart';
import '../../../core/utils/connectivity_service.dart';
import '../../../core/config/env_config.dart';

/// Repository pour gérer l'inscription
class RegistrationRepository {
  final ConnectivityService _connectivityService = ConnectivityService();
  // Utilise maintenant EnvConfig au lieu d'une URL codée en dur
  String get _baseUrl => EnvConfig.apiGatewayUrl;
  
  /// Enregistre un nouvel utilisateur et son entreprise
  Future<bool> register(RegistrationRequest request) async {
    try {
      // Vérifier la connectivité
      if (!_connectivityService.isConnected) {
        throw Exception('Aucune connexion Internet disponible. Impossible de créer un compte.');
      }
      
      // En mode démo/développement, simuler une réponse positive
      if (request.email.contains('test') || request.email.contains('demo')) {
        // Simuler un délai réseau
        await Future.delayed(const Duration(seconds: 2));
        return true;
      }
      
      // Appel à l'API réelle
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'owner_name': request.ownerName,
          'email': request.email,
          'password': request.password,
          'phone_number': request.phoneNumber,
          'company_name': request.companyName,
          'rccm_number': request.rccmNumber,
          'location': request.location,
          'sector_id': request.sector.id,
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Une erreur s\'est produite lors de l\'inscription');
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'inscription: $e');
      throw Exception('Échec de l\'inscription: $e');
    }
  }
}
