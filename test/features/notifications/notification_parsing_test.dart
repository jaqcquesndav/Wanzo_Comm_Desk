// Notifications du serveur : double enveloppe gestion et champs camelCase.

import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/notifications/models/notification_model.dart';
import 'package:wanzo/features/notifications/repositories/notification_repository.dart';
import 'package:wanzo/features/notifications/utils/notification_router.dart';

void main() {
  test('la liste est lue sous la double enveloppe', () {
    final response = {
      'success': true,
      'message': 'ok',
      'data': {
        'data': [
          {'id': 'n1'},
          {'id': 'n2'},
        ],
        'total': 2,
        'page': 1,
        'limit': 10,
      },
    };
    expect(NotificationRepository.extractNotificationList(response), hasLength(2));
    expect(
      NotificationRepository.extractNotificationList({'data': [{'id': 'x'}]}),
      hasLength(1),
    );
    expect(NotificationRepository.extractNotificationList(null), isEmpty);
  });

  test('readAt, actionRoute et additionalData de l entite sont lus', () {
    final lue = NotificationRepository.parseApiNotification({
      'id': 'n1',
      'title': 'Vente',
      'message': 'Vente enregistree',
      'type': 'sale',
      'timestamp': '2026-10-01T10:00:00.000Z',
      'readAt': '2026-10-01T12:00:00.000Z',
      'actionRoute': '/sales/abc',
      'additionalData': {'entityType': 'sale', 'entityId': 'abc'},
    });
    expect(lue.isRead, isTrue);
    expect(lue.type, NotificationType.sale);
    expect(lue.actionRoute, '/sales/abc');
    expect(lue.additionalData, contains('"entityId":"abc"'));

    final nonLue = NotificationRepository.parseApiNotification({
      'id': 'n2',
      'title': 'Stock',
      'message': 'Stock bas',
      'type': 'lowStock',
      'timestamp': '2026-10-01T10:00:00.000Z',
      'readAt': null,
    });
    expect(nonLue.isRead, isFalse);
    expect(nonLue.type, NotificationType.lowStock);
  });

  test('les anciennes routes menent a des ecrans qui existent', () {
    expect(NotificationRouter.normalizeRoute('/products/42'), '/inventory/product/42');
    expect(NotificationRouter.normalizeRoute('/payments/7'), '/operations');
    expect(NotificationRouter.normalizeRoute('/sales/9'), '/sales/9');
    expect(
      NotificationRouter.normalizeRoute('/inventory?filter=expired'),
      '/inventory?filter=expired',
    );
  });
}
