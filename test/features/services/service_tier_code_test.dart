import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/services/models/service_item.dart';

void main() {
  test('code de palier limite a 30 caracteres, comme sa colonne', () {
    final code = ServicePriceTier.codeFromLabel(
        'Lavage complet interieur et exterieur avec cire premium');
    expect(code.length, lessThanOrEqualTo(30));
    expect(code.endsWith('_'), isFalse);
    final doublon = ServicePriceTier.clampCode(code, '_2');
    expect(doublon.length, lessThanOrEqualTo(30));
    expect(doublon.endsWith('_2'), isTrue);
    final tier = ServicePriceTier(code: 'x' * 45, label: 'X', priceCdf: 1);
    expect((tier.toJson()['code'] as String).length, 30);
    expect(ServicePriceTier.codeFromLabel('Premium +'), 'premium');
  });
}
