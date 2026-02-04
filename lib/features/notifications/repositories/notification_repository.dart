// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\notifications\repositories\notification_repository.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import '../models/notification_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/connectivity_service.dart';
import '../../../core/utils/logger.dart';

/// Repository pour gérer les notifications
class NotificationRepository {
  static const String _notificationsBoxName = 'notifications';
  final ApiService _apiService = ApiService();
  final DatabaseService _databaseService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();

  Box<NotificationModel>? _notificationsBox;
  final StreamController<List<NotificationModel>> _notificationsController =
      StreamController<List<NotificationModel>>.broadcast();

  // États pour la synchronisation
  int _pendingSyncCount = 0;

  /// Stream qui émet la liste des notifications à chaque changement
  Stream<List<NotificationModel>> get notifications => _notificationsController.stream;

  /// Retourne le nombre de notifications en attente de synchronisation
  Future<int> getPendingSyncCount() async {
    await _updatePendingSyncCount();
    return _pendingSyncCount;
  }

  /// Initialise le repository
  Future<void> init() async {
    try {
      // Ouvrir la box Hive si elle n'est pas déjà ouverte
      _notificationsBox = await Hive.openBox<NotificationModel>(_notificationsBoxName);

      // Émettre les notifications actuelles
      _emitCurrentNotifications();

      // Compter les notifications en attente de synchronisation
      await _updatePendingSyncCount();

      // Récupérer les notifications depuis l'API si connecté
      if (_connectivityService.isConnected) {
        await fetchNotificationsFromApi();
      } else {
        // En mode hors ligne, charger les notifications du cache
        await _loadNotificationsFromCache();
      }

      // Écouter les changements de connectivité
      _connectivityService.connectionStatus.addListener(_onConnectivityChanged);
    } catch (e) {
      Logger.error('Erreur lors de l\'initialisation du repository de notifications', error: e);
    }
  }

  /// Gère les changements de connectivité
  void _onConnectivityChanged() {
    final isConnected = _connectivityService.isConnected;

    if (isConnected && _pendingSyncCount > 0) {
      // Synchroniser les notifications quand la connexion est rétablie
      Logger.info('Connexion rétablie. Lancement de la synchronisation de $_pendingSyncCount notifications');
      syncNotifications();
    }
  }

  /// Émet les notifications actuelles aux abonnés du stream
  void _emitCurrentNotifications() {
    if (_notificationsBox != null) {
      final notifications = _notificationsBox!.values.toList();
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _notificationsController.add(notifications);
    }
  }

