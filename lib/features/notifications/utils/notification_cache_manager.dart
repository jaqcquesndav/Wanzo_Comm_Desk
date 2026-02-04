// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\notifications\utils\notification_cache_manager.dart

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/notification_model.dart';
import '../../../core/services/database_service.dart';

/// Gestionnaire de cache pour les notifications
class NotificationCacheManager {
  final DatabaseService _databaseService;
  
  /// Constructeur
  NotificationCacheManager({
    required DatabaseService databaseService,
  }) : _databaseService = databaseService;
  
  /// Sauvegarde une notification dans le cache SQLite
  Future<void> cacheNotification(NotificationModel notification) async {
    try {
      final db = await _databaseService.database;
      
      await db.insert(
        'notifications',
        {
          'id': notification.id,
          'title': notification.title,
          'message': notification.message,
          'type': notification.type.toString().split('.').last,
          'timestamp': notification.timestamp.millisecondsSinceEpoch,
          'is_read': notification.isRead ? 1 : 0,
          'action_route': notification.actionRoute,
          'additional_data': notification.additionalData,
          'synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      debugPrint('Notification ${notification.id} mise en cache');
    } catch (e) {
      debugPrint('Erreur lors de la mise en cache de la notification: $e');
    }
  }
  
  /// Récupère les notifications mises en cache
  Future<List<NotificationModel>> getCachedNotifications() async {
    try {
      final db = await _databaseService.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'notifications',
        orderBy: 'timestamp DESC',
      );
      
      return List.generate(maps.length, (i) {
        return NotificationModel(
          id: maps[i]['id'] as String,
          title: maps[i]['title'] as String,
          message: maps[i]['message'] as String,
          type: _parseNotificationType(maps[i]['type'] as String),
          timestamp: DateTime.fromMillisecondsSinceEpoch(maps[i]['timestamp'] as int),
          isRead: (maps[i]['is_read'] as int) == 1,
          actionRoute: maps[i]['action_route'] as String?,
          additionalData: maps[i]['additional_data'] as String?,
        );
      });
    } catch (e) {
      debugPrint('Erreur lors de la récupération des notifications en cache: $e');
      return [];
    }
  }
  
  /// Marque une notification comme lue dans le cache
  Future<void> markAsRead(String id) async {
    try {
      final db = await _databaseService.database;
      
      await db.update(
        'notifications',
        {'is_read': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      
      debugPrint('Notification $id marquée comme lue dans le cache');
    } catch (e) {
      debugPrint('Erreur lors du marquage de la notification comme lue dans le cache: $e');
    }
  }
  
  /// Supprime une notification du cache
  Future<void> deleteNotification(String id) async {
    try {
      final db = await _databaseService.database;
      
      await db.delete(
        'notifications',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      debugPrint('Notification $id supprimée du cache');
    } catch (e) {
      debugPrint('Erreur lors de la suppression de la notification du cache: $e');
    }
  }
  
  /// Nettoie les notifications anciennes (plus de 30 jours)
  Future<void> cleanOldNotifications() async {
    try {
      final db = await _databaseService.database;
      
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final cutoffTimestamp = thirtyDaysAgo.millisecondsSinceEpoch;
      
      final result = await db.delete(
        'notifications',
        where: 'timestamp < ?',
        whereArgs: [cutoffTimestamp],
      );
      
      debugPrint('$result anciennes notifications supprimées du cache');
    } catch (e) {
      debugPrint('Erreur lors du nettoyage des anciennes notifications du cache: $e');
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
}
