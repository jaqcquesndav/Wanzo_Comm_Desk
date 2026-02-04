// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\notifications\bloc\sync_status_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/notification_repository.dart';
import '../../../core/utils/connectivity_service.dart';

// Événements
abstract class SyncStatusEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SyncStatusRequested extends SyncStatusEvent {}
class SyncStatusUpdated extends SyncStatusEvent {
  final int pendingCount;
  
  SyncStatusUpdated(this.pendingCount);
  
  @override
  List<Object?> get props => [pendingCount];
}

class SyncStarted extends SyncStatusEvent {}
class SyncCompleted extends SyncStatusEvent {}
class SyncFailed extends SyncStatusEvent {
  final String error;
  
  SyncFailed(this.error);
  
  @override
  List<Object?> get props => [error];
}

// États
abstract class SyncStatusState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SyncStatusInitial extends SyncStatusState {}
class SyncStatusLoading extends SyncStatusState {}

class SyncStatusReady extends SyncStatusState {
  final int pendingCount;
  final bool isConnected;
  
  SyncStatusReady({
    required this.pendingCount,
    required this.isConnected,
  });
  
  @override
  List<Object?> get props => [pendingCount, isConnected];
}

class SyncStatusInProgress extends SyncStatusState {
  final int pendingCount;
  
  SyncStatusInProgress({required this.pendingCount});
  
  @override
  List<Object?> get props => [pendingCount];
}

class SyncStatusError extends SyncStatusState {
  final String error;
  
  SyncStatusError({required this.error});
  
  @override
  List<Object?> get props => [error];
}

// Bloc
class SyncStatusBloc extends Bloc<SyncStatusEvent, SyncStatusState> {
  final NotificationRepository _notificationRepository;
  final ConnectivityService _connectivityService;
  
  SyncStatusBloc({
    required NotificationRepository notificationRepository,
    required ConnectivityService connectivityService,
  }) : 
    _notificationRepository = notificationRepository,
    _connectivityService = connectivityService,
    super(SyncStatusInitial()) {
    on<SyncStatusRequested>(_onSyncStatusRequested);
    on<SyncStatusUpdated>(_onSyncStatusUpdated);
    on<SyncStarted>(_onSyncStarted);
    on<SyncCompleted>(_onSyncCompleted);
    on<SyncFailed>(_onSyncFailed);
    
    // S'abonner aux changements de connectivité
    _connectivityService.connectionStatus.addListener(_onConnectivityChanged);
  }
  
  Future<void> _onSyncStatusRequested(
    SyncStatusRequested event, 
    Emitter<SyncStatusState> emit,
  ) async {
    emit(SyncStatusLoading());
    
    try {
      final pendingSyncCount = await _notificationRepository.getPendingSyncCount();
      final isConnected = _connectivityService.isConnected;
      
      emit(SyncStatusReady(
        pendingCount: pendingSyncCount,
        isConnected: isConnected,
      ));
    } catch (e) {
      emit(SyncStatusError(error: e.toString()));
    }
  }
  
  void _onSyncStatusUpdated(
    SyncStatusUpdated event, 
    Emitter<SyncStatusState> emit,
  ) {
    if (state is SyncStatusInProgress) {
      emit(SyncStatusInProgress(pendingCount: event.pendingCount));
    } else {
      emit(SyncStatusReady(
        pendingCount: event.pendingCount,
        isConnected: _connectivityService.isConnected,
      ));
    }
  }
  
  void _onSyncStarted(
    SyncStarted event, 
    Emitter<SyncStatusState> emit,
  ) {
    final currentState = state;
    if (currentState is SyncStatusReady) {
      emit(SyncStatusInProgress(pendingCount: currentState.pendingCount));
    }
  }
  
  void _onSyncCompleted(
    SyncCompleted event, 
    Emitter<SyncStatusState> emit,
  ) {
    emit(SyncStatusReady(
      pendingCount: 0,
      isConnected: _connectivityService.isConnected,
    ));
  }
  
  void _onSyncFailed(
    SyncFailed event, 
    Emitter<SyncStatusState> emit,
  ) {
    emit(SyncStatusError(error: event.error));
  }
  
  void _onConnectivityChanged() {
    if (_connectivityService.isConnected) {
      final currentState = state;
      if (currentState is SyncStatusReady && currentState.pendingCount > 0) {
        add(SyncStarted());
        _notificationRepository.syncNotifications().then((_) {
          add(SyncCompleted());
        }).catchError((error) {
          add(SyncFailed(error.toString()));
        });
      }
    }
    
    // Mettre à jour l'état avec la connectivité actuelle
    add(SyncStatusRequested());
  }
  
  @override
  Future<void> close() {
    _connectivityService.connectionStatus.removeListener(_onConnectivityChanged);
    return super.close();
  }
}
