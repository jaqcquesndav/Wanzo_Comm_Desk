import 'package:equatable/equatable.dart';
import 'package:wanzo/features/operations/models/operation.dart';

/// Filtre pour les opérations
class OperationFilter extends Equatable {
  final OperationType? type;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? relatedPartyId;
  final String? status;
  final double? minAmount;
  final double? maxAmount;
  final String sortBy; // 'date', 'amount', 'type'
  final bool sortAscending;

  const OperationFilter({
    this.type,
    this.startDate,
    this.endDate,
    this.relatedPartyId,
    this.status,
    this.minAmount,
    this.maxAmount,
    this.sortBy = 'date',
    this.sortAscending = false,
  });

  /// Vérifie si une opération correspond aux critères du filtre
  bool matches(Operation operation) {
    // Filtre par type
    if (type != null && operation.type != type) {
      return false;
    }

    // Filtre par date
    if (startDate != null && operation.date.isBefore(startDate!)) {
      return false;
    }
    if (endDate != null &&
        operation.date.isAfter(endDate!.add(const Duration(days: 1)))) {
      return false;
    }

    // Filtre par partie liée
    if (relatedPartyId != null && operation.relatedPartyId != relatedPartyId) {
      return false;
    }

    // Filtre par statut
    if (status != null && operation.status != status) {
      return false;
    }

    // Filtre par montant
    if (minAmount != null && operation.amountCdf < minAmount!) {
      return false;
    }
    if (maxAmount != null && operation.amountCdf > maxAmount!) {
      return false;
    }

    return true;
  }

  OperationFilter copyWith({
    OperationType? type,
    DateTime? startDate,
    DateTime? endDate,
    String? relatedPartyId,
    String? status,
    double? minAmount,
    double? maxAmount,
    String? sortBy,
    bool? sortAscending,
  }) {
    return OperationFilter(
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      relatedPartyId: relatedPartyId ?? this.relatedPartyId,
      status: status ?? this.status,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  /// Crée un filtre vide (sans restrictions)
  factory OperationFilter.empty() {
    return const OperationFilter();
  }

  /// Crée un filtre pour aujourd'hui
  factory OperationFilter.today() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return OperationFilter(startDate: startOfDay, endDate: endOfDay);
  }

  /// Crée un filtre pour cette semaine
  factory OperationFilter.thisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );

    return OperationFilter(startDate: startOfDay, endDate: now);
  }

  /// Crée un filtre pour ce mois
  factory OperationFilter.thisMonth() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return OperationFilter(startDate: startOfMonth, endDate: now);
  }

  @override
  List<Object?> get props => [
    type,
    startDate,
    endDate,
    relatedPartyId,
    status,
    minAmount,
    maxAmount,
    sortBy,
    sortAscending,
  ];
}
