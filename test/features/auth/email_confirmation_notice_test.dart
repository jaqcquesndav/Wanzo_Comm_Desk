import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wanzo/features/auth/widgets/email_confirmation_notice.dart';

Widget _app(Widget child, Size size, double scale) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: ListView(padding: const EdgeInsets.all(24), children: [child])),
      ),
    );

/// Invitation en attente, email pas encore confirmé : message et « Vérifier »
/// lisibles sur 320 dp, police agrandie comprise.
void main() {
  const appareils = <String, Size>{
    'petit telephone 320dp': Size(320, 568),
    'telephone en paysage': Size(740, 360),
  };
  for (final appareil in appareils.entries) {
    for (final echelle in const [1.0, 1.3, 2.0]) {
      testWidgets('${appareil.key}, police x$echelle : sans débordement, Vérifier atteignable', (tester) async {
        tester.view.physicalSize = appareil.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        var verifie = 0;
        await tester.pumpWidget(_app(
          EmailConfirmationNotice(onVerify: () => verifie++, loadPending: () async => true),
          appareil.value,
          echelle,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(kConfirmEmailMessage), findsOneWidget);
        expect(find.text(kConfirmEmailHint), findsOneWidget);
        final bouton = find.byKey(const Key('email_confirmation_verify'));
        await tester.ensureVisible(bouton);
        await tester.pumpAndSettle();
        await tester.tap(bouton);
        expect(verifie, 1);
      });
    }
  }

  testWidgets('rien à confirmer selon le serveur : aucun message', (tester) async {
    await tester.pumpWidget(_app(EmailConfirmationNotice(onVerify: () {}, loadPending: () async => false), const Size(320, 568), 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('email_confirmation_notice')), findsNothing);
  });

  testWidgets('vérification en cours : bouton désactivé', (tester) async {
    await tester.pumpWidget(_app(EmailConfirmationNotice(verifying: true, onVerify: () {}, loadPending: () async => true), const Size(320, 568), 1));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('email_confirmation_verify'))).onPressed, isNull);
  });
}
