import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/services/reauth_service.dart';

void main() {
  late DateTime now;
  late ReauthPolicy policy;

  setUp(() {
    now = DateTime(2026, 10, 25, 9);
    policy = ReauthPolicy(clock: () => now);
  });

  test('un 401 declenche un renouvellement, sans attente la premiere fois', () {
    expect(policy.onUnauthorized(), ReauthDecision.refresh);
    expect(policy.nextDelay(), Duration.zero);
  });

  test('401 juste apres un renouvellement reussi : retour a la connexion', () {
    policy.recordAttempt();
    policy.recordSuccess();
    now = now.add(const Duration(seconds: 5));
    expect(policy.onUnauthorized(), ReauthDecision.login);
    // Plus tard, un jeton simplement expire se renouvelle de nouveau.
    now = now.add(const Duration(minutes: 2));
    expect(policy.onUnauthorized(), ReauthDecision.refresh);
  });

  test('attente croissante entre renouvellements successifs, plafonnee', () {
    final delays = <Duration>[];
    for (var i = 0; i < 8; i++) {
      delays.add(policy.nextDelay());
      policy.recordAttempt();
      now = now.add(const Duration(seconds: 40));
    }
    expect(delays.take(4).map((d) => d.inSeconds), [0, 1, 2, 4]);
    expect(delays.last, const Duration(seconds: 30));
    // Calme prolonge : l'attente repart de zero.
    now = now.add(const Duration(minutes: 10));
    expect(policy.nextDelay(), Duration.zero);
  });

  test('reset apres retour a la connexion', () {
    policy.recordAttempt();
    policy.recordSuccess();
    policy.reset();
    expect(policy.onUnauthorized(), ReauthDecision.refresh);
    expect(policy.nextDelay(), Duration.zero);
  });
}
