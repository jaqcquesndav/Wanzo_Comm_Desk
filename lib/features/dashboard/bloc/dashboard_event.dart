part of 'dashboard_bloc.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object> get props => [];
}

class LoadDashboardData extends DashboardEvent {
  final DateTime date; // Date for which to load data, typically 'today'

  const LoadDashboardData({required this.date});

  @override
  List<Object> get props => [date];
}

class RefreshDashboardData extends DashboardEvent {
  final DateTime date; // Date for which to refresh data

  const RefreshDashboardData(this.date);

  @override
  List<Object> get props => [date];
}
