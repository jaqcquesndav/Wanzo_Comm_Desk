// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\notifications\bloc\notification_bloc.dart

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import 'notification_event.dart';
import 'notification_state.dart';

/// Bloc pour gérer les notifications
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository _notificationRepository;
  StreamSubscription? _notificationsSubscription;
  
  /// Constructeur
  NotificationBloc({
    required NotificationRepository notificationRepository,
  }) : _notificationRepository = notificationRepository,
       super(NotificationState.initial()) {
    on<NotificationsInitialized>(_onNotificationsInitialized);
    on<NotificationsLoaded>(_onNotificationsLoaded);
    on<NotificationsRefreshed>(_onNotificationsRefreshed);
    on<NotificationCreated>(_onNotificationCreated);
    on<NotificationMarkedAsRead>(_onNotificationMarkedAsRead);
    on<AllNotificationsMarkedAsRead>(_onAllNotificationsMarkedAsRead);
    on<NotificationDeleted>(_onNotificationDeleted);
    on<LowStockNotificationCreated>(_onLowStockNotificationCreated);
    on<NewSaleNotificationCreated>(_onNewSaleNotificationCreated);
    on<NotificationsSynchronized>(_onNotificationsSynchronized);
  }
  
  /// Initialise le bloc et s'abonne aux changements de notifications
  Future<void> _onNotificationsInitialized(
    NotificationsInitialized event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      // Initialiser le repository
      await _notificationRepository.init();
      
      // S'abonner aux changements de notifications
      _notificationsSubscription = _notificationRepository.notifications.listen(
        (notifications) {
          add(const NotificationsLoaded());
        },
      );
      
      // Charger les notifications
      add(const NotificationsLoaded());
    } catch (e) {
      emit(state.copyWith(error: 'Erreur lors de l\'initialisation des notifications: $e', isLoading: false));
    }
  }
  
  /// Charge les notifications depuis le repository
  void _onNotificationsLoaded(
    NotificationsLoaded event,
    Emitter<NotificationState> emit,
  ) {
    try {
      final notifications = _notificationRepository.getAllNotifications();
      emit(state.loaded(notifications));
    } catch (e) {
      emit(state.copyWith(error: 'Erreur lors du chargement des notifications: $e', isLoading: false));
    }
  }
  
  /// Actualise les notifications depuis l'API
  Future<void> _onNotificationsRefreshed(
    NotificationsRefreshed event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      emit(state.loading());
      await _notificationRepository.fetchNotificationsFromApi();
    } catch (e) {
      emit(state.copyWith(error: 'Erreur lors de l\'actualisation des notifications: $e', isLoading: false));
    }
  }
  
  /// Crée une nouvelle notification
  Future<void> _onNotificationCreated(
    NotificationCreated event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _notificationRepository.createNotification(
        title: event.title,
        message: event.message,
        type: event.type,
        actionRoute: event.actionRoute,
        additionalData: event.additionalData,
      );
    } catch (e) {
      emit(state.copyWith(error: 'Erreur lors de la création de la notification: $e', isLoading: false));
    }
  }
  
  /// Marque une notification comme lue
  Future<void> _onNotificationMarkedAsRead(
    NotificationMarkedAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _notificationRepository.markAsRead(event.id);
    } catch (e) {
      emit(state.copyWith(error: 'Erreur lors du marquage de la notification comme lue: $e', isLoading: false));
    }
  }
  
  /// Marque toutes les notifications comme lues
  Future<void> _onAllNotificationsMarkedAsRead(
    AllNotificationsMarkedAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _notificationRepository.markAllAsRead();
    } catch (e) {
      emit(state.copyWith(error: 'Erreur lors du marquage de toutes les notifications comme lues: $e', isLoading: false));
    }
  }
  
  /// Supprime une notification
  Future<void> _onNotificationDeleted(
    NotificationDeleted event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _notificationRepository.deleteNotification(event.id);
    } catch (e) {
      emit(state.copyWith(error: 'Erreur lors de la suppression de la notification: $e', isLoading: false));
    }
  }
  
  /// Crée une notification de stock bas
  Future<void> _onLowStockNotificationCreated(
    LowStockNotificationCreated event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final notification = NotificationModel.create(
        title: 'Stock bas',
        message: 'Le produit ${event.productName} n\'a plus que ${event.quantity} unités en stock.',
        type: NotificationType.lowStock,
        actionRoute: '/inventory',
        additionalData: event.productId,
      );
      
      await _notificationRepository.saveNotification(notification);
    } catch (e) {
      emit(state.copyWith(error: 'Erreur lors de la création de la notification de stock bas: $e', isLoading: false));
    }
  }
  
  /// Crée une notification de nouvelle vente
  Future<void> _onNewSaleNotificationCreated(
    NewSaleNotificationCreated event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final notification = NotificationModel.create(
        title: 'Nouvelle vente',
        message: 'Vente #${event.invoiceNumber} de ${event.amount.toStringAsFixed(2)} à ${event.customerName}',
        type: NotificationType.sale,
        actionRoute: event.saleId != null ? '/sales/${event.saleId}' : '/sales',
        additionalData: event.saleId,
      );
      
      await _notificationRepository.saveNotification(notification);
    } catch (e) {
      emit(state.copyWith(error: 'Erreur lors de la création de la notification de nouvelle vente: $e', isLoading: false));
    }
  }
  
  /// Synchronise les notifications avec l'API
  Future<void> _onNotificationsSynchronized(
    NotificationsSynchronized event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true));
      await _notificationRepository.syncNotifications();
    } catch (e) {
      emit(state.copyWith(error: 'Erreur lors de la synchronisation des notifications: $e', isLoading: false));
    }
  }
  
  @override
  Future<void> close() {
    _notificationsSubscription?.cancel();
    _notificationRepository.dispose();
    return super.close();
  }
}
