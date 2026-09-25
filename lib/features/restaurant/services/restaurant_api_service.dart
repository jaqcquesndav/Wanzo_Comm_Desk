import '../../../core/services/api_client.dart';
import '../models/menu_course.dart';
import '../models/menu_item.dart';

/// Une TABLE physique du restaurant, telle que gérée par le backend
/// (module restaurant). Sert à générer un QR public par table (menu +
/// commande en ligne). Modèle volontairement minimal : `{id, label, active}`.
class RestaurantTable {
  final String id;
  final String label;
  final bool active;

  const RestaurantTable({
    required this.id,
    required this.label,
    this.active = true,
  });

  factory RestaurantTable.fromJson(Map<String, dynamic> json) {
    return RestaurantTable(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      active: json['active'] as bool? ?? true,
    );
  }
  /// Pour garder le plan de salle sur l'appareil : un demarrage hors ligne
  /// affichait un plan vide faute de tables en cache.
  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'active': active};
}

/// Commande passee par un CLIENT depuis le lien de table (page publique QR).
///
/// Elle attend qu'un poste la prenne en charge : elle devient alors une
/// commande de salle ordinaire, que la cuisine prepare et que la caisse
/// encaisse.
class RestaurantWebOrder {
  final String id;
  final String? tableId;
  final String? tableLabel;
  final List<RestaurantWebOrderLine> lines;
  final double totalCdf;
  final String? customerContact;
  final DateTime createdAt;

  const RestaurantWebOrder({
    required this.id,
    required this.lines,
    required this.totalCdf,
    required this.createdAt,
    this.tableId,
    this.tableLabel,
    this.customerContact,
  });

  static double _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  factory RestaurantWebOrder.fromJson(Map<String, dynamic> json) {
    final brut = json['lines'];
    return RestaurantWebOrder(
      id: (json['id'] ?? '').toString(),
      tableId: (json['tableId'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['tableId'] as String).trim(),
      tableLabel: json['tableLabel'] as String?,
      lines: brut is List
          ? brut
              .whereType<Map>()
              .map((l) =>
                  RestaurantWebOrderLine.fromJson(Map<String, dynamic>.from(l)))
              .toList()
          : const [],
      totalCdf: _d(json['totalCdf']),
      customerContact: json['customerContact'] as String?,
      createdAt:
          DateTime.tryParse('${json['createdAt']}')?.toLocal() ?? DateTime.now(),
    );
  }

  int get itemCount => lines.fold<int>(0, (s, l) => s + l.quantity);
}

class RestaurantWebOrderLine {
  final String menuItemId;
  final String name;
  final double unitPriceCdf;
  final int quantity;
  final String? note;

  const RestaurantWebOrderLine({
    required this.menuItemId,
    required this.name,
    required this.unitPriceCdf,
    required this.quantity,
    this.note,
  });

