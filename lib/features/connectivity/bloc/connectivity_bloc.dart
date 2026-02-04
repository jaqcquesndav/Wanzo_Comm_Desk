import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/utils/connectivity_service.dart';

// Événements
abstract class ConnectivityEvent extends Equatable {
  const ConnectivityEvent();

  @override
  List<Object?> get props => [];
}

class ConnectivityStatusChanged extends ConnectivityEvent {
  final bool isConnected;

  const ConnectivityStatusChanged(this.isConnected);

  @override
  List<Object> get props => [isConnected];
}

// États
abstract class ConnectivityState extends Equatable {
  const ConnectivityState();

  @override
  List<Object> get props => [];
}

class ConnectivityInitial extends ConnectivityState {
  const ConnectivityInitial();
}

class ConnectivityOnline extends ConnectivityState {
  const ConnectivityOnline();
}

class ConnectivityOffline extends ConnectivityState {
  const ConnectivityOffline();
}

/// BLoC pour gérer l'état de la connectivité
class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  final ConnectivityService _connectivityService;
  late StreamSubscription<bool> _connectivitySubscription;

  ConnectivityBloc(this._connectivityService) : super(const ConnectivityInitial()) {
    on<ConnectivityStatusChanged>(_onConnectivityStatusChanged);    // S'abonner aux changements de connectivité
    _connectivityService.connectionStatus.addListener(() {
      add(ConnectivityStatusChanged(_connectivityService.isConnected));
    });

    // Définir l'état initial en fonction de l'état actuel de la connectivité
    add(ConnectivityStatusChanged(_connectivityService.isConnected));
  }

  void _onConnectivityStatusChanged(
    ConnectivityStatusChanged event,
    Emitter<ConnectivityState> emit,
  ) {
    if (event.isConnected) {
      emit(const ConnectivityOnline());
    } else {
      emit(const ConnectivityOffline());
    }
  }

  @override
  Future<void> close() {
    _connectivitySubscription.cancel();
    return super.close();
  }
}
