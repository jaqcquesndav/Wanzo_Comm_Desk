import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/subscription/services/subscription_status_service.dart';

void main() {
  test("l'en-tete du jeton est reconnu quelle que soit sa casse", () {
    expect(SubscriptionStatusService.hasBearerToken({'authorization': 'Bearer abc'}), isTrue);
    expect(SubscriptionStatusService.hasBearerToken({'Authorization': 'Bearer abc'}), isTrue);
    expect(SubscriptionStatusService.hasBearerToken({'authorization': 'Bearer '}), isFalse);
    expect(SubscriptionStatusService.hasBearerToken({}), isFalse);
  });
}
