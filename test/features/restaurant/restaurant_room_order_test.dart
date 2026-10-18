import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/restaurant/models/restaurant_order.dart';
import 'package:wanzo/features/restaurant/services/restaurant_reservations_service.dart';

/// Commande « Réservation » (chambre ou salle) : type, rattachement, lieu,
/// lecture serveur.
void main() {
  RestaurantOrder commande({
    RestaurantOrderType type = RestaurantOrderType.reservation,
    String? reservationId = 'r1',
    String label = 'Chambre 12',
    String? kind = ReservationSpaceKind.room,
    String? tableId,
  }) =>
      RestaurantOrder(
        id: 'o1',
        label: label,
        lines: const [],
        status: RestaurantOrderStatus.open,
        createdAt: DateTime(2026, 10, 18, 12),
        type: type,
        tableId: tableId,
        reservationId: reservationId,
        spaceId: 's1',
        spaceKind: kind,
        customerName: 'Mme Kabila',
      );

  group('Modèle', () {
    test('libellé et valeur API du type réservation', () {
      expect(RestaurantOrderType.reservation.label, 'Réservation');
      expect(RestaurantOrderType.reservation.apiValue, 'reservation');
    });

    test('aller-retour JSON : type, réservation, espace et nature conservés', () {
      final relu =
          RestaurantOrder.fromJson(commande(kind: ReservationSpaceKind.hall).toJson());
      expect(relu.type, RestaurantOrderType.reservation);
      expect(relu.reservationId, 'r1');
      expect(relu.spaceId, 's1');
      expect(relu.isHall, isTrue);
      expect(relu.isOnReservation, isTrue);
    });

    test('sans réservation, une commande n\'est pas sur réservation', () {
      expect(commande(reservationId: null).isOnReservation, isFalse);
      expect(commande(type: RestaurantOrderType.dineIn).isOnReservation,
          isFalse);
    });

    test('lieu lisible : chambre, salle, table, à emporter', () {
      expect(commande().placeLabel, 'Chambre 12');
      expect(commande(label: '12').placeLabel, 'Chambre 12');
      expect(
          commande(label: 'Lualaba', kind: ReservationSpaceKind.hall)
              .placeLabel,
          'Salle Lualaba');
      expect(
          commande(
                  type: RestaurantOrderType.dineIn,
                  label: 'Table 4',
                  tableId: 't4')
              .placeLabel,
          'Table 4');
      expect(commande(type: RestaurantOrderType.takeaway).placeLabel,
          'À emporter');
    });

    test('ancienne commande sans champs : rien d\'inventé', () {
      final relu = RestaurantOrder.fromJson({
        'id': 'o2',
        'label': 'Table 4',
        'lines': const [],
        'status': 'open',
        'type': 'dineIn',
        'reservationId': '',
      });
      expect(relu.reservationId, isNull);
      expect(relu.type, RestaurantOrderType.dineIn);
    });
  });

  group('Réservations servables (serveur)', () {
    test('lit la double enveloppe, les chambres et les salles', () {
      final snap = RestaurantReservationsService.parse({
        'success': true,
        'data': {
          'success': true,
          'data': {
            'hasRooms': true,
            'hasHalls': true,
            'rooms': [
              {
                'reservationId': 'r1',
                'spaceId': 's1',
                'spaceName': 'Chambre 12',
                'customerName': 'Mme Kabila',
                'status': 'inProgress',
                'startAt': '2026-10-17T12:00:00Z',
                'endAt': '2026-10-19T10:00:00Z',
                'inProgress': true,
              },
              {'spaceName': 'sans réservation'},
            ],
            'halls': [
              {
                'reservationId': 'e1',
                'spaceId': 'h1',
                'spaceName': 'Salle Lualaba',
                'customerName': 'Banque X',
                'status': 'quote',
                'startAt': '2026-10-20T08:00:00Z',
                'endAt': '2026-10-20T17:00:00Z',
              },
            ],
          },
        },
      });
      expect(snap.hasAny, isTrue);
      expect(snap.rooms, hasLength(1));
      expect(snap.rooms.first.inProgress, isTrue);
      expect(snap.rooms.first.matches('kabila'), isTrue);
      expect(snap.halls.single.isHall, isTrue);
      expect(snap.halls.single.statusLabel, 'Devis');
    });

    test('établissement sans chambres ni salles', () {
      final snap = RestaurantReservationsService.parse(
          {'hasRooms': false, 'hasHalls': false, 'rooms': [], 'halls': []});
      expect(snap.hasAny, isFalse);
    });

    test('réponse illisible : rien de supposé', () {
      expect(RestaurantReservationsService.parse('oops').hasAny, isNull);
    });
  });
}
