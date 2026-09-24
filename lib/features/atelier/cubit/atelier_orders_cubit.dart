import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/atelier_order.dart';
import '../services/atelier_api_service.dart';
import '../repositories/atelier_order_cache.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';

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
/// Ce que rend un enregistrement de fiche.
///
/// Distinguer « enregistre » de « conserve hors ligne » evite le pire des deux
/// mondes : un faux succes qui laisse croire que le serveur a la fiche, ou un
/// echec qui pousse a ressaisir ce qui est deja en file.
class AtelierOrderSaveResult {
  const AtelierOrderSaveResult({this.order, this.horsLigne = false});

  /// La fiche telle qu'elle est desormais connue, localement ou du serveur.
  final AtelierOrder? order;

  /// Vrai quand l'ecriture attend le retour du reseau.
  final bool horsLigne;

  bool get ok => order != null;
}

class AtelierOrdersCubit extends Cubit<AtelierOrdersState> {
  final AtelierApiService _api;
  final AtelierOrderCache _cache;
  String? _businessUnitId;
  // Métier du board (couture / cordonnerie / maintenance / imprimerie), dérivé
  // du mode d'activité courant. Isole les commandes : un board de maintenance ne
  // doit jamais afficher une commande de couture ou d'imprimerie.
  AtelierMetier? _metier;

  AtelierOrdersCubit(this._api, {AtelierOrderCache? cache})
      : _cache = cache ?? AtelierOrderCache(),
        super(const AtelierOrdersState());

  Future<void> load({String? businessUnitId, AtelierMetier? metier}) async {
    _businessUnitId = businessUnitId ?? _businessUnitId;
    _metier = metier ?? _metier;
    final metierKey = _metier?.apiValue;
    emit(state.copyWith(loading: true, error: null));
    try {
      final orders = await _api.getOrders(
        businessUnitId: _businessUnitId,
        metier: metierKey,
      );
      // Garde-fou client : même si le backend renvoyait des commandes d'autres
      // métiers (ancienne version, cache serveur), on n'affiche que le métier
      // courant sur ce board.
      final scoped = _scope(orders);
      emit(AtelierOrdersState(orders: scoped, loading: false));
      // Mémoriser pour l'affichage hors-ligne (cache scindé par métier).
      await _cache.save(_businessUnitId, scoped, metier: metierKey);
    } catch (e) {
      // Réseau indisponible : servir la dernière liste connue (offline).
      final cached = _scope(await _cache.load(_businessUnitId, metier: metierKey));
      if (cached.isNotEmpty) {
        emit(AtelierOrdersState(
          orders: cached,
          loading: false,
          error: 'Hors ligne — dernières commandes connues',
        ));
      } else {
        emit(state.copyWith(loading: false, error: e.toString()));
      }
    }
  }

  /// Ne conserve que les commandes du métier courant (isolation du board).
  List<AtelierOrder> _scope(List<AtelierOrder> orders) {
    final m = _metier;
    if (m == null) return orders;
    return orders.where((o) => o.metier == m).toList();
  }

  /// Enregistre une nouvelle fiche. Meme traitement du hors ligne que
  /// [updateOrder] : la saisie n'est jamais perdue.
  Future<AtelierOrderSaveResult> createOrder(AtelierOrder draft) async {
    try {
      final created = await _api.createOrder(draft);
      emit(state.copyWith(orders: [created, ...state.orders], error: null));
      return AtelierOrderSaveResult(order: created);
    } on OfflineQueuedException {
      final orders = [draft, ...state.orders];
      emit(state.copyWith(orders: orders, error: null));
      await _cache.save(_businessUnitId, orders, metier: _metier?.apiValue);
      return AtelierOrderSaveResult(order: draft, horsLigne: true);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      return const AtelierOrderSaveResult();
    }
  }

  Future<void> updateStatus(String id, AtelierOrderStatus status,
      {String? saleId}) async {
    // Optimiste : refléter tout de suite le déplacement de carte.
    final previous = state.orders;
    emit(state.copyWith(
      orders: previous
          .map((o) => o.id == id ? o.copyWith(status: status) : o)
          .toList(),
    ));
    try {
      final updated = await _api.updateStatus(id, status, saleId: saleId);
      emit(state.copyWith(
        orders: state.orders.map((o) => o.id == id ? updated : o).toList(),
      ));
    } catch (e) {
      // Rollback via rechargement de la source de vérité.
      emit(state.copyWith(error: e.toString(), orders: previous));
      await load();
    }
  }

  /// Corrige une fiche.
  ///
  /// Hors ligne, l'ecriture est conservee par la file du client HTTP et sera
  /// rejouee : on applique la correction a l'etat local et on le signale par
  /// [horsLigne], au lieu d'afficher un echec qui pousserait a ressaisir.
  Future<AtelierOrderSaveResult> updateOrder(
    String id,
    Map<String, dynamic> payload, {
    AtelierOrder? local,
  }) async {
    try {
      final updated = await _api.updateOrder(id, payload);
      emit(state.copyWith(
        orders: state.orders.map((o) => o.id == id ? updated : o).toList(),
        error: null,
      ));
      return AtelierOrderSaveResult(order: updated);
    } on OfflineQueuedException {
      // La correction est en file : la carte doit la refleter tout de suite,
      // sinon l'utilisateur croit que rien n'a ete pris en compte.
      if (local != null) {
        final orders =
            state.orders.map((o) => o.id == id ? local : o).toList();
        emit(state.copyWith(orders: orders, error: null));
        await _cache.save(_businessUnitId, orders, metier: _metier?.apiValue);
      }
      return AtelierOrderSaveResult(order: local, horsLigne: true);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      return const AtelierOrderSaveResult();
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
