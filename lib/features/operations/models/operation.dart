import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';

part 'operation.g.dart';

/// Types d'opérations commerciales
@HiveType(typeId: 60)
@JsonEnum()
enum OperationType {
  @HiveField(0)
  sale, // Vente

  @HiveField(1)
  expense, // Dépense

  @HiveField(2)
  financing, // Demande de Financement

  @HiveField(3)
  inventory, // Opération d'Inventaire

  @HiveField(4)
  transaction, // Transaction Financière
}

/// Statuts d'opérations (conformément à l'API documentation)
@HiveType(typeId: 62)
@JsonEnum()
enum OperationStatus {
  @HiveField(0)
  completed, // Opération terminée avec succès

  @HiveField(1)
  pending, // Opération en cours de traitement

  @HiveField(2)
  cancelled, // Opération annulée

  @HiveField(3)
  failed, // Opération échouée (erreur)
}

/// Extension pour faciliter l'utilisation des statuts d'opération
extension OperationStatusExtension on OperationStatus {
  String get displayName {
    switch (this) {
      case OperationStatus.completed:
        return 'Complétée';
      case OperationStatus.pending:
        return 'En attente';
      case OperationStatus.cancelled:
        return 'Annulée';
      case OperationStatus.failed:
        return 'Échouée';
    }
  }

  String get apiValue {
    switch (this) {
      case OperationStatus.completed:
        return 'completed';
      case OperationStatus.pending:
        return 'pending';
      case OperationStatus.cancelled:
        return 'cancelled';
      case OperationStatus.failed:
        return 'failed';
    }
  }

  static OperationStatus fromApiValue(String value) {
    switch (value) {
      case 'completed':
        return OperationStatus.completed;
      case 'pending':
        return OperationStatus.pending;
      case 'cancelled':
        return OperationStatus.cancelled;
      case 'failed':
        return OperationStatus.failed;
      default:
        return OperationStatus.pending;
    }
  }
}

/// Extension pour faciliter l'utilisation des types d'opération
extension OperationTypeExtension on OperationType {
  String get displayName {
    switch (this) {
      case OperationType.sale:
        return 'Vente';
      case OperationType.expense:
        return 'Dépense';
      case OperationType.financing:
        return 'Financement';
      case OperationType.inventory:
        return 'Inventaire';
      case OperationType.transaction:
        return 'Transaction';
    }
  }
}

/// Modèle représentant une opération commerciale centralisée
@HiveType(typeId: 61)
@JsonSerializable(explicitToJson: true)
class Operation extends Equatable {
  /// Identifiant unique de l'opération
  @HiveField(0)
  final String id;

  /// Type d'opération
  @HiveField(1)
  final OperationType type;

  /// Date de l'opération
  @HiveField(2)
  final DateTime date;

  /// Description de l'opération
  @HiveField(3)
  final String description;

  /// ID de l'entité associée (vente, dépense, etc.)
  @HiveField(4)
  final String? entityId;

  /// Montant en CDF
  @HiveField(5)
  final double amountCdf;

  /// Montant en USD (si applicable)
  @HiveField(6)
  final double? amountUsd;

  /// ID de la partie liée (client, fournisseur)
  @HiveField(7)
  final String? relatedPartyId;

  /// Nom de la partie liée
  @HiveField(8)
  final String? relatedPartyName;

  /// Statut de l'opération (typed enum)
  @HiveField(9)
  @JsonKey(fromJson: _statusFromJson, toJson: _statusToJson)
  final OperationStatus status;

  /// ID de l'utilisateur qui a créé l'opération
  @HiveField(10)
  final String? createdBy;

  /// Date de création
  @HiveField(11)
  final DateTime createdAt;

  /// Date de mise à jour
  @HiveField(12)
  final DateTime updatedAt;

  /// Méthode de paiement (pour les ventes/dépenses)
  @HiveField(13)
  final String? paymentMethod;

  /// ID de la catégorie (pour les dépenses)
  @HiveField(14)
  final String? categoryId;

  /// Nombre de produits (pour les ventes)
  @HiveField(15)
  final int? productCount;

  /// Notes supplémentaires
  @HiveField(16)
  final String? notes;

  // ============= BUSINESS UNIT FIELDS =============

  /// ID de l'entreprise associée
  @HiveField(17)
  final String? companyId;

  /// ID de l'unité commerciale
  @HiveField(18)
  final String? businessUnitId;

  /// Code de l'unité (ex: POS-001)
  @HiveField(19)
  final String? businessUnitCode;

  /// Type d'unité: company, branch ou pos
  @HiveField(20)
  @JsonKey(fromJson: _businessUnitTypeFromJson, toJson: _businessUnitTypeToJson)
  final BusinessUnitType? businessUnitType;

  /// Données additionnelles (JSONB format libre)
  @HiveField(21)
  final Map<String, dynamic>? additionalData;

  const Operation({
    required this.id,
    required this.type,
    required this.date,
    required this.description,
    this.entityId,
    required this.amountCdf,
    this.amountUsd,
    this.relatedPartyId,
    this.relatedPartyName,
    required this.status,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.paymentMethod,
    this.categoryId,
    this.productCount,
    this.notes,
    // Business Unit fields
    this.companyId,
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitType,
    this.additionalData,
  });

  // Helpers pour la sérialisation
  static OperationStatus _statusFromJson(dynamic value) =>
      value is String
          ? OperationStatusExtension.fromApiValue(value)
          : OperationStatus.pending;

  static String _statusToJson(OperationStatus status) => status.apiValue;

  static BusinessUnitType? _businessUnitTypeFromJson(String? value) =>
      value != null ? BusinessUnitTypeExtension.fromApiValue(value) : null;

  static String? _businessUnitTypeToJson(BusinessUnitType? type) =>
      type?.apiValue;

  factory Operation.fromJson(Map<String, dynamic> json) =>
      _$OperationFromJson(json);
  Map<String, dynamic> toJson() => _$OperationToJson(this);

  Operation copyWith({
    String? id,
    OperationType? type,
    DateTime? date,
    String? description,
    String? entityId,
    double? amountCdf,
    double? amountUsd,
    String? relatedPartyId,
    String? relatedPartyName,
    OperationStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? paymentMethod,
    String? categoryId,
    int? productCount,
    String? notes,
    String? companyId,
    String? businessUnitId,
    String? businessUnitCode,
    BusinessUnitType? businessUnitType,
    Map<String, dynamic>? additionalData,
  }) {
    return Operation(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      description: description ?? this.description,
      entityId: entityId ?? this.entityId,
      amountCdf: amountCdf ?? this.amountCdf,
      amountUsd: amountUsd ?? this.amountUsd,
      relatedPartyId: relatedPartyId ?? this.relatedPartyId,
      relatedPartyName: relatedPartyName ?? this.relatedPartyName,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      categoryId: categoryId ?? this.categoryId,
      productCount: productCount ?? this.productCount,
      notes: notes ?? this.notes,
      companyId: companyId ?? this.companyId,
      businessUnitId: businessUnitId ?? this.businessUnitId,
      businessUnitCode: businessUnitCode ?? this.businessUnitCode,
      businessUnitType: businessUnitType ?? this.businessUnitType,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    date,
    description,
    entityId,
    amountCdf,
    amountUsd,
    relatedPartyId,
    relatedPartyName,
    status,
    createdBy,
    createdAt,
    updatedAt,
    paymentMethod,
    categoryId,
    productCount,
    notes,
    companyId,
    businessUnitId,
    businessUnitCode,
    businessUnitType,
    additionalData,
  ];
}
