import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:flutter/material.dart'; // Import pour IconData et Icons
import 'package:wanzo/core/enums/business_unit_enums.dart';

part 'expense.g.dart';

@HiveType(
  typeId: 202,
) // Changé à 202 pour éviter conflits (9 utilisé par NotificationAdapter et FinancialInstitutionAdapter)
enum ExpenseCategory {
  @HiveField(0)
  rent,
  @HiveField(1)
  utilities,
  @HiveField(2)
  supplies,
  @HiveField(3)
  salaries,
  @HiveField(4)
  marketing,
  @HiveField(5)
  transport,
  @HiveField(6)
  maintenance,
  @HiveField(7)
  other,
  // Nouvelles catégories pour les entreprises commerciales
  @HiveField(8)
  inventory,
  @HiveField(9)
  equipment,
  @HiveField(10)
  taxes,
  @HiveField(11)
  insurance,
  @HiveField(12)
  loan,
  @HiveField(13)
  office,
  @HiveField(14)
  training,
  @HiveField(15)
  travel,
  @HiveField(16)
  software,
  @HiveField(17)
  advertising,
  @HiveField(18)
  legal,
  @HiveField(19)
  manufacturing,
  @HiveField(20)
  consulting,
  @HiveField(21)
  research,
  @HiveField(22)
  fuel,
  @HiveField(23)
  entertainment,
  @HiveField(24)
  communication,
}

@HiveType(typeId: 203) // Payment status enum
enum ExpensePaymentStatus {
  @HiveField(0)
  paid,
  @HiveField(1)
  partial,
  @HiveField(2)
  unpaid,
  @HiveField(3)
  credit,
}

extension ExpenseCategoryExtension on ExpenseCategory {
  String get displayName {
    switch (this) {
      case ExpenseCategory.rent:
        return 'Loyer';
      case ExpenseCategory.utilities:
        return 'Services Publics';
      case ExpenseCategory.supplies:
        return 'Fournitures';
      case ExpenseCategory.salaries:
        return 'Salaires';
      case ExpenseCategory.marketing:
        return 'Marketing';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.maintenance:
        return 'Maintenance';
      case ExpenseCategory.inventory:
        return 'Stock et Inventaire';
      case ExpenseCategory.equipment:
        return 'Équipement';
      case ExpenseCategory.taxes:
        return 'Taxes et Impôts';
      case ExpenseCategory.insurance:
        return 'Assurances';
      case ExpenseCategory.loan:
        return 'Remboursement de Prêt';
      case ExpenseCategory.office:
        return 'Fournitures de Bureau';
      case ExpenseCategory.training:
        return 'Formation et Développement';
      case ExpenseCategory.travel:
        return 'Voyages d\'Affaires';
      case ExpenseCategory.software:
        return 'Logiciels et Technologie';
      case ExpenseCategory.advertising:
        return 'Publicité';
      case ExpenseCategory.legal:
        return 'Services Juridiques';
      case ExpenseCategory.manufacturing:
        return 'Production et Fabrication';
      case ExpenseCategory.consulting:
        return 'Conseil et Services';
      case ExpenseCategory.research:
        return 'Recherche et Développement';
      case ExpenseCategory.fuel:
        return 'Carburant';
      case ExpenseCategory.entertainment:
        return 'Représentation et Cadeaux';
      case ExpenseCategory.communication:
        return 'Télécommunications';
      case ExpenseCategory.other:
        return 'Autre';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.rent:
        return Icons.home;
      case ExpenseCategory.utilities:
        return Icons.electric_bolt;
      case ExpenseCategory.supplies:
        return Icons.shopping_bag;
      case ExpenseCategory.salaries:
        return Icons.people;
      case ExpenseCategory.marketing:
        return Icons.campaign;
      case ExpenseCategory.transport:
        return Icons.directions_car;
      case ExpenseCategory.maintenance:
        return Icons.build;
      case ExpenseCategory.inventory:
        return Icons.inventory_2;
      case ExpenseCategory.equipment:
        return Icons.construction;
      case ExpenseCategory.taxes:
        return Icons.receipt_long;
      case ExpenseCategory.insurance:
        return Icons.security;
      case ExpenseCategory.loan:
        return Icons.account_balance;
      case ExpenseCategory.office:
        return Icons.business_center;
      case ExpenseCategory.training:
        return Icons.school;
      case ExpenseCategory.travel:
        return Icons.flight;
      case ExpenseCategory.software:
        return Icons.computer;
      case ExpenseCategory.advertising:
        return Icons.ads_click;
      case ExpenseCategory.legal:
        return Icons.gavel;
      case ExpenseCategory.manufacturing:
        return Icons.precision_manufacturing;
      case ExpenseCategory.consulting:
        return Icons.support_agent;
      case ExpenseCategory.research:
        return Icons.science;
      case ExpenseCategory.fuel:
        return Icons.local_gas_station;
      case ExpenseCategory.entertainment:
        return Icons.card_giftcard;
      case ExpenseCategory.communication:
        return Icons.phone_in_talk;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }
}

@JsonSerializable() // Added for json_serializable
@HiveType(typeId: 11) // Ensure typeId is unique
class Expense extends Equatable {
  @HiveField(0)
  final String id; // Server ID

