import 'package:wanzo/core/services/api_client.dart';

import '../models/salon_service.dart';
import '../models/stylist.dart';

/// Commission agrégée d'un coiffeur sur une période (entrée de préparation de
/// la paie). Renvoyée par `/salon/performers/commissions`.
///
/// `{stylistId,stylistName,serviceRevenue,retailRevenue,servicesCount,serviceCommission,retailCommission,totalCommission}`.
class StylistCommission {
  final String stylistId;
  final String stylistName;

  /// Chiffre réalisé sur les prestations (CDF).
  final double serviceRevenue;

  /// Chiffre réalisé sur les produits de détail (CDF).
  final double retailRevenue;

  /// Nombre de prestations exécutées.
  final int servicesCount;

  /// Commission due sur les prestations (CDF).
  final double serviceCommission;

  /// Commission due sur les produits (CDF).
  final double retailCommission;

  /// Commission totale à verser (CDF).
  final double totalCommission;

  const StylistCommission({
    required this.stylistId,
    required this.stylistName,
    required this.serviceRevenue,
    required this.retailRevenue,
    required this.servicesCount,
    required this.serviceCommission,
    required this.retailCommission,
    required this.totalCommission,
  });

  factory StylistCommission.fromJson(Map<String, dynamic> json) {
    // TypeORM renvoie les colonnes Postgres `numeric` comme des CHAÎNES JSON
    // (ex. "50.00") : accepter un num OU une chaîne numérique.
    double d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    int i(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    return StylistCommission(
      stylistId: (json['stylistId'] ?? '').toString(),
      stylistName: (json['stylistName'] ?? '').toString(),
      serviceRevenue: d(json['serviceRevenue']),
      retailRevenue: d(json['retailRevenue']),
      servicesCount: i(json['servicesCount']),
      serviceCommission: d(json['serviceCommission']),
      retailCommission: d(json['retailCommission']),
      totalCommission: d(json['totalCommission']),
    );
  }
}

/// Client HTTP du module SALON (backend `/salon`).
///
/// S'appuie sur [ApiClient] qui préfixe déjà `commerce/api/v1` (→ backend
/// `/api`). Toutes les méthodes sont « best-effort / offline-tolerant » : elles
/// laissent remonter l'exception (réseau, 4xx/5xx) aux appelants, qui affichent
/// un message dégradé. Aucune ne fait planter l'app hors-ligne.
class SalonApiService {
  final ApiClient _apiClient;

  SalonApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // ── Helpers d'extraction (tolérants à la double-enveloppe API) ───────────

  List<dynamic> _asList(dynamic response) {
    dynamic data = response;
    while (data is Map && data.containsKey('data')) {
      data = data['data'];
    }
    if (data is List) return data;
    return const [];
  }

  Map<String, dynamic> _asMap(dynamic response) {
    dynamic data = response;
    while (data is Map && data.containsKey('data') && data['data'] is Map) {
      data = data['data'];
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  // ── Prestations (carte) ──────────────────────────────────────────────────

  /// Récupère la carte des prestations publiée côté backend.
  Future<List<SalonService>> getServices() async {
    final response = await _apiClient.get('salon/services', requiresAuth: true);
    final list = _asList(response);
    final items = <SalonService>[];
    for (final raw in list) {
      if (raw is Map) {
        try {
          items.add(SalonService.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // Item malformé : ignoré plutôt que de casser toute la carte.
        }
      }
    }
    return items;
  }

  /// Publie la carte locale complète (upsert en masse). L'ordre local est
  /// conservé via `position`.
  Future<void> bulkUpsertServices(List<SalonService> services) async {
    final payload = <Map<String, dynamic>>[
      for (var i = 0; i < services.length; i++)
        services[i].copyWith(position: i).toJson(),
    ];
    await _apiClient.post(
      'salon/services/bulk-upsert',
      body: payload,
      requiresAuth: true,
    );
  }

  /// Crée une prestation isolée.
  Future<SalonService> createService(SalonService service) async {
    final response = await _apiClient.post(
      'salon/services',
      body: service.toJson(),
      requiresAuth: true,
    );
    return SalonService.fromJson(_asMap(response));
  }

  /// Met à jour une prestation.
  Future<SalonService> updateService(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.patch(
      'salon/services/$id',
      body: payload,
      requiresAuth: true,
    );
    return SalonService.fromJson(_asMap(response));
  }

  /// Supprime une prestation.
  Future<void> deleteService(String id) async {
    await _apiClient.delete('salon/services/$id', requiresAuth: true);
  }

  // ── Coiffeurs ──────────────────────────────────────────────────────────

  /// Liste les coiffeurs du salon.
  Future<List<Stylist>> getStylists() async {
    final response = await _apiClient.get('salon/stylists', requiresAuth: true);
    return _asList(response)
        .whereType<Map>()
        .map((e) => Stylist.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Crée un coiffeur.
  Future<Stylist> createStylist(Stylist stylist) async {
    final response = await _apiClient.post(
      'salon/stylists',
      body: stylist.toCreateJson(),
      requiresAuth: true,
    );
    return Stylist.fromJson(_asMap(response));
  }

  /// Met à jour un coiffeur.
  Future<Stylist> updateStylist(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.patch(
      'salon/stylists/$id',
      body: payload,
      requiresAuth: true,
    );
    return Stylist.fromJson(_asMap(response));
  }

  /// Supprime un coiffeur.
  Future<void> deleteStylist(String id) async {
    await _apiClient.delete('salon/stylists/$id', requiresAuth: true);
  }

  // ── Performances / commissions ───────────────────────────────────────────

  /// Commissions par coiffeur sur une période (préparation de la paie).
  Future<List<StylistCommission>> getCommissions({
    DateTime? from,
    DateTime? to,
  }) async {
    final qp = <String, String>{
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    };
    final response = await _apiClient.get(
      'salon/performers/commissions',
      queryParameters: qp.isEmpty ? null : qp,
      requiresAuth: true,
    );
    return _asList(response)
        .whereType<Map>()
        .map((e) => StylistCommission.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Commission d'UN coiffeur sur une période.
  Future<StylistCommission?> getStylistCommission(
    String stylistId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final qp = <String, String>{
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    };
    final response = await _apiClient.get(
      'salon/performers/$stylistId/commissions',
      queryParameters: qp.isEmpty ? null : qp,
      requiresAuth: true,
    );
    final map = _asMap(response);
    if (map.isEmpty) return null;
    return StylistCommission.fromJson(map);
  }
}
