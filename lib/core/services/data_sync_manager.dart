// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\core\services\data_sync_manager.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/connectivity_service.dart';
import '../utils/logger.dart';
import 'database_service.dart';
import 'api_service.dart';

/// Gestionnaire de synchronisation des données entre le stockage local et l'API
class DataSyncManager {  final ConnectivityService _connectivityService;
  final DatabaseService _databaseService;
  final ApiService _apiService;
  // Suppression du service non utilisé
  // final ConflictResolutionService _conflictResolutionService = ConflictResolutionService();
  
  bool _isSyncing = false;
  Timer? _syncTimer;
  // Ces compteurs seront utilisés dans une future version
  // int _syncConflicts = 0;
  // int _syncSuccesses = 0;

  /// Constructeur
  DataSyncManager({
    required ConnectivityService connectivityService,
    required DatabaseService databaseService,
    required ApiService apiService,
  }) : _connectivityService = connectivityService,
       _databaseService = databaseService,
       _apiService = apiService {    // S'abonner aux changements de connectivité
    _connectivityService.connectionStatus.addListener(() {
      final isConnected = _connectivityService.isConnected;
      if (isConnected) {
        // Si la connexion est rétablie, lancer une synchronisation
        Logger.info('Connexion rétablie, démarrage de la synchronisation...');
        syncData();
      } else {
        Logger.info('Connexion perdue, synchronisation interrompue');
      }
    });
  }
  
  /// Commence à surveiller la connectivité et à synchroniser les données périodiquement
  void startSyncMonitoring({Duration period = const Duration(minutes: 15)}) {
    // Annuler le timer existant s'il y en a un
    _syncTimer?.cancel();
    
    // Créer un nouveau timer pour la synchronisation périodique
    _syncTimer = Timer.periodic(period, (timer) async {
      if (_connectivityService.isConnected && !_isSyncing) {
        await syncData();
      }
    });
    
    debugPrint('Surveillance de la synchronisation démarrée (période: ${period.inMinutes} minutes)');
  }
  
  /// Arrête la surveillance de la synchronisation
  void stopSyncMonitoring() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('Surveillance de la synchronisation arrêtée');
  }
  /// Synchronise les données avec l'API
  Future<void> syncData() async {
    if (!_connectivityService.isConnected || _isSyncing) {
      debugPrint('Pas de connexion Internet disponible ou synchronisation déjà en cours');
      return;
    }

    try {
      _isSyncing = true;
      debugPrint('Début de la synchronisation des données...');
      
      // Synchroniser les opérations en attente
      final pendingOperations = await _databaseService.getPendingOperations();
      debugPrint('${pendingOperations.length} opérations en attente de synchronisation');
      
      for (final operation in pendingOperations) {
        try {
          final endpoint = operation['endpoint'] as String;
          final method = operation['method'] as String;
          final body = operation['body'] as Map<String, dynamic>?;
          final id = operation['id'] as String;
          
          // Exécuter l'opération sur l'API
          switch (method) {
            case 'GET':
              await _apiService.get(endpoint);
              break;
            case 'POST':
              await _apiService.post(endpoint, body: body);
              break;
            case 'PUT':
              await _apiService.put(endpoint, body: body);
              break;
            case 'DELETE':
              await _apiService.delete(endpoint);
              break;
          }
          
          // Marquer l'opération comme synchronisée
          await _databaseService.markOperationAsSynchronized(id);
          debugPrint('Opération $id synchronisée avec succès');
        } catch (e) {
          debugPrint('Erreur lors de la synchronisation de l\'opération: $e');
        }
      }
      
      // Synchroniser les notifications non synchronisées
      await syncNotifications();
      
      // Nettoyer les anciennes opérations synchronisées
      await _databaseService.cleanupSynchronizedOperations();
      
      debugPrint('Fin de la synchronisation');
    } catch (e) {
      debugPrint('Erreur lors de la synchronisation des données: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Synchronise les notifications locales avec le serveur
  Future<void> syncNotifications() async {
    if (!_connectivityService.isConnected) {
      return;
    }
    
    try {
      final db = await _databaseService.database;
      
      // Récupérer les notifications non synchronisées
      final List<Map<String, dynamic>> localNotifications = await db.query(
        'notifications',
        where: 'synced = ?',
        whereArgs: [0],
      );
      
      if (localNotifications.isEmpty) {
        return;
      }
      
      debugPrint('${localNotifications.length} notifications à synchroniser');
      
      // Synchroniser chaque notification
      for (final notification in localNotifications) {
        try {
          // Envoyer la notification au serveur
          await _apiService.post(
            '/notifications',
            body: {
              'id': notification['id'],
              'title': notification['title'],
              'message': notification['message'],
              'type': notification['type'],
              'timestamp': notification['timestamp'],
              'is_read': notification['is_read'] == 1,
              'action_route': notification['action_route'],
              'additional_data': notification['additional_data'],
            },
          );
          
          // Marquer la notification comme synchronisée
          await db.update(
            'notifications',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [notification['id']],
          );
          
          debugPrint('Notification ${notification['id']} synchronisée avec succès');
        } catch (e) {
          debugPrint('Erreur lors de la synchronisation de la notification ${notification['id']}: $e');
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de la synchronisation des notifications: $e');
    }
  }
    /// Stocke une opération pour synchronisation ultérieure
  Future<void> storeOperationForSync({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
  }) async {
    await _databaseService.savePendingOperation(
      endpoint: endpoint,
      method: method,
      body: body,
    );
    
    debugPrint('Opération $method $endpoint stockée pour synchronisation ultérieure');
    
    // Si la connexion est disponible, synchroniser immédiatement
    if (_connectivityService.isConnected) {
      syncData();
    }
  }
  
  /// Nettoie les anciennes données du cache (notifications et opérations)
  Future<void> cleanupOldData({Duration maxAge = const Duration(days: 30)}) async {
    try {
      final db = await _databaseService.database;
      final cutoffTimestamp = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
      
      // Nettoyer les anciennes notifications
      final notificationsDeleted = await db.delete(
        'notifications',
        where: 'timestamp < ? AND synced = ?',
        whereArgs: [cutoffTimestamp, 1],
      );
      
      // Nettoyer les anciennes opérations synchronisées
      await _databaseService.cleanupSynchronizedOperations();
      
      debugPrint('Nettoyage terminé: $notificationsDeleted notifications supprimées');
    } catch (e) {
      debugPrint('Erreur lors du nettoyage des anciennes données: $e');
    }
  }
}
