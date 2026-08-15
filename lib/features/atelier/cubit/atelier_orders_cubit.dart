import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/atelier_order.dart';
import '../services/atelier_api_service.dart';

class AtelierOrdersState extends Equatable {
  final List<AtelierOrder> orders;
  final bool loading;
  final String? error;

  const AtelierOrdersState({
    this.orders = const [],
    this.loading = false,
    this.error,
  });

  AtelierOrdersState copyWith({
    List<AtelierOrder>? orders,
    bool? loading,
    String? error,
  }) {
    return AtelierOrdersState(
      orders: orders ?? this.orders,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [orders, loading, error];
}

/// Pilote les commandes de confection (persistées côté backend).
///
/// Le changement de statut est optimiste (mise à jour immédiate de la carte sur
/// le board), puis réconcilié avec la réponse serveur ; en cas d'échec, on
/// recharge pour retrouver l'état de vérité.
class AtelierOrdersCubit extends Cubit<AtelierOrdersState> {
  final AtelierApiService _api;
  String? _businessUnitId;

  AtelierOrdersCubit(this._api) : super(const AtelierOrdersState());

  Future<void> load({String? businessUnitId}) async {
    _businessUnitId = businessUnitId ?? _businessUnitId;
    emit(state.copyWith(loading: true, error: null));
    try {
      final orders = await _api.getOrders(businessUnitId: _businessUnitId);
      emit(AtelierOrdersState(orders: orders, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<AtelierOrder?> createOrder(AtelierOrder draft) async {
    try {
      final created = await _api.createOrder(draft);
      emit(state.copyWith(orders: [created, ...state.orders], error: null));
      return created;
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      return null;
    }
  }

  Future<void> updateStatus(String id, AtelierOrderStatus status) async {
    // Optimiste : refléter tout de suite le déplacement de carte.
    final previous = state.orders;
    emit(state.copyWith(
      orders: previous
          .map((o) => o.id == id ? o.copyWith(status: status) : o)
          .toList(),
    ));
    try {
      final updated = await _api.updateStatus(id, status);
      emit(state.copyWith(
        orders: state.orders.map((o) => o.id == id ? updated : o).toList(),
      ));
    } catch (e) {
      // Rollback via rechargement de la source de vérité.
      emit(state.copyWith(error: e.toString(), orders: previous));
      await load();
    }
  }

  Future<AtelierOrder?> updateOrder(String id, Map<String, dynamic> payload) async {
    try {
      final updated = await _api.updateOrder(id, payload);
      emit(state.copyWith(
        orders: state.orders.map((o) => o.id == id ? updated : o).toList(),
      ));
      return updated;
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      return null;
    }
  }

  Future<void> deleteOrder(String id) async {
    final previous = state.orders;
    emit(state.copyWith(orders: previous.where((o) => o.id != id).toList()));
    try {
      await _api.deleteOrder(id);
    } catch (e) {
      emit(state.copyWith(error: e.toString(), orders: previous));
    }
  }
}
