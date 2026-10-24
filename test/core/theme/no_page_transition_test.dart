import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/utils/theme.dart';

/// Desktop : une page s'ouvre d'un coup, sans zoom, fondu ni glissement.
void main() {
  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
          '${platform.name} ${dark ? 'sombre' : 'clair'} : '
          'page entièrement affichée dès la première image', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final navKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(MaterialApp(
          navigatorKey: navKey,
          theme: dark ? WanzoTheme.darkTheme : WanzoTheme.lightTheme,
          home: const Scaffold(body: Text('Accueil')),
        ));

        navKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('Page B'))),
        ));
        // Aucun temps écoulé : la première image (route hors scène le temps
        // de la mesure des Hero), puis celle où la page est posée.
        await tester.pump();
        await tester.pump();

        final page = find.text('Page B');
        expect(page, findsOneWidget);
        final firstFrame = tester.getRect(page);

        // Aucune animation d'apparition autour de la page.
        for (final type in [
          FadeTransition,
          ScaleTransition,
          SlideTransition,
        ]) {
          expect(
            find.ancestor(of: page, matching: find.byType(type)),
            findsNothing,
            reason: '$type autour de la page',
          );
        }

        await tester.pumpAndSettle();
        expect(tester.getRect(page), firstFrame);
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
}
