// Identifiants Hive : deux modèles ne peuvent pas partager un typeId, sinon
// l'écriture du second échoue (ou pire, se relit comme le premier).

import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/inventory/models/product_attribute.dart';
import 'package:wanzo/features/notifications/models/notification_model.dart';

void main() {
  test('ProductAttribute et NotificationModel ont des typeId distincts', () {
    expect(ProductAttributeAdapter().typeId, isNot(NotificationModelAdapter().typeId));
    expect(ProductAttributeAdapter().typeId, 120);
  });
}
