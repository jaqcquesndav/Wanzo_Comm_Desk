import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../dashboard/bloc/operation_journal_bloc.dart'; // Correct import for BLoC and its events
import '../../dashboard/models/operation_journal_entry.dart';
import '../models/financing_request.dart';
import '../repositories/financing_repository.dart';

part 'financing_event.dart';
part 'financing_state.dart';

class FinancingBloc extends Bloc<FinancingEvent, FinancingState> {
  final FinancingRepository _financingRepository;
  final OperationJournalBloc _operationJournalBloc;

  // Expose the repository for direct access when needed
  FinancingRepository get financingRepository => _financingRepository;

  FinancingBloc({
    required FinancingRepository financingRepository,
    required OperationJournalBloc operationJournalBloc,
  })  : _financingRepository = financingRepository,
        _operationJournalBloc = operationJournalBloc,
        super(FinancingInitial()) {
    on<AddFinancingRequest>(_onAddFinancingRequest);
    on<LoadFinancingRequests>(_onLoadFinancingRequests);
    on<UpdateFinancingRequest>(_onUpdateFinancingRequest);
    on<ApproveFinancingRequest>(_onApproveFinancingRequest);
    on<DisburseFunds>(_onDisburseFunds);
    on<RecordPayment>(_onRecordPayment);
    on<DeleteFinancingRequest>(_onDeleteFinancingRequest);
  }

  Future<void> _onAddFinancingRequest(
    AddFinancingRequest event,
    Emitter<FinancingState> emit,
  ) async {
    emit(FinancingLoading());
    try {
      final requestWithId = event.request.id.isEmpty 
          ? event.request.copyWith(id: const Uuid().v4()) 
          : event.request;

      await _financingRepository.addRequest(requestWithId);
        final journalEntry = OperationJournalEntry(
        id: const Uuid().v4(),
        date: requestWithId.requestDate,
        description: 'Demande de financement: ${requestWithId.type.displayName} - ${requestWithId.institution.displayName}',
        type: OperationType.financingRequest,
        amount: requestWithId.amount, 
        relatedDocumentId: requestWithId.id,
        paymentMethod: requestWithId.currency, 
        currencyCode: requestWithId.currency, // Utiliser la devise spécifiée dans la demande
        isDebit: false, // Financing request itself is not a debit/credit yet until approved/rejected or funds move
        isCredit: false,
        balanceAfter: 0, // Placeholder, journal service should calculate this
      );
      _operationJournalBloc.add(AddOperationJournalEntry(journalEntry));

      emit(const FinancingOperationSuccess('Demande de financement soumise avec succès.'));
    } catch (e) {
      emit(FinancingError('Erreur lors de la soumission: ${e.toString()}'));
    }
  }
  Future<void> _onLoadFinancingRequests(
    LoadFinancingRequests event,
    Emitter<FinancingState> emit,
  ) async {
    emit(FinancingLoading());
    try {
      // Utiliser la méthode spécialisée du repository
      final filteredRequests = await _financingRepository.getFilteredRequests(
        status: event.status,
        type: event.type,
        financialProduct: event.financialProduct,
      );
      
      emit(FinancingLoadSuccess(filteredRequests));
    } catch (e) {
      emit(FinancingError('Erreur lors du chargement des demandes: ${e.toString()}'));
    }
  }
  