  @HiveField(9)
  @JsonKey(includeIfNull: false)
  final String? localId; // Local unique ID

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  @JsonKey(name: 'motif') // Map 'motif' from JSON to 'motif' in Dart
  final String motif; // Renamed from description

  @HiveField(3)
  final double amount;

  @HiveField(4)
  final ExpenseCategory category;

  @HiveField(5)
  final String? paymentMethod; // e.g., cash, bank transfer

  @HiveField(6)
  @JsonKey(name: 'attachmentUrls') // Map 'attachmentUrls' from JSON
  final List<String>? attachmentUrls; // Synced Cloudinary URLs

  @HiveField(10)
  @JsonKey(
    includeToJson: false,
    includeFromJson: false,
  ) // Only for local use before sync
  final List<String>? localAttachmentPaths;

  @HiveField(7) // New HiveField, ensure unique index
  @JsonKey(name: 'supplierId') // Map 'supplierId' from JSON
  final String? supplierId; // Added supplierId

  @HiveField(11)
  @JsonKey(includeIfNull: false)
  final String? beneficiary;

  @HiveField(12)
  @JsonKey(includeIfNull: false)
  final String? notes;

  @JsonKey(includeIfNull: false)
  final String? userId;

  @JsonKey(includeIfNull: false)
  final DateTime? createdAt;

  @JsonKey(includeIfNull: false)
  final DateTime? updatedAt;

  @JsonKey(includeToJson: false, includeFromJson: false)
  final String? syncStatus;

  @JsonKey(includeToJson: false, includeFromJson: false)
  final DateTime? lastSyncAttempt;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final String? errorMessage;

  @HiveField(8) // Nouvelle propriété pour la devise
  final String? currencyCode; // Code de la devise (USD, CDF, etc.)

  @HiveField(13) // Supplier name for display
  @JsonKey(includeIfNull: false)
  final String? supplierName;

  @HiveField(14) // Amount paid so far
  final double? paidAmount;

  @HiveField(15) // Exchange rate used for multi-currency
  @JsonKey(includeIfNull: false)
  final double? exchangeRate;

  @HiveField(16) // Payment status
  final ExpensePaymentStatus? paymentStatus;

  // Business unit context fields
  @HiveField(17)
  @JsonKey(includeIfNull: false)
  final String? companyId;

  @HiveField(18)
  @JsonKey(includeIfNull: false)
  final String? businessUnitId;

  @HiveField(19)
  @JsonKey(includeIfNull: false)
  final String? businessUnitCode;

  @HiveField(20)
  @JsonKey(includeIfNull: false)
  final BusinessUnitType? businessUnitType;

