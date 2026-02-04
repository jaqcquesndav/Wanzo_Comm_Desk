import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service pour gérer la connectivité réseau
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  
  /// Instance unique du service (singleton)
  factory ConnectivityService() => _instance;
  
  ConnectivityService._internal();
    final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> _connectionStatus = ValueNotifier<bool>(true);
  bool _isConnected = false;

  /// ValueListenable qui émet l'état de la connectivité (true = connecté, false = déconnecté)
  ValueListenable<bool> get connectionStatus => _connectionStatus;
  
  /// État actuel de la connectivité
  bool get isConnected => _isConnected;

  /// Initialise le service de connectivité
  Future<void> init() async {
    // Vérification initiale de la connectivité
    _checkConnectivity();
    
    // Écouter les changements de connectivité
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> result) {
      _updateConnectionStatus(result);
    });
  }

  /// Vérifie l'état actuel de la connexion
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result); // Pass the list directly
    } catch (e) {
      debugPrint('Erreur lors de la vérification de la connectivité: $e');
      _isConnected = false;
      _connectionStatus.value = false;
    }
  }

  /// Met à jour l'état de la connexion
  void _updateConnectionStatus(List<ConnectivityResult> result) { // Modified to accept List<ConnectivityResult>
    final wasConnected = _isConnected;
    // Check if 'none' is present in the list. If not, we are connected.
    _isConnected = !result.contains(ConnectivityResult.none); 
      // Notifier les écouteurs si l'état a changé
    if (wasConnected != _isConnected) {
      _connectionStatus.value = _isConnected;
      
      debugPrint('État de la connectivité mis à jour: ${_isConnected ? 'Connecté' : 'Déconnecté'}');
    }
  }

  /// Libère les ressources
  void dispose() {
    // No need to dispose ValueNotifier as it will be garbage collected
  }
}