  Future<void> _onUpdateFinancingRequest(
    UpdateFinancingRequest event,
    Emitter<FinancingState> emit,
  ) async {
    emit(FinancingLoading());
    try {
      await _financingRepository.updateRequest(event.request);
      emit(const FinancingOperationSuccess('Demande de financement mise à jour avec succès.'));
    } catch (e) {
      emit(FinancingError('Erreur lors de la mise à jour: ${e.toString()}'));
    }
  }
    Future<void> _onApproveFinancingRequest(
    ApproveFinancingRequest event,
    Emitter<FinancingState> emit,
  ) async {
    emit(FinancingLoading());
    try {
      // Utiliser la méthode spécialisée du repository
      final updatedRequest = await _financingRepository.approveFinancingRequest(
        requestId: event.requestId,
        approvalDate: event.approvalDate,
        interestRate: event.interestRate,
        termMonths: event.termMonths,
        monthlyPayment: event.monthlyPayment,
      );
        // Créer une entrée dans le journal des opérations
      final journalEntry = OperationJournalEntry(
        id: const Uuid().v4(),
        date: event.approvalDate,
        description: 'Financement approuvé: ${updatedRequest.type.displayName} - ${updatedRequest.institution.displayName}',
        type: OperationType.financingApproved,
        amount: updatedRequest.amount,
        relatedDocumentId: updatedRequest.id,
        paymentMethod: updatedRequest.currency,
        currencyCode: updatedRequest.currency, // Utiliser la devise spécifiée dans la demande
        isDebit: false,
        isCredit: false,
        balanceAfter: 0, // Placeholder
      );
      _operationJournalBloc.add(AddOperationJournalEntry(journalEntry));
      
      emit(const FinancingOperationSuccess('Demande de financement approuvée avec succès.'));
    } catch (e) {
      emit(FinancingError('Erreur lors de l\'approbation: ${e.toString()}'));
    }
  }
    Future<void> _onDisburseFunds(
    DisburseFunds event,
    Emitter<FinancingState> emit,
  ) async {
    emit(FinancingLoading());
    try {
      // Utiliser la méthode spécialisée du repository
      final updatedRequest = await _financingRepository.disburseFunds(
        requestId: event.requestId,
        disbursementDate: event.disbursementDate,
        scheduledPayments: event.scheduledPayments,
      );
        // Créer une entrée dans le journal des opérations pour le décaissement
      final journalEntry = OperationJournalEntry(
        id: const Uuid().v4(),
        date: event.disbursementDate,
        description: 'Décaissement: ${updatedRequest.type.displayName} - ${updatedRequest.institution.displayName}',
        type: OperationType.cashIn, // Entrée d'espèces ou de stock selon le type
        amount: updatedRequest.amount,
        relatedDocumentId: updatedRequest.id,
        paymentMethod: updatedRequest.currency,
        currencyCode: updatedRequest.currency, // Utiliser la devise spécifiée dans la demande
        isDebit: false,
        isCredit: true,
        balanceAfter: 0, // Placeholder
      );
      _operationJournalBloc.add(AddOperationJournalEntry(journalEntry));
      
      emit(const FinancingOperationSuccess('Fonds débloqués avec succès.'));
    } catch (e) {
      emit(FinancingError('Erreur lors du déblocage des fonds: ${e.toString()}'));
    }
  }
    Future<void> _onRecordPayment(
    RecordPayment event,
    Emitter<FinancingState> emit,
  ) async {
    emit(FinancingLoading());
    try {
      // Utiliser la méthode spécialisée du repository
      final updatedRequest = await _financingRepository.recordPayment(
        requestId: event.requestId,
        paymentDate: event.paymentDate,
        amount: event.amount,
      );
        // Créer une entrée dans le journal des opérations pour le paiement
      final journalEntry = OperationJournalEntry(
        id: const Uuid().v4(),
        date: event.paymentDate,
        description: 'Remboursement financement: ${updatedRequest.type.displayName} - ${updatedRequest.institution.displayName}',
        type: OperationType.cashOut, // Un remboursement est une sortie d'argent
        amount: event.amount,
        relatedDocumentId: updatedRequest.id,
        paymentMethod: updatedRequest.currency,
        currencyCode: updatedRequest.currency, // Utiliser la devise spécifiée dans la demande
        isDebit: true,
        isCredit: false,
        balanceAfter: 0, // Placeholder
      );
      _operationJournalBloc.add(AddOperationJournalEntry(journalEntry));
      
      emit(const FinancingOperationSuccess('Paiement enregistré avec succès.'));
    } catch (e) {
      emit(FinancingError('Erreur lors de l\'enregistrement du paiement: ${e.toString()}'));
    }
  }
  
  Future<void> _onDeleteFinancingRequest(
    DeleteFinancingRequest event,
    Emitter<FinancingState> emit,
  ) async {
    emit(FinancingLoading());
    try {
      await _financingRepository.deleteRequest(event.requestId);
      emit(const FinancingOperationSuccess('Demande de financement supprimée avec succès.'));
    } catch (e) {
      emit(FinancingError('Erreur lors de la suppression: ${e.toString()}'));
    }
  }
}
