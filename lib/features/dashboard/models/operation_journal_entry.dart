import 'package:flutter/material.dart'; // Added for IconData
import 'package:hive/hive.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';

part 'operation_journal_entry.g.dart'; // Pour la génération de code Hive

@HiveType(typeId: 200)
enum OperationType {
  @HiveField(0)
  saleCash,
  @HiveField(1)
  saleCredit,
  @HiveField(2)
  saleInstallment,
  @HiveField(3)
  stockIn, // Entrée de stock (ex: nouvel arrivage, achat fournisseur)
  @HiveField(4)
  stockOut, // Sortie de stock suite à une vente ou ajustement
  @HiveField(5)
  cashIn, // Entrée d'espèce (ex: paiement client, apport)
  @HiveField(6)
  cashOut, // Sortie d'espèce (ex: dépense, retrait)
  @HiveField(7)
  customerPayment, // Paiement reçu d'un client pour une vente à crédit
  @HiveField(8)
  supplierPayment, // Paiement effectué à un fournisseur
  @HiveField(9)
  financingRequest, // Nouvelle demande de financement
  @HiveField(10)
  financingApproved, // Financement approuvé (entrée de fonds)
  @HiveField(11)
  financingRepayment, // Remboursement de financement (sortie de fonds)
  @HiveField(12)
  other;

  // Helper to convert string to OperationType, with a default value
  static OperationType fromString(String? typeString) {
    if (typeString == null) return OperationType.other;
    try {
      return OperationType.values.firstWhere(
        (e) =>
            e.toString().split('.').last.toLowerCase() ==
            typeString.toLowerCase(),
      );
    } catch (e) {
      return OperationType.other;
    }
  }

  String toJson() => name;
  static OperationType fromJson(String json) => fromString(json);
}

extension OperationTypeExtension on OperationType {
  String get displayName {
    switch (this) {
      case OperationType.saleCash:
        return 'Vente (Espèce)';
      case OperationType.saleCredit:
        return 'Vente (Crédit)';
      case OperationType.saleInstallment:
        return 'Vente (Échelonnée)';
      case OperationType.stockIn:
        return 'Entrée Stock';
      case OperationType.stockOut:
        return 'Sortie Stock';
      case OperationType.cashIn:
        return 'Entrée Espèce';
      case OperationType.cashOut:
        return 'Sortie Espèce';
      case OperationType.customerPayment:
        return 'Paiement Client';
      case OperationType.supplierPayment:
        return 'Paiement Fournisseur';
      case OperationType.financingRequest:
        return 'Demande de Financement';
      case OperationType.financingApproved:
        return 'Financement Approuvé';
      case OperationType.financingRepayment:
        return 'Remboursement Financement';
      case OperationType.other:
        return 'Autre'; // Cas 'other' explicite
    }
  }

  /// Indique si cette opération impacte la TRÉSORERIE (caisse/banque)
  bool get impactsCash {
    switch (this) {
      case OperationType.cashIn:
      case OperationType.cashOut:
      case OperationType.customerPayment:
      case OperationType.supplierPayment:
      case OperationType.financingRepayment:
        return true;
      default:
        return false;
    }
  }

  /// Indique si cette opération représente une VENTE (chiffre d'affaires)
  bool get isSalesOperation {
    switch (this) {
      case OperationType.saleCash:
      case OperationType.saleCredit:
      case OperationType.saleInstallment:
        return true;
      default:
        return false;
    }
  }

  /// Indique si cette opération impacte le STOCK (inventaire)
  bool get impactsStock {
    switch (this) {
      case OperationType.stockIn:
      case OperationType.stockOut:
        return true;
      default:
        return false;
    }
  }

  /// Indique si c'est une opération de FINANCEMENT (pas d'impact trésorerie directe)
  bool get isFinancingOperation {
    switch (this) {
      case OperationType.financingRequest:
      case OperationType.financingApproved:
        return true;
      default:
        return false;
    }
  }

