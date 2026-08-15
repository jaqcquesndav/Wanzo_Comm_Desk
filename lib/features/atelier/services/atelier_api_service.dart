import '../../../core/services/api_client.dart';
import '../models/atelier_order.dart';

/// Client API du module Atelier (backend `/atelier`).
///
/// Les commandes atelier sont PERSISTÉES côté serveur (multi-appareils, suivi
/// sur plusieurs jours) — contrairement aux commandes restaurant qui sont
/// locales. Le profil de mesures est rattaché au client.
class AtelierApiService {
  final ApiClient _apiClient;

  AtelierApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // ── Commandes ──────────────────────────────────────────────────────────────

  Future<List<AtelierOrder>> getOrders({String? businessUnitId, String? status}) async {
    final qp = <String, String>{};
    if (businessUnitId != null) qp['businessUnitId'] = businessUnitId;
    if (status != null) qp['status'] = status;
    final res = await _apiClient.get('atelier/orders',
        queryParameters: qp.isEmpty ? null : qp, requiresAuth: true);
    final data = res?['data'];
    final list = data is List ? data : (data is Map ? (data['data'] as List? ?? []) : []);
    return list
        .map((e) => AtelierOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AtelierOrder> createOrder(AtelierOrder order) async {
    final res = await _apiClient.post('atelier/orders',
        body: order.toCreateJson(), requiresAuth: true);
    return AtelierOrder.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<AtelierOrder> updateOrder(String id, Map<String, dynamic> payload) async {
    final res = await _apiClient.patch('atelier/orders/$id',
        body: payload, requiresAuth: true);
    return AtelierOrder.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<AtelierOrder> updateStatus(String id, AtelierOrderStatus status) async {
    final res = await _apiClient.patch('atelier/orders/$id/status',
        body: {'status': status.apiValue}, requiresAuth: true);
    return AtelierOrder.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteOrder(String id) async {
    await _apiClient.delete('atelier/orders/$id', requiresAuth: true);
  }

  // ── Profil de mesures ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getProfile(String customerId) async {
    final res = await _apiClient.get('atelier/customers/$customerId/profile',
        requiresAuth: true);
    return res?['data'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> upsertProfile(
    String customerId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _apiClient.put('atelier/customers/$customerId/profile',
        body: payload, requiresAuth: true);
    return res['data'] as Map<String, dynamic>;
  }
}
