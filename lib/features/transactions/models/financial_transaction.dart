import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';

part 'financial_transaction.g.dart';

/// Enum pour le type de transaction financière
/// Conformité: Aligné avec financial-transactions API documentation
@HiveType(typeId: 78)
enum TransactionType {
  /// Vente (sale)
  @HiveField(0)
  @JsonValue('sale')
  sale,

  /// Achat fournisseur (purchase)
  @HiveField(1)
  @JsonValue('purchase')
  purchase,

  /// Paiement client (customer_payment)
  @HiveField(2)
  @JsonValue('customer_payment')
  customerPayment,

  /// Paiement fournisseur (supplier_payment)
  @HiveField(3)
  @JsonValue('supplier_payment')
  supplierPayment,

  /// Remboursement (refund)
  @HiveField(4)
  @JsonValue('refund')
  refund,

  /// Dépense (expense)
  @HiveField(5)
  @JsonValue('expense')
  expense,

  /// Paie employés (payroll)
  @HiveField(6)
  @JsonValue('payroll')
  payroll,

  /// Paiement taxes (tax_payment)
  @HiveField(7)
  @JsonValue('tax_payment')
  taxPayment,

  /// Transfert (transfer)
  @HiveField(8)
  @JsonValue('transfer')
  transfer,

  /// Revenu/Entrée (income)
  @HiveField(9)
  @JsonValue('income')
  income,

  /// Solde d'ouverture
  @HiveField(10)
  @JsonValue('opening_balance')
  openingBalance,

  /// Autre
  @HiveField(11)
  @JsonValue('other')
  other,
}

/// Extension pour les fonctionnalités de TransactionType
extension TransactionTypeExtension on TransactionType {
  String get apiValue {
    switch (this) {
      case TransactionType.sale:
        return 'sale';
      case TransactionType.purchase:
        return 'purchase';
      case TransactionType.customerPayment:
        return 'customer_payment';
      case TransactionType.supplierPayment:
        return 'supplier_payment';
      case TransactionType.refund:
        return 'refund';
      case TransactionType.expense:
        return 'expense';
      case TransactionType.payroll:
        return 'payroll';
      case TransactionType.taxPayment:
        return 'tax_payment';
      case TransactionType.transfer:
        return 'transfer';
      case TransactionType.income:
        return 'income';
      case TransactionType.openingBalance:
        return 'opening_balance';
      case TransactionType.other:
        return 'other';
    }
  }

  static TransactionType fromApiValue(String value) {
    switch (value.toLowerCase()) {
      case 'sale':
        return TransactionType.sale;
      case 'purchase':
        return TransactionType.purchase;
      case 'customer_payment':
        return TransactionType.customerPayment;
      case 'supplier_payment':
        return TransactionType.supplierPayment;
      case 'refund':
        return TransactionType.refund;
      case 'expense':
        return TransactionType.expense;
      case 'payroll':
        return TransactionType.payroll;
      case 'tax_payment':
        return TransactionType.taxPayment;
      case 'transfer':
        return TransactionType.transfer;
      case 'income':
        return TransactionType.income;
      case 'opening_balance':
        return TransactionType.openingBalance;
      default:
        return TransactionType.other;
    }
  }

  String get displayName {
    switch (this) {
      case TransactionType.sale:
        return 'Vente';
      case TransactionType.purchase:
        return 'Achat';
      case TransactionType.customerPayment:
        return 'Paiement client';
      case TransactionType.supplierPayment:
        return 'Paiement fournisseur';
      case TransactionType.refund:
        return 'Remboursement';
      case TransactionType.expense:
        return 'Dépense';
      case TransactionType.payroll:
        return 'Paie employés';
      case TransactionType.taxPayment:
        return 'Paiement taxes';
      case TransactionType.transfer:
        return 'Transfert';
      case TransactionType.income:
        return 'Revenu';
      case TransactionType.openingBalance:
        return 'Solde d\'ouverture';
      case TransactionType.other:
        return 'Autre';
    }
  }

  bool get isIncome =>
      this == TransactionType.sale ||
      this == TransactionType.customerPayment ||
      this == TransactionType.income;

  bool get isExpense =>
      this == TransactionType.purchase ||
      this == TransactionType.supplierPayment ||
      this == TransactionType.expense ||
      this == TransactionType.payroll ||
      this == TransactionType.taxPayment;
}

/// Enum pour le statut de transaction financière
/// Conformité: Aligné avec financial-transactions API documentation
@HiveType(typeId: 79)
enum TransactionStatus {
  /// En attente (pending)
  @HiveField(0)
  @JsonValue('pending')
  pending,

  /// Complétée (completed)
  @HiveField(1)
  @JsonValue('completed')
  completed,

  /// Échouée (failed)
  @HiveField(2)
  @JsonValue('failed')
  failed,

  /// Annulée (voided)
  @HiveField(3)
  @JsonValue('voided')
  voided,

  /// Remboursée (refunded)
  @HiveField(4)
  @JsonValue('refunded')
  refunded,

