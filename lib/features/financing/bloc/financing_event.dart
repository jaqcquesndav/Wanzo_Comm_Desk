part of 'financing_bloc.dart';

abstract class FinancingEvent extends Equatable {
  const FinancingEvent();

  @override
  List<Object> get props => [];
}

class AddFinancingRequest extends FinancingEvent {
  final FinancingRequest request;

  const AddFinancingRequest(this.request);

  @override
  List<Object> get props => [request];
}

class LoadFinancingRequests extends FinancingEvent {
  final String? status;
  final FinancingType? type;
  final FinancialProduct? financialProduct;
  
  const LoadFinancingRequests({
    this.status, 
    this.type, 
    this.financialProduct
  });
  
  @override
  List<Object> get props {
    final List<Object> result = [];
    if (status != null) result.add(status!);
    if (type != null) result.add(type!);
    if (financialProduct != null) result.add(financialProduct!);
    return result;
  }
}

class UpdateFinancingRequest extends FinancingEvent {
  final FinancingRequest request;
  
  const UpdateFinancingRequest(this.request);
  
  @override
  List<Object> get props => [request];
}

class ApproveFinancingRequest extends FinancingEvent {
  final String requestId;
  final DateTime approvalDate;
  final double? interestRate;
  final int? termMonths;
  final double? monthlyPayment;
  
  const ApproveFinancingRequest({
    required this.requestId,
    required this.approvalDate,
    this.interestRate,
    this.termMonths,
    this.monthlyPayment,
  });
  
  @override
  List<Object> get props {
    final List<Object> result = [requestId, approvalDate];
    if (interestRate != null) result.add(interestRate!);
    if (termMonths != null) result.add(termMonths!);
    if (monthlyPayment != null) result.add(monthlyPayment!);
    return result;
  }
}

class DisburseFunds extends FinancingEvent {
  final String requestId;
  final DateTime disbursementDate;
  final List<DateTime>? scheduledPayments;
  
  const DisburseFunds({
    required this.requestId,
    required this.disbursementDate,
    this.scheduledPayments,
  });
  
  @override
  List<Object> get props {
    final List<Object> result = [requestId, disbursementDate];
    if (scheduledPayments != null) result.add(List<DateTime>.from(scheduledPayments!));
    return result;
  }
}

class RecordPayment extends FinancingEvent {
  final String requestId;
  final DateTime paymentDate;
  final double amount;
  
  const RecordPayment({
    required this.requestId,
    required this.paymentDate,
    required this.amount,
  });
  
  @override
  List<Object> get props => [requestId, paymentDate, amount];
}

class DeleteFinancingRequest extends FinancingEvent {
  final String requestId;
  
  const DeleteFinancingRequest(this.requestId);
  
  @override
  List<Object> get props => [requestId];
}
