import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/core/shared_widgets/wanzo_app_bar.dart';
import 'package:wanzo/features/auth/bloc/auth_bloc.dart';
import 'package:wanzo/features/notifications/bloc/notifications_bloc.dart';
import 'package:wanzo/features/settings/bloc/settings_bloc.dart';
import 'package:wanzo/features/settings/bloc/settings_event.dart';
import 'package:wanzo/features/settings/bloc/settings_state.dart';

class _Auth extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class _Settings extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _Notif extends MockBloc<NotificationsEvent, NotificationsState>
    implements NotificationsBloc {}

const _pageActions = ['Rechercher', 'Filtrer', 'Exporter'];

const _profile = ValueKey('app-bar-profile');
const _notifications = ValueKey('app-bar-notifications');
const _adha = ValueKey('app-bar-adha');
const _overflow = ValueKey('app-bar-overflow');

/// En-tête étroit (fenêtre réduite) : lu depuis la droite, profil,
/// 3 points, puis au plus deux actions de la page. À 320 et 360 dp, police
/// x1, x1,3 et x2, rien ne déborde : ce qui ne tient plus passe dans le menu
/// 3 points, dans le même ordre, et le profil reste visible.
void main() {
  Widget app(double scale, {bool back = false}) {
    final auth = _Auth();
    whenListen(auth, const Stream<AuthState>.empty(),
        initialState: const AuthUnauthenticated());
    final notif = _Notif();
    whenListen(notif, const Stream<NotificationsState>.empty(),
        initialState: NotificationsInitial());
    final settings = _Settings();
    whenListen(settings, const Stream<SettingsState>.empty(),
        initialState: const SettingsInitial());
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          appBar: WanzoAppBar(
            title: 'Inventaire des articles du siège social',
            onBackPressed: back ? () {} : null,
            additionalActions: [
              for (final label in _pageActions)
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.star_border),
                  tooltip: label,
                ),
            ],
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    ]);
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<SettingsBloc>.value(value: settings),
        BlocProvider<NotificationsBloc>.value(value: notif),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    );
  }

  double rightOf(WidgetTester tester, Finder f) => tester.getRect(f).right;

  testWidgets('ordre depuis la droite : profil, notifications, Adha, menu, '
      'puis deux actions de page', (tester) async {
    tester.view.physicalSize = const Size(800, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(1.0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final profile = rightOf(tester, find.byKey(_profile));
    final notif = rightOf(tester, find.byKey(_notifications));
    final adha = rightOf(tester, find.byKey(_adha));
    final menu = rightOf(tester, find.byKey(_overflow));
    final second = rightOf(tester, find.byTooltip('Filtrer'));
    final first = rightOf(tester, find.byTooltip('Rechercher'));
    expect(profile, greaterThan(notif));
    expect(notif, greaterThan(adha));
    expect(adha, greaterThan(menu));
    expect(menu, greaterThan(second));
    expect(second, greaterThan(first));

    // Au plus deux actions de page visibles : la troisième est dans le menu.
    expect(find.byTooltip('Exporter'), findsNothing);
    await tester.tap(find.byKey(_overflow));
    await tester.pumpAndSettle();
    expect(find.text('Exporter'), findsOneWidget);
  });

  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final back in [false, true]) {
        testWidgets(
            'barre à $width dp, police x$scale${back ? ', retour' : ''}',
            (tester) async {
          tester.view.physicalSize = Size(width, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(app(scale, back: back));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Le profil reste toujours affiché, tout à droite.
          expect(find.byKey(_profile), findsOneWidget);
          final profileRight = rightOf(tester, find.byKey(_profile));
          for (final key in [_notifications, _adha, _overflow]) {
            final f = find.byKey(key);
            if (f.evaluate().isNotEmpty) {
              expect(rightOf(tester, f), lessThan(profileRight));
            }
          }

          final notifVisible = find.byKey(_notifications).evaluate().isNotEmpty;
          final adhaVisible = find.byKey(_adha).evaluate().isNotEmpty;
          final visiblePage = [
            for (final l in _pageActions)
              if (find.byTooltip(l).evaluate().isNotEmpty) l,
          ];
          expect(visiblePage.length, lessThanOrEqualTo(2));
          // Ordre de priorité : rien n'est masqué avant ce qui le précède.
          if (!notifVisible) expect(adhaVisible, isFalse);
          if (!adhaVisible) expect(visiblePage, isEmpty);

          await tester.tap(find.byKey(_overflow));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final hidden = [
            if (!notifVisible) 'Notifications',
            if (!adhaVisible) 'Adha IA',
            for (final l in _pageActions)
              if (!visiblePage.contains(l)) l,
          ];
          for (final label in hidden) {
            expect(find.text(label), findsOneWidget, reason: label);
          }
          // Même ordre dans le menu, de haut en bas.
          for (var i = 1; i < hidden.length; i++) {
            expect(
              tester.getTopLeft(find.text(hidden[i - 1])).dy,
              lessThan(tester.getTopLeft(find.text(hidden[i])).dy),
            );
          }
        });
      }
    }
  }
}
