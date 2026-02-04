part of 'notifications_bloc.dart';

/// Événements liés aux notifications
abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();
  
  @override
  List<Object?> get props => [];
}

/// Événement pour charger toutes les notifications
class LoadNotifications extends NotificationsEvent {}

/// Événement lorsqu'une nouvelle notification est ajoutée
class NotificationAdded extends NotificationsEvent {
  /// La notification qui vient d'être ajoutée
  final NotificationModel notification;
  
  const NotificationAdded(this.notification);
  
  @override
  List<Object> get props => [notification];
}

/// Événement pour marquer une notification comme lue
class MarkNotificationAsRead extends NotificationsEvent {
  /// Identifiant de la notification à marquer comme lue
  final String notificationId;
  
  const MarkNotificationAsRead(this.notificationId);
  
  @override
  List<Object> get props => [notificationId];
}

/// Événement pour marquer toutes les notifications comme lues
class MarkAllNotificationsAsRead extends NotificationsEvent {}

/// Événement pour supprimer une notification
class DeleteNotification extends NotificationsEvent {
  /// Identifiant de la notification à supprimer
  final String notificationId;
  
  const DeleteNotification(this.notificationId);
  
  @override
  List<Object> get props => [notificationId];
}

/// Événement pour supprimer toutes les notifications
class DeleteAllNotifications extends NotificationsEvent {}
