import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/salon_service.dart';
import '../models/stylist.dart';
import '../repositories/salon_service_repository.dart';
import '../repositories/salon_stylist_cache.dart';
import '../services/salon_api_service.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';

/// État partagé du mode salon : la carte des prestations (offline-first) et la
/// liste des coiffeurs (persistés côté backend, avec repli hors-ligne).
class SalonState extends Equatable {
  final List<SalonService> services;
  final List<Stylist> stylists;
  final bool loading;
  final String? error;

  const SalonState({
    this.services = const [],
    this.stylists = const [],
    this.loading = false,
    this.error,
  });

  /// Coiffeurs actifs uniquement (pour la sélection sur un ticket).
  List<Stylist> get activeStylists =>
      stylists.where((s) => s.active).toList();

  /// Prestations actives uniquement (proposables à la vente).
  List<SalonService> get activeServices =>
      services.where((s) => s.active).toList();

  SalonState copyWith({
    List<SalonService>? services,
    List<Stylist>? stylists,
    bool? loading,
    String? error,
  }) {
    return SalonState(
      services: services ?? this.services,
      stylists: stylists ?? this.stylists,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [services, stylists, loading, error];
}

/// Pilote le mode salon : charge la carte (locale + backend optionnel) et les
/// coiffeurs, gère la CRUD coiffeurs. Tolérant au hors-ligne : la carte locale
/// et le dernier cache d'affichage restent servis si le réseau est indisponible.
/// Ce que rend un enregistrement de salon.
///
/// Distinguer « enregistre » de « conserve hors ligne » evite le pire des deux
/// mondes : un faux succes, ou un echec qui pousse a ressaisir ce qui est deja
/// en file.
class SalonSaveResult<T> {
  const SalonSaveResult({this.value, this.horsLigne = false});

  final T? value;

  /// Vrai quand l'ecriture attend le retour du reseau.
  final bool horsLigne;

  bool get ok => value != null;
}

class SalonCubit extends Cubit<SalonState> {
  final SalonServiceRepository _repo;
  final SalonApiService _api;
  final SalonStylistCache _stylistCache;

  SalonCubit({
    SalonServiceRepository? repo,
    SalonApiService? api,
    SalonStylistCache? stylistCache,
  })  : _repo = repo ?? SalonServiceRepository(),
        _api = api ?? SalonApiService(),
        _stylistCache = stylistCache ?? SalonStylistCache(),
        super(const SalonState());

  /// Charge la carte (locale d'abord, puis réconciliée avec le backend si
  /// joignable) et les coiffeurs. Le hors-ligne n'est jamais bloquant.
  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));

    // 1) Carte locale (source d'affichage immédiate, offline-first).
    final localServices = await _repo.loadAll();
    emit(state.copyWith(services: localServices, loading: true));

    // 2) Réconciliation backend (best-effort).
    List<SalonService> services = localServices;
    try {
      final remote = await _api.getServices();
      if (remote.isNotEmpty) {
        await _repo.replaceAll(remote);
        services = await _repo.loadAll();
      }
    } catch (_) {
      // Hors-ligne : on conserve la carte locale.
    }

    // 3) Coiffeurs (backend, best-effort) + cache local offline-first.
    List<Stylist> stylists = state.stylists;
    String? error;
    try {
      stylists = await _api.getStylists();
      // Mémoriser pour l'affichage hors-ligne.
      await _stylistCache.save(stylists);
    } catch (e) {
      // Hors-ligne : servir la dernière liste connue.
      final cached = await _stylistCache.load();
      if (cached.isNotEmpty) {
        stylists = cached;
        error = 'Coiffeurs hors ligne — dernières données connues';
      } else {
        error = 'Coiffeurs indisponibles hors ligne';
      }
    }

    emit(SalonState(
      services: services,
      stylists: stylists,
      loading: false,
      error: error,
    ));
  }

  /// Recharge uniquement la carte locale (après édition dans l'écran carte).
  Future<void> reloadServices() async {
    final services = await _repo.loadAll();
    emit(state.copyWith(services: services));
  }

  // ── CRUD coiffeurs (backend) ─────────────────────────────────────────────

  /// Ajoute un coiffeur.
  ///
  /// Hors ligne, l'ecriture est conservee par la file du client HTTP : le
  /// coiffeur doit apparaitre TOUT DE SUITE, sinon on ne peut lui attribuer
  /// aucune prestation sur le ticket en cours.
  Future<SalonSaveResult<Stylist>> createStylist(Stylist draft) async {
    try {
      final created = await _api.createStylist(draft);
      final stylists = [...state.stylists, created];
      emit(state.copyWith(stylists: stylists, error: null));
      await _stylistCache.save(stylists);
      return SalonSaveResult(value: created);
    } on OfflineQueuedException {
      final stylists = [...state.stylists, draft];
      emit(state.copyWith(stylists: stylists, error: null));
      await _stylistCache.save(stylists);
      return SalonSaveResult(value: draft, horsLigne: true);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      return const SalonSaveResult();
    }
  }

  /// Corrige un coiffeur. Meme traitement du hors ligne que [createStylist].
  Future<SalonSaveResult<Stylist>> updateStylist(
    String id,
    Map<String, dynamic> payload, {
    Stylist? local,
  }) async {
    try {
      final updated = await _api.updateStylist(id, payload);
      final stylists =
          state.stylists.map((s) => s.id == id ? updated : s).toList();
      emit(state.copyWith(stylists: stylists, error: null));
      await _stylistCache.save(stylists);
      return SalonSaveResult(value: updated);
    } on OfflineQueuedException {
      if (local == null) return const SalonSaveResult(horsLigne: true);
      final stylists =
          state.stylists.map((s) => s.id == id ? local : s).toList();
      emit(state.copyWith(stylists: stylists, error: null));
      await _stylistCache.save(stylists);
      return SalonSaveResult(value: local, horsLigne: true);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      return const SalonSaveResult();
    }
  }

  /// Retire un coiffeur. Le retrait est applique tout de suite ; hors ligne il
  /// est conserve et rejoue, donc on ne le defait PAS comme on le ferait pour
  /// un vrai echec.
  Future<void> deleteStylist(String id) async {
    final previous = state.stylists;
    final restants = previous.where((s) => s.id != id).toList();
    emit(state.copyWith(stylists: restants));
    try {
      await _api.deleteStylist(id);
      await _stylistCache.save(restants);
    } on OfflineQueuedException {
      await _stylistCache.save(restants);
    } catch (e) {
      emit(state.copyWith(error: e.toString(), stylists: previous));
    }
  }
}
