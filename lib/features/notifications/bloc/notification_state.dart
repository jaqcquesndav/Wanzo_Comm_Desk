// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\notifications\bloc\notification_state.dart

import 'package:equatable/equatable.dart';
import '../models/notification_model.dart';

/// État du bloc de notifications
class NotificationState extends Equatable {
  /// Liste des notifications
  final List<NotificationModel> notifications;
  
  /// Indique si les notifications sont en cours de chargement
  final bool isLoading;
  
  /// Message d'erreur éventuel
  final String? error;
  
  /// Constructeur
  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });
  
  /// État initial
  factory NotificationState.initial() {
    return const NotificationState(
      notifications: [],
      isLoading: true,
    );
  }
  
  /// État en cours de chargement
  NotificationState loading() {
    return NotificationState(
      notifications: notifications,
      isLoading: true,
      error: null,
    );
  }
  
  /// État chargé avec succès
  NotificationState loaded(List<NotificationModel> newNotifications) {
    return NotificationState(
      notifications: newNotifications,
      isLoading: false,
      error: null,
    );
  }
    /// État en erreur
  // This method has been replaced by copyWith to avoid name conflicts
  // NotificationState error(String errorMessage) {
  //   return NotificationState(
  //     notifications: notifications,
  //     isLoading: false,
  //     error: errorMessage,
  //   );
  // }
  
  /// Nombre de notifications non lues
  int get unreadCount => notifications.where((notification) => !notification.isRead).length;
  
  /// Crée une copie de l'état avec des propriétés modifiées
  NotificationState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
  
  @override
  List<Object?> get props => [notifications, isLoading, error];
}
