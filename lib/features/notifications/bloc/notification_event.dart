// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\notifications\bloc\notification_event.dart

import 'package:equatable/equatable.dart';
import '../models/notification_model.dart';

/// Événements pour le bloc de notifications
abstract class NotificationEvent extends Equatable {
  const NotificationEvent();
  
  @override
  List<Object?> get props => [];
}

/// Événement pour initialiser les notifications
class NotificationsInitialized extends NotificationEvent {
  const NotificationsInitialized();
}

/// Événement pour charger les notifications
class NotificationsLoaded extends NotificationEvent {
  const NotificationsLoaded();
}

/// Événement pour actualiser les notifications
class NotificationsRefreshed extends NotificationEvent {
  const NotificationsRefreshed();
}

/// Événement pour créer une notification
class NotificationCreated extends NotificationEvent {
  final String title;
  final String message;
  final NotificationType type;
  final String? actionRoute;
  final String? additionalData;
  
  const NotificationCreated({
    required this.title,
    required this.message,
    required this.type,
    this.actionRoute,
    this.additionalData,
  });
  
  @override
  List<Object?> get props => [title, message, type, actionRoute, additionalData];
}

/// Événement pour marquer une notification comme lue
class NotificationMarkedAsRead extends NotificationEvent {
  final String id;
  
  const NotificationMarkedAsRead(this.id);
  
  @override
  List<Object?> get props => [id];
}

/// Événement pour marquer toutes les notifications comme lues
class AllNotificationsMarkedAsRead extends NotificationEvent {
  const AllNotificationsMarkedAsRead();
}

/// Événement pour supprimer une notification
class NotificationDeleted extends NotificationEvent {
  final String id;
  
  const NotificationDeleted(this.id);
  
  @override
  List<Object?> get props => [id];
}

/// Événement pour créer une notification de stock bas
class LowStockNotificationCreated extends NotificationEvent {
  final String productName;
  final int quantity;
  final String? productId;
  
  const LowStockNotificationCreated({
    required this.productName,
    required this.quantity,
    this.productId,
  });
  
  @override
  List<Object?> get props => [productName, quantity, productId];
}

/// Événement pour créer une notification de nouvelle vente
class NewSaleNotificationCreated extends NotificationEvent {
  final String invoiceNumber;
  final double amount;
  final String customerName;
  final String? saleId;
  
  const NewSaleNotificationCreated({
    required this.invoiceNumber,
    required this.amount,
    required this.customerName,
    this.saleId,
  });
  
  @override
  List<Object?> get props => [invoiceNumber, amount, customerName, saleId];
}

/// Événement pour synchroniser les notifications
class NotificationsSynchronized extends NotificationEvent {
  const NotificationsSynchronized();
}