  /// Récupère les notifications depuis l'API
  Future<List<NotificationModel>> fetchNotificationsFromApi() async {
    try {
      final response = await _apiService.get('notifications');

      if (response['success'] == true && response.containsKey('data')) {
        final List<dynamic> notificationsData = response['data'] as List<dynamic>;

        final notifications = <NotificationModel>[];

        for (final data in notificationsData) {
          try {
            final notificationData = data as Map<String, dynamic>;

            // Convertir le type de notification
            final NotificationType type = _parseNotificationType(notificationData['type'] as String? ?? 'info');

            final notification = NotificationModel(
              id: notificationData['id'] as String,
              title: notificationData['title'] as String,
              message: notificationData['message'] as String,
              type: type,
              timestamp: DateTime.parse(notificationData['timestamp'] as String),
              isRead: notificationData['is_read'] as bool? ?? false,
              actionRoute: notificationData['action_route'] as String?,
              additionalData: notificationData['additional_data'] as String?,
            );

            // Sauvegarder la notification en local
            await saveNotification(notification);
            notifications.add(notification);
          } catch (e) {
            debugPrint('Erreur lors du traitement d\'une notification: $e');
          }
        }

        return notifications;
      }

      return [];
    } catch (e) {
      debugPrint('Erreur lors de la récupération des notifications: $e');
      return [];
    }
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
      case 'low_stock':
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

  /// Récupère toutes les notifications locales
  List<NotificationModel> getAllNotifications() {
    if (_notificationsBox == null) return [];

    final notifications = _notificationsBox!.values.toList();
    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return notifications;
  }

  /// Récupère les notifications non lues
  List<NotificationModel> getUnreadNotifications() {
    return getAllNotifications().where((notification) => !notification.isRead).toList();
  }

  /// Crée une nouvelle notification
  Future<NotificationModel> createNotification({
    required String title,
    required String message,
    required NotificationType type,
    DateTime? timestamp,
    bool isRead = false,
    String? actionRoute,
    String? additionalData,
  }) async {
    final notification = NotificationModel(
      id: const Uuid().v4(),
      title: title,
      message: message,
      type: type,
      timestamp: timestamp ?? DateTime.now(),
      isRead: isRead,
      actionRoute: actionRoute,
      additionalData: additionalData,
    );

    await saveNotification(notification);
    // Synchroniser avec l'API si connecté
    if (_connectivityService.isConnected) {
      _syncNotificationToApi(notification);
    } else {
      // Enregistrer pour synchronisation future
      await _databaseService.savePendingOperation(
        endpoint: 'notifications',
        method: 'POST',
        body: {
          'id': notification.id,
          'title': notification.title,
          'message': notification.message,
          'type': notification.type.toString().split('.').last,
          'timestamp': notification.timestamp.toIso8601String(),
          'is_read': notification.isRead,
          'action_route': notification.actionRoute,
          'additional_data': notification.additionalData,
        },
      );
    }

    return notification;
  }

  /// Enregistre une notification en local
  Future<void> saveNotification(NotificationModel notification) async {
    if (_notificationsBox != null) {
      await _notificationsBox!.put(notification.id, notification);
      _emitCurrentNotifications();
    }
  }

  /// Marque une notification comme lue
  Future<void> markAsRead(String id) async {
    if (_notificationsBox != null) {
      final notification = _notificationsBox!.get(id);

      if (notification != null && !notification.isRead) {
        final updatedNotification = notification.markAsRead();
        await _notificationsBox!.put(id, updatedNotification);

        // Synchroniser avec l'API si connecté
        if (_connectivityService.isConnected) {
          _markAsReadOnApi(id);
        } else {
          // Enregistrer pour synchronisation future
          await _databaseService.savePendingOperation(
            endpoint: 'notifications/$id/read',
            method: 'PUT',
            body: {'read': true},
          );
        }

        _emitCurrentNotifications();
      }
    }
  }

  /// Marque une notification comme lue sur l'API
  Future<void> _markAsReadOnApi(String id) async {
    try {
      await _apiService.put('notifications/$id/read', body: {'read': true});
    } catch (e) {
      debugPrint('Erreur lors du marquage de la notification comme lue sur l\'API: $e');
    }
  }

  /// Synchronise une notification avec l'API
  Future<void> _syncNotificationToApi(NotificationModel notification) async {
    try {
      await _apiService.post('notifications', body: {
        'id': notification.id,
        'title': notification.title,
        'message': notification.message,
        'type': notification.type.toString().split('.').last,
        'timestamp': notification.timestamp.toIso8601String(),
        'is_read': notification.isRead,
        'action_route': notification.actionRoute,
        'additional_data': notification.additionalData,
      });
    } catch (e) {
      debugPrint('Erreur lors de la synchronisation de la notification avec l\'API: $e');
    }
  }

  /// Supprime une notification
  Future<void> deleteNotification(String id) async {
    if (_notificationsBox != null) {
      await _notificationsBox!.delete(id);

      // Synchroniser avec l'API si connecté
      if (_connectivityService.isConnected) {
        _deleteNotificationOnApi(id);
      } else {
        // Enregistrer pour synchronisation future
        await _databaseService.savePendingOperation(
          endpoint: 'notifications/$id',
          method: 'DELETE',
        );
      }

      _emitCurrentNotifications();
    }
  }

  /// Supprime une notification sur l'API
  Future<void> _deleteNotificationOnApi(String id) async {
    try {
      await _apiService.delete('notifications/$id');
    } catch (e) {
      debugPrint('Erreur lors de la suppression de la notification sur l\'API: $e');
    }
  }

  /// Marque toutes les notifications comme lues
  Future<void> markAllAsRead() async {
    if (_notificationsBox != null) {
      final unreadNotifications = getUnreadNotifications();

      for (final notification in unreadNotifications) {
        await _notificationsBox!.put(
          notification.id,
          notification.markAsRead(),
        );
      }

      // Synchroniser avec l'API si connecté
      if (_connectivityService.isConnected) {
        _markAllAsReadOnApi();
      } else {
        // Enregistrer pour synchronisation future
        await _databaseService.savePendingOperation(
          endpoint: 'notifications/read-all',
          method: 'PUT',
        );
      }

      _emitCurrentNotifications();
    }
  }

  /// Marque toutes les notifications comme lues sur l'API
  Future<void> _markAllAsReadOnApi() async {
    try {
      await _apiService.put('notifications/read-all');
    } catch (e) {
      debugPrint('Erreur lors du marquage de toutes les notifications comme lues sur l\'API: $e');
    }
  }

  /// Synchronise les notifications locales avec l'API
  Future<void> syncNotifications() async {
    if (!_connectivityService.isConnected) return;

    try {
      // Récupérer les nouvelles notifications depuis l'API
      await fetchNotificationsFromApi();

      // Synchroniser les opérations en attente
      final pendingOperations = await _databaseService.getPendingOperations();

      for (final operation in pendingOperations) {
        final String endpoint = operation['endpoint'] as String;
        final String method = operation['method'] as String;
        final Map<String, dynamic>? body = operation['body'] as Map<String, dynamic>?;
        final String id = operation['id'] as String;
        if (endpoint.startsWith('notifications')) {
          try {
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

            await _databaseService.markOperationAsSynchronized(id);
          } catch (e) {
            debugPrint('Erreur lors de la synchronisation d\'une opération: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de la synchronisation des notifications: $e');
    }
  }

  /// Met à jour le compteur des notifications en attente de synchronisation
  Future<void> _updatePendingSyncCount() async {
    try {
      // Get pending operations from database service and count those related to notifications
      final pendingOperations = await _databaseService.getPendingOperations();
      _pendingSyncCount = pendingOperations
          .where((op) => op['endpoint'].toString().startsWith('notifications'))
          .length;

      debugPrint('Notifications en attente de synchronisation: $_pendingSyncCount');
    } catch (e) {
      Logger.error('Erreur lors du comptage des notifications en attente de synchronisation', error: e);
    }
  }
  /// Charge les notifications depuis le cache local  
  Future<void> _loadNotificationsFromCache() async {
    try {
      // Get notifications from cache using database service directly
      final db = await _databaseService.database;
      final notificationsData = await db.query('notifications');

      // Convert the raw data to notification models
      for (final data in notificationsData) {
        try {
          final notification = NotificationModel(
            id: data['id'] as String,
            title: data['title'] as String,
            message: data['message'] as String,
            type: _parseNotificationType(data['type'] as String? ?? 'info'),
            timestamp: DateTime.parse(data['timestamp'] as String),
            isRead: (data['is_read'] as int? ?? 0) == 1,
            actionRoute: data['action_route'] as String?,
            additionalData: data['additional_data'] as String?,
          );

          await _notificationsBox?.put(notification.id, notification);
        } catch (e) {
          debugPrint('Erreur lors de la conversion d\'une notification du cache: $e');
        }
      }

      // Émettre les notifications actuelles
      _emitCurrentNotifications();
    } catch (e) {
      Logger.error('Erreur lors du chargement des notifications depuis le cache', error: e);
    }
  }

  /// Ferme le repository et libère les ressources
  void dispose() {
    _notificationsController.close();
  }
}