  /// Catégorie comptable principale de l'opération
  String get accountingCategory {
    if (impactsCash) return 'Trésorerie';
    if (isSalesOperation) return 'Ventes';
    if (impactsStock) return 'Stock';
    if (isFinancingOperation) return 'Financement';
    return 'Autre';
  }

  IconData get icon {
    switch (this) {
      case OperationType.saleCash:
      case OperationType.saleCredit:
      case OperationType.saleInstallment:
        return Icons.shopping_cart_checkout;
      case OperationType.stockIn:
        return Icons.inventory_2_outlined; // More specific for stock in
      case OperationType.stockOut:
        return Icons.outbox_outlined; // More specific for stock out
      case OperationType.cashIn:
        return Icons.attach_money;
      case OperationType.cashOut:
        return Icons.money_off_csred_outlined;
      case OperationType.customerPayment:
        return Icons.person_pin_circle_outlined;
      case OperationType.supplierPayment:
        return Icons.store_mall_directory_outlined;
      case OperationType.financingRequest:
        return Icons.post_add_outlined;
      case OperationType.financingApproved:
        return Icons.check_circle_outline;
      case OperationType.financingRepayment:
        return Icons.assignment_returned_outlined;
      case OperationType.other:
        return Icons.receipt_long_outlined;
    }
  }
}

@immutable
@HiveType(typeId: 201)
class OperationJournalEntry {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final DateTime date;
  @HiveField(2)
  final String description;
  @HiveField(3)
  final OperationType type;
  @HiveField(4)
  final double amount; // Positif pour entrées/revenus, négatif pour sorties/dépenses
  @HiveField(5)
  final String? relatedDocumentId; // Ex: ID de la vente
  @HiveField(6)
  final double? quantity; // Quantité pour les mouvements de stock
  @HiveField(7)
  final String? productId; // ID du produit pour les mouvements de stock
  @HiveField(8)
  final String? productName; // Nom du produit pour les mouvements de stock
  @HiveField(9)
  final String? paymentMethod; // Méthode de paiement pour les transactions financières
  @HiveField(10)
  final String? currencyCode; // Code de la devise pour le montant (obligatoire pour le calcul du solde correct)
  @HiveField(11)
  final bool isDebit;
  @HiveField(12)
  final bool isCredit;
  @HiveField(13)
  @Deprecated('Utiliser cashBalance, salesBalance ou stockValue selon le type')
  final double balanceAfter; // Conservé pour rétrocompatibilité
  @HiveField(14)
  final Map<String, double>? balancesByCurrency; // Soldes par devise (CDF, USD, etc.)
  @HiveField(15)
  final String? supplierId; // ID du fournisseur pour les achats
  @HiveField(16)
  final String? supplierName; // Nom du fournisseur pour les achats
  @HiveField(17)
  final String? customerId; // ID du client pour les ventes
  @HiveField(18)
  final String? customerName; // Nom du client pour les ventes
  @HiveField(19)
  final double? cashBalance; // Solde de TRÉSORERIE après l'opération (si applicable)
  @HiveField(20)
  final double? salesBalance; // Cumul des VENTES après l'opération (si applicable)
  @HiveField(21)
  final double? stockValue; // Valeur du STOCK après l'opération (si applicable)
  @HiveField(22)
  final Map<String, double>? cashBalancesByCurrency; // Soldes de trésorerie par devise
  @HiveField(23)
  final Map<String, double>? salesBalancesByCurrency; // Cumul ventes par devise
  @HiveField(24)
  final Map<String, double>? stockValuesByCurrency; // Valeur stock par devise

  // === Champs Business Unit (Multi-Tenant) ===
  @HiveField(25)
  final String? companyId; // ID de l'entreprise principale
  @HiveField(26)
  final String? businessUnitId; // ID de l'unité commerciale
  @HiveField(27)
  final String? businessUnitCode; // Code unique de l'unité (ex: POS-001)
  @HiveField(28)
  final BusinessUnitType? businessUnitType; // Type: company, branch, pos

