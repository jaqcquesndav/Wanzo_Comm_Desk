// lib/services/auth_service.dart
import 'package:auth0_flutter/auth0_flutter.dart';
import './api_service.dart';

class AuthService {
  // Utilisez les vraies valeurs de vos variables d'environnement Auth0
  final Auth0 auth0 = Auth0(
    'wanzo.eu.auth0.com', // Domaine Auth0 de Wanzo
    'GDX5Wqib0J5A3jzKLLwYr1lQEqT6aBHl' // Client ID pour l'application mobile
  );
  
  final ApiService _apiService = ApiService();
  
  Future<Credentials> login() async {
    final credentials = await auth0.webAuthentication().login(
      audience: 'https://api.wanzo.be', // L'audience configurée dans Auth0
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
    
    // Mettre à jour le token dans l'ApiService
    _apiService.token = credentials.accessToken;
    
    // Obtenir les informations utilisateur depuis Auth0
    final userInfo = await auth0.api.userProfile(accessToken: credentials.accessToken);
    
    // Envoyer les données d'authentification au backend pour synchronisation
    try {
      await _apiService.sendAuthDataToBackend(
        credentials.accessToken, 
        {
          'sub': userInfo.sub,
          'email': userInfo.email,
          'name': userInfo.name,
          'picture': userInfo.pictureUrl?.toString(),
          'email_verified': userInfo.isEmailVerified,
        }
      );
    } catch (e) {
      print('Erreur lors de la synchronisation avec le backend: $e');
      // Continuer même en cas d'erreur car l'utilisateur est déjà authentifié via Auth0
    }
    
    return credentials;
  }
  
  Future<void> logout() async {
    await auth0.webAuthentication().logout();
  }
}
