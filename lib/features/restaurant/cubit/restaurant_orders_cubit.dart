import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../models/restaurant_order.dart';
import '../repositories/restaurant_order_repository.dart';
import '../services/restaurant_order_sync.dart';

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
  final RestaurantOrderSync _sync;
  final Uuid _uuid;

  RestaurantOrdersCubit(
    this._repository, {
    Uuid uuid = const Uuid(),
    RestaurantOrderSync? sync,
  })  : _uuid = uuid,
        _sync = sync ?? RestaurantOrderSync(),
        super(const RestaurantOrdersState());

  /// Vrai pendant un chargement : le rafraichissement periodique des ecrans
  /// de service ne doit pas empiler les chargements.
  bool _chargement = false;

  /// Commandes que le serveur connait (lues ou confirmees) : une commande
  /// videe de ses plats apres avoir ete partagee doit repartir, pour que les
  /// autres postes la voient videe elle aussi.
  final Set<String> _connuesDuServeur = {};

  /// Au-dela de ce delai, une commande ouverte sans aucun plat est un reste
  /// (une table touchee sans rien commander) et non un service en cours.
  static const _delaiCommandeVide = Duration(minutes: 30);

  Future<void> load() async {
    if (_chargement) return;
    _chargement = true;
    try {
      if (state.orders.isEmpty) emit(state.copyWith(loading: true));
      // Le local d'abord : l'ecran s'affiche immediatement, meme hors ligne.
      var local = await _repository.loadAll();
      local = await _retirerCommandesVidesAbandonnees(local);
      emit(RestaurantOrdersState(orders: local, loading: false));

      final attente = await _repository.enAttente();
      // Ce qui n'a pas encore ete confirme repart d'abord.
      for (final o in local.where((o) => attente.contains(o.id))) {
        unawaited(_pousser(o));
      }

      // Puis ce que les AUTRES postes ont ouvert, regle ou annule. Le serveur
      // fait foi entre appareils, SAUF pour une commande modifiee ici et pas
      // encore confirmee : sa copie serveur est plus ancienne, l'appliquer
      // effacait des plats deja saisis (« 0 article »).
      final remote = await _sync.pull();
      final byId = {for (final o in local) o.id: o};
      final actifsServeur = <String>{};
      for (final o in remote) {
        actifsServeur.add(o.id);
        _connuesDuServeur.add(o.id);
        if (attente.contains(o.id)) continue;
        byId[o.id] = o;
        await _repository.save(o);
      }

      // Une commande encore active ici que le serveur ne compte plus parmi
      // les actives : reglee, annulee ou retiree sur un autre poste. Sans ce
      // rapprochement, la table restait occupee sur ce poste jusqu'au
      // redemarrage. On lit son statut REEL au serveur plutot que de deviner :
      // renvoyer la copie locale rouvrirait une commande deja reglee.
      final suspectes = byId.values
          .where((o) =>
              o.status.isActive &&
              o.lines.isNotEmpty &&
              !actifsServeur.contains(o.id) &&
              !attente.contains(o.id))
          .toList();
      if (suspectes.isNotEmpty) {
        final toutes = {
          for (final o in await _sync.pull(activeOnly: false)) o.id: o,
        };
        final limite = DateTime.now().subtract(const Duration(hours: 24));
        for (final o in suspectes) {
          final serveur = toutes[o.id];
          if (serveur != null) {
            // Le serveur sait ce qu'elle est devenue : on l'applique.
            byId[o.id] = serveur;
            await _repository.save(serveur);
            _connuesDuServeur.add(o.id);
          } else if (o.createdAt.isBefore(limite)) {
            // Introuvable et ancienne : un reste, pas un service en cours.
            byId.remove(o.id);
            await _repository.delete(o.id);
          } else {
            // Introuvable et recente : jamais arrivee au serveur (ouverte
            // hors ligne sur une version precedente). On la partage.
            unawaited(_pousser(o));
          }
        }
      }

      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      emit(RestaurantOrdersState(orders: merged, loading: false));
    } catch (_) {
      // Hors ligne : on garde la vue locale, le service continue.
    } finally {
      _chargement = false;
    }
  }

  /// Retire les commandes ouvertes sans aucun plat depuis plus de
  /// [_delaiCommandeVide] : restes d'une table touchee sans rien commander,
  /// qui occupaient la table et encombraient le kanban a « 0 article ».
  Future<List<RestaurantOrder>> _retirerCommandesVidesAbandonnees(
    List<RestaurantOrder> orders,
  ) async {
    final limite = DateTime.now().subtract(_delaiCommandeVide);
    final gardees = <RestaurantOrder>[];
    for (final o in orders) {
      final abandonnee = o.status == RestaurantOrderStatus.open &&
          o.lines.isEmpty &&
          o.createdAt.isBefore(limite);
      if (!abandonnee) {
        gardees.add(o);
        continue;
      }
      await _repository.delete(o.id);
      unawaited(_sync.remove(o.id).catchError((_) {}));
    }
    return gardees;
  }

  /// Envoie la commande, dans l'ordre, et la tient en attente tant que le
  /// serveur ne l'a pas confirmee.
  Future<void> _pousser(RestaurantOrder order) async {
    // Une commande sans aucun plat reste sur ce poste tant qu'elle n'a jamais
    // ete partagee : l'envoyer affichait une table occupee a 0 article sur
    // tous les postes des qu'on touchait une table sans rien commander.
    if (order.lines.isEmpty &&
        order.status == RestaurantOrderStatus.open &&
        !_connuesDuServeur.contains(order.id)) {
      return;
    }
    await _repository.marquerEnAttente(order.id);
    final ok = await _sync.push(order);
    if (ok && _sync.estAJour(order.id)) {
      _connuesDuServeur.add(order.id);
      await _repository.retirerEnAttente(order.id);
    }
  }

  /// Ouvre une nouvelle commande (table / emporter) et la retourne.
  /// Ouvre une nouvelle commande (table / emporter) et la retourne.
  ///
  /// [tableId] lie fortement la commande à une table du plan de salle (source de
  /// vérité du rapprochement, plus fiable que le libellé). [type] force la nature
  /// du service ; sans précision on la dérive du tableId puis du libellé.
  Future<RestaurantOrder> openOrder(
    String label, {
    String? tableId,
    RestaurantOrderType? type,
    String? customerId,
    String? customerName,
  }) async {
    final cleanTableId =
        (tableId != null && tableId.trim().isNotEmpty) ? tableId.trim() : null;
    final resolvedType = type ??
        RestaurantOrderTypeX.resolve(tableId: cleanTableId, label: label);
    final order = RestaurantOrder(
      id: _uuid.v4(),
      label: label.trim().isEmpty ? 'Sans nom' : label.trim(),
      lines: const [],
      status: RestaurantOrderStatus.open,
      createdAt: DateTime.now(),
      tableId: cleanTableId,
      type: resolvedType,
      customerId: (customerId != null && customerId.trim().isNotEmpty)
          ? customerId.trim()
          : null,
      customerName: (customerName != null && customerName.trim().isNotEmpty)
          ? customerName.trim()
          : null,
    );
    await _upsert(order);
    return order;
  }

  /// Ajoute un article ou incrémente sa quantité s'il est déjà présent
  /// (même produit + même note).
  Future<void> addLine(String orderId, RestaurantOrderLine line) async {
    final order = state.byId(orderId);
    // Une commande réglée ou annulée est close : le plat ajouté après coup ne
    // serait sur aucune facture. Les écrans masquent déjà l'action, cette garde
    // est le filet qui empêche un autre chemin de la contourner.
    if (order == null || order.isSettled) return;
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

  /// Renomme le libellé d'une commande (« Table 4 », « Emporter », nom du
  /// client…). Ignore un libellé vide (garde l'ancien).
  Future<void> renameOrder(String orderId, String label) async {
    final order = state.byId(orderId);
    if (order == null || order.isSettled) return;
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed == order.label) return;
    await _upsert(order.copyWith(label: trimmed));
  }

  Future<void> setQuantity(
    String orderId,
    int lineIndex,
    int quantity,
  ) async {
    final order = state.byId(orderId);
    if (order == null ||
        order.isSettled ||
        lineIndex < 0 ||
        lineIndex >= order.lines.length) {
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
    // Historise le passage d'étape (KPI temps de service / cote crédit).
    final history = [
      ...order.stageHistory,
      {'status': status.apiValue, 'at': DateTime.now().toIso8601String()},
    ];
    await _upsert(order.copyWith(status: status, stageHistory: history));
  }

  /// Marque la commande réglée. À appeler APRÈS création réussie de la `Sale`.
  /// Une commande déjà close est ignorée : deux encaissements du même ticket
  /// produiraient deux ventes pour un seul repas.
  Future<void> markPaid(String orderId) async {
    final order = state.byId(orderId);
    if (order == null || order.isSettled) return;
    await updateStatus(orderId, RestaurantOrderStatus.paid);
  }

  /// Rattache (ou détache) le client enregistré d'une commande en cours.
  Future<void> setCustomer(
    String orderId, {
    String? customerId,
    String? customerName,
  }) async {
    final order = state.byId(orderId);
    if (order == null || order.isSettled) return;
    await _upsert(RestaurantOrder(
      id: order.id,
      label: order.label,
      lines: order.lines,
      status: order.status,
      createdAt: order.createdAt,
      notes: order.notes,
      tableId: order.tableId,
      type: order.type,
      customerId: customerId,
      customerName: customerName,
      stageHistory: order.stageHistory,
    ));
  }

  Future<void> cancel(String orderId) =>
      updateStatus(orderId, RestaurantOrderStatus.cancelled);

  Future<void> deleteOrder(String orderId) async {
    await _repository.delete(orderId);
    _connuesDuServeur.remove(orderId);
    unawaited(_sync.remove(orderId).catchError((_) {}));
    emit(
      state.copyWith(
        orders: state.orders.where((o) => o.id != orderId).toList(),
      ),
    );
  }

  Future<void> _upsert(RestaurantOrder order) async {
    await _repository.save(order);
    // Partage dans l'ordre : l'echec ne bloque pas le service, la commande
    // reste en attente et repartira au prochain enregistrement ou chargement.
    unawaited(_pousser(order).catchError((_) {}));
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
