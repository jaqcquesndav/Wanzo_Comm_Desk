import 'package:wanzo/core/services/api_client.dart';

import '../models/restaurant_order.dart';

/// Partage des commandes de SALLE entre les postes du restaurant.
///
/// Le service se joue à plusieurs : la salle prend la commande, la cuisine la
/// prépare, la caisse l'encaisse. Tant que la commande ne vivait que sur
/// l'appareil qui l'avait ouverte, chaque poste tenait son propre service en
/// aveugle.
///
/// L'appareil reste la source immédiate : la commande s'ouvre en local (le
/// service ne s'arrête pas quand le réseau tombe), puis se pousse sous LE MÊME
/// identifiant. Rejouer l'envoi met à jour la même commande au lieu d'en créer
/// une seconde.
class RestaurantOrderSync {
  final ApiClient _apiClient;

  RestaurantOrderSync({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  List<dynamic> _asList(dynamic response) {
    dynamic data = response;
    while (data is Map && data.containsKey('data')) {
      data = data['data'];
    }
    return data is List ? data : const [];
  }

  /// Les commandes du service telles que le serveur les connaît.
  ///
  /// Par défaut, celles qui sont encore ouvertes : c'est ce qu'un poste a
  /// besoin de voir. Lève en cas d'échec — l'appelant garde alors ses
  /// commandes locales, qui restent la vérité de cet appareil.
  Future<List<RestaurantOrder>> pull({bool activeOnly = true}) async {
    final res = await _apiClient.get(
      'restaurant/orders${activeOnly ? '' : '?activeOnly=false'}',
      requiresAuth: true,
    );
    final orders = <RestaurantOrder>[];
    for (final raw in _asList(res)) {
      if (raw is Map) {
        try {
          orders.add(RestaurantOrder.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // Commande illisible : on l'ignore plutôt que de perdre les autres.
        }
      }
    }
    return orders;
  }

  /// Pousse une commande. Best-effort : un échec laisse la commande locale
  /// intacte, elle repartira au prochain envoi.
  Future<void> push(RestaurantOrder order) async {
    await _apiClient.post(
      'restaurant/orders',
      body: {
        ...order.toJson(),
        // Le serveur nomme l'ouverture `openedAt` ; l'app la stocke en
        // `createdAt`, qui est la date à laquelle le poste a ouvert le ticket.
        'openedAt': order.createdAt.toIso8601String(),
      },
      requiresAuth: true,
    );
  }

  /// Retire une commande partagée (erreur de saisie).
  Future<void> remove(String id) async {
    await _apiClient.delete('restaurant/orders/$id', requiresAuth: true);
  }
}
