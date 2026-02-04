import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:firebase_messaging/firebase_messaging.dart'; // Commented out
import 'package:hive/hive.dart';
import '../models/notification_model.dart';
// Suppression de l'import redondant: import '../models/notification_adapter.dart';
import '../../settings/models/settings.dart';
import '../../../core/services/database_service.dart';
// import '../../../core/services/api_service.dart'; // Commented out as _apiService is unused
// import '../../../core/services/data_sync_manager.dart'; // Commented out as _dataSyncManager is unused
import '../../../core/utils/connectivity_service.dart';
import '../../../core/utils/logger.dart'; // Corrected logger import
import '../utils/notification_cache_manager.dart';
import 'package:sqflite/sqflite.dart' as sqflite; // Import Sqflite with alias

/// Service pour gérer les notifications
class NotificationService {  static final NotificationService _instance = NotificationService._internal();
  
  /// Instance unique du service (singleton)
  factory NotificationService() => _instance;
      /// API Service instance
  // final ApiService _apiService = ApiService(); // Commented out as it's unused
    
  NotificationService._internal();
  
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  // final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance; // Commented out
  final StreamController<NotificationModel> _notificationStreamController = 
      StreamController<NotificationModel>.broadcast();
  
  Box<NotificationModel>? _notificationsBox;
  Settings? _settings;
    // Services pour la gestion hors ligne
  final DatabaseService _databaseService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  late final NotificationCacheManager _notificationCacheManager;
  // late final DataSyncManager _dataSyncManager; // Commented out as it's unused
  
  /// Indique si le service fonctionne en mode hors ligne
  bool _isOfflineMode = false;
  
  /// Accès au mode hors ligne
  bool get isOfflineMode => _isOfflineMode;
  
  /// Stream qui émet les nouvelles notifications
  Stream<NotificationModel> get notificationsStream => _notificationStreamController.stream;
  
  /// Initialise le service de notification
  Future<void> init(Settings settings) async {
    _settings = settings;
    
    // Initialisation de la connectivité
    await _connectivityService.init();
    _isOfflineMode = !_connectivityService.isConnected;
    
    // S'abonner aux changements de connectivité
    _connectivityService.connectionStatus.addListener(_onConnectivityChanged);
    
    // Initialisation du gestionnaire de cache de notifications
    _notificationCacheManager = NotificationCacheManager(databaseService: _databaseService);
    
    // Initialisation du gestionnaire de synchronisation
    /* // Commented out as _dataSyncManager is unused
    _dataSyncManager = DataSyncManager(
      connectivityService: _connectivityService,
      databaseService: _databaseService,
      apiService: _apiService, // _apiService would also need to be uncommented
    );
    */
    
    // Initialisation de la boîte Hive pour les notifications
    await _initHive();
    
    // Initialisation des notifications locales
    await _initLocalNotifications();
    
    // Initialisation des notifications push Firebase
    // if (settings.pushNotificationsEnabled) { // Commented out
    //   await _initFirebaseMessaging(); // Commented out
    // } // Commented out
    
    // Nettoyer les anciennes notifications au démarrage
    await _cleanOldNotifications();
    
    // Chargement des notifications en cache
    await _loadCachedNotifications();
  }
  
  /// Met à jour les paramètres de notification
  void updateSettings(Settings settings) {
    _settings = settings;
  }
  
  /// Initialise Hive pour stocker les notifications
  Future<void> _initHive() async {
    // Hive est déjà initialisé dans main.dart, pas besoin de l'initialiser à nouveau
    
    // Vérifier si les adaptateurs sont déjà enregistrés
    if (!Hive.isAdapterRegistered(28)) { // Corrected typeId for NotificationModelAdapter
      Hive.registerAdapter(NotificationModelAdapter()); // Using the imported adapter
    }
    
    if (!Hive.isAdapterRegistered(29)) { // Corrected typeId for NotificationTypeAdapter
      Hive.registerAdapter(NotificationTypeAdapter()); // Using the imported adapter
    }
    
    // Ouvrir la boîte de notifications
    _notificationsBox = await Hive.openBox<NotificationModel>('notifications');
  }
  
