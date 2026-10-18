import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/services/company_scope_guard.dart';
import 'package:wanzo/features/auth/screens/sync_pending_screen.dart';
import 'package:wanzo/features/subscription/widgets/subscription_banner_overlay.dart'
    show MembershipSuspendedScreen;
import 'package:wanzo/features/auth/bloc/auth_bloc.dart';
import 'package:wanzo/features/auth/models/join_request.dart';
import 'package:wanzo/features/auth/models/user.dart';
import 'package:wanzo/features/auth/repositories/auth_repository.dart';
import 'package:wanzo/features/auth/services/auth_backend_service.dart';

/// Compte retiré de son entreprise : jamais le tableau de bord, l'écran pour
/// rejoindre une entreprise ; purge des données de l'ancienne entreprise,
/// souvenir gardé hors ligne ; « Vérifier » relit aussi /auth/me.

const _user = User(
  id: 'u1',
  name: 'Amani Kabila',
  email: 'amani@example.com',
  phone: '',
  role: 'user',
  emailVerified: true,
  phoneVerified: false,
);

/// Réponse d'un service qui renvoie le compte sans entreprise, sans
/// « synchronisation en cours » (ancien chemin : tableau de bord ouvert).
final _revokedMe = AuthMeResponse.fromJson({
  'user': {
    'id': 'u1',
    'email': 'amani@example.com',
    'role': 'user',
    'companyId': null,
    'revokedFromCompanyId': 'c1',
    'membershipRevokedAt': '2026-10-18T10:00:00Z',
  },
  'company': null,
  'businessUnit': null,
});

final _noCompanyMe = AuthMeResponse.fromJson({
  'user': {'id': 'u1', 'email': 'amani@example.com', 'role': 'user'},
  'company': null,
});

final _completeMe = AuthMeResponse.fromJson({
  'user': {
    'id': 'u1',
    'email': 'amani@example.com',
    'role': 'user',
    'companyId': 'c2',
    'businessUnitId': 'b1',
  },
  'company': {'id': 'c2', 'name': 'Nouvelle'},
});

const _pending = JoinRequest(
  id: 'r1',
  status: JoinRequestStatus.pending,
  companyName: 'Nouvelle',
  businessUnitName: 'Agence Gombe',
  businessUnitCode: 'BRN-GOMBE',
);

class _Depot implements AuthRepository {
  AuthMeResponse? me;
  AuthMeResponse? meAfterRefresh;
  JoinRequest? mine;
  int refreshCalls = 0;

  @override
  Future<bool> isLoggedIn() async => true;

  @override
  Future<User?> getCurrentUser() async => _user;

  @override
  Future<User?> getLastKnownUser() async => _user;

  @override
  AuthMeResponse? getLastAuthMeResponse() => me;

  @override
  Future<User?> refreshUserProfile() async {
    refreshCalls++;
    me = meAfterRefresh;
    return _user;
  }

  @override
  Future<JoinRequest?> fetchMyJoinRequest() async => mine;

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  widgetTests();

  test('AuthMeResponse : sans entreprise et retrait lus', () {
    expect(_revokedMe.hasNoCompany, isTrue);
    expect(_revokedMe.wasRevoked, isTrue);
    expect(_revokedMe.revokedFromCompanyId, 'c1');
    expect(_revokedMe.membershipRevokedAt, isNotNull);
    expect(_noCompanyMe.hasNoCompany, isTrue);
    expect(_noCompanyMe.wasRevoked, isFalse);
    expect(_completeMe.hasNoCompany, isFalse);
  });

  group('compte retiré', () {
    late _Depot depot;
    late MemoryCompanyScopeStore store;
    late int purges;
    late CompanyScopeGuard guard;

    setUp(() {
      depot = _Depot();
      purges = 0;
      // Dernière session connue : membre de c1.
      store = MemoryCompanyScopeStore(
        const CompanyScopeSnapshot(userId: 'u1', companyId: 'c1'),
      );
      guard = CompanyScopeGuard(purge: () async => purges++, store: store);
    });

    blocTest<AuthBloc, AuthState>(
      'en ligne : écran pour rejoindre (message de retrait), données purgées',
      build: () {
        depot.me = _revokedMe;
        return AuthBloc(
          authRepository: depot,
          isOnline: () => true,
          scopeGuard: guard,
        );
      },
      act: (b) => b.add(const AuthCheckRequested()),
      expect: () => [
        const AuthLoading(),
        isA<AuthSyncPending>().having((s) => s.revoked, 'retiré', true),
      ],
      verify: (_) {
        expect(purges, 1);
        expect(store.snapshot!.hasCompany, isFalse);
        expect(store.snapshot!.revokedFromCompanyId, 'c1');
      },
    );

    blocTest<AuthBloc, AuthState>(
      'sans entreprise ni retrait : écran pour rejoindre, sans message de retrait',
      build: () {
        depot.me = _noCompanyMe;
        return AuthBloc(
          authRepository: depot,
          isOnline: () => true,
          scopeGuard: guard,
        );
      },
      act: (b) => b.add(const AuthCheckRequested()),
      expect: () => [
        const AuthLoading(),
        isA<AuthSyncPending>().having((s) => s.revoked, 'retiré', false),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'hors ligne après un retrait : l\'ancienne session ne se rouvre pas',
      build: () {
        store.snapshot = const CompanyScopeSnapshot(
          userId: 'u1',
          revokedFromCompanyId: 'c1',
        );
        // Aucune réponse du serveur : la relecture échoue (hors ligne).
        depot.me = null;
        depot.meAfterRefresh = null;
        return AuthBloc(
          authRepository: depot,
          isOnline: () => false,
          scopeGuard: guard,
        );
      },
      act: (b) => b.add(const AuthCheckRequested()),
      expect: () => [
        const AuthLoading(),
        isA<AuthSyncPending>().having((s) => s.revoked, 'retiré', true),
      ],
      verify: (_) => expect(purges, 0),
    );

    blocTest<AuthBloc, AuthState>(
      'hors ligne, membre connu : la session en cache s\'ouvre',
      build: () {
        depot.me = null;
        depot.meAfterRefresh = null;
        return AuthBloc(
          authRepository: depot,
          isOnline: () => false,
          scopeGuard: guard,
        );
      },
      act: (b) => b.add(const AuthCheckRequested()),
      expect: () => [const AuthLoading(), const AuthAuthenticated(_user)],
    );
  });

  group('Vérifier : /auth/me relu même si la demande est en attente', () {
    late _Depot depot;
    late CompanyScopeGuard guard;

    setUp(() {
      depot = _Depot()
        ..me = _noCompanyMe
        ..mine = _pending;
      guard = CompanyScopeGuard(
        purge: () async {},
        store: MemoryCompanyScopeStore(),
      );
    });

    blocTest<AuthBloc, AuthState>(
      'ajouté directement par l\'administrateur : entrée',
      build: () {
        depot.meAfterRefresh = _completeMe;
        return AuthBloc(authRepository: depot, scopeGuard: guard);
      },
      seed: () => const AuthJoinRequestState(_user, _pending),
      act: (b) => b.add(const AuthJoinRequestCheckRequested()),
      expect: () => [
        isA<AuthJoinRequestState>().having((s) => s.busy, 'occupé', true),
        const AuthAuthenticated(_user),
      ],
      verify: (_) => expect(depot.refreshCalls, 1),
    );

    blocTest<AuthBloc, AuthState>(
      'toujours sans entreprise : l\'écran d\'attente reste',
      build: () {
        depot.meAfterRefresh = _noCompanyMe;
        return AuthBloc(authRepository: depot, scopeGuard: guard);
      },
      seed: () => const AuthJoinRequestState(_user, _pending),
      act: (b) => b.add(const AuthJoinRequestCheckRequested()),
      expect: () => [
        isA<AuthJoinRequestState>().having((s) => s.busy, 'occupé', true),
        isA<AuthJoinRequestState>()
            .having((s) => s.request.isPending, 'en attente', true)
            .having((s) => s.busy, 'occupé', false),
      ],
    );
  });
}

class _AuthBlocFactice extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

Widget _app(AuthBloc bloc, Widget child) => MaterialApp(
  home: BlocProvider<AuthBloc>.value(value: bloc, child: child),
);

void widgetTests() {
  testWidgets('écran sans entreprise : message de retrait et saisie du code', (
    tester,
  ) async {
    final bloc = _AuthBlocFactice();
    whenListen(
      bloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthSyncPending(_user, revoked: true),
    );
    await tester.pumpWidget(
      _app(bloc, const SyncPendingScreen(autoRetryDelays: [])),
    );
    expect(find.text(kRevokedFromCompanyMessage), findsOneWidget);
    expect(find.text('Ouvrir Wanzo Land'), findsOneWidget);
    expect(find.byKey(const Key('join_code_field')), findsOneWidget);
    expect(find.text('Configuration en cours'), findsNothing);
  });

  testWidgets('accès suspendu : titre, message, consigne et déconnexion', (
    tester,
  ) async {
    var logout = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MembershipSuspendedScreen(
          message: 'Accès suspendu par votre administrateur.',
          onLogout: () => logout++,
          onRetry: () {},
        ),
      ),
    );
    expect(find.text('Accès suspendu'), findsOneWidget);
    expect(find.text('Accès suspendu par votre administrateur.'), findsOneWidget);
    expect(
      find.text("Contactez l'administrateur de votre entreprise."),
      findsOneWidget,
    );
    await tester.tap(find.text('Se déconnecter'));
    expect(logout, 1);
  });
}
