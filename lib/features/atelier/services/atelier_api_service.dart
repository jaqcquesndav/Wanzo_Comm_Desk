import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/features/atelier/models/atelier_order.dart';
import 'package:wanzo/features/atelier/models/customer_vehicle.dart';

/// Client API du module Atelier (backend `/atelier`).
///
/// Les commandes atelier sont PERSISTÉES côté serveur (multi-appareils, suivi
/// sur plusieurs jours) — contrairement aux commandes restaurant qui sont
/// locales. Le profil de mesures est rattaché au client.
class AtelierApiService {
  final ApiClient _apiClient;

  AtelierApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // ── Véhicules des clients (mode garage) ────────────────────────────────────

  Future<List<CustomerVehicle>> getVehicles(String customerId) async {
    final res = await _apiClient.get('atelier/customers/$customerId/vehicles',
        requiresAuth: true);
    final data = res?['data'];
    final list = data is List ? data : (data is Map ? (data['data'] as List? ?? []) : []);
    return list
        .map((e) => CustomerVehicle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerVehicle> createVehicle(
      String customerId, Map<String, dynamic> payload) async {
    final res = await _apiClient.post('atelier/customers/$customerId/vehicles',
        body: payload, requiresAuth: true);
    return CustomerVehicle.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<CustomerVehicle> updateVehicle(
      String id, Map<String, dynamic> payload) async {
    final res = await _apiClient.patch('atelier/vehicles/$id',
        body: payload, requiresAuth: true);
    return CustomerVehicle.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteVehicle(String id) async {
    await _apiClient.delete('atelier/vehicles/$id', requiresAuth: true);
  }

  // ── Commandes ──────────────────────────────────────────────────────────────

  Future<List<AtelierOrder>> getOrders(
      {String? businessUnitId,
      String? status,
      String? customerId,
      String? metier,
      String? vehicleId}) async {
    final qp = <String, String>{};
    if (businessUnitId != null) qp['businessUnitId'] = businessUnitId;
    if (status != null) qp['status'] = status;
    if (customerId != null) qp['customerId'] = customerId;
    // Fiche de suivi d'un véhicule : ses interventions uniquement.
    if (vehicleId != null) qp['vehicleId'] = vehicleId;
    // Isolation par métier : le board d'un atelier de couture ne demande que les
    // commandes de couture (idem maintenance / imprimerie). Filtre appliqué côté
    // backend ; on refiltre aussi côté client par sécurité.
    if (metier != null) qp['metier'] = metier;
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

  Future<AtelierOrder> updateStatus(String id, AtelierOrderStatus status,
      {String? saleId}) async {
    final res = await _apiClient.patch('atelier/orders/$id/status',
        body: {
          'status': status.apiValue,
          if (saleId != null) 'saleId': saleId,
        },
        requiresAuth: true);
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