  factory RestaurantWebOrderLine.fromJson(Map<String, dynamic> json) =>
      RestaurantWebOrderLine(
        menuItemId: (json['menuItemId'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        unitPriceCdf: RestaurantWebOrder._d(json['unitPriceCdf']),
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        note: json['note'] as String?,
      );
}

/// Lien PUBLIC signé d'une table : l'URL à encoder dans le QR (menu public +
/// prise de commande). L'URL est fournie par le backend (domaine public,
/// signée) — elle ne doit JAMAIS être reconstruite côté client.
class RestaurantTableLink {
  final String url;
  final String tableId;
  final String label;

  const RestaurantTableLink({
    required this.url,
    required this.tableId,
    required this.label,
  });

  factory RestaurantTableLink.fromJson(Map<String, dynamic> json) {
    return RestaurantTableLink(
      url: (json['url'] ?? '').toString(),
      tableId: (json['tableId'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
    );
  }
}

/// Client HTTP du module RESTAURANT (carte publiée + tables/QR).
///
/// S'appuie sur [ApiClient] qui préfixe déjà `commerce/api/v1` (→ backend
/// `/api`). Toutes les méthodes sont « best-effort / offline-tolerant » : elles
/// laissent remonter l'exception (réseau, 4xx/5xx) aux appelants, qui affichent
/// un message dégradé. Aucune ne fait planter l'app hors-ligne.
class RestaurantApiService {
  final ApiClient _apiClient;

  RestaurantApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // ── Helpers d'extraction (tolérants à la double-enveloppe API) ───────────
  // L'ApiResponseInterceptor du backend ré-enveloppe les réponses en
  // `{success, data}` (parfois deux fois). On déballe jusqu'à la charge utile.

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
    while (data is Map &&
        data.containsKey('data') &&
        data['data'] is Map) {
      data = data['data'];
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  /// Convertit un [MenuItem] local vers la forme attendue par le backend.
  /// La photo transmise est l'URL réseau (hébergée) — le chemin local n'a
  /// aucun sens pour la page publique et n'est donc PAS envoyé.
  Map<String, dynamic> _menuItemToApi(MenuItem item, int position) {
    final description = item.description?.trim();
    final photoUrl = item.photoUrl?.trim();
    return {
      'id': item.id,
      'name': item.name,
      'priceCdf': item.priceCdf,
      if (item.priceInputCurrencyCode != null)
        'priceInputCurrencyCode': item.priceInputCurrencyCode,
      if (item.priceInInputCurrency != null)
        'priceInInputCurrency': item.priceInInputCurrency,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
      'course': item.course.apiValue,
      'available': item.available,
      // Optionnel : les groupes de modificateurs (cuisson, suppléments…) pour
      // que la page publique (QR) puisse les afficher/proposer.
      if (item.modifierGroups.isNotEmpty)
        'modifierGroups':
            item.modifierGroups.map((g) => g.toJson()).toList(),
      'position': position,
    };
  }

  // ── Carte (menu items) ───────────────────────────────────────────────────

  /// Publie la carte locale complète vers le backend (upsert en masse), afin
  /// que la page publique (QR) ET les autres postes affichent la carte à jour.
  /// Envoie un tableau d'items (id client CONSERVÉ côté backend → idempotent,
  /// pas de doublon) ; l'ordre local est conservé via `position`. Renvoie les
  /// items tels que persistés (avec leurs ids) pour permettre une réconciliation
  /// locale éventuelle.
  Future<List<MenuItem>> bulkUpsertMenuItems(List<MenuItem> items) async {
    final payload = <Map<String, dynamic>>[
      for (var i = 0; i < items.length; i++) _menuItemToApi(items[i], i),
    ];
    final response = await _apiClient.post(
      'restaurant/menu-items/bulk-upsert',
      body: payload,
      requiresAuth: true,
    );
    final saved = <MenuItem>[];
    for (final raw in _asList(response)) {
      if (raw is Map) {
        try {
          saved.add(MenuItem.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // Item malformé dans la réponse : ignoré (n'empêche pas la publication).
        }
      }
    }
    return saved;
  }

  /// Envoie UN plat au serveur, a sa place dans la carte.
  ///
  /// Passe par l'upsert en masse (un seul element) : le serveur y conserve
  /// l'id choisi par l'appareil, donc un renvoi ne cree jamais de doublon.
  /// Hors ligne, `ApiClient` met l'ecriture en file et leve
  /// `OfflineQueuedException` : elle sera rejouee au retour du reseau.
  Future<void> upsertMenuItem(MenuItem item, int position) async {
    await _apiClient.post(
      'restaurant/menu-items/bulk-upsert',
      body: [_menuItemToApi(item, position)],
      requiresAuth: true,
    );
  }

  /// Retire UN plat du serveur. Sans cet appel, un plat supprime sur
  /// l'appareil restait publie : visible sur le lien de table, et rapatrie
  /// dans la carte a la synchronisation suivante.
  Future<void> deleteMenuItem(String id) async {
    await _apiClient.delete(
      'restaurant/menu-items/$id',
      requiresAuth: true,
    );
  }

  /// Récupère la carte publiée côté backend.
  Future<List<MenuItem>> getMenuItems() async {
    final response = await _apiClient.get(
      'restaurant/menu-items',
      requiresAuth: true,
    );
    final list = _asList(response);
    final items = <MenuItem>[];
    for (final raw in list) {
      if (raw is Map) {
        try {
          items.add(MenuItem.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // Item malformé : on l'ignore plutôt que de casser toute la carte.
        }
      }
    }
    return items;
  }

  // ── Commandes des clients (lien de table) ─────────────────────────────────

  /// Commandes envoyees par les clients et pas encore prises en charge.
  Future<List<RestaurantWebOrder>> getPendingWebOrders() async {
    final response = await _apiClient.get(
      'restaurant/web-orders',
      queryParameters: const {'status': 'sent'},
      requiresAuth: true,
    );
    final commandes = <RestaurantWebOrder>[];
    for (final raw in _asList(response)) {
      if (raw is Map) {
        try {
          commandes.add(
              RestaurantWebOrder.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // Commande illisible : ignoree, les autres restent visibles.
        }
      }
    }
    return commandes;
  }

  /// `open` = prise en charge par un poste ; `cancelled` = refusee.
  Future<void> updateWebOrderStatus(String id, String status) async {
    await _apiClient.patch(
      'restaurant/web-orders/$id/status',
      body: {'status': status},
      requiresAuth: true,
    );
  }

  // ── Tables ───────────────────────────────────────────────────────────────

  /// Liste les tables du restaurant.
  Future<List<RestaurantTable>> getTables() async {
    final response = await _apiClient.get(
      'restaurant/tables',
      requiresAuth: true,
    );
    return _asList(response)
        .whereType<Map>()
        .map((e) => RestaurantTable.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Crée une table (`label`), active par défaut.
  Future<RestaurantTable> createTable(String label) async {
    final response = await _apiClient.post(
      'restaurant/tables',
      body: {'label': label, 'active': true},
      requiresAuth: true,
    );
    return RestaurantTable.fromJson(_asMap(response));
  }

  /// Met à jour une table (libellé et/ou activation).
  Future<RestaurantTable> updateTable(
    String id, {
    String? label,
    bool? active,
  }) async {
    final body = <String, dynamic>{
      if (label != null) 'label': label,
      if (active != null) 'active': active,
    };
    final response = await _apiClient.patch(
      'restaurant/tables/$id',
      body: body,
      requiresAuth: true,
    );
    return RestaurantTable.fromJson(_asMap(response));
  }

  /// Supprime une table.
  Future<void> deleteTable(String id) async {
    await _apiClient.delete('restaurant/tables/$id', requiresAuth: true);
  }

  /// Récupère le lien PUBLIC signé d'une table (URL à encoder dans le QR).
  /// L'URL est produite par le backend (domaine public + signature) et ne doit
  /// pas être reconstruite côté client.
  Future<RestaurantTableLink> getTableLink(String id) async {
    final response = await _apiClient.get(
      'restaurant/tables/$id/link',
      requiresAuth: true,
    );
    return RestaurantTableLink.fromJson(_asMap(response));
  }
}