  const OperationJournalEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.type,
    required this.amount,
    this.relatedDocumentId,
    this.quantity,
    this.productId,
    this.productName,
    this.paymentMethod,
    required this.currencyCode, // Maintenant requis pour le traitement correct des devises
    required this.isDebit,
    required this.isCredit,
    required this.balanceAfter,
    this.balancesByCurrency,
    this.supplierId,
    this.supplierName,
    this.customerId,
    this.customerName,
    this.cashBalance,
    this.salesBalance,
    this.stockValue,
    this.cashBalancesByCurrency,
    this.salesBalancesByCurrency,
    this.stockValuesByCurrency,
    this.companyId,
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitType,
  });
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'description': description,
      'type': type.toJson(), // Use the enum's toJson method
      'amount': amount,
      if (relatedDocumentId != null) 'relatedDocumentId': relatedDocumentId,
      if (quantity != null) 'quantity': quantity,
      if (productId != null) 'productId': productId,
      if (productName != null) 'productName': productName,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      'currencyCode': currencyCode, // Désormais obligatoire
      'isDebit': isDebit,
      'isCredit': isCredit,
      'balanceAfter': balanceAfter,
      if (balancesByCurrency != null) 'balancesByCurrency': balancesByCurrency,
      if (supplierId != null) 'supplierId': supplierId,
      if (supplierName != null) 'supplierName': supplierName,
      if (customerId != null) 'customerId': customerId,
      if (customerName != null) 'customerName': customerName,
      if (cashBalance != null) 'cashBalance': cashBalance,
      if (salesBalance != null) 'salesBalance': salesBalance,
      if (stockValue != null) 'stockValue': stockValue,
      if (cashBalancesByCurrency != null)
        'cashBalancesByCurrency': cashBalancesByCurrency,
      if (salesBalancesByCurrency != null)
        'salesBalancesByCurrency': salesBalancesByCurrency,
      if (stockValuesByCurrency != null)
        'stockValuesByCurrency': stockValuesByCurrency,
      if (companyId != null) 'companyId': companyId,
      if (businessUnitId != null) 'businessUnitId': businessUnitId,
      if (businessUnitCode != null) 'businessUnitCode': businessUnitCode,
      if (businessUnitType != null) 'businessUnitType': businessUnitType?.name,
    };
  }

  factory OperationJournalEntry.fromJson(Map<String, dynamic> json) {
    Map<String, double>? balancesByCurrency;
    if (json['balancesByCurrency'] != null) {
      balancesByCurrency = Map<String, double>.from(
        (json['balancesByCurrency'] as Map).map(
          (key, value) => MapEntry(key as String, (value as num).toDouble()),
        ),
      );
    }

    return OperationJournalEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String,
      type: OperationType.fromJson(
        json['type'] as String,
      ), // Use the enum's fromJson method
      amount: (json['amount'] as num).toDouble(),
      relatedDocumentId: json['relatedDocumentId'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble(),
      productId: json['productId'] as String?,
      productName: json['productName'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      currencyCode:
          json['currencyCode'] as String? ??
          'CDF', // Valeur par défaut 'CDF' si non spécifié
      isDebit: json['isDebit'] as bool? ?? false, // Provide default if null
      isCredit: json['isCredit'] as bool? ?? false, // Provide default if null
      balanceAfter:
          (json['balanceAfter'] as num?)?.toDouble() ??
          0.0, // Provide default if null
      balancesByCurrency: balancesByCurrency,
      supplierId: json['supplierId'] as String?,
      supplierName: json['supplierName'] as String?,
      customerId: json['customerId'] as String?,
      customerName: json['customerName'] as String?,
      cashBalance: (json['cashBalance'] as num?)?.toDouble(),
      salesBalance: (json['salesBalance'] as num?)?.toDouble(),
      stockValue: (json['stockValue'] as num?)?.toDouble(),
      cashBalancesByCurrency:
          json['cashBalancesByCurrency'] != null
              ? Map<String, double>.from(
                (json['cashBalancesByCurrency'] as Map).map(
                  (key, value) =>
                      MapEntry(key as String, (value as num).toDouble()),
                ),
              )
              : null,
      salesBalancesByCurrency:
          json['salesBalancesByCurrency'] != null
              ? Map<String, double>.from(
                (json['salesBalancesByCurrency'] as Map).map(
                  (key, value) =>
                      MapEntry(key as String, (value as num).toDouble()),
                ),
              )
              : null,
      stockValuesByCurrency:
          json['stockValuesByCurrency'] != null
              ? Map<String, double>.from(
                (json['stockValuesByCurrency'] as Map).map(
                  (key, value) =>
                      MapEntry(key as String, (value as num).toDouble()),
                ),
              )
              : null,
      companyId: json['companyId'] as String?,
      businessUnitId: json['businessUnitId'] as String?,
      businessUnitCode: json['businessUnitCode'] as String?,
      businessUnitType:
          json['businessUnitType'] != null
              ? BusinessUnitType.values.firstWhere(
                (e) => e.name == json['businessUnitType'],
                orElse: () => BusinessUnitType.company,
              )
              : null,
    );
  }
  OperationJournalEntry copyWith({
    String? id,
    DateTime? date,
    String? description,
    OperationType? type,
    double? amount,
    String? relatedDocumentId,
    double? quantity,
    String? productId,
    String? productName,
    String? paymentMethod,
    String? currencyCode,
    bool? isDebit,
    bool? isCredit,
    double? balanceAfter,
    Map<String, double>? balancesByCurrency,
    String? supplierId,
    String? supplierName,
    String? customerId,
    String? customerName,
    double? cashBalance,
    double? salesBalance,
    double? stockValue,
    Map<String, double>? cashBalancesByCurrency,
    Map<String, double>? salesBalancesByCurrency,
    Map<String, double>? stockValuesByCurrency,
    String? companyId,
    String? businessUnitId,
    String? businessUnitCode,
    BusinessUnitType? businessUnitType,
  }) {
    return OperationJournalEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      description: description ?? this.description,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      relatedDocumentId: relatedDocumentId ?? this.relatedDocumentId,
      quantity: quantity ?? this.quantity,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      currencyCode: currencyCode ?? this.currencyCode,
      isDebit: isDebit ?? this.isDebit,
      isCredit: isCredit ?? this.isCredit,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      balancesByCurrency: balancesByCurrency ?? this.balancesByCurrency,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      cashBalance: cashBalance ?? this.cashBalance,
      salesBalance: salesBalance ?? this.salesBalance,
      stockValue: stockValue ?? this.stockValue,
      cashBalancesByCurrency:
          cashBalancesByCurrency ?? this.cashBalancesByCurrency,
      salesBalancesByCurrency:
          salesBalancesByCurrency ?? this.salesBalancesByCurrency,
      stockValuesByCurrency:
          stockValuesByCurrency ?? this.stockValuesByCurrency,
      companyId: companyId ?? this.companyId,
      businessUnitId: businessUnitId ?? this.businessUnitId,
      businessUnitCode: businessUnitCode ?? this.businessUnitCode,
      businessUnitType: businessUnitType ?? this.businessUnitType,
    );
  }

  /// Retourne le solde approprié selon le type d'opération
  double? getRelevantBalance() {
    if (type.impactsCash) return cashBalance;
    if (type.isSalesOperation) return salesBalance;
    if (type.impactsStock) return stockValue;
    return balanceAfter; // Fallback pour rétrocompatibilité
  }

  /// Retourne le label du solde affiché
  String getBalanceLabel() {
    if (type.impactsCash) return 'Solde Caisse';
    if (type.isSalesOperation) return 'Total Ventes';
    if (type.impactsStock) return 'Valeur Stock';
    return 'Solde';
  }

  // Placeholder for AdhaBloc integration
  Map<String, dynamic> toContextMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'description': description,
      'type': type.toString().split('.').last, // Enum to string
      'amount': amount,
      if (relatedDocumentId != null) 'relatedDocumentId': relatedDocumentId,
      if (quantity != null) 'quantity': quantity,
      if (productId != null) 'productId': productId,
      if (productName != null) 'productName': productName,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      'currencyCode': currencyCode, // Obligatoire maintenant
      if (balancesByCurrency != null) 'balancesByCurrency': balancesByCurrency,
    };
  }
}
