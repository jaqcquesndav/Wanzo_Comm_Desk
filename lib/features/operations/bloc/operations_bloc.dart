import 'dart:io'; // Added for SocketException
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/features/sales/repositories/sales_repository.dart';
import 'package:wanzo/features/expenses/repositories/expense_repository.dart';
import 'package:wanzo/features/financing/models/financing_request.dart';
import 'package:wanzo/features/financing/repositories/financing_repository.dart';

part 'operations_event.dart';
part 'operations_state.dart';

class OperationsBloc extends Bloc<OperationsEvent, OperationsState> {
  final SalesRepository salesRepository;
  final ExpenseRepository expenseRepository;
  final FinancingRepository financingRepository;

  OperationsBloc({
    required this.salesRepository,
    required this.expenseRepository,
    required this.financingRepository,
  }) : super(OperationsInitial()) {
    on<LoadOperations>(_onLoadOperations);
  }
  Future<void> _onLoadOperations(
    LoadOperations event,
    Emitter<OperationsState> emit,
  ) async {
    emit(OperationsLoading());
    try {
      List<Sale> sales = await salesRepository.getAllSales();
      List<Expense> expenses = await expenseRepository.getAllExpenses();
      List<FinancingRequest> financingRequests = await financingRepository.getAllRequests();

      // Apply date filtering to both sales and expenses
      if (event.startDate != null) {
        sales = sales.where((sale) => 
          !sale.date.isBefore(event.startDate!)
        ).toList();
        expenses = expenses.where((expense) => 
          !expense.date.isBefore(event.startDate!)
        ).toList();
        financingRequests = financingRequests.where((request) =>
          !request.requestDate.isBefore(event.startDate!)
        ).toList();
      }      if (event.endDate != null) {
        // Adjust endDate to include the whole day
        DateTime endOfDay = DateTime(event.endDate!.year, event.endDate!.month, event.endDate!.day, 23, 59, 59);
        sales = sales.where((sale) => 
          !sale.date.isAfter(endOfDay)
        ).toList();
        expenses = expenses.where((expense) => 
          !expense.date.isAfter(endOfDay)
        ).toList();
        financingRequests = financingRequests.where((request) =>
          !request.requestDate.isAfter(endOfDay)
        ).toList();
      }      // Apply payment status filtering to sales only
      if (event.paymentStatus != null && event.paymentStatus!.isNotEmpty) {
        try {
          SaleStatus statusFilter = SaleStatus.values.firstWhere(
            (e) => e.toString().split('.').last == event.paymentStatus,
          );
          sales = sales.where((sale) => sale.status == statusFilter).toList();
        } catch (e) {
          // Handle case where paymentStatus string doesn't match any SaleStatus enum member
          print("Invalid payment status string: ${event.paymentStatus}");
        }
      }
      
      // Appliquer le filtrage par type de financement
      if (event.financingType != null) {
        financingRequests = financingRequests.where((request) => 
          request.type == event.financingType
        ).toList();
      }

      emit(OperationsLoaded(
        sales: sales, 
        expenses: expenses,
        financingRequests: financingRequests,
      ));
    } catch (e, s) { // Added stack trace for better debugging
      String errorMessage;
      final eString = e.toString().toLowerCase();
      
      // Check for specific network-related exceptions
      if (e is SocketException || 
          eString.contains('socketexception') ||
          eString.contains('failed host lookup') ||
          eString.contains('network is unreachable') || // More specific network error
          eString.contains('errno = 7') || // No address associated with hostname
          eString.contains('handshakeexception') // SSL/TLS handshake issues often network related
          // Avoid overly broad terms like 'network error' if they might hide other issues
          ) {
        errorMessage = 'Problème de connexion réseau. Veuillez vérifier votre connexion et réessayer.';
        print('OperationsBloc: Erreur réseau détectée: $e');
      } else {
        // For other errors, assume it might be data-related or other local issue
        errorMessage = 'Impossible de charger les opérations. Veuillez réessayer.';
        // Log the actual error for debugging purposes, as it's not a standard network one
        print('OperationsBloc: Erreur non réseau lors de LoadOperations: $e');
        print('Stack trace: $s');
      }
      emit(OperationsError(errorMessage));
    }
  }
}
