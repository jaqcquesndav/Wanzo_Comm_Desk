import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart'; // Required for @immutable
import 'dart:async'; // Pour le Timer
import '../../sales/repositories/sales_repository.dart';
import '../../customer/repositories/customer_repository.dart';
import '../../transactions/repositories/transaction_repository.dart';
import '../../expenses/repositories/expense_repository.dart';
import '../services/dashboard_api_service.dart';
import '../models/dashboard_data.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DashboardApiService _dashboardApiService;
  
  // Timer pour la mise à jour périodique des données
  Timer? _refreshTimer;
  static const _refreshIntervalInSeconds = 300; // 5 minutes

  DashboardBloc({
    required SalesRepository salesRepository,
    required CustomerRepository customerRepository,
    required TransactionRepository transactionRepository,
    ExpenseRepository? expenseRepository,
  }) : _dashboardApiService = DashboardApiService(
         salesRepository: salesRepository,
         customerRepository: customerRepository,
         transactionRepository: transactionRepository,
         expenseRepository: expenseRepository,
       ),
       super(DashboardInitial()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<RefreshDashboardData>(_onRefreshDashboardData);
    
    // Démarrer la mise à jour périodique
    _startPeriodicRefresh();
  }

  @override
  Future<void> close() {
    // Annuler le timer lors de la fermeture du bloc
    _refreshTimer?.cancel();
    return super.close();
  }

  void _startPeriodicRefresh() {
    // Annuler un éventuel timer existant
    _refreshTimer?.cancel();
    
    // Créer un nouveau timer pour les mises à jour périodiques
    _refreshTimer = Timer.periodic(
      const Duration(seconds: _refreshIntervalInSeconds), 
      (_) => add(RefreshDashboardData(DateTime.now()))
    );
  }
  Future<void> _onLoadDashboardData(LoadDashboardData event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      // Utiliser le service API pour récupérer les données
      final response = await _dashboardApiService.getDashboardData(event.date);
      
      if (response.success && response.data != null) {
        emit(DashboardLoaded(response.data!));
      } else {
        emit(DashboardError(response.message ?? "Erreur lors du chargement des données"));
      }
    } catch (e) {
      emit(DashboardError("Erreur de chargement des données du tableau de bord: ${e.toString()}"));
    }
  }

  Future<void> _onRefreshDashboardData(RefreshDashboardData event, Emitter<DashboardState> emit) async {
    // Ne pas afficher l'état de chargement pour ne pas perturber l'UI pendant les rafraîchissements
    try {
      final response = await _dashboardApiService.getDashboardData(event.date);
      
      if (response.success && response.data != null) {
        emit(DashboardLoaded(response.data!));
      }
      // En cas d'erreur de rafraîchissement, on ne change pas l'état pour ne pas perturber l'UI
    } catch (e) {
      print("Erreur lors du rafraîchissement des données: ${e.toString()}");
      // Ne pas émettre d'état d'erreur pour éviter de perturber l'interface utilisateur
    }
  }
}