  /// Partiellement remboursée (partially_refunded)
  @HiveField(5)
  @JsonValue('partially_refunded')
  partiallyRefunded,

  /// En attente d'approbation (pending_approval)
  @HiveField(6)
  @JsonValue('pending_approval')
  pendingApproval,

  /// Annulée (cancelled) - backward compatibility
  @HiveField(7)
  @JsonValue('cancelled')
  cancelled,

  /// En attente (onHold) - backward compatibility
  @HiveField(8)
  @JsonValue('on_hold')
  onHold,
}

/// Extension pour les fonctionnalités de TransactionStatus
extension TransactionStatusExtension on TransactionStatus {
  String get apiValue {
    switch (this) {
      case TransactionStatus.pending:
        return 'pending';
      case TransactionStatus.completed:
        return 'completed';
      case TransactionStatus.failed:
        return 'failed';
      case TransactionStatus.voided:
        return 'voided';
      case TransactionStatus.refunded:
        return 'refunded';
      case TransactionStatus.partiallyRefunded:
        return 'partially_refunded';
      case TransactionStatus.pendingApproval:
        return 'pending_approval';
      case TransactionStatus.cancelled:
        return 'cancelled';
      case TransactionStatus.onHold:
        return 'on_hold';
    }
  }

  static TransactionStatus fromApiValue(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return TransactionStatus.pending;
      case 'completed':
        return TransactionStatus.completed;
      case 'failed':
        return TransactionStatus.failed;
      case 'voided':
        return TransactionStatus.voided;
      case 'refunded':
        return TransactionStatus.refunded;
      case 'partially_refunded':
        return TransactionStatus.partiallyRefunded;
      case 'pending_approval':
        return TransactionStatus.pendingApproval;
      case 'cancelled':
        return TransactionStatus.cancelled;
      case 'on_hold':
        return TransactionStatus.onHold;
      default:
        return TransactionStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case TransactionStatus.pending:
        return 'En attente';
      case TransactionStatus.completed:
        return 'Complétée';
      case TransactionStatus.failed:
        return 'Échouée';
      case TransactionStatus.voided:
        return 'Annulée';
      case TransactionStatus.refunded:
        return 'Remboursée';
      case TransactionStatus.partiallyRefunded:
        return 'Partiellement remboursée';
      case TransactionStatus.pendingApproval:
        return 'En attente d\'approbation';
      case TransactionStatus.cancelled:
        return 'Annulée';
      case TransactionStatus.onHold:
        return 'En attente';
    }
  }

  bool get isFinal =>
      this == TransactionStatus.completed ||
      this == TransactionStatus.voided ||
      this == TransactionStatus.refunded ||
      this == TransactionStatus.cancelled;
}

/// Enum pour les méthodes de paiement
/// Conformité: Aligné avec financial-transactions API documentation
@HiveType(typeId: 80)
enum PaymentMethod {
  /// Espèces (cash)
  @HiveField(0)
  @JsonValue('cash')
  cash,

  /// Virement bancaire (bank_transfer)
  @HiveField(1)
  @JsonValue('bank_transfer')
  bankTransfer,

  /// Chèque (check)
  @HiveField(2)
  @JsonValue('check')
  check,

  /// Carte de crédit (credit_card)
  @HiveField(3)
  @JsonValue('credit_card')
  creditCard,

  /// Carte de débit (debit_card)
  @HiveField(4)
  @JsonValue('debit_card')
  debitCard,

  /// Mobile Money (mobile_money)
  @HiveField(5)
  @JsonValue('mobile_money')
  mobileMoney,

  /// PayPal (paypal)
  @HiveField(6)
  @JsonValue('paypal')
  paypal,

  /// Autre (other)
  @HiveField(7)
  @JsonValue('other')
  other,
}

/// Extension pour les fonctionnalités de PaymentMethod
extension PaymentMethodExtension on PaymentMethod {
  String get apiValue {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.bankTransfer:
        return 'bank_transfer';
      case PaymentMethod.check:
        return 'check';
      case PaymentMethod.creditCard:
        return 'credit_card';
      case PaymentMethod.debitCard:
        return 'debit_card';
      case PaymentMethod.mobileMoney:
        return 'mobile_money';
      case PaymentMethod.paypal:
        return 'paypal';
      case PaymentMethod.other:
        return 'other';
    }
  }

  static PaymentMethod fromApiValue(String? value) {
    if (value == null) return PaymentMethod.cash;
    switch (value.toLowerCase()) {
      case 'cash':
        return PaymentMethod.cash;
      case 'bank_transfer':
        return PaymentMethod.bankTransfer;
      case 'check':
        return PaymentMethod.check;
      case 'credit_card':
        return PaymentMethod.creditCard;
      case 'debit_card':
        return PaymentMethod.debitCard;
      case 'mobile_money':
        return PaymentMethod.mobileMoney;
      case 'paypal':
        return PaymentMethod.paypal;
      default:
        return PaymentMethod.other;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Espèces';
      case PaymentMethod.bankTransfer:
        return 'Virement bancaire';
      case PaymentMethod.check:
        return 'Chèque';
      case PaymentMethod.creditCard:
        return 'Carte de crédit';
      case PaymentMethod.debitCard:
        return 'Carte de débit';
      case PaymentMethod.mobileMoney:
        return 'Mobile Money';
      case PaymentMethod.paypal:
        return 'PayPal';
      case PaymentMethod.other:
        return 'Autre';
    }
  }
}

