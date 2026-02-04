// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\auth\providers\auth_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth0_service.dart';
import '../services/offline_auth_service.dart';
import '../models/user.dart';
import '../../../core/utils/connectivity_service.dart';
import '../../../core/services/database_service.dart'; // Ensure DatabaseService is imported

/// Énumération des états d'authentification
enum AuthStatus {
  /// Indéterminé (chargement initial)
  indeterminate,
  
  /// Authentifié
  authenticated,
  
  /// Non authentifié
  unauthenticated,
  
  /// Authentifié en mode hors ligne
  authenticatedOffline,
}

/// Provider pour gérer l'état d'authentification
class AuthProvider extends ChangeNotifier {
  final Auth0Service _auth0Service;
  late final OfflineAuthService _offlineAuthService;
  final ConnectivityService _connectivityService;
  
  AuthStatus _status = AuthStatus.indeterminate;
  User? _user;
  bool _offlineMode = false;
  
  /// État actuel de l'authentification
  AuthStatus get status => _status;
  
  /// Utilisateur actuellement connecté
  User? get user => _user;
  
  /// Indique si l'application est en mode hors ligne
  bool get isOfflineMode => _offlineMode;
  
  /// Constructeur
  AuthProvider()
      : _connectivityService = ConnectivityService(),
        _offlineAuthService = OfflineAuthService(
            secureStorage: const FlutterSecureStorage(),
            // Instantiate DatabaseService and ConnectivityService for OfflineAuthService
            databaseService: DatabaseService(), 
            connectivityService: ConnectivityService(), 
          ),
        // Pass the _offlineAuthService instance to Auth0Service
        _auth0Service = Auth0Service(
          offlineAuthService: OfflineAuthService( 
            secureStorage: const FlutterSecureStorage(),
            databaseService: DatabaseService(),
            connectivityService: ConnectivityService(),
          ),
        ) {
    _initialize();
  }
  
  /// Initialise le provider
  Future<void> _initialize() async {
    await _auth0Service.init();
    
    // Récupérer l'instance du service d'authentification hors ligne
    _offlineAuthService = _auth0Service.offlineAuthService;
      // Vérifier si l'utilisateur est déjà authentifié
    await checkAuthStatus();
    
    // Écouter les changements de connectivité
    _connectivityService.connectionStatus.addListener(() {
      final isConnected = _connectivityService.isConnected;
      _offlineMode = !isConnected;
      notifyListeners();
      
      // Si la connexion est rétablie et que l'utilisateur est en mode hors ligne,
      // essayer de rafraîchir les tokens
      if (isConnected && _status == AuthStatus.authenticatedOffline && _user != null) {
        _tryRefreshAuthentication();
      }
    });
  }
  
  /// Vérifie l'état de l'authentification
  Future<void> checkAuthStatus() async {
    try {
      _offlineMode = !_connectivityService.isConnected;
      
      // Vérifier l'authentification en ligne
      final isAuthenticated = await _auth0Service.isAuthenticated();
      
      if (isAuthenticated) {
        final token = await _auth0Service.getAccessToken();      if (token != null) {
          // Utiliser le token pour récupérer les informations utilisateur
          _user = await _auth0Service.getUserInfo(token);
          _status = AuthStatus.authenticated;
          notifyListeners();
          return;
        }
      }
      
      // Si pas d'authentification en ligne, vérifier le mode hors ligne
      if (_offlineMode) {
        final canLoginOffline = await _offlineAuthService.canLoginOffline();
        if (canLoginOffline) {
          _user = await _offlineAuthService.getLastLoggedInUser();
          if (_user != null) {
            _status = AuthStatus.authenticatedOffline;
            notifyListeners();
            return;
          }
        }
      }
      
      // Si aucune authentification n'est valide
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors de la vérification du statut d\'authentification: $e');
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
    }
  }
  
  /// Effectue la connexion
  Future<void> login() async {
    try {
      _user = await _auth0Service.login();
      _status = _connectivityService.isConnected 
        ? AuthStatus.authenticated 
        : AuthStatus.authenticatedOffline;
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors de la connexion: $e');
      rethrow;
    }
  }
  
  /// Effectue la déconnexion
  Future<void> logout() async {
    try {
      await _auth0Service.logout();
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors de la déconnexion: $e');
      rethrow;
    }
  }
  
  /// Active ou désactive l'authentification hors ligne
  Future<void> setOfflineLoginEnabled(bool enabled) async {
    await _offlineAuthService.setOfflineLoginEnabled(enabled);
    
    // Si activé et qu'un utilisateur est connecté, le sauvegarder
    if (enabled && _user != null) {
      await _offlineAuthService.saveUserForOfflineLogin(_user!);
    }
      // Si désactivé, effacer les données utilisateur en cache
    if (!enabled) {
      await _offlineAuthService.clearOfflineData();
    }
  }
  
  /// Vérifie si la connexion hors ligne est disponible
  Future<bool> isOfflineLoginAvailable() async {
    return await _offlineAuthService.canLoginOffline();
  }
  
  /// Essaie de rafraîchir l'authentification en ligne quand la connexion est rétablie
  Future<void> _tryRefreshAuthentication() async {
    try {
      final token = await _auth0Service.getAccessToken();
      if (token != null) {
        _user = await _auth0Service.getUserInfo(token);
        _status = AuthStatus.authenticated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erreur lors du rafraîchissement de l\'authentification: $e');
      // Garder l'état actuel en cas d'échec
    }
  }
}
