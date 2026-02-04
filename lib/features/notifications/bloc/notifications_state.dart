part of 'notifications_bloc.dart';

/// États liés aux notifications
abstract class NotificationsState extends Equatable {
  const NotificationsState();
  
  @override
  List<Object> get props => [];
}

/// État initial des notifications
class NotificationsInitial extends NotificationsState {}

/// État du chargement des notifications en cours
class NotificationsLoading extends NotificationsState {}

/// État des notifications chargées avec succès
class NotificationsLoaded extends NotificationsState {
  /// Liste des notifications
  final List<NotificationModel> notifications;
  
  /// Nombre de notifications non lues
  final int unreadCount;
  
  const NotificationsLoaded({
    required this.notifications,
    required this.unreadCount,
  });
  
  @override
  List<Object> get props => [notifications, unreadCount];
}

/// État d'erreur lors du chargement des notifications
class NotificationsError extends NotificationsState {
  /// Message d'erreur
  final String message;
  
  const NotificationsError(this.message);
  
  @override
  List<Object> get props => [message];
}
