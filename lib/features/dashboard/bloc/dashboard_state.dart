part of 'dashboard_bloc.dart';

@immutable
abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardData dashboardData;

  const DashboardLoaded(this.dashboardData);

  // Properties for backward compatibility
  double get salesTodayCdf => dashboardData.salesTodayCdf;
  double get salesTodayUsd => dashboardData.salesTodayUsd;
  int get clientsServedToday => dashboardData.clientsServedToday;
  double get receivables => dashboardData.receivables;
  double get expenses => dashboardData.expenses;
  double get expensesCdf => dashboardData.expensesCdf;
  double get expensesUsd => dashboardData.expensesUsd;

  @override
  List<Object> get props => [dashboardData];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object> get props => [message];
}
