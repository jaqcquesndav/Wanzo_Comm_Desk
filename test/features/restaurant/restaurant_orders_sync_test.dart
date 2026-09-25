import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/features/restaurant/cubit/restaurant_orders_cubit.dart';
import 'package:wanzo/features/restaurant/models/restaurant_order.dart';
import 'package:wanzo/features/restaurant/repositories/restaurant_order_repository.dart';
import 'package:wanzo/features/restaurant/services/restaurant_order_sync.dart';

/// Serveur factice de `restaurant/orders`. Il garde la DERNIÈRE commande reçue
/// (comme le vrai), et peut ralentir un envoi pour reproduire un désordre
/// d'arrivée.
class _ServeurFactice implements ApiClient {
  final Map<String, Map<String, dynamic>> commandes = {};
  int envoisSimultanesMax = 0;
  int _envoisEnCours = 0;
  Duration latence = Duration.zero;

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool requiresAuth = false,
    bool bypassCircuitBreaker = false,
    bool includeBusinessContext = false,
  }) async {
    final toutes = endpoint.contains('activeOnly=false');
    return commandes.values
        .where((c) =>
            toutes || ['open', 'sent', 'served'].contains(c['status']))
        .map((c) => {...c, 'createdAt': c['openedAt']})
        .toList();
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool requiresAuth = false,
    int? customTimeoutMs,
    bool bypassCircuitBreaker = false,
  }) async {
    _envoisEnCours++;
    if (_envoisEnCours > envoisSimultanesMax) {
      envoisSimultanesMax = _envoisEnCours;
    }
    // Le premier envoi d'une commande est le plus lent : sans ordre imposé,
    // c'est lui qui arriverait en dernier.
    final lent = !commandes.containsKey((body as Map)['id']);
    await Future<void>.delayed(lent ? latence * 3 : latence);
    commandes[body['id'] as String] = Map<String, dynamic>.from(body);
    _envoisEnCours--;
    return body;
  }

  @override
  Future<dynamic> delete(
    String endpoint, {
    bool requiresAuth = false,
    bool bypassCircuitBreaker = false,
  }) async {
    commandes.remove(endpoint.split('/').last);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _poulet = RestaurantOrderLine(
    productId: 'p1', productName: 'Poulet', unitPriceCdf: 8000, quantity: 1);
const _liboke = RestaurantOrderLine(
    productId: 'p2', productName: 'Liboke', unitPriceCdf: 9000, quantity: 2);

Future<void> _laisserPartir() =>
    Future<void>.delayed(const Duration(milliseconds: 200));

void main() {
  late Directory dossier;
  late _ServeurFactice serveur;
  late RestaurantOrdersCubit cubit;

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('commandes_');
    Hive.init(dossier.path);
    serveur = _ServeurFactice();
    cubit = RestaurantOrdersCubit(
      RestaurantOrderRepository(),
      sync: RestaurantOrderSync(apiClient: serveur),
    );
  });

  tearDown(() async {
    // Laisser finir les envois et écritures lancés sans attente par le cubit,
    // sinon Windows refuse de supprimer un fichier encore ouvert.
    await _laisserPartir();
    await cubit.close();
    await Hive.close();
    try {
      await dossier.delete(recursive: true);
    } catch (_) {
      // Dossier temporaire : le système le nettoiera.
    }
  });

  test('les plats saisis vite ne sont pas écrasés par un envoi plus ancien',
      () async {
    serveur.latence = const Duration(milliseconds: 20);
    final commande = await cubit.openOrder('Table 4', tableId: 't4');
    await cubit.addLine(commande.id, _poulet);
    await cubit.addLine(commande.id, _liboke);
    await _laisserPartir();

    expect(serveur.envoisSimultanesMax, 1,
        reason: 'une commande ne doit jamais avoir deux envois en vol');
    final lignes = serveur.commandes[commande.id]!['lines'] as List;
    expect(lignes.length, 2, reason: 'le serveur doit garder la version finale');
  });

  test('une commande ouverte sans aucun plat n\'est pas partagée', () async {
    await cubit.openOrder('Table 2', tableId: 't2');
    await _laisserPartir();
    expect(serveur.commandes, isEmpty);
  });

  test('le chargement n\'écrase pas une commande pas encore confirmée',
      () async {
    final commande = await cubit.openOrder('Table 4', tableId: 't4');
    await cubit.addLine(commande.id, _poulet);
    await _laisserPartir();

    // Le serveur ne tient qu'une copie ancienne, sans plat.
    serveur.commandes[commande.id] = {
      ...serveur.commandes[commande.id]!,
      'lines': <dynamic>[],
    };
    // Une modification locale part... mais le réseau ne répond plus.
    final repo = RestaurantOrderRepository();
    await repo.marquerEnAttente(commande.id);

    await cubit.load();
    expect(cubit.state.byId(commande.id)!.itemCount, 1);
  });

  test('une commande réglée sur un autre poste libère la table ici', () async {
    final commande = await cubit.openOrder('Table 4', tableId: 't4');
    await cubit.addLine(commande.id, _poulet);
    await _laisserPartir();

    // Un autre poste l'encaisse.
    serveur.commandes[commande.id] = {
      ...serveur.commandes[commande.id]!,
      'status': 'paid',
    };

    await cubit.load();
    expect(cubit.state.active.map((o) => o.id), isNot(contains(commande.id)));
  });

  test('une commande ouverte ailleurs apparaît au chargement', () async {
    serveur.commandes['autre'] = {
      'id': 'autre',
      'label': 'Table 7',
      'tableId': 't7',
      'lines': [_poulet.toJson()],
      'status': 'open',
      'type': 'dineIn',
      'openedAt': DateTime.now().toIso8601String(),
    };
    await cubit.load();
    final c = cubit.state.byId('autre');
    expect(c, isNotNull);
    expect(c!.itemCount, 1);
  });

  test('une commande vide abandonnée est retirée', () async {
    final repo = RestaurantOrderRepository();
    await repo.save(RestaurantOrder(
      id: 'vide',
      label: 'Table 9',
      lines: const [],
      status: RestaurantOrderStatus.open,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      tableId: 't9',
    ));
    await cubit.load();
    expect(cubit.state.byId('vide'), isNull);
  });
}
