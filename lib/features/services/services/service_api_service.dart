import 'package:wanzo/core/services/api_client.dart';

import '../models/service_item.dart';

/// Accès HTTP au catalogue des services (`/services`, gestion commerciale).
class ServiceApiService {
  final ApiClient _apiClient;

  ServiceApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // ── Helpers d'extraction (tolérants à la double-enveloppe API) ───────────

  List<dynamic> _asList(dynamic response) {
    dynamic data = response;
    while (data is Map && data.containsKey('data')) {
      data = data['data'];
    }
    return data is List ? data : const [];
  }

  Map<String, dynamic> _asMap(dynamic response) {
    dynamic data = response;
    while (data is Map && data.containsKey('data') && data['data'] is Map) {
      data = data['data'];
    }
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// Services de l'entreprise, filtrés côté serveur par mode et métier.
  Future<List<ServiceItem>> getServices({String? mode, String? metier}) async {
    final query = <String, String>{};
    if (mode != null && mode.isNotEmpty) query['mode'] = mode;
    if (metier != null && metier.isNotEmpty) query['metier'] = metier;
    final response = await _apiClient.get(
      'services',
      queryParameters: query.isEmpty ? null : query,
      requiresAuth: true,
    );
    final items = <ServiceItem>[];
    for (final raw in _asList(response)) {
      if (raw is Map) {
        try {
          items.add(ServiceItem.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // Item malformé : ignoré.
        }
      }
    }
    return items;
  }

  /// URL publique signée du catalogue (vitrine) de l'entreprise, produite
  /// par le backend : jamais reconstruite côté client.
  Future<String> getPublicCatalogLink() async {
    final response = await _apiClient.get('public-catalog/link', requiresAuth: true);
    final url = _asMap(response)['url'];
    if (url is! String || url.isEmpty) {
      throw Exception('Lien du catalogue indisponible');
    }
    return url;
  }

  Future<ServiceItem> createService(ServiceItem service) async {
    final response = await _apiClient.post('services', body: service.toJson(), requiresAuth: true);
    return ServiceItem.fromJson(_asMap(response));
  }

  Future<ServiceItem> updateService(ServiceItem service) async {
    final body = service.toJson()..remove('id');
    final response = await _apiClient.patch('services/${service.id}', body: body, requiresAuth: true);
    return ServiceItem.fromJson(_asMap(response));
  }

  Future<void> deleteService(String id) async {
    await _apiClient.delete('services/$id', requiresAuth: true);
  }

  /// Republie en masse les écritures faites hors ligne (upsert par id).
  Future<void> bulkUpsert(List<ServiceItem> services) async {
    if (services.isEmpty) return;
    await _apiClient.post(
      'services/bulk-upsert',
      body: {'items': services.map((s) => s.toJson()).toList()},
      requiresAuth: true,
    );
  }
}