  /// Initialise les notifications locales
  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onSelectNotification,
    );
  }
  
  /// Initialise Firebase Messaging pour les notifications push
  // Future<void> _initFirebaseMessaging() async { // Commented out
  //   // Demander la permission pour les notifications // Commented out
  //   /*NotificationSettings settings = await _firebaseMessaging.requestPermission( // Commented out
  //     alert: true, // Commented out
  //     badge: true, // Commented out
  //     sound: true, // Commented out
  //   ); // Commented out
    
  //   if (settings.authorizationStatus == AuthorizationStatus.authorized) { // Commented out
  //     // Configure les gestionnaires de notifications // Commented out
  //     FirebaseMessaging.onMessage.listen(_handleFirebaseMessage); // Commented out
  //     FirebaseMessaging.onMessageOpenedApp.listen(_handleFirebaseMessageOpenedApp); // Commented out
      
  //     // Gérer les notifications en arrière-plan // Commented out
  //     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler); // Commented out
      
  //     // Obtenir le token FCM // Commented out
  //     String? token = await _firebaseMessaging.getToken(); // Commented out
  //     debugPrint('FCM Token: $token'); // Commented out
  //   }*/ // Commented out
  // } // Commented out
  
  /// Gère les notifications Firebase reçues lorsque l'application est ouverte
  // void _handleFirebaseMessage(RemoteMessage message) { // Commented out
  //   debugPrint('Notification reçue: ${message.notification?.title}'); // Commented out
    
  //   final notification = NotificationModel.create( // Commented out
  //     title: message.notification?.title ?? 'Nouvelle notification', // Commented out
  //     message: message.notification?.body ?? '', // Commented out
  //     type: _getNotificationTypeFromData(message.data), // Commented out
  //     actionRoute: message.data['route'], // Commented out
  //     additionalData: message.data.isNotEmpty ? jsonEncode(message.data) : null, // Commented out
  //   ); // Commented out
    
  //   // Ajouter à la liste des notifications // Commented out
  //   _addNotification(notification); // Commented out
    
  //   // Afficher la notification locale si les notifications in-app sont activées // Commented out
  //   if (_settings?.inAppNotificationsEnabled ?? true) { // Commented out
  //     _showLocalNotification(notification); // Commented out
  //   } // Commented out
  // } // Commented out
  
  /// Gère les notifications Firebase lorsqu'elles sont cliquées pour ouvrir l'application
  // void _handleFirebaseMessageOpenedApp(RemoteMessage message) { // Commented out
  //   debugPrint('Notification ouverte: ${message.notification?.title}'); // Commented out
    
  //   final notification = NotificationModel.create( // Commented out
  //     title: message.notification?.title ?? 'Notification', // Commented out
  //     message: message.notification?.body ?? '', // Commented out
  //     type: _getNotificationTypeFromData(message.data), // Commented out
  //     actionRoute: message.data['route'], // Commented out
  //     additionalData: message.data.isNotEmpty ? jsonEncode(message.data) : null, // Commented out
  //     isRead: true, // Marquer comme lue car l'utilisateur l'a ouverte // Commented out
  //   ); // Commented out
    
  //   // Ajouter à la liste des notifications // Commented out
  //   _addNotification(notification); // Commented out
    
  //   // Naviguer vers la route spécifiée si disponible // Commented out
  //   // Note: La navigation devrait être gérée par le BloC qui écoute le stream // Commented out
  // } // Commented out
  
  /// Détermine le type de notification à partir des données
  // NotificationType _getNotificationTypeFromData(Map<String, dynamic> data) { // Commented out
  //   final typeString = data['type']?.toString().toLowerCase() ?? 'info'; // Commented out
    
  //   switch (typeString) { // Commented out
  //     case 'success': // Commented out
  //       return NotificationType.success; // Commented out
  //     case 'warning': // Commented out
  //       return NotificationType.warning; // Commented out
  //     case 'error': // Commented out
  //       return NotificationType.error; // Commented out
  //     case 'lowstock': // Commented out
  //     case 'low_stock': // Commented out
  //       return NotificationType.lowStock; // Commented out
  //     case 'sale': // Commented out
  //     case 'new_sale': // Commented out
  //       return NotificationType.sale; // Commented out
  //     case 'payment': // Commented out
  //       return NotificationType.payment; // Commented out
  //     default: // Commented out
  //       return NotificationType.info; // Commented out
  //   } // Commented out
  // } // Commented out
  
  /// Gérer la sélection d'une notification locale
  void _onSelectNotification(NotificationResponse response) {
    debugPrint('Notification cliquée avec payload: ${response.payload}');
    
    // Tenter de décoder le payload pour obtenir l'ID de la notification
    if (response.payload != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(response.payload!);
        final String? notificationId = data['id'];
        
        if (notificationId != null) {
          // Marquer la notification comme lue
          markNotificationAsRead(notificationId);
          
          // La navigation sera gérée par le BloC qui écoute le stream
        }
      } catch (e) {
        debugPrint('Erreur lors du décodage du payload: $e');
      }
    }
  }
  
  /// Affiche une notification locale
  Future<void> _showLocalNotification(NotificationModel notification) async {
    if (!(_settings?.inAppNotificationsEnabled ?? true)) {
      return;
    }
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'wanzo_notifications',
      'Notifications Wanzo',
      channelDescription: 'Canal pour les notifications de l\'application Wanzo',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    final payload = jsonEncode({
      'id': notification.id,
      'route': notification.actionRoute,
      'data': notification.additionalData,
    });
    
    await _localNotifications.show(
      notification.id.hashCode,
      notification.title,
      notification.message,
      notificationDetails,
      payload: payload,
    );
  }
  
  /// Ajoute une notification à la liste et au stream
  Future<void> _addNotification(NotificationModel notification) async {
    // Ajouter à la boîte Hive
    await _notificationsBox?.put(notification.id, notification);
    
    // Émettre la notification au stream
    _notificationStreamController.add(notification);
  }
  
  /// Nettoie les anciennes notifications
  Future<void> _cleanOldNotifications() async {
    try {
      if (_notificationsBox != null) {
        final now = DateTime.now();
        final List<String> keysToDelete = [];
        
        // Parcourir toutes les notifications
        for (final notification in _notificationsBox!.values) {
          // Supprimer les notifications de plus de 30 jours
          if (now.difference(notification.timestamp).inDays > 30) {
            keysToDelete.add(notification.id);
          }
        }
        
        // Supprimer les notifications
        await Future.forEach(keysToDelete, (key) async {
          await _notificationsBox!.delete(key);
        });
        
        debugPrint('${keysToDelete.length} anciennes notifications supprimées');
      }
    } catch (e) {
      debugPrint('Erreur lors du nettoyage des anciennes notifications: $e');
    }
  }
  
  /// Crée et envoie une nouvelle notification
  Future<void> sendNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? actionRoute,
    String? additionalData,
  }) async {
    final notification = NotificationModel.create(
      title: title,
      message: message,
      type: type,
      actionRoute: actionRoute,
      additionalData: additionalData,
    );
    
    await _addNotification(notification);
    
    if (_settings?.inAppNotificationsEnabled ?? true) {
      await _showLocalNotification(notification);
    }
  }
  
  /// Récupère toutes les notifications
  List<NotificationModel> getAllNotifications() {
    return _notificationsBox?.values.toList() ?? [];
  }
  
  /// Récupère les notifications non lues
  List<NotificationModel> getUnreadNotifications() {
    return _notificationsBox?.values.where((note) => !note.isRead).toList() ?? [];
  }
  
  /// Marque une notification comme lue
  Future<void> markNotificationAsRead(String notificationId) async {
    final notification = _notificationsBox?.get(notificationId);
    if (notification != null && !notification.isRead) {
      final updatedNotification = notification.markAsRead();
      await _notificationsBox?.put(notificationId, updatedNotification);
      
      // Émettre la notification mise à jour au stream
      _notificationStreamController.add(updatedNotification);
    }
  }
  
  /// Marque toutes les notifications comme lues
  Future<void> markAllNotificationsAsRead() async {
    final unreadNotifications = getUnreadNotifications();
    
    for (var notification in unreadNotifications) {
      final updatedNotification = notification.markAsRead();
      await _notificationsBox?.put(notification.id, updatedNotification);
      
      // Émettre la notification mise à jour au stream
      _notificationStreamController.add(updatedNotification);
    }
  }
  
  /// Supprime une notification
  Future<void> deleteNotification(String notificationId) async {
    await _notificationsBox?.delete(notificationId);
  }
  
  /// Supprime toutes les notifications
  Future<void> deleteAllNotifications() async {
    await _notificationsBox?.clear();
  }
    /// Charge les notifications mises en cache dans SQLite
  Future<void> _loadCachedNotifications() async {
    try {
      final cachedNotifications = await _notificationCacheManager.getCachedNotifications();
      
      // Ajouter les notifications en cache à la boîte Hive
      for (final notification in cachedNotifications) {
        // Vérifier si la notification existe déjà dans Hive
        final existingNotification = _notificationsBox?.get(notification.id);
        if (existingNotification == null) {
          await _notificationsBox?.put(notification.id, notification);
        }
      }
      
      debugPrint('${cachedNotifications.length} notifications chargées depuis le cache');    } catch (e) {
      Logger.error('Erreur lors du chargement des notifications en cache', error: e);
    }
  }
    /// Ajoute une notification au système
  Future<void> addNotification(NotificationModel notification) async {
    try {
      // Ajouter la notification à Hive
      await _notificationsBox?.put(notification.id, notification);
      
      // Émettre la notification au stream
      _notificationStreamController.add(notification);
      
      Logger.info('Notification ajoutée: ${notification.id}');
    } catch (e) {
      Logger.error('Erreur lors de l\'ajout de notification', error: e);
    }
  }
  
  /// Ajoute une notification avec support hors ligne
  Future<void> addNotificationWithOfflineSupport(NotificationModel notification) async {
    try {
      // Ajouter la notification à Hive pour l'affichage immédiat
      await addNotification(notification);
      
      // Stocker dans SQLite pour le support hors ligne
      await _notificationCacheManager.cacheNotification(notification);
      
      // Synchroniser avec le serveur si connecté
      if (_connectivityService.isConnected) {
        // TODO: Synchroniser avec le serveur
        // Exemple: await _apiService.syncNotification(notification);
      }
      
      Logger.info('Notification ajoutée avec support hors ligne: ${notification.id}');
    } catch (e) {
      Logger.error('Erreur lors de l\'ajout de notification avec support hors ligne', error: e);
    }
  }
  
  /// Obtient le nombre de notifications non synchronisées
  Future<int> getUnsyncedNotificationsCount() async {
    try {
      final db = await _databaseService.database;
      
      final result = await db.rawQuery(
        'SELECT COUNT(*) FROM notifications WHERE synced = 0',
      );
      
      return sqflite.Sqflite.firstIntValue(result) ?? 0; // Using the imported Sqflite with namespace
    } catch (e) {
      Logger.error('Erreur lors du comptage des notifications non synchronisées', error: e);
      return 0;
    }
  }
  
  /// Gestion des changements de connectivité
  void _onConnectivityChanged() {
    final isConnected = _connectivityService.isConnected;
    _isOfflineMode = !isConnected;
    
    Logger.info('Connectivité changée: ${isConnected ? 'En ligne' : 'Hors ligne'}');
    
    // Si la connexion est rétablie, synchroniser les notifications
    if (isConnected) {
      _syncOfflineNotifications();
    }
  }
  
  /// Synchronise les notifications stockées hors ligne
  Future<void> _syncOfflineNotifications() async {
    try {
      if (!_connectivityService.isConnected) {
        Logger.warning('Tentative de synchronisation sans connexion');
        return;
      }
      
      Logger.info('Démarrage de la synchronisation des notifications hors ligne');
      
      // Récupérer les notifications non synchronisées
      final db = await _databaseService.database;
      final List<Map<String, dynamic>> unsyncedMaps = await db.query(
        'notifications',
        where: 'synced = ?',
        whereArgs: [0],
      );
      
      if (unsyncedMaps.isEmpty) {
        Logger.info('Aucune notification à synchroniser');
        return;
      }
      
      Logger.info('${unsyncedMaps.length} notifications à synchroniser');
      
      // Pour chaque notification non synchronisée
      for (final map in unsyncedMaps) {
        // Construire l'objet notification
        final notification = NotificationModel(
          id: map['id'] as String,
          title: map['title'] as String,
          message: map['message'] as String,
          type: _parseNotificationType(map['type'] as String),
          timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
          isRead: (map['is_read'] as int) == 1,
          actionRoute: map['action_route'] as String?,
          additionalData: map['additional_data'] as String?,
        );
        
        // Tenter de synchroniser avec le serveur
        try {
          // TODO: Implémenter l'appel API pour synchroniser la notification
          // await _apiService.syncNotification(notification);
          
          // Marquer comme synchronisée dans SQLite
          await db.update(
            'notifications',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [notification.id],
          );
          
          Logger.info('Notification ${notification.id} synchronisée');
        } catch (e) {
          Logger.error('Erreur lors de la synchronisation de la notification ${notification.id}', error: e);
        }
      }
    } catch (e) {
      Logger.error('Erreur lors de la synchronisation des notifications', error: e);
    }
  }
  
  /// Ferme le service de notification
  void dispose() {
    _notificationStreamController.close();
  }
}

/// Gestionnaire de messages Firebase en arrière-plan
// @pragma('vm:entry-point') // Commented out
// Future<void> _firebaseMessagingBackgroundHandler(/*RemoteMessage message*/) async { // Commented out RemoteMessage type
//   // Assurez-vous que Firebase est initialisé // Commented out
//   // await Firebase.initializeApp(); // Commented out
  
//   // Traiter le message en arrière-plan // Commented out
//   // debugPrint('Notification en arrière-plan: ${message.notification?.title}'); // Commented out
//     // Vous ne pouvez pas accéder au service ici, mais vous pouvez stocker la notification // Commented out
//   // dans une base de données locale qui sera lue au prochain démarrage de l'application // Commented out
// } // Commented out

/// Fonction externe pour analyser le type de notification
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
