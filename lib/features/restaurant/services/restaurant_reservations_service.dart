import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../core/services/api_client.dart';
import '../models/restaurant_order.dart';

/// Réservation à laquelle rattacher une commande « Réservation » : chambre
/// occupée (séjour) ou salle louée (événement), avec le client et les dates.
///
/// Source : `GET restaurant/orders/reservations` (gestion_commerciale_service).
/// La facturation reste celle des réservations : à l'encaissement, la commande
/// rejoint le folio de la réservation (« Sur une réservation »).
class ServableReservation {
  final String reservationId;
  final String spaceId;
  final String spaceName;

  /// [ReservationSpaceKind.room] ou [ReservationSpaceKind.hall].
  final String kind;
  final String? customerId;
  final String? customerName;
  final String status;
  final DateTime startAt;
  final DateTime endAt;

  /// Client arrivé, événement commencé.
  final bool inProgress;

  /// Déjà facturée (salle prépayée, séjour payé à l'arrivée) : la commande
  /// ira sur une facture complémentaire au compte du client.
  final bool invoiced;

  const ServableReservation({
    required this.reservationId,
    required this.spaceId,
    required this.spaceName,
    required this.status,
    required this.startAt,
    required this.endAt,
    this.kind = ReservationSpaceKind.room,
    this.customerId,
    this.customerName,
    this.inProgress = false,
    this.invoiced = false,
  });

  bool get isHall => kind == ReservationSpaceKind.hall;

