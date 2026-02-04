import 'dart:async';
// Removed unused import: import 'package:flutter/material.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/connectivity_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/database_service.dart';
// import '../../../core/services/conflict_resolution_service.dart'; // Commented out as _conflictResolver is unused
import '../models/notification_model.dart';
import 'notification_cache_manager.dart';

/// Service pour gérer la synchronisation des notifications entre le serveur et le stockage local
class NotificationSyncService {
  static final NotificationSyncService _instance = NotificationSyncService._internal();

  /// Instance unique du service (singleton)
  factory NotificationSyncService() => _instance;

  NotificationSyncService._internal() {
    // Initialize any fields that require initialization
  }

  final ApiService _apiService = ApiService();
  final DatabaseService _databaseService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  late final NotificationCacheManager _cacheManager;
  // Unused field, keeping for future use
  // final ConflictResolutionService _conflictResolver = ConflictResolutionService(); // Commented out as it's unused

  bool _isSyncing = false;
  Timer? _periodicSyncTimer;
  
  // Statistiques de synchronisation
  int _totalSynced = 0;
  int _failedSync = 0;
  DateTime? _lastSyncTime;
  /// Initialise le service
  Future<void> init() async {
    _cacheManager = NotificationCacheManager(databaseService: _databaseService);
    
    // S'abonner aux changements de connectivité
    _connectivityService.connectionStatus.addListener(_onConnectivityChanged);
  }
  
  /// Gère les changements de connectivité
  void _onConnectivityChanged() {
    final isConnected = _connectivityService.isConnected;
    if (isConnected) {
      Logger.info('Connexion rétablie, synchronisation des notifications...');
      synchronizeNotifications();
    }
  }

  /// Démarre une synchronisation périodique des notifications
  void startPeriodicSync({Duration period = const Duration(minutes: 15)}) {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(period, (timer) {
      if (_connectivityService.isConnected && !_isSyncing) {
        synchronizeNotifications();
      }
    });
    Logger.info('Synchronisation périodique des notifications programmée (${period.inMinutes} min)');
  }

