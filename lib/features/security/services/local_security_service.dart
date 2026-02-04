import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service de gestion de la sécurité locale avec code PIN
class LocalSecurityService {
  static LocalSecurityService? _instance;
  static LocalSecurityService get instance => _instance ??= LocalSecurityService._();

  LocalSecurityService._();

  static const String _pinKey = 'local_pin_hash';
  static const String _pinEnabledKey = 'local_pin_enabled';
  static const String _defaultPin = '1234';
  static const Duration _inactivityTimeout = Duration(minutes: 5);

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  Timer? _inactivityTimer;
  DateTime? _lastActivity;
  bool _isLocked = false;
  bool _isPinEnabled = false;
  
  final ValueNotifier<bool> _lockStateNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _pinEnabledNotifier = ValueNotifier<bool>(false);

  /// Notificateur d'état de verrouillage
  ValueListenable<bool> get lockStateNotifier => _lockStateNotifier;
  
  /// Notificateur d'état d'activation du PIN
  ValueListenable<bool> get pinEnabledNotifier => _pinEnabledNotifier;

  /// État actuel du verrouillage
  bool get isLocked => _isLocked;
  
  /// État d'activation du PIN
  bool get isPinEnabled => _isPinEnabled;

  /// Initialise le service de sécurité locale
  Future<void> init() async {
    try {
      // Vérifier si le PIN est activé
      final enabledValue = await _secureStorage.read(key: _pinEnabledKey);
      _isPinEnabled = enabledValue == 'true';
      _pinEnabledNotifier.value = _isPinEnabled;
      
      // Si le PIN est activé, initialiser avec le PIN par défaut s'il n'existe pas
      if (_isPinEnabled) {
        final existingPin = await _secureStorage.read(key: _pinKey);
        if (existingPin == null) {
          await _setPinHash(_defaultPin);
          debugPrint('LocalSecurityService: Default PIN set');
        }
        
        // Démarrer en mode verrouillé si le PIN est activé
        _setLockState(true);
      }
      
      // Initialiser le timer d'inactivité
      _resetInactivityTimer();
      
      debugPrint('LocalSecurityService: Initialized with PIN ${_isPinEnabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      debugPrint('LocalSecurityService: Error during initialization: $e');
    }
  }

  /// Active ou désactive le système de PIN local
  Future<void> setPinEnabled(bool enabled, {String? newPin}) async {
    try {
      _isPinEnabled = enabled;
      await _secureStorage.write(key: _pinEnabledKey, value: enabled.toString());
      _pinEnabledNotifier.value = enabled;
      
      if (enabled) {
        // Définir le PIN (nouveau ou par défaut)
        final pin = newPin ?? _defaultPin;
        await _setPinHash(pin);
        _setLockState(true);
        _resetInactivityTimer();
        debugPrint('LocalSecurityService: PIN security enabled');
      } else {
        // Désactiver le PIN
        await _secureStorage.delete(key: _pinKey);
        _setLockState(false);
        _stopInactivityTimer();
        debugPrint('LocalSecurityService: PIN security disabled');
      }
    } catch (e) {
      debugPrint('LocalSecurityService: Error setting PIN enabled state: $e');
      rethrow;
    }
  }

  /// Change le code PIN
  Future<bool> changePin(String currentPin, String newPin) async {
    try {
      if (!_isPinEnabled) {
        debugPrint('LocalSecurityService: Cannot change PIN when security is disabled');
        return false;
      }
      
      // Vérifier le PIN actuel
      final isCurrentValid = await verifyPin(currentPin);
      if (!isCurrentValid) {
        debugPrint('LocalSecurityService: Current PIN verification failed');
        return false;
      }
      
      // Définir le nouveau PIN
      await _setPinHash(newPin);
      debugPrint('LocalSecurityService: PIN changed successfully');
      return true;
    } catch (e) {
      debugPrint('LocalSecurityService: Error changing PIN: $e');
      return false;
    }
  }

  /// Vérifie si le PIN fourni est correct
  Future<bool> verifyPin(String pin) async {
    try {
      if (!_isPinEnabled) {
        debugPrint('LocalSecurityService: PIN verification skipped - security disabled');
        return true; // Si le PIN n'est pas activé, toujours autoriser
      }
      
      final storedHash = await _secureStorage.read(key: _pinKey);
      if (storedHash == null) {
        debugPrint('LocalSecurityService: No stored PIN hash found');
        return false;
      }
      
      final inputHash = _hashPin(pin);
      final isValid = storedHash == inputHash;
      
      if (isValid) {
        debugPrint('LocalSecurityService: PIN verification successful');
        unlock();
      } else {
        debugPrint('LocalSecurityService: PIN verification failed');
      }
      
      return isValid;
    } catch (e) {
      debugPrint('LocalSecurityService: Error verifying PIN: $e');
      return false;
    }
  }

  /// Déverrouille l'application
  void unlock() {
    if (_isPinEnabled) {
      _setLockState(false);
      _resetInactivityTimer();
      debugPrint('LocalSecurityService: Application unlocked');
    }
  }

  /// Verrouille immédiatement l'application
  void lock() {
    if (_isPinEnabled) {
      _setLockState(true);
      _stopInactivityTimer();
      debugPrint('LocalSecurityService: Application locked');
    }
  }

  /// Enregistre une activité utilisateur
  void recordActivity() {
    if (!_isPinEnabled || _isLocked) return;
    
    _lastActivity = DateTime.now();
    _resetInactivityTimer();
  }

  /// Vérifie si l'application doit être verrouillée pour inactivité
  void checkInactivity() {
    if (!_isPinEnabled || _isLocked) return;
    
    final now = DateTime.now();
    if (_lastActivity != null && 
        now.difference(_lastActivity!) >= _inactivityTimeout) {
      lock();
    }
  }

  /// Hash le PIN avec un salt pour la sécurité
  String _hashPin(String pin) {
    final bytes = utf8.encode('${pin}wanzo_salt_2024'); // Ajouter un salt
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Stocke le hash du PIN de manière sécurisée
  Future<void> _setPinHash(String pin) async {
    final hash = _hashPin(pin);
    await _secureStorage.write(key: _pinKey, value: hash);
  }

  /// Met à jour l'état de verrouillage
  void _setLockState(bool locked) {
    _isLocked = locked;
    _lockStateNotifier.value = locked;
  }

  /// Démarre/redémarre le timer d'inactivité
  void _resetInactivityTimer() {
    if (!_isPinEnabled) return;
    
    _stopInactivityTimer();
    _lastActivity = DateTime.now();
    
    _inactivityTimer = Timer(_inactivityTimeout, () {
      if (_isPinEnabled && !_isLocked) {
        lock();
      }
    });
  }

  /// Arrête le timer d'inactivité
  void _stopInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  /// Nettoie les ressources
  void dispose() {
    _stopInactivityTimer();
    _lockStateNotifier.dispose();
    _pinEnabledNotifier.dispose();
    _instance = null;
    debugPrint('LocalSecurityService: Disposed');
  }

  /// Réinitialise le PIN au défaut (pour les tests ou cas d'urgence)
  Future<void> resetToDefaultPin() async {
    try {
      await _setPinHash(_defaultPin);
      debugPrint('LocalSecurityService: PIN reset to default');
    } catch (e) {
      debugPrint('LocalSecurityService: Error resetting PIN to default: $e');
      rethrow;
    }
  }

  /// Obtient le temps restant avant verrouillage automatique
  Duration? get timeUntilLock {
    if (!_isPinEnabled || _isLocked || _lastActivity == null) return null;
    
    final now = DateTime.now();
    final elapsed = now.difference(_lastActivity!);
    final remaining = _inactivityTimeout - elapsed;
    
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Vérifie si l'application est proche du verrouillage automatique
  bool get isNearAutoLock {
    final remaining = timeUntilLock;
    return remaining != null && remaining.inSeconds <= 60; // 1 minute avant verrouillage
  }
}
