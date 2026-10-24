import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/widgets/desktop/desktop_header.dart';
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

/// En-tête desktop : lu depuis la droite, profil, notifications, Adha, menu
/// 3 points, puis au plus deux actions de la page.
void main() {
  testWidgets('ordre et sobriété de l\'en-tête desktop', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = _Auth();
    whenListen(auth, const Stream<AuthState>.empty(),
        initialState: const AuthUnauthenticated());
    final notif = _Notif();
    whenListen(notif, const Stream<NotificationsState>.empty(),
        initialState: NotificationsInitial());
    final settings = _Settings();
    whenListen(settings, const Stream<SettingsState>.empty(),
        initialState: const SettingsInitial());

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<SettingsBloc>.value(value: settings),
        BlocProvider<NotificationsBloc>.value(value: notif),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: DesktopHeader(
            title: 'Ventes',
            adha: IconButton(
              key: const ValueKey('adha'),
              tooltip: 'Adha IA',
              icon: const Icon(Icons.auto_awesome),
              onPressed: () {},
            ),
            actions: [
              for (final label in ['Filtrer', 'Factures proforma', 'Exporter'])
                IconButton(
                  tooltip: label,
                  icon: const Icon(Icons.star_border),
                  onPressed: () {},
                ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    double right(Finder f) => tester.getRect(f).right;
    final profile = right(find.byKey(const ValueKey('app-bar-profile')));
    final bell = right(find.byKey(const ValueKey('app-bar-notifications')));
    final adha = right(find.byKey(const ValueKey('adha')));
    final menu = right(find.byKey(const ValueKey('app-bar-overflow')));
    final second = right(find.byTooltip('Factures proforma'));
    final first = right(find.byTooltip('Filtrer'));
    expect(profile, greaterThan(bell));
    expect(bell, greaterThan(adha));
    expect(adha, greaterThan(menu));
    expect(menu, greaterThan(second));
    expect(second, greaterThan(first));

    // Deux actions de page au plus : la troisième passe dans le menu.
    expect(find.byTooltip('Exporter'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('app-bar-overflow')));
    await tester.pumpAndSettle();
    expect(find.text('Exporter'), findsOneWidget);
  });
}
