import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/sales/repositories/sales_repository.dart';

// Events
abstract class SalesEvent extends Equatable {
  const SalesEvent();

  @override
  List<Object?> get props => [];
}

class LoadSales extends SalesEvent {
  const LoadSales();
}

class LoadSalesByStatus extends SalesEvent {
  final SaleStatus status;
  
  const LoadSalesByStatus(this.status);
  
  @override
  List<Object?> get props => [status];
}

class LoadSalesByDateRange extends SalesEvent {
  final DateTime startDate;
  final DateTime endDate;
  
  const LoadSalesByDateRange({
    required this.startDate,
    required this.endDate,
  });
  
  @override
  List<Object?> get props => [startDate, endDate];
}

// States
abstract class SalesState extends Equatable {
  const SalesState();
  
  @override
  List<Object?> get props => [];
}

class SalesInitial extends SalesState {}

class SalesLoading extends SalesState {}

class SalesLoaded extends SalesState {
  final List<Sale> sales;
  
  const SalesLoaded(this.sales);
  
  /// Calcule le montant total des ventes
  double get totalAmount {
    return sales.fold<double>(0, (total, sale) => total + sale.totalAmountInCdf); // Changed to totalAmountInCdf
  }
  
  @override
  List<Object?> get props => [sales];
}

class SalesError extends SalesState {
  final String message;
  
  const SalesError(this.message);
  
  @override
  List<Object?> get props => [message];
}

// Bloc
class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final SalesRepository salesRepository;
  
  SalesBloc({
    required this.salesRepository,
  }) : super(SalesInitial()) {
    on<LoadSales>(_onLoadSales);
    on<LoadSalesByStatus>(_onLoadSalesByStatus);
    on<LoadSalesByDateRange>(_onLoadSalesByDateRange);
  }
  
  Future<void> _onLoadSales(
    LoadSales event,
    Emitter<SalesState> emit,
  ) async {
    emit(SalesLoading());
    try {
      final sales = await salesRepository.getAllSales();
      emit(SalesLoaded(sales));
    } catch (e) {
      emit(SalesError('Impossible de charger les ventes: $e'));
    }
  }
  
  Future<void> _onLoadSalesByStatus(
    LoadSalesByStatus event,
    Emitter<SalesState> emit,
  ) async {
    emit(SalesLoading());
    try {
      final sales = await salesRepository.getSalesByStatus(event.status);
      emit(SalesLoaded(sales));
    } catch (e) {
      emit(SalesError('Impossible de charger les ventes: $e'));
    }
  }
  
  Future<void> _onLoadSalesByDateRange(
    LoadSalesByDateRange event,
    Emitter<SalesState> emit,
  ) async {
    emit(SalesLoading());
    try {
      final sales = await salesRepository.getAllSales();
      final filteredSales = sales.where((sale) {
        return sale.date.isAfter(event.startDate) && 
               sale.date.isBefore(event.endDate.add(const Duration(days: 1)));
      }).toList();
      emit(SalesLoaded(filteredSales));
    } catch (e) {
      emit(SalesError('Impossible de charger les ventes: $e'));
    }
  }
}