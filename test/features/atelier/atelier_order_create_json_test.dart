import 'package:flutter_test/flutter_test.dart';

import 'package:wanzo/features/atelier/models/atelier_order.dart';

void main() {
  group('AtelierOrder.toCreateJson', () {
    test('transmet le nom et le téléphone du client (DTO atelier)', () {
      const order = AtelierOrder(
        id: '',
        customerId: '0b1c2d3e-0000-4000-8000-000000000001',
        customerName: ' Jean Mukendi ',
        customerPhone: '+243 990 000 002',
        label: 'Costume trois pièces',
      );
      final json = order.toCreateJson();
      expect(json['customerName'], 'Jean Mukendi');
      expect(json['customerPhone'], '+243 990 000 002');
    });

    test('jamais de chaîne vide pour le nom ou le téléphone', () {
      const order = AtelierOrder(
        id: '',
        customerId: '0b1c2d3e-0000-4000-8000-000000000001',
        customerName: '',
        label: 'Ourlet',
      );
      final json = order.toCreateJson();
      expect(json.containsKey('customerName'), isFalse);
      expect(json.containsKey('customerPhone'), isFalse);
    });

    test('le téléphone se relit depuis la relation client', () {
      final o = AtelierOrder.fromJson({
        'id': 'o1',
        'customerId': 'c1',
        'label': 'Robe',
        'customer': {'fullName': 'Aline', 'phoneNumber': '+243 811 000 000'},
      });
      expect(o.customerName, 'Aline');
      expect(o.customerPhone, '+243 811 000 000');
      // Aller-retour du cache local.
      expect(AtelierOrder.fromJson(o.toJson()).customerPhone, '+243 811 000 000');
    });
  });
}
