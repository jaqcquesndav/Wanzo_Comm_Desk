import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Service pour gérer le cache des requêtes API
class ApiCacheService {
  static final ApiCacheService _instance = ApiCacheService._internal();
  
  /// Instance unique du service (singleton)
  factory ApiCacheService() => _instance;
  
  ApiCacheService._internal();
  
  Box<String>? _cacheBox;
  
  /// Durée de validité du cache par défaut
  static const Duration defaultCacheDuration = Duration(days: 1);
  
  /// Initialise le service de cache
  Future<void> init() async {
    // NE PAS ré-initialiser Hive ici : le répertoire Hive est fixé une seule
    // fois au démarrage (main._initializeHive → sous-dossier propre à l'app).
    // Un Hive.init(Documents) ré-orientait TOUTES les boxes ouvertes ensuite
    // vers C:\Users\...\Documents (dossier partagé) → collision de verrou avec
    // les autres apps Wanzo. On ouvre simplement la box dans le répertoire courant.
    _cacheBox = await Hive.openBox<String>('api_cache');
  }
  
  /// Récupère une réponse du cache
  Future<Map<String, dynamic>?> getCachedResponse(String key) async {
    if (_cacheBox == null) {
      await init();
    }
    
    final cachedDataString = _cacheBox?.get(key);
    if (cachedDataString == null) {
      return null;
    }
    
    try {
      final Map<String, dynamic> cachedDataMap = jsonDecode(cachedDataString);
      final timestamp = cachedDataMap['timestamp'] as int;
      final data = cachedDataMap['data'] as Map<String, dynamic>;
      
      // Vérifier si le cache est expiré
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiryTime = timestamp + defaultCacheDuration.inMilliseconds;
      
      if (now > expiryTime) {
        // Cache expiré, le supprimer
        await _cacheBox?.delete(key);
        return null;
      }
      
      return data;
    } catch (e) {
      debugPrint('Erreur lors de la récupération du cache: $e');
      return null;
    }
  }
  
  /// Stocke une réponse dans le cache
  Future<void> setCachedResponse(String key, Map<String, dynamic> data) async {
    if (_cacheBox == null) {
      await init();
    }
    
    final cacheData = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    };
    
    await _cacheBox?.put(key, jsonEncode(cacheData));
  }
  
  /// Génère une clé de cache à partir d'une URI et d'une méthode
  String generateCacheKey(String uri, String method) {
    return '$method:$uri';
  }
  
  /// Supprime toutes les entrées du cache
  Future<void> clearCache() async {
    await _cacheBox?.clear();
  }
  
  /// Supprime une entrée spécifique du cache
  Future<void> removeCacheEntry(String key) async {
    await _cacheBox?.delete(key);
  }
  
  /// Vérifie si une clé existe dans le cache
  bool hasCacheEntry(String key) {
    return _cacheBox?.containsKey(key) ?? false;
  }
}