  /// Arrête la synchronisation périodique
  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    Logger.info('Synchronisation périodique des notifications arrêtée');
  }

  /// Exécute la synchronisation des notifications
  Future<bool> synchronizeNotifications() async {
    if (_isSyncing || !_connectivityService.isConnected) {
      return false;
    }

    _isSyncing = true;
    Logger.info('Début de la synchronisation des notifications');

    try {
      // 1. Synchroniser les notifications en attente
      await _syncPendingNotifications();

      // 2. Récupérer les nouvelles notifications
      await _fetchNewNotifications();

      // 3. Mettre à jour les statuts de lecture des notifications
      await _syncReadStatus();

      _lastSyncTime = DateTime.now();
      Logger.info('Synchronisation des notifications terminée avec succès');
      _isSyncing = false;
      return true;
    } catch (e) {
      _failedSync++;
      Logger.error('Erreur de synchronisation des notifications', error: e);
      _isSyncing = false;
      return false;
    }
  }
  /// Synchronise les notifications en attente d'envoi  
  Future<void> _syncPendingNotifications() async {
    final pendingOperations = await _databaseService.getPendingOperations();
    
    // Filtrer pour ne garder que les opérations sur les notifications
    final notificationOperations = pendingOperations
        .where((op) => op['endpoint'].toString().startsWith('notifications'))
        .toList();

    for (final operation in notificationOperations) {
      try {
        // Utiliser la méthode appropriée selon le type de requête
        final String method = operation['method'] as String;
        final String endpoint = operation['endpoint'] as String;
        final Map<String, dynamic>? body = operation['body'] as Map<String, dynamic>?;
        Map<String, dynamic> response;
        
        switch (method.toUpperCase()) {
          case 'GET':
            response = await _apiService.get(endpoint);
            break;
          case 'POST':
            response = await _apiService.post(endpoint, body: body);
            break;
          case 'PUT':
            response = await _apiService.put(endpoint, body: body);
            break;
          case 'DELETE':
            response = await _apiService.delete(endpoint);
            break;
          default:
            throw Exception('Méthode HTTP non supportée: $method');
        }

        if (response['success'] == true) {          // Supprime l'opération car elle a été traitée
          await _databaseService.markOperationAsSynchronized(operation['id'] as String);
          _totalSynced++;
        } else {
          Logger.warning('Échec de synchronisation d\'une notification: ${response['message']}');
        }
      } catch (e) {
        Logger.error('Erreur lors de la synchronisation d\'une notification', error: e);
      }
    }
  }

  /// Récupère les nouvelles notifications depuis l'API
  Future<void> _fetchNewNotifications() async {
    try {
      // Récupérer la date de dernière synchronisation
      String? lastSyncDate;
      if (_lastSyncTime != null) {
        lastSyncDate = _lastSyncTime!.toIso8601String();
      }

      final Map<String, dynamic> queryParams = {};
      if (lastSyncDate != null) {
        queryParams['since'] = lastSyncDate;
      }

      final response = await _apiService.get('notifications', queryParams: queryParams);
      
      if (response['success'] == true && response.containsKey('data')) {
        final List<dynamic> notificationsData = response['data'] as List<dynamic>;
        
        for (final data in notificationsData) {
          try {
            final notificationData = data as Map<String, dynamic>;
            
            // Convertir les données en modèle de notification
            final notification = _parseNotificationFromApi(notificationData);
            
            // Mettre en cache la notification
            await _cacheManager.cacheNotification(notification);
          } catch (e) {
            Logger.error('Erreur lors du traitement d\'une notification', error: e);
          }
        }
      }
    } catch (e) {
      Logger.error('Erreur lors de la récupération des notifications', error: e);
    }
  }
  /// Synchronise l'état de lecture des notifications
  Future<void> _syncReadStatus() async {
    try {
      // Récupérer les notifications lues localement mais pas encore synchronisées
      final db = await _databaseService.database;
      final List<Map<String, dynamic>> readNotifications = await db.query(
        'notifications',
        where: 'is_read = ? AND synced = ?',
        whereArgs: [1, 0],
      );

      if (readNotifications.isEmpty) {
        return;
      }

      // Préparer les IDs pour l'API
      final List<String> notificationIds = 
          readNotifications.map((n) => n['id'] as String).toList();

      // Envoyer au serveur
      await _apiService.post('notifications/mark-read', body: {
        'notification_ids': notificationIds,
      });

      // Marquer comme synchronisées
      for (final notification in readNotifications) {
        await db.update(
          'notifications',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [notification['id']],
        );
      }
    } catch (e) {
      Logger.error('Erreur lors de la synchronisation des états de lecture', error: e);
    }
  }  /// Vérifie s'il y a des notifications en attente de synchronisation
  Future<bool> hasPendingSynchronizations() async {
    final pendingOps = await _databaseService.getPendingOperations();
    // Filtrer pour ne garder que les opérations sur les notifications
    final notificationOps = pendingOps
        .where((op) => op['endpoint'].toString().startsWith('notifications'))
        .toList();
    return notificationOps.isNotEmpty;
  }

  /// Convertit les données d'API en modèle de notification
  NotificationModel _parseNotificationFromApi(Map<String, dynamic> data) {
    // Convertir le type de notification
    final NotificationType type = _parseNotificationType(data['type'] as String? ?? 'info');
    
    return NotificationModel(
      id: data['id'] as String,
      title: data['title'] as String,
      message: data['message'] as String,
      type: type,
      timestamp: DateTime.parse(data['timestamp'] as String),
      isRead: data['is_read'] as bool? ?? false,
      actionRoute: data['action_route'] as String?,
      additionalData: data['additional_data'] as String?,
    );
  }

  /// Convertit une chaîne en type de notification
  NotificationType _parseNotificationType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'success':
        return NotificationType.success;
      case 'warning':
        return NotificationType.warning;
      case 'error':
        return NotificationType.error;
      case 'lowstock':
        return NotificationType.lowStock;
      case 'sale':
        return NotificationType.sale;
      case 'payment':
        return NotificationType.payment;
      case 'info':
      default:
        return NotificationType.info;
    }
  }
  
  /// Obtient les statistiques de synchronisation
  Map<String, dynamic> getSyncStats() {
    return {
      'total_synced': _totalSynced,
      'failed_sync': _failedSync,
      'last_sync_time': _lastSyncTime?.toIso8601String(),
      'is_syncing': _isSyncing,
    };
  }
}
