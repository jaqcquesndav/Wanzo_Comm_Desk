// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\connectivity\providers\connectivity_provider.dart

import 'package:flutter/material.dart';
import '../../../core/utils/connectivity_service.dart';

/// Provider pour l'état de connectivité dans l'application
class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isConnected = true;
  DateTime? _lastConnectedTime;
  DateTime? _lastDisconnectedTime;
  
  /// Indique si l'appareil est connecté à Internet
  bool get isConnected => _isConnected;
  
  /// Date de la dernière connexion
  DateTime? get lastConnectedTime => _lastConnectedTime;
  
  /// Date de la dernière déconnexion
  DateTime? get lastDisconnectedTime => _lastDisconnectedTime;
  
  /// Temps écoulé en mode hors ligne (en secondes)
  int get offlineDurationInSeconds {
    if (_isConnected || _lastDisconnectedTime == null) {
      return 0;
    }
    
    return DateTime.now().difference(_lastDisconnectedTime!).inSeconds;
  }
  
  /// Indique si l'application est hors ligne depuis longtemps (plus de 5 minutes)
  bool get isLongOffline => 
      !_isConnected && 
      _lastDisconnectedTime != null &&
      DateTime.now().difference(_lastDisconnectedTime!).inMinutes > 5;
  
  /// Constructeur
  ConnectivityProvider() {
    _initialize();
  }
  
  /// Initialise le provider
  Future<void> _initialize() async {
    await _connectivityService.init();
    
    // État initial
    _isConnected = _connectivityService.isConnected;
    if (_isConnected) {
      _lastConnectedTime = DateTime.now();
    } else {
      _lastDisconnectedTime = DateTime.now();
    }
      // S'abonner aux changements de connectivité
    _connectivityService.connectionStatus.addListener(() {
      _updateConnectivityStatus(_connectivityService.isConnected);
    });
  }
  
  /// Met à jour l'état de connectivité
  void _updateConnectivityStatus(bool isConnected) {
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      
      if (isConnected) {
        _lastConnectedTime = DateTime.now();
      } else {
        _lastDisconnectedTime = DateTime.now();
      }
      
      notifyListeners();
    }
  }
  
  /// Redémarre la surveillance de la connectivité
  Future<void> restartConnectivityMonitoring() async {
    await _connectivityService.init();
    _updateConnectivityStatus(_connectivityService.isConnected);
  }
}
