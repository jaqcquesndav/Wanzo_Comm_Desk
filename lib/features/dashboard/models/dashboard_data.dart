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

  const DashboardData({
    required this.salesTodayCdf,
    required this.salesTodayUsd,
    required this.clientsServedToday,
    required this.receivables,
    required this.expenses,
    this.expensesCdf = 0.0,
    this.expensesUsd = 0.0,
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
  }) {
    return DashboardData(
      salesTodayCdf: salesTodayCdf ?? this.salesTodayCdf,
      salesTodayUsd: salesTodayUsd ?? this.salesTodayUsd,
      clientsServedToday: clientsServedToday ?? this.clientsServedToday,
      receivables: receivables ?? this.receivables,
      expenses: expenses ?? this.expenses,
      expensesCdf: expensesCdf ?? this.expensesCdf,
      expensesUsd: expensesUsd ?? this.expensesUsd,
    );
  }
}