@JsonSerializable(explicitToJson: true)
@HiveType(typeId: 81)
class FinancialTransaction extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final TransactionType type;

  @HiveField(4)
  final String description;

  @HiveField(5)
  final String? category; // e.g., 'Office Supplies', 'Revenue from Sales'

  @HiveField(6)
  final String? relatedParty; // e.g., Customer ID, Supplier ID, Employee ID

  @HiveField(7)
  @JsonKey(fromJson: _paymentMethodFromJson, toJson: _paymentMethodToJson)
  final PaymentMethod? paymentMethod;

  @HiveField(8)
  final String? referenceNumber; // e.g., Invoice number, Receipt number

  @HiveField(9)
  final TransactionStatus status;

  @HiveField(10)
  final String? notes;

  @HiveField(11)
  final DateTime createdAt;

  @HiveField(12)
  final DateTime updatedAt;

  @HiveField(13)
  final String? linkedDocumentId;

  @HiveField(14)
  final String? linkedDocumentType; // e.g., 'Invoice', 'Expense'

  // ============= BUSINESS UNIT FIELDS =============

  @HiveField(15)
  final String? companyId;

  @HiveField(16)
  final String? businessUnitId;

  @HiveField(17)
  final String? businessUnitCode;

  @HiveField(18)
  @JsonKey(fromJson: _businessUnitTypeFromJson, toJson: _businessUnitTypeToJson)
  final BusinessUnitType? businessUnitType;

  /// Code devise (CDF, USD, EUR, etc.)
  @HiveField(19)
  final String? currencyCode;

  /// Taux de change si devise étrangère
  @HiveField(20)
  final double? exchangeRate;

  const FinancialTransaction({
    required this.id,
    required this.date,
    required this.amount,
    required this.type,
    required this.description,
    this.category,
    this.relatedParty,
    this.paymentMethod,
    this.referenceNumber,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.linkedDocumentId,
    this.linkedDocumentType,
    // Business Unit fields
    this.companyId,
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitType,
    this.currencyCode,
    this.exchangeRate,
  });

  factory FinancialTransaction.fromJson(Map<String, dynamic> json) =>
      _$FinancialTransactionFromJson(json);

  Map<String, dynamic> toJson() => _$FinancialTransactionToJson(this);

  // Helpers pour la sérialisation
  static PaymentMethod? _paymentMethodFromJson(String? value) =>
      value != null ? PaymentMethodExtension.fromApiValue(value) : null;

  static String? _paymentMethodToJson(PaymentMethod? method) =>
      method?.apiValue;

  static BusinessUnitType? _businessUnitTypeFromJson(String? value) =>
      value != null ? BusinessUnitTypeExtension.fromApiValue(value) : null;

  static String? _businessUnitTypeToJson(BusinessUnitType? type) =>
      type?.apiValue;

  FinancialTransaction copyWith({
    String? id,
    DateTime? date,
    double? amount,
    TransactionType? type,
    String? description,
    String? category,
    String? relatedParty,
    PaymentMethod? paymentMethod,
    String? referenceNumber,
    TransactionStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? linkedDocumentId,
    String? linkedDocumentType,
    String? companyId,
    String? businessUnitId,
    String? businessUnitCode,
    BusinessUnitType? businessUnitType,
    String? currencyCode,
    double? exchangeRate,
  }) {
    return FinancialTransaction(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: description ?? this.description,
      category: category ?? this.category,
      relatedParty: relatedParty ?? this.relatedParty,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      linkedDocumentId: linkedDocumentId ?? this.linkedDocumentId,
      linkedDocumentType: linkedDocumentType ?? this.linkedDocumentType,
      companyId: companyId ?? this.companyId,
      businessUnitId: businessUnitId ?? this.businessUnitId,
      businessUnitCode: businessUnitCode ?? this.businessUnitCode,
      businessUnitType: businessUnitType ?? this.businessUnitType,
      currencyCode: currencyCode ?? this.currencyCode,
      exchangeRate: exchangeRate ?? this.exchangeRate,
    );
  }

  @override
  List<Object?> get props => [
    id,
    date,
    amount,
    type,
    description,
    category,
    relatedParty,
    paymentMethod,
    referenceNumber,
    status,
    notes,
    createdAt,
    updatedAt,
    linkedDocumentId,
    linkedDocumentType,
    companyId,
    businessUnitId,
    businessUnitCode,
    businessUnitType,
    currencyCode,
    exchangeRate,
  ];
}
