import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/modules/activity_mode.dart';
import '../../../core/services/business_context_service.dart';
import '../../atelier/models/atelier_order.dart';
import '../models/service_item.dart';
import '../repositories/service_repository.dart';
import '../services/service_api_service.dart';

class ServicesState extends Equatable {
  final List<ServiceItem> items;
  final bool loading;
  final String? error;

  const ServicesState({this.items = const [], this.loading = false, this.error});

  ServicesState copyWith({List<ServiceItem>? items, bool? loading, String? error, bool clearError = false}) {
    return ServicesState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<ServiceItem> get activeItems => items.where((s) => s.active).toList();

  List<String> get categories {
    final set = <String>{};
    for (final s in items) {
      if (s.category != null && s.category!.trim().isNotEmpty) set.add(s.category!.trim());
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  List<Object?> get props => [items, loading, error];
}

/// Catalogue des services : cache local d'abord (offline-first), puis
/// rafraîchissement serveur filtré sur le mode et le métier courants. Les
/// écritures passent au serveur quand il répond, sinon restent locales
/// (`pendingSync`) et sont republiées au prochain chargement.
class ServicesCubit extends Cubit<ServicesState> {
  final ServiceRepository _repository;
  final ServiceApiService _api;

  ServicesCubit({ServiceRepository? repository, ServiceApiService? api})
      : _repository = repository ?? ServiceRepository(),
        _api = api ?? ServiceApiService(),
        super(const ServicesState());

  ActivityMode get _mode => BusinessContextService().activityMode;

  /// Métier d'atelier courant, pour isoler les catalogues (pressing ≠ garage).
  String? get currentMetier {
    final mode = _mode;
    if (!mode.isWorkshop) return null;
    return metierForMode(mode).apiValue;
  }

  /// Mapping mode → métier par défaut (même règle que le tableau Kanban).
  static AtelierMetier metierForMode(ActivityMode mode) {
    switch (mode) {
      case ActivityMode.atelierMaintenance:
        return AtelierMetier.maintenance;
      case ActivityMode.imprimerie:
        return AtelierMetier.imprimerie;
      case ActivityMode.pressing:
        return AtelierMetier.pressing;
      case ActivityMode.garage:
        return AtelierMetier.garage;
      default:
        return AtelierMetier.couture;
    }
  }

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    final local = _visible(await _repository.loadAll());
    emit(state.copyWith(items: local));
    try {
      final pending = await _repository.pendingItems();
      if (pending.isNotEmpty) await _api.bulkUpsert(pending);
      final server = await _api.getServices(mode: _mode.apiValue, metier: currentMetier);
      await _repository.replaceFromServer(server);
      emit(state.copyWith(items: _visible(await _repository.loadAll()), loading: false));
    } catch (e) {
      // Hors ligne ou serveur indisponible : le cache local fait foi.
      emit(state.copyWith(loading: false, error: local.isEmpty ? e.toString() : null));
    }
  }

  Future<void> save(ServiceItem item) async {
    final isNew = (await _repository.getById(item.id)) == null;
    await _repository.upsert(item.copyWith(pendingSync: true));
    emit(state.copyWith(items: _visible(await _repository.loadAll())));
    try {
      final saved = isNew ? await _api.createService(item) : await _api.updateService(item);
      if (saved.id != item.id) await _repository.delete(item.id);
      await _repository.upsert(saved.copyWith(pendingSync: false));
    } catch (_) {
      // Reste en attente ; republié par `load()`.
    }
    emit(state.copyWith(items: _visible(await _repository.loadAll())));
  }

  Future<void> toggleActive(ServiceItem item) => save(item.copyWith(active: !item.active));

  /// Import en masse (CSV) : cache local d'abord (visible hors ligne), puis
  /// publication groupée ; les éléments non publiés restent en attente et
  /// repartent au prochain `load()`.
  Future<void> importAll(List<ServiceItem> items) async {
    if (items.isEmpty) return;
    final metier = currentMetier;
    final stamped = [for (final it in items) it.copyWith(metier: it.metier ?? metier, pendingSync: true)];
    for (final it in stamped) {
      await _repository.upsert(it);
    }
    emit(state.copyWith(items: _visible(await _repository.loadAll())));
    try {
      await _api.bulkUpsert(stamped);
      await load();
    } catch (_) {
      // Reste en attente ; republié par `load()`.
    }
  }

  /// Services actifs correspondant à une recherche du point de vente
  /// (nom ou catégorie), limités pour rester lisibles sous le champ.
  List<ServiceItem> search(String query, {int limit = 5}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return state.items
        .where((s) => s.active &&
            s.priceTiers.isNotEmpty &&
            (s.name.toLowerCase().contains(q) || (s.category ?? '').toLowerCase().contains(q)))
        .take(limit)
        .toList();
  }

  Future<void> delete(ServiceItem item) async {
    await _repository.delete(item.id);
    emit(state.copyWith(items: _visible(await _repository.loadAll())));
    try {
      await _api.deleteService(item.id);
    } catch (_) {
      // Suppression locale conservée ; le serveur sera cohérent au prochain load
      // (l'élément réapparaîtra s'il existe encore côté serveur).
    }
  }

  /// Le cache peut contenir des services d'autres métiers (changement de mode
  /// sur l'appareil) : on n'affiche que ceux du mode et du métier courants.
  List<ServiceItem> _visible(List<ServiceItem> all) {
    final mode = _mode.apiValue;
    final metier = currentMetier;
    return all.where((s) {
      final modeOk = s.activityModes.isEmpty || s.activityModes.contains(mode);
      final metierOk = metier == null || s.metier == null || s.metier == metier;
      return modeOk && metierOk;
    }).toList();
  }
}
