import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../models/restaurant_order.dart';
import '../repositories/restaurant_order_repository.dart';

class RestaurantOrdersState extends Equatable {
  final List<RestaurantOrder> orders;
  final bool loading;

  const RestaurantOrdersState({this.orders = const [], this.loading = false});

  /// Commandes actives (ouvertes / en cuisine / servies), plus récentes d'abord.
  List<RestaurantOrder> get active =>
      orders.where((o) => o.status.isActive).toList();

  RestaurantOrder? byId(String id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  RestaurantOrdersState copyWith({
    List<RestaurantOrder>? orders,
    bool? loading,
  }) {
    return RestaurantOrdersState(
      orders: orders ?? this.orders,
      loading: loading ?? this.loading,
    );
  }

  @override
  List<Object?> get props => [orders, loading];
}

/// Gère le cycle de vie des commandes restaurant et leur persistance locale.
///
/// N'a AUCUNE dépendance à la chaîne de vente : l'encaissement (création d'une
/// `Sale`) est piloté par l'écran caisse, qui appelle ensuite [markPaid].
class RestaurantOrdersCubit extends Cubit<RestaurantOrdersState> {
  final RestaurantOrderRepository _repository;
  final Uuid _uuid;

  RestaurantOrdersCubit(this._repository, {Uuid uuid = const Uuid()})
    : _uuid = uuid,
      super(const RestaurantOrdersState());

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    final orders = await _repository.loadAll();
    emit(RestaurantOrdersState(orders: orders, loading: false));
  }

  /// Ouvre une nouvelle commande (table / emporter) et la retourne.
  Future<RestaurantOrder> openOrder(String label) async {
    final order = RestaurantOrder(
      id: _uuid.v4(),
      label: label.trim().isEmpty ? 'Sans nom' : label.trim(),
      lines: const [],
      status: RestaurantOrderStatus.open,
      createdAt: DateTime.now(),
    );
    await _upsert(order);
    return order;
  }

  /// Ajoute un article ou incrémente sa quantité s'il est déjà présent
  /// (même produit + même note).
  Future<void> addLine(String orderId, RestaurantOrderLine line) async {
    final order = state.byId(orderId);
    if (order == null) return;
    final lines = List<RestaurantOrderLine>.from(order.lines);
    final idx = lines.indexWhere(
      (l) => l.productId == line.productId && l.note == line.note,
    );
    if (idx >= 0) {
      lines[idx] = lines[idx].copyWith(
        quantity: lines[idx].quantity + line.quantity,
      );
    } else {
      lines.add(line);
    }
    await _upsert(order.copyWith(lines: lines));
  }

  Future<void> setQuantity(
    String orderId,
    int lineIndex,
    int quantity,
  ) async {
    final order = state.byId(orderId);
    if (order == null || lineIndex < 0 || lineIndex >= order.lines.length) {
      return;
    }
    final lines = List<RestaurantOrderLine>.from(order.lines);
    if (quantity <= 0) {
      lines.removeAt(lineIndex);
    } else {
      lines[lineIndex] = lines[lineIndex].copyWith(quantity: quantity);
    }
    await _upsert(order.copyWith(lines: lines));
  }

  Future<void> updateStatus(
    String orderId,
    RestaurantOrderStatus status,
  ) async {
    final order = state.byId(orderId);
    if (order == null) return;
    await _upsert(order.copyWith(status: status));
  }

  /// Marque la commande réglée. À appeler APRÈS création réussie de la `Sale`.
  Future<void> markPaid(String orderId) =>
      updateStatus(orderId, RestaurantOrderStatus.paid);

  Future<void> cancel(String orderId) =>
      updateStatus(orderId, RestaurantOrderStatus.cancelled);

  Future<void> deleteOrder(String orderId) async {
    await _repository.delete(orderId);
    emit(
      state.copyWith(
        orders: state.orders.where((o) => o.id != orderId).toList(),
      ),
    );
  }

  Future<void> _upsert(RestaurantOrder order) async {
    await _repository.save(order);
    final orders = List<RestaurantOrder>.from(state.orders);
    final idx = orders.indexWhere((o) => o.id == order.id);
    if (idx >= 0) {
      orders[idx] = order;
    } else {
      orders.insert(0, order);
    }
    emit(state.copyWith(orders: orders));
  }
}
