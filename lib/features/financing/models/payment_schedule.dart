import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'payment_schedule.g.dart';

/// États de paiement d'une échéance
@HiveType(typeId: 30)
enum PaymentScheduleStatus {
  @HiveField(0)
  pending, // En attente

  @HiveField(1)
  paid, // Payé

  @HiveField(2)
  late, // En retard

  @HiveField(3)
  defaulted, // En défaut

  @HiveField(4)
  partial, // Paiement partiel
}

extension PaymentScheduleStatusExtension on PaymentScheduleStatus {
  String get displayName {
    switch (this) {
      case PaymentScheduleStatus.pending:
        return 'En attente';
      case PaymentScheduleStatus.paid:
        return 'Payé';
      case PaymentScheduleStatus.late:
        return 'En retard';
      case PaymentScheduleStatus.defaulted:
        return 'En défaut';
      case PaymentScheduleStatus.partial:
        return 'Paiement partiel';
    }
  }
}

/// Modèle détaillé pour une échéance de paiement
@HiveType(typeId: 71) // Changed from 31 to 71 to avoid conflict with Document
class PaymentSchedule extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String contractId;

  @HiveField(2)
  final DateTime dueDate;

  @HiveField(3)
  final double principalAmount;

  @HiveField(4)
  final double interestAmount;

  @HiveField(5)
  final double totalAmount;

  @HiveField(6)
  final PaymentScheduleStatus status;

  @HiveField(7)
  final DateTime? paymentDate;

  @HiveField(8)
  final double paidAmount;

  @HiveField(9)
  final double remainingAmount;

  @HiveField(10)
  final String? paymentMethod;

  @HiveField(11)
  final String? transactionReference;

  @HiveField(12)
  final int scheduleNumber;

  @HiveField(13)
  final String? notes;

  @HiveField(14)
  final DateTime? latePaymentStartDate;

  @HiveField(15)
  final double? lateFee;

  const PaymentSchedule({
    required this.id,
    required this.contractId,
    required this.dueDate,
    required this.principalAmount,
    required this.interestAmount,
    required this.totalAmount,
    this.status = PaymentScheduleStatus.pending,
    this.paymentDate,
    this.paidAmount = 0.0,
    this.remainingAmount = 0.0,
    this.paymentMethod,
    this.transactionReference,
    required this.scheduleNumber,
    this.notes,
    this.latePaymentStartDate,
    this.lateFee,
  });

  @override
  List<Object?> get props => [
    id,
    contractId,
    dueDate,
    principalAmount,
    interestAmount,
    totalAmount,
    status,
    paymentDate,
    paidAmount,
    remainingAmount,
    paymentMethod,
    transactionReference,
    scheduleNumber,
    notes,
    latePaymentStartDate,
    lateFee,
  ];

  PaymentSchedule copyWith({
    String? id,
    String? contractId,
    DateTime? dueDate,
    double? principalAmount,
    double? interestAmount,
    double? totalAmount,
    PaymentScheduleStatus? status,
    DateTime? paymentDate,
    double? paidAmount,
    double? remainingAmount,
    String? paymentMethod,
    String? transactionReference,
    int? scheduleNumber,
    String? notes,
    DateTime? latePaymentStartDate,
    double? lateFee,
  }) {
    return PaymentSchedule(
      id: id ?? this.id,
      contractId: contractId ?? this.contractId,
      dueDate: dueDate ?? this.dueDate,
      principalAmount: principalAmount ?? this.principalAmount,
      interestAmount: interestAmount ?? this.interestAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paymentDate: paymentDate ?? this.paymentDate,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionReference: transactionReference ?? this.transactionReference,
      scheduleNumber: scheduleNumber ?? this.scheduleNumber,
      notes: notes ?? this.notes,
      latePaymentStartDate: latePaymentStartDate ?? this.latePaymentStartDate,
      lateFee: lateFee ?? this.lateFee,
    );
  }

  /// Vérifier si l'échéance est en retard
  bool get isLate {
    if (status == PaymentScheduleStatus.paid) return false;
    return DateTime.now().isAfter(dueDate);
  }

  /// Vérifier si l'échéance est en défaut (plus de 30 jours de retard)
  bool get isInDefault {
    if (status == PaymentScheduleStatus.paid) return false;
    final thirtyDaysAfterDue = dueDate.add(const Duration(days: 30));
    return DateTime.now().isAfter(thirtyDaysAfterDue);
  }

  /// Calculer les jours de retard
  int get daysLate {
    if (!isLate) return 0;
    return DateTime.now().difference(dueDate).inDays;
  }

  /// Conversion depuis/vers JSON
  factory PaymentSchedule.fromJson(Map<String, dynamic> json) {
    return PaymentSchedule(
      id: json['id'] as String,
      contractId: json['contract_id'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      principalAmount: (json['principal_amount'] as num).toDouble(),
      interestAmount: (json['interest_amount'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: _parseStatus(json['status'] as String?),
      paymentDate:
          json['payment_date'] != null
              ? DateTime.parse(json['payment_date'] as String)
              : null,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String?,
      transactionReference: json['transaction_reference'] as String?,
      scheduleNumber: json['schedule_number'] as int,
      notes: json['notes'] as String?,
      latePaymentStartDate:
          json['late_payment_start_date'] != null
              ? DateTime.parse(json['late_payment_start_date'] as String)
              : null,
      lateFee: (json['late_fee'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'contract_id': contractId,
      'due_date': dueDate.toIso8601String(),
      'principal_amount': principalAmount,
      'interest_amount': interestAmount,
      'total_amount': totalAmount,
      'status': status.name,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'schedule_number': scheduleNumber,
    };

    if (paymentDate != null) {
      data['payment_date'] = paymentDate!.toIso8601String();
    }
    if (paymentMethod != null) {
      data['payment_method'] = paymentMethod;
    }
    if (transactionReference != null) {
      data['transaction_reference'] = transactionReference;
    }
    if (notes != null) {
      data['notes'] = notes;
    }
    if (latePaymentStartDate != null) {
      data['late_payment_start_date'] = latePaymentStartDate!.toIso8601String();
    }
    if (lateFee != null) {
      data['late_fee'] = lateFee;
    }

    return data;
  }

  static PaymentScheduleStatus _parseStatus(String? status) {
    if (status == null) return PaymentScheduleStatus.pending;

    switch (status.toLowerCase()) {
      case 'paid':
        return PaymentScheduleStatus.paid;
      case 'late':
        return PaymentScheduleStatus.late;
      case 'defaulted':
        return PaymentScheduleStatus.defaulted;
      case 'partial':
        return PaymentScheduleStatus.partial;
      default:
        return PaymentScheduleStatus.pending;
    }
  }
}
