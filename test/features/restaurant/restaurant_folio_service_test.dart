import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/features/restaurant/cubit/restaurant_orders_cubit.dart';
import 'package:wanzo/features/restaurant/models/restaurant_order.dart';
import 'package:wanzo/features/restaurant/repositories/restaurant_order_repository.dart';
import 'package:wanzo/features/restaurant/services/restaurant_folio_service.dart';
import 'package:wanzo/features/restaurant/services/restaurant_order_sync.dart';

/// Serveur factice de gestion : `GET reservations` (double enveloppe, comme
/// l'ApiResponseInterceptor), `POST reservations/:id/folio` et
/// `restaurant/orders`. Peut simuler l'absence de réseau (mise en file) ou un
/// refus du serveur.
class _GestionFactice implements ApiClient {
  List<Map<String, dynamic>> reservations = [];
  final List<({String endpoint, dynamic body})> envois = [];
  Map<String, String>? derniereRequete;
  bool horsLigne = false;
  bool refus = false;
  final Map<String, Map<String, dynamic>> commandes = {};

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool requiresAuth = false,
    bool bypassCircuitBreaker = false,
    bool includeBusinessContext = false,
  }) async {
    if (endpoint.startsWith('reservations')) {
      derniereRequete = queryParameters;
      return {
        'success': true,
        'data': {'success': true, 'data': reservations},
      };
    }
    return {'success': true, 'data': commandes.values.toList()};
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool requiresAuth = false,
    int? customTimeoutMs,
    bool bypassCircuitBreaker = false,
    bool queueOffline = true,
  }) async {
    if (endpoint.startsWith('reservations/')) {
      if (horsLigne) throw OfflineQueuedException(endpoint: endpoint);
      if (refus) {
        throw ApiExceptionFactory.fromStatusCode(
          400,
          'Ce séjour est déjà facturé ou annulé',
          endpoint: endpoint,
        );
      }
      envois.add((endpoint: endpoint, body: body));
      return {'success': true, 'data': {}};
    }
    commandes[(body as Map)['id'] as String] = Map<String, dynamic>.from(body);
    return body;
  }

  @override
  Future<dynamic> delete(
    String endpoint, {
    bool requiresAuth = false,
    bool bypassCircuitBreaker = false,
    bool queueOffline = true,
  }) async =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _resa(
  String id, {
  required String status,
  required DateTime start,
  required DateTime end,
  String? saleId,
  String spaceName = 'Chambre 12',
}) =>
    {
      'id': id,
      'spaceName': spaceName,
      'customerName': 'M. Kabila',
      'status': status,
      'startAt': start.toUtc().toIso8601String(),
      'endAt': end.toUtc().toIso8601String(),
      // Colonne decimal : arrive en texte.
      'totalAmount': '150.00',
      'currencyCode': 'USD',
      if (saleId != null) 'saleId': saleId,
    };

RestaurantOrder _commande() => RestaurantOrder(
      id: 'cmd-1',
      label: 'Table 4',
      status: RestaurantOrderStatus.served,
      createdAt: DateTime(2026, 10, 17, 12),
      lines: const [
        RestaurantOrderLine(
          productId: 'plat-1',
          productName: 'Poulet mayo',
          unitPriceCdf: 15000,
          quantity: 2,
          note: 'Bien cuit',
        ),
        RestaurantOrderLine(
          productId: 'prod-biere',
          productName: 'Primus',
          unitPriceCdf: 3500,
          quantity: 3,
          fromStock: true,
        ),
      ],
    );

