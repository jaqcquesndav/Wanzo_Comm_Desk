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
///
/// **Un envoi à la fois par commande, toujours la dernière version.** Chaque
/// modification partait auparavant sans attendre la précédente : ouverture (0
/// ligne), premier plat, deuxième plat. Arrivés dans le désordre, l'ancien
/// instantané à 0 ligne écrasait la commande complète sur le serveur (qui
/// garde le dernier reçu), puis revenait sur tous les postes : « 0 article »
/// dans le kanban. Désormais les envois d'une même commande s'enchaînent, et
/// chacun porte la version la plus récente au moment où il part.
class RestaurantOrderSync {
  final ApiClient _apiClient;

  RestaurantOrderSync({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Dernière version connue de chaque commande, à envoyer.
  final Map<String, RestaurantOrder> _derniere = {};

  /// Dernière version effectivement confirmée par le serveur.
  final Map<String, RestaurantOrder> _confirmee = {};

  /// Envoi en cours pour une commande (au plus un).
  final Map<String, Future<bool>> _enCours = {};

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

  /// Pousse la commande. Si un envoi est déjà en cours pour elle, celui-ci
  /// enverra cette version à la suite. Le futur rend `true` quand la version
  /// la plus récente a été confirmée par le serveur.
  Future<bool> push(RestaurantOrder order) {
    _derniere[order.id] = order;
    return _enCours[order.id] ??= _boucle(order.id);
  }

  /// Vrai si la version la plus récente de la commande est confirmée.
  bool estAJour(String id) {
    final derniere = _derniere[id];
    return derniere != null && identical(_confirmee[id], derniere);
  }

  Future<bool> _boucle(String id) async {
    var ok = false;
    try {
      RestaurantOrder? envoyee;
      while (!identical(_derniere[id], envoyee)) {
        envoyee = _derniere[id]!;
        try {
          await _post(envoyee);
          _confirmee[id] = envoyee;
          ok = true;
        } catch (_) {
          // Hors ligne (mise en file par ApiClient) ou serveur indisponible :
          // la commande reste à confirmer, elle repartira au prochain envoi.
          ok = false;
        }
      }
    } finally {
      _enCours.remove(id);
    }
    // Une version arrivée entre la fin de la boucle et son retrait repart.
    if (!identical(_derniere[id], _confirmee[id]) && ok) {
      return push(_derniere[id]!);
    }
    return ok && estAJour(id);
  }

  Future<void> _post(RestaurantOrder order) async {
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

  /// Retire une commande partagée (erreur de saisie, commande vide).
  Future<void> remove(String id) async {
    _derniere.remove(id);
    _confirmee.remove(id);
    await _apiClient.delete('restaurant/orders/$id', requiresAuth: true);
  }
}