  static String? _texte(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  static DateTime _date(dynamic v) =>
      DateTime.tryParse('${v ?? ''}')?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  factory ServableReservation.fromJson(
    Map<String, dynamic> json, {
    String? kind,
  }) {
    final k = _texte(json['kind']) ?? kind ?? ReservationSpaceKind.room;
    return ServableReservation(
      reservationId: (json['reservationId'] ?? '').toString(),
      spaceId: (json['spaceId'] ?? '').toString(),
      spaceName: _texte(json['spaceName']) ??
          (k == ReservationSpaceKind.hall ? 'Salle' : 'Chambre'),
      kind: k,
      customerId: _texte(json['customerId']),
      customerName: _texte(json['customerName']),
      status: (json['status'] ?? 'confirmed').toString(),
      startAt: _date(json['startAt']),
      endAt: _date(json['endAt']),
      inProgress: json['inProgress'] == true,
      invoiced: json['invoiced'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'reservationId': reservationId,
        'spaceId': spaceId,
        'spaceName': spaceName,
        'kind': kind,
        if (customerId != null) 'customerId': customerId,
        if (customerName != null) 'customerName': customerName,
        'status': status,
        'startAt': startAt.toUtc().toIso8601String(),
        'endAt': endAt.toUtc().toIso8601String(),
        'inProgress': inProgress,
        'invoiced': invoiced,
      };

  /// Libellé lisible du statut (mêmes termes que l'app Assets).
  String get statusLabel => switch (status) {
        'quote' => 'Devis',
        'option' => 'Option',
        'confirmed' => 'Confirmée',
        'inProgress' => isHall ? 'En cours' : 'Arrivé',
        _ => status,
      };

  /// Vrai si la recherche (espace ou client) correspond.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return spaceName.toLowerCase().contains(q) ||
        (customerName ?? '').toLowerCase().contains(q);
  }
}

/// Réservations connues (chambres et salles), avec leur origine.
class ReservationsSnapshot {
  /// L'établissement a des chambres, des salles. `null` : encore inconnu.
  final bool? hasRooms;
  final bool? hasHalls;
  final List<ServableReservation> rooms;
  final List<ServableReservation> halls;

  /// Date de la liste : celle du dernier chargement réussi.
  final DateTime? fetchedAt;

  /// Liste relue sur l'appareil faute de réseau.
  final bool fromCache;

  const ReservationsSnapshot({
    required this.hasRooms,
    required this.hasHalls,
    required this.rooms,
    required this.halls,
    this.fetchedAt,
    this.fromCache = false,
  });

  static const unknown = ReservationsSnapshot(
    hasRooms: null,
    hasHalls: null,
    rooms: [],
    halls: [],
  );

  /// Chambres ou salles connues ; `null` tant que rien n'est su.
  bool? get hasAny => (hasRooms == null && hasHalls == null)
      ? null
      : (hasRooms == true || hasHalls == true);
}

/// Lecture des réservations servables, en ligne d'abord puis la dernière
/// réponse connue (hors ligne) : la prise de commande ne s'arrête pas avec le
/// réseau.
class RestaurantReservationsService {
  static const _boite = 'restaurant_reservations_cache';
  static const _cle = 'reservations';

  final ApiClient _apiClient;

  RestaurantReservationsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Déballe la (double) enveloppe `{success, data}` de gestion.
  static dynamic _deballer(dynamic response) {
    dynamic data = response;
    while (data is Map && data.containsKey('data') && data['data'] != null) {
      data = data['data'];
    }
    return data;
  }

  static List<ServableReservation> _liste(dynamic raw, String kind) {
    final out = <ServableReservation>[];
    for (final e in (raw is List ? raw : const [])) {
      if (e is! Map) continue;
      try {
        final r = ServableReservation.fromJson(
          Map<String, dynamic>.from(e),
          kind: kind,
        );
        if (r.reservationId.isNotEmpty) out.add(r);
      } catch (_) {
        // Ligne illisible : les autres restent proposées.
      }
    }
    return out;
  }

  /// Lit la réponse du serveur (`{hasRooms, hasHalls, rooms, halls}`).
  static ReservationsSnapshot parse(dynamic response, {DateTime? at}) {
    final data = _deballer(response);
    if (data is! Map) {
      return ReservationsSnapshot(
        hasRooms: null,
        hasHalls: null,
        rooms: const [],
        halls: const [],
        fetchedAt: at,
      );
    }
    final rooms = _liste(data['rooms'], ReservationSpaceKind.room);
    final halls = _liste(data['halls'], ReservationSpaceKind.hall);
    final hr = data['hasRooms'];
    final hh = data['hasHalls'];
    return ReservationsSnapshot(
      hasRooms: hr is bool ? hr : rooms.isNotEmpty,
      hasHalls: hh is bool ? hh : halls.isNotEmpty,
      rooms: rooms,
      halls: halls,
      fetchedAt: at,
    );
  }

  Future<Box<String>> _ouvrir() async => Hive.isBoxOpen(_boite)
      ? Hive.box<String>(_boite)
      : await Hive.openBox<String>(_boite);

  /// Dernière liste connue sur l'appareil.
  Future<ReservationsSnapshot> cached() async {
    try {
      final brut = (await _ouvrir()).get(_cle);
      if (brut == null) return ReservationsSnapshot.unknown;
      final json = jsonDecode(brut) as Map<String, dynamic>;
      final snap = parse(json, at: DateTime.tryParse('${json['at'] ?? ''}'));
      return ReservationsSnapshot(
        hasRooms: snap.hasRooms,
        hasHalls: snap.hasHalls,
        rooms: snap.rooms,
        halls: snap.halls,
        fetchedAt: snap.fetchedAt,
        fromCache: true,
      );
    } catch (_) {
      return ReservationsSnapshot.unknown;
    }
  }

  Future<void> _garder(ReservationsSnapshot s) async {
    try {
      await (await _ouvrir()).put(
        _cle,
        jsonEncode({
          'hasRooms': s.hasRooms,
          'hasHalls': s.hasHalls,
          'rooms': s.rooms.map((r) => r.toJson()).toList(),
          'halls': s.halls.map((r) => r.toJson()).toList(),
          'at': (s.fetchedAt ?? DateTime.now()).toIso8601String(),
        }),
      );
    } catch (_) {
      // Sans cache, la liste reste disponible en ligne.
    }
  }

  /// Réservations servables : serveur d'abord, sinon la dernière liste connue.
  Future<ReservationsSnapshot> load() async {
    try {
      final res = await _apiClient.get(
        'restaurant/orders/reservations',
        requiresAuth: true,
      );
      final snap = parse(res, at: DateTime.now());
      await _garder(snap);
      return snap;
    } catch (_) {
      return cached();
    }
  }
}
