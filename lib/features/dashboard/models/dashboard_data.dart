// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\dashboard\models\dashboard_data.dart
import 'package:equatable/equatable.dart';

/// Model class for the Dashboard data
class DashboardData extends Equatable {
  final double salesTodayCdf;
  final double salesTodayUsd;
  final int clientsServedToday;
  final double receivables;
  final double expenses;
  final double expensesCdf;
  final double expensesUsd;

  // Soldes de caisse (trésorerie)
  final double cashBalanceCdf;
  final double cashBalanceUsd;

  // Flux de trésorerie du jour par catégorie (en CDF)
  final double exploitationFlowsCdf;
  final double investmentFlowsCdf;
  final double financingFlowsCdf;

  // Encaissements / Décaissements du jour
  final double cashInTodayCdf;
  final double cashOutTodayCdf;
  final double cashInTodayUsd;
  final double cashOutTodayUsd;

  const DashboardData({
    required this.salesTodayCdf,
    required this.salesTodayUsd,
    required this.clientsServedToday,
    required this.receivables,
    required this.expenses,
    this.expensesCdf = 0.0,
    this.expensesUsd = 0.0,
    this.cashBalanceCdf = 0.0,
    this.cashBalanceUsd = 0.0,
    this.exploitationFlowsCdf = 0.0,
    this.investmentFlowsCdf = 0.0,
    this.financingFlowsCdf = 0.0,
    this.cashInTodayCdf = 0.0,
    this.cashOutTodayCdf = 0.0,
    this.cashInTodayUsd = 0.0,
    this.cashOutTodayUsd = 0.0,
  });

  @override
  List<Object> get props => [
    salesTodayCdf,
    salesTodayUsd,
    clientsServedToday,
    receivables,
    expenses,
    expensesCdf,
    expensesUsd,
    cashBalanceCdf,
    cashBalanceUsd,
    exploitationFlowsCdf,
    investmentFlowsCdf,
    financingFlowsCdf,
    cashInTodayCdf,
    cashOutTodayCdf,
    cashInTodayUsd,
    cashOutTodayUsd,
  ];

  /// Create an empty DashboardData object with default values
  factory DashboardData.empty() {
    return const DashboardData(
      salesTodayCdf: 0.0,
      salesTodayUsd: 0.0,
      clientsServedToday: 0,
      receivables: 0.0,
      expenses: 0.0,
      expensesCdf: 0.0,
      expensesUsd: 0.0,
      cashBalanceCdf: 0.0,
      cashBalanceUsd: 0.0,
      exploitationFlowsCdf: 0.0,
      investmentFlowsCdf: 0.0,
      financingFlowsCdf: 0.0,
      cashInTodayCdf: 0.0,
      cashOutTodayCdf: 0.0,
      cashInTodayUsd: 0.0,
      cashOutTodayUsd: 0.0,
    );
  }

  /// Create a copy of this DashboardData with the given fields replaced with new values
  DashboardData copyWith({
    double? salesTodayCdf,
    double? salesTodayUsd,
    int? clientsServedToday,
    double? receivables,
    double? expenses,
    double? expensesCdf,
    double? expensesUsd,
    double? cashBalanceCdf,
    double? cashBalanceUsd,
    double? exploitationFlowsCdf,
    double? investmentFlowsCdf,
    double? financingFlowsCdf,
    double? cashInTodayCdf,
    double? cashOutTodayCdf,
    double? cashInTodayUsd,
    double? cashOutTodayUsd,
  }) {
    return DashboardData(
      salesTodayCdf: salesTodayCdf ?? this.salesTodayCdf,
      salesTodayUsd: salesTodayUsd ?? this.salesTodayUsd,
      clientsServedToday: clientsServedToday ?? this.clientsServedToday,
      receivables: receivables ?? this.receivables,
      expenses: expenses ?? this.expenses,
      expensesCdf: expensesCdf ?? this.expensesCdf,
      expensesUsd: expensesUsd ?? this.expensesUsd,
      cashBalanceCdf: cashBalanceCdf ?? this.cashBalanceCdf,
      cashBalanceUsd: cashBalanceUsd ?? this.cashBalanceUsd,
      exploitationFlowsCdf: exploitationFlowsCdf ?? this.exploitationFlowsCdf,
      investmentFlowsCdf: investmentFlowsCdf ?? this.investmentFlowsCdf,
      financingFlowsCdf: financingFlowsCdf ?? this.financingFlowsCdf,
      cashInTodayCdf: cashInTodayCdf ?? this.cashInTodayCdf,
      cashOutTodayCdf: cashOutTodayCdf ?? this.cashOutTodayCdf,
      cashInTodayUsd: cashInTodayUsd ?? this.cashInTodayUsd,
      cashOutTodayUsd: cashOutTodayUsd ?? this.cashOutTodayUsd,
    );
  }
}
