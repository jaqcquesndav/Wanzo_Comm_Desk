import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

part 'notifications_event.dart';
part 'notifications_state.dart';

/// Bloc pour gérer l'état des notifications
class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final NotificationService _notificationService;
  late StreamSubscription<NotificationModel> _notificationSubscription;
  
  /// Constructeur
  NotificationsBloc(this._notificationService) : super(NotificationsInitial()) {
    on<LoadNotifications>(_onLoadNotifications);
    on<NotificationAdded>(_onNotificationAdded);
    on<MarkNotificationAsRead>(_onMarkNotificationAsRead);
    on<MarkAllNotificationsAsRead>(_onMarkAllNotificationsAsRead);
    on<DeleteNotification>(_onDeleteNotification);
    on<DeleteAllNotifications>(_onDeleteAllNotifications);
    
    // S'abonner au flux de notifications
    _notificationSubscription = _notificationService.notificationsStream
        .listen((notification) {
          add(NotificationAdded(notification));
        });
  }
  
  Future<void> _onLoadNotifications(
    LoadNotifications event, 
    Emitter<NotificationsState> emit
  ) async {
    emit(NotificationsLoading());
    
    try {
      final allNotifications = _notificationService.getAllNotifications();
      final unreadNotifications = _notificationService.getUnreadNotifications();
      
      emit(NotificationsLoaded(
        notifications: allNotifications,
        unreadCount: unreadNotifications.length,
      ));
    } catch (e) {
      emit(NotificationsError('Erreur lors du chargement des notifications: $e'));
    }
  }
  
  void _onNotificationAdded(
    NotificationAdded event,
    Emitter<NotificationsState> emit
  ) {
    final currentState = state;
    
    if (currentState is NotificationsLoaded) {
      final updatedNotifications = List<NotificationModel>.from(currentState.notifications)
        ..add(event.notification);
      
      final unreadCount = updatedNotifications
        .where((notification) => !notification.isRead)
        .length;
      
      emit(NotificationsLoaded(
        notifications: updatedNotifications,
        unreadCount: unreadCount,
      ));
    } else {
      add(LoadNotifications());
    }
  }
  
  Future<void> _onMarkNotificationAsRead(
    MarkNotificationAsRead event,
    Emitter<NotificationsState> emit
  ) async {
    final currentState = state;
    
    if (currentState is NotificationsLoaded) {
      await _notificationService.markNotificationAsRead(event.notificationId);
      
      // Mettre à jour la liste des notifications
      final updatedNotifications = currentState.notifications.map((notification) {
        if (notification.id == event.notificationId) {
          return notification.markAsRead();
        }
        return notification;
      }).toList();
      
      final unreadCount = updatedNotifications
        .where((notification) => !notification.isRead)
        .length;
      
      emit(NotificationsLoaded(
        notifications: updatedNotifications,
        unreadCount: unreadCount,
      ));
    }
  }
  
  Future<void> _onMarkAllNotificationsAsRead(
    MarkAllNotificationsAsRead event,
    Emitter<NotificationsState> emit
  ) async {
    final currentState = state;
    
    if (currentState is NotificationsLoaded) {
      await _notificationService.markAllNotificationsAsRead();
      
      // Mettre à jour toutes les notifications comme lues
      final updatedNotifications = currentState.notifications
        .map((notification) => notification.markAsRead())
        .toList();
      
      emit(NotificationsLoaded(
        notifications: updatedNotifications,
        unreadCount: 0,
      ));
    }
  }
  
  Future<void> _onDeleteNotification(
    DeleteNotification event,
    Emitter<NotificationsState> emit
  ) async {
    final currentState = state;
    
    if (currentState is NotificationsLoaded) {
      await _notificationService.deleteNotification(event.notificationId);
      
      // Retirer la notification de la liste
      final updatedNotifications = currentState.notifications
        .where((notification) => notification.id != event.notificationId)
        .toList();
      
      final unreadCount = updatedNotifications
        .where((notification) => !notification.isRead)
        .length;
      
      emit(NotificationsLoaded(
        notifications: updatedNotifications,
        unreadCount: unreadCount,
      ));
    }
  }
  
  Future<void> _onDeleteAllNotifications(
    DeleteAllNotifications event,
    Emitter<NotificationsState> emit
  ) async {
    await _notificationService.deleteAllNotifications();
    
    emit(const NotificationsLoaded(
      notifications: [],
      unreadCount: 0,
    ));
  }
  
  @override
  Future<void> close() {
    _notificationSubscription.cancel();
    return super.close();
  }
}
