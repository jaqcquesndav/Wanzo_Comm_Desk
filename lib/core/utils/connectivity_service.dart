import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_client.dart';

/// Service pour gérer la connectivité réseau
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  
  /// Instance unique du service (singleton)
  factory ConnectivityService() => _instance;
  
  ConnectivityService._internal();
    final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> _connectionStatus = ValueNotifier<bool>(true);
  bool _isConnected = false;
  bool _hasInitialStatus = false;

  /// ValueListenable qui émet l'état de la connectivité (true = connecté, false = déconnecté)
  ValueListenable<bool> get connectionStatus => _connectionStatus;
  
  /// État actuel de la connectivité
  bool get isConnected => _isConnected;

  /// Initialise le service de connectivité
  Future<void> init() async {
    // Vérification initiale de la connectivité : attendue, pour que l'état
    // soit connu quand le lancement décide de rejouer la file hors ligne.
    await _checkConnectivity();
    
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
    final isFirstStatus = !_hasInitialStatus;
    _hasInitialStatus = true;
    // Check if 'none' is present in the list. If not, we are connected.
    _isConnected = !result.contains(ConnectivityResult.none);

    // Premier état connu : on le publie toujours. Sans cela, une application
    // lancée HORS LIGNE gardait `connectionStatus` à true (valeur initiale)
    // alors que `isConnected` valait false, et le bandeau hors ligne ne
    // s'affichait pas.
    if (isFirstStatus) {
      _connectionStatus.value = _isConnected;
    }

    // Notifier les écouteurs si l'état a changé
    if (wasConnected != _isConnected) {
      _connectionStatus.value = _isConnected;

      // Retour du réseau : rejouer les écritures conservées hors ligne,
      // dans l'ordre. Sans ce rejeu, la file ne se viderait qu'au prochain
      // lancement de l'application.
      // Le tout premier état (lancement) ne rejoue pas ici : à cet instant
      // Hive et la session ne sont pas encore prêts. Le lancement rejoue la
      // file une fois l'application démarrée (main.dart).
      if (_isConnected && !isFirstStatus) {
        ApiClient().replayPendingWrites().then((report) {
          if (!report.isEmpty) {
            debugPrint('[Connectivité] Écritures hors ligne rejouées : $report');
          }
        }).catchError((Object e) {
          debugPrint('[Connectivité] Rejeu des écritures impossible : $e');
        });
      }
      
      debugPrint('État de la connectivité mis à jour: ${_isConnected ? 'Connecté' : 'Déconnecté'}');
    }
  }

  /// Libère les ressources
  void dispose() {
    // No need to dispose ValueNotifier as it will be garbage collected
  }
}
