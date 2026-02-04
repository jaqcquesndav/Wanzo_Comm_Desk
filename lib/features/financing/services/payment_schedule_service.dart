import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import '../models/payment_schedule.dart';

/// Service pour générer et gérer les échéanciers de paiement
class PaymentScheduleService {
  static const _uuid = Uuid();

  /// Générer un échéancier de paiement pour un financement approuvé
  static List<PaymentSchedule> generatePaymentSchedule({
    required String contractId,
    required double totalAmount,
    required double interestRate,
    required int termMonths,
    required DateTime startDate,
  }) {
    final List<PaymentSchedule> schedules = [];
    
    // Calculer le paiement mensuel (capital + intérêts)
    final monthlyPayment = _calculateMonthlyPayment(
      totalAmount, 
      interestRate, 
      termMonths
    );
    
    double remainingPrincipal = totalAmount;
    
    for (int i = 0; i < termMonths; i++) {
      final dueDate = DateTime(
        startDate.year,
        startDate.month + i + 1,
        startDate.day,
      );
      
      // Calculer les intérêts pour ce mois
      final interestAmount = remainingPrincipal * (interestRate / 100 / 12);
      final principalAmount = monthlyPayment - interestAmount;
      
      // Ajuster le dernier paiement pour éviter les erreurs d'arrondi
      final adjustedPrincipalAmount = i == termMonths - 1 
          ? remainingPrincipal 
          : principalAmount;
      
      final adjustedTotalAmount = adjustedPrincipalAmount + interestAmount;
      
      final schedule = PaymentSchedule(
        id: _uuid.v4(),
        contractId: contractId,
        dueDate: dueDate,
        principalAmount: adjustedPrincipalAmount,
        interestAmount: interestAmount,
        totalAmount: adjustedTotalAmount,
        scheduleNumber: i + 1,
        remainingAmount: adjustedTotalAmount,
      );
      
      schedules.add(schedule);
      remainingPrincipal -= adjustedPrincipalAmount;
    }
    
    return schedules;
  }

  /// Calculer le paiement mensuel en utilisant la formule des annuités
  static double _calculateMonthlyPayment(
    double principal, 
    double annualInterestRate, 
    int termMonths
  ) {
    if (annualInterestRate == 0) {
      return principal / termMonths;
    }
    
    final monthlyRate = annualInterestRate / 100 / 12;
    final numerator = monthlyRate * principal;
    final denominator = 1 - (1 / math.pow(1 + monthlyRate, termMonths));
    
    return numerator / denominator;
  }

  /// Calculer les échéances en retard
  static List<PaymentSchedule> getLatePayments(List<PaymentSchedule> schedules) {
    final now = DateTime.now();
    return schedules.where((schedule) => 
      schedule.status != PaymentScheduleStatus.paid && 
      schedule.dueDate.isBefore(now)
    ).toList();
  }

  /// Calculer les échéances en défaut (plus de 30 jours de retard)
  static List<PaymentSchedule> getDefaultedPayments(List<PaymentSchedule> schedules) {
    final now = DateTime.now();
    return schedules.where((schedule) => 
      schedule.status != PaymentScheduleStatus.paid && 
      schedule.dueDate.add(const Duration(days: 30)).isBefore(now)
    ).toList();
  }

  /// Mettre à jour le statut des échéances en fonction des dates
  static List<PaymentSchedule> updateScheduleStatuses(List<PaymentSchedule> schedules) {
    final now = DateTime.now();
    final updatedSchedules = <PaymentSchedule>[];
    
    for (final schedule in schedules) {
      if (schedule.status == PaymentScheduleStatus.paid) {
        updatedSchedules.add(schedule);
        continue;
      }
      
      PaymentScheduleStatus newStatus = schedule.status;
      DateTime? lateStartDate = schedule.latePaymentStartDate;
      
      if (schedule.dueDate.isBefore(now)) {
        // Vérifier si c'est en défaut (plus de 30 jours)
        if (schedule.dueDate.add(const Duration(days: 30)).isBefore(now)) {
          newStatus = PaymentScheduleStatus.defaulted;
        } else {
          newStatus = PaymentScheduleStatus.late;
        }
        
        // Marquer la date de début de retard si pas déjà fait
        lateStartDate ??= schedule.dueDate;
      }
      
      updatedSchedules.add(schedule.copyWith(
        status: newStatus,
        latePaymentStartDate: lateStartDate,
      ));
    }
    
    return updatedSchedules;
  }

  /// Enregistrer un paiement sur une échéance
  static PaymentSchedule recordPayment({
    required PaymentSchedule schedule,
    required double amount,
    required DateTime paymentDate,
    required String paymentMethod,
    String? transactionReference,
    String? notes,
  }) {
    final paidAmount = schedule.paidAmount + amount;
    final remainingAmount = schedule.totalAmount - paidAmount;
    
    PaymentScheduleStatus newStatus;
    if (remainingAmount <= 0) {
      newStatus = PaymentScheduleStatus.paid;
    } else if (paidAmount > 0) {
      newStatus = PaymentScheduleStatus.partial;
    } else {
      newStatus = schedule.status;
    }
    
    return schedule.copyWith(
      status: newStatus,
      paymentDate: newStatus == PaymentScheduleStatus.paid ? paymentDate : schedule.paymentDate,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount > 0 ? remainingAmount : 0,
      paymentMethod: paymentMethod,
      transactionReference: transactionReference,
      notes: notes,
    );
  }

  /// Calculer le total des paiements restants
  static double calculateTotalRemaining(List<PaymentSchedule> schedules) {
    return schedules
        .where((s) => s.status != PaymentScheduleStatus.paid)
        .fold(0.0, (sum, s) => sum + s.remainingAmount);
  }

  /// Calculer le total des paiements effectués
  static double calculateTotalPaid(List<PaymentSchedule> schedules) {
    return schedules.fold(0.0, (sum, s) => sum + s.paidAmount);
  }

  /// Vérifier si le contrat est entièrement remboursé
  static bool isFullyRepaid(List<PaymentSchedule> schedules) {
    return schedules.every((s) => s.status == PaymentScheduleStatus.paid);
  }

  /// Obtenir la prochaine échéance à payer
  static PaymentSchedule? getNextDuePayment(List<PaymentSchedule> schedules) {
    final unpaidSchedules = schedules
        .where((s) => s.status != PaymentScheduleStatus.paid)
        .toList();
    
    if (unpaidSchedules.isEmpty) return null;
    
    // Trier par date d'échéance et retourner la première
    unpaidSchedules.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return unpaidSchedules.first;
  }

  /// Calculer les frais de retard
  static double calculateLateFee({
    required PaymentSchedule schedule,
    required double lateFeeRate, // Taux de pénalité par jour
  }) {
    if (!schedule.isLate || schedule.status == PaymentScheduleStatus.paid) {
      return 0.0;
    }
    
    final daysLate = schedule.daysLate;
    return schedule.remainingAmount * (lateFeeRate / 100) * daysLate;
  }
}

/// Extension pour simplifier les calculs
extension DoubleExtension on double {
  double pow(double exponent) {
    return math.pow(this, exponent).toDouble();
  }
}
