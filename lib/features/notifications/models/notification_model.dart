import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notification_model.g.dart';

/// Type de notification
@HiveType(typeId: 29)
@JsonEnum()
enum NotificationType {
  /// Notification d'information
  @HiveField(0)
  info,

  /// Notification de succès
  @HiveField(1)
  success,

  /// Notification d'avertissement
  @HiveField(2)
  warning,

  /// Notification d'erreur
  @HiveField(3)
  error,

  /// Notification de stock bas
  @HiveField(4)
  lowStock,

  /// Notification de vente
  @HiveField(5)
  sale,

  /// Notification de paiement
  @HiveField(6)
  payment,
}

/// Modèle pour les notifications de l'application
@HiveType(typeId: 28)
@JsonSerializable(explicitToJson: true)
class NotificationModel extends Equatable {
  /// Identifiant unique de la notification
  @HiveField(0)
  final String id;

  /// Titre de la notification
  @HiveField(1)
  final String? title; // Made title nullable

  /// Message de la notification
  @HiveField(2)
  final String message;

  /// Type de notification
  @HiveField(3)
  final NotificationType type;

  /// Date de la notification
  @HiveField(4)
  final DateTime timestamp;

  /// La notification a-t-elle été lue?
  @HiveField(5)
  final bool isRead;

  /// URL ou route associée à la notification
  @HiveField(6)
  final String? actionRoute;

  /// Données additionnelles (JSON sérialisé)
  @HiveField(7)
  final String? additionalData;

  // === Champs Business Unit (Multi-Tenant) ===
  /// ID de l'entreprise principale
  @HiveField(8)
  @JsonKey(name: 'companyId')
  final String? companyId;

  /// ID de l'unité commerciale
  @HiveField(9)
  @JsonKey(name: 'businessUnitId')
  final String? businessUnitId;

  /// Constructeur
  const NotificationModel({
    required this.id,
    this.title, // Updated constructor
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.actionRoute,
    this.additionalData,
    this.companyId,
    this.businessUnitId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationModelToJson(this);

  /// Crée une nouvelle notification avec un ID généré automatiquement
  factory NotificationModel.create({
    required String title,
    required String message,
    required NotificationType type,
    DateTime? timestamp,
    bool isRead = false,
    String? actionRoute,
    String? additionalData,
    String? companyId,
    String? businessUnitId,
  }) {
    return NotificationModel(
      id: const Uuid().v4(),
      title: title,
      message: message,
      type: type,
      timestamp: timestamp ?? DateTime.now(),
      isRead: isRead,
      actionRoute: actionRoute,
      additionalData: additionalData,
      companyId: companyId,
      businessUnitId: businessUnitId,
    );
  }

  /// Crée une notification de stock bas
  factory NotificationModel.lowStock({
    required String productName,
    required int quantity,
    String? productId,
  }) {
    return NotificationModel.create(
      title: 'Stock bas',
      message:
          'Le produit $productName n\'a plus que $quantity unités en stock.',
      type: NotificationType.lowStock,
      actionRoute: '/inventory',
      additionalData: productId,
    );
  }

  /// Crée une notification de nouvelle vente
  factory NotificationModel.newSale({
    required String invoiceNumber,
    required double amount,
    required String customerName,
    String? saleId,
  }) {
    return NotificationModel.create(
      title: 'Nouvelle vente',
      message:
          'Vente #$invoiceNumber de ${amount.toStringAsFixed(2)} à $customerName',
      type: NotificationType.sale,
      actionRoute: saleId != null ? '/sales/$saleId' : '/sales',
      additionalData: saleId,
    );
  }

  /// Crée une copie de la notification avec des valeurs modifiées
  NotificationModel copyWith({
    String? title,
    String? message,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    String? actionRoute,
    String? additionalData,
    String? companyId,
    String? businessUnitId,
  }) {
    return NotificationModel(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      actionRoute: actionRoute ?? this.actionRoute,
      additionalData: additionalData ?? this.additionalData,
      companyId: companyId ?? this.companyId,
      businessUnitId: businessUnitId ?? this.businessUnitId,
    );
  }

  /// Marque la notification comme lue
  NotificationModel markAsRead() {
    return copyWith(isRead: true);
  }

  @override
  List<Object?> get props => [
    id,
    title, // Added to props
    message,
    type,
    timestamp,
    isRead,
    actionRoute,
    additionalData,
    companyId,
    businessUnitId,
  ];
}