void main() {
  final now = DateTime(2026, 10, 17, 14);

  group('reservationsFacturables', () {
    test('garde les réservations ouvertes, en cours d\'abord', () {
      final toutes = [
        _resa('confirmee-demain',
                status: 'confirmed',
                start: now.add(const Duration(days: 1)),
                end: now.add(const Duration(days: 2)))
            ,
        _resa('en-cours',
            status: 'inProgress',
            start: now.subtract(const Duration(days: 2)),
            end: now.add(const Duration(days: 1))),
        _resa('facturee',
            status: 'inProgress',
            start: now.subtract(const Duration(days: 2)),
            end: now.add(const Duration(days: 1)),
            saleId: 'vente-1'),
        _resa('annulee',
            status: 'cancelled',
            start: now,
            end: now.add(const Duration(days: 1))),
        _resa('trop-loin',
            status: 'confirmed',
            start: now.add(const Duration(days: 9)),
            end: now.add(const Duration(days: 10))),
        _resa('finie-hier',
            status: 'confirmed',
            start: now.subtract(const Duration(days: 3)),
            end: now.subtract(const Duration(days: 1))),
      ].map(FolioReservation.fromJson).toList();

      final ids = reservationsFacturables(toutes, now).map((r) => r.id);
      expect(ids, ['en-cours', 'confirmee-demain']);
    });
  });

  group('lignesDeFolio', () {
    test('prix en base CDF, productId seulement pour un article du stock', () {
      final lignes = lignesDeFolio(_commande());
      expect(lignes, hasLength(2));
      expect(lignes[0], {
        'label': 'Poulet mayo (Bien cuit)',
        'quantity': 2,
        'unitPriceCdf': 15000.0,
      });
      expect(lignes[1]['productId'], 'prod-biere',
          reason: 'la bouteille sortira du stock à la facturation du séjour');
      expect(lignes[1]['unitPriceCdf'], 3500.0);
    });
  });

  group('RestaurantFolioService', () {
    late _GestionFactice serveur;
    late RestaurantFolioService service;

    setUp(() {
      serveur = _GestionFactice();
      service = RestaurantFolioService(apiClient: serveur);
    });

    test('lit la liste malgré la double enveloppe et filtre', () async {
      serveur.reservations = [
        _resa('r1',
            status: 'inProgress',
            start: now.subtract(const Duration(days: 1)),
            end: now.add(const Duration(days: 1))),
        _resa('r2',
            status: 'invoiced',
            start: now.subtract(const Duration(days: 1)),
            end: now.add(const Duration(days: 1))),
      ];
      final liste = await service.reservationsOuvertes(now: now);
      expect(liste.map((r) => r.id), ['r1']);
      expect(liste.single.currencyCode, 'USD');
      expect(serveur.derniereRequete!.keys, containsAll(['from', 'to']));
    });

    test('envoie le folio avec sourceId (pas de double report)', () async {
      final ok = await service.reporterSurReservation('r1', _commande());
      expect(ok, isTrue);
      final envoi = serveur.envois.single;
      expect(envoi.endpoint, 'reservations/r1/folio');
      final body = envoi.body as Map;
      expect(body['source'], 'restaurant');
      expect(body['sourceId'], 'cmd-1');
      expect((body['items'] as List), hasLength(2));
    });

    test('hors ligne : mis en file, signalé comme différé', () async {
      serveur.horsLigne = true;
      final ok = await service.reporterSurReservation('r1', _commande());
      expect(ok, isFalse);
    });

    test('refus du serveur : l\'erreur remonte (jamais avalée)', () async {
      serveur.refus = true;
      expect(
        () => service.reporterSurReservation('r1', _commande()),
        throwsA(isA<ApiException>()),
      );
    });

    test('commande vide : refusée avant tout envoi', () async {
      final vide = RestaurantOrder(
        id: 'vide',
        label: 'Table 1',
        lines: const [],
        status: RestaurantOrderStatus.open,
        createdAt: now,
      );
      expect(() => service.reporterSurReservation('r1', vide),
          throwsArgumentError);
      expect(serveur.envois, isEmpty);
    });
  });

  group('RestaurantOrder', () {
    test('mode et date de règlement conservés au va-et-vient JSON', () {
      final reglee = _commande().copyWith(
        status: RestaurantOrderStatus.paid,
        paymentMethod: 'room',
        paidAt: DateTime(2026, 10, 17, 15),
      );
      final relue = RestaurantOrder.fromJson(reglee.toJson());
      expect(relue.paymentMethod, 'room');
      expect(relue.paidAt, DateTime(2026, 10, 17, 15));
      expect(relue, reglee);
    });

    test('montant decimal reçu en texte', () {
      final relue = RestaurantOrder.fromJson({
        'id': 'x',
        'label': 'Table 2',
        'status': 'paid',
        'createdAt': '2026-10-17T10:00:00.000Z',
        'paymentMethod': '',
        'lines': [
          {
            'productId': 'p',
            'productName': 'Liboke',
            'unitPriceCdf': '8000.00',
            'quantity': '2',
          },
        ],
      });
      expect(relue.totalCdf, 16000);
      expect(relue.paymentMethod, isNull);
    });
  });

  group('markPaid', () {
    late Directory dossier;
    late _GestionFactice serveur;
    late RestaurantOrdersCubit cubit;

    setUp(() async {
      dossier = await Directory.systemTemp.createTemp('folio_');
      Hive.init(dossier.path);
      serveur = _GestionFactice();
      cubit = RestaurantOrdersCubit(
        RestaurantOrderRepository(),
        sync: RestaurantOrderSync(apiClient: serveur),
      );
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await cubit.close();
      await Hive.close();
      try {
        await dossier.delete(recursive: true);
      } catch (_) {}
    });

    test('report sur réservation : réglée en mode room, partagée au serveur',
        () async {
      final c = await cubit.openOrder('Table 4', tableId: 't4');
      await cubit.addLine(c.id, _commande().lines.first);
      await cubit.markPaid(c.id, method: 'room');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final locale = cubit.state.byId(c.id)!;
      expect(locale.status, RestaurantOrderStatus.paid);
      expect(locale.paymentMethod, 'room');
      expect(locale.paidAt, isNotNull);
      expect(serveur.commandes[c.id]!['paymentMethod'], 'room');
      expect(serveur.commandes[c.id]!['status'], 'paid');

      // Un second règlement du même ticket est ignoré.
      await cubit.markPaid(c.id, method: 'cash');
      expect(cubit.state.byId(c.id)!.paymentMethod, 'room');
    });

    test('rattacher un client garde le mode de règlement', () async {
      final c = await cubit.openOrder('Emporter');
      await cubit.addLine(c.id, _commande().lines.first);
      await cubit.setCustomer(c.id, customerId: 'cli-1', customerName: 'Awa');
      final o = cubit.state.byId(c.id)!;
      expect(o.customerId, 'cli-1');
      expect(o.customerName, 'Awa');
    });
  });
}