  const Expense({
    required this.id,
    this.localId,
    required this.date,
    required this.motif, // Updated from description
    required this.amount,
    required this.category,
    this.paymentMethod,
    this.attachmentUrls, // Updated from relatedDocumentId
    this.localAttachmentPaths,
    this.supplierId, // Added supplierId
    this.beneficiary,
    this.notes,
    this.currencyCode, // Ajout du code de devise
    this.supplierName, // Added supplier name
    this.paidAmount = 0.0, // Default to 0
    this.exchangeRate, // Optional exchange rate
    this.paymentStatus = ExpensePaymentStatus.unpaid, // Default to unpaid
    this.companyId,
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitType,
    this.userId,
    this.createdAt,
    this.updatedAt,
    this.syncStatus,
    this.lastSyncAttempt,
    this.errorMessage,
  });
  @override
  List<Object?> get props => [
    id,
    localId,
    date,
    motif,
    amount,
    category,
    paymentMethod,
    attachmentUrls,
    localAttachmentPaths,
    supplierId,
    beneficiary,
    notes,
    currencyCode,
    supplierName,
    paidAmount,
    exchangeRate,
    paymentStatus,
    companyId,
    businessUnitId,
    businessUnitCode,
    businessUnitType,
    userId,
    createdAt,
    updatedAt,
    syncStatus,
    lastSyncAttempt,
    errorMessage,
  ]; // Updated props
  Expense copyWith({
    String? id,
    String? localId,
    DateTime? date,
    String? motif, // Updated from description
    double? amount,
    ExpenseCategory? category,
    String? paymentMethod,
    List<String>? attachmentUrls, // Updated from relatedDocumentId
    List<String>? localAttachmentPaths,
    String? supplierId, // Added supplierId
    String? beneficiary,
    String? notes,
    String? currencyCode, // Ajout du code de devise
    String? supplierName,
    double? paidAmount,
    double? exchangeRate,
    ExpensePaymentStatus? paymentStatus,
    String? companyId,
    String? businessUnitId,
    String? businessUnitCode,
    BusinessUnitType? businessUnitType,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
    DateTime? lastSyncAttempt,
    String? errorMessage,
  }) {
    return Expense(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      date: date ?? this.date,
      motif: motif ?? this.motif, // Updated from description
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls, // Updated
      localAttachmentPaths: localAttachmentPaths ?? this.localAttachmentPaths,
      supplierId: supplierId ?? this.supplierId, // Added
      beneficiary: beneficiary ?? this.beneficiary,
      notes: notes ?? this.notes,
      currencyCode:
          currencyCode ?? this.currencyCode, // Ajout du code de devise
      supplierName: supplierName ?? this.supplierName,
      paidAmount: paidAmount ?? this.paidAmount,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      companyId: companyId ?? this.companyId,
      businessUnitId: businessUnitId ?? this.businessUnitId,
      businessUnitCode: businessUnitCode ?? this.businessUnitCode,
      businessUnitType: businessUnitType ?? this.businessUnitType,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // Add fromJson and toJson factory constructors for json_serializable
  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);
  Map<String, dynamic> toJson() => _$ExpenseToJson(this);

  String get hiveKey {
    // If 'id' (server ID) is empty, it implies it's a new, unsynced item,
    // so 'localId' (if available and not empty) should be its key in Hive.
    if (id.isEmpty && localId != null && localId!.isNotEmpty) {
      return localId!;
    }
    // Otherwise, 'id' (server ID) is assumed to be the key.
    // This covers synced items and items fetched from the API.
    return id;
  }

  /// Obtient le code de devise effectif pour cette dépense
  String get effectiveCurrencyCode => currencyCode ?? 'CDF';

  /// Calcule le montant restant à payer
  double get remainingAmount => amount - (paidAmount ?? 0.0);

  /// Vérifie si la dépense est complètement payée
  bool get isPaidFully => (paidAmount ?? 0.0) >= amount;

  /// Obtient la couleur du statut de paiement
  String get paymentStatusColor {
    switch (paymentStatus) {
      case ExpensePaymentStatus.paid:
        return '#4CAF50'; // Green
      case ExpensePaymentStatus.partial:
        return '#FF9800'; // Orange
      case ExpensePaymentStatus.unpaid:
      case null:
        return '#F44336'; // Red
      case ExpensePaymentStatus.credit:
        return '#2196F3'; // Blue
    }
  }

  /// Obtient le texte du statut de paiement
  String get paymentStatusText {
    switch (paymentStatus) {
      case ExpensePaymentStatus.paid:
        return 'Payé';
      case ExpensePaymentStatus.partial:
        return 'Partiellement payé';
      case ExpensePaymentStatus.unpaid:
      case null:
        return 'Non payé';
      case ExpensePaymentStatus.credit:
        return 'À crédit';
    }
  }
}

extension ExpensePaymentStatusExtension on ExpensePaymentStatus {
  String get displayName {
    switch (this) {
      case ExpensePaymentStatus.paid:
        return 'Payé';
      case ExpensePaymentStatus.partial:
        return 'Partiellement payé';
      case ExpensePaymentStatus.unpaid:
        return 'Non payé';
      case ExpensePaymentStatus.credit:
        return 'À crédit';
    }
  }
}

// Note: BusinessUnitType serialization is handled by json_serializable
// using the enum's default serialization since it's a simple enum with JsonValue annotations
// in business_unit_enums.dart
