import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/features/auth/bloc/auth_bloc.dart';
import 'package:wanzo/features/auth/models/join_request.dart';
import 'package:wanzo/features/auth/models/user.dart';
import 'package:wanzo/features/auth/repositories/auth_repository.dart';
import 'package:wanzo/features/auth/services/auth_backend_service.dart';

/// Reprise de session sur le poste, demande de rattachement par code et
/// relecture de /auth/me (parité avec le mobile).

const _cached = User(
  id: 'u1',
  name: 'Amani Kabila',
  email: 'amani@example.com',
  phone: '',
  role: 'user',
  emailVerified: true,
  phoneVerified: false,
);

final _syncPendingMe = AuthMeResponse.fromJson({
  'user': {'id': 'u1', 'email': 'amani@example.com', 'role': 'user', 'companyId': null},
  'company': null,
  'businessUnit': null,
  'syncStatus': {'pending': true, 'message': 'Synchronisation'},
});

final _completeMe = AuthMeResponse.fromJson({
  'user': {
    'id': 'u1',
    'email': 'amani@example.com',
    'role': 'user',
    'companyId': 'c1',
    'businessUnitId': 'b1',
  },
  'company': {'id': 'c1', 'name': 'Acme'},
});

const _pending = JoinRequest(
  id: 'r1',
  status: JoinRequestStatus.pending,
  companyName: 'Acme',
  businessUnitName: 'Agence Gombe',
  businessUnitCode: 'BRN-GOMBE',
);

/// Dépôt factice : la relecture de /auth/me renseigne [me] comme le vrai
/// Auth0Service renseigne lastAuthMeResponse.
class _Depot implements AuthRepository {
  bool loggedIn = true;
  AuthMeResponse? me;
  AuthMeResponse? meAfterRefresh;
  Object? refreshError;
  JoinBusinessUnitResponse? joinResponse;
  JoinRequest? mine;
  int logoutCalls = 0;
  int refreshCalls = 0;

  @override
  Future<bool> isLoggedIn() async => loggedIn;

  @override
  Future<User?> getCurrentUser() async => _cached;

  @override
  Future<User?> getLastKnownUser() async => _cached;

  @override
  AuthMeResponse? getLastAuthMeResponse() => me;

  @override
  Future<User?> refreshUserProfile() async {
    refreshCalls++;
    if (refreshError != null) throw refreshError!;
    me = meAfterRefresh;
    return _cached;
  }

  @override
  Future<JoinBusinessUnitResponse> joinBusinessUnit(String code) async =>
      joinResponse!;

  @override
  Future<JoinRequest?> fetchMyJoinRequest() async => mine;

  @override
  Future<void> logout() async => logoutCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Client HTTP factice : renvoie la réponse POST réglée.
class _Api implements ApiClient {
  dynamic postResponse;
  String? lastEndpoint;
  dynamic lastBody;
  bool? lastQueueOffline;

  @override
  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool requiresAuth = false,
    int? customTimeoutMs,
    bool bypassCircuitBreaker = false,
    bool queueOffline = true,
  }) async {
    lastEndpoint = endpoint;
    lastBody = body;
    lastQueueOffline = queueOffline;
    return postResponse;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('reprise de session (poste)', () {
    late _Depot depot;
    setUp(() => depot = _Depot());

    blocTest<AuthBloc, AuthState>(
      'cache puis /auth/me : demande en attente, l écran d attente s ouvre',
      build: () {
        depot
          ..meAfterRefresh = _syncPendingMe
          ..mine = _pending;
        return AuthBloc(authRepository: depot, isOnline: () => true);
      },
      act: (b) => b.add(const AuthCheckRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthAuthenticated(_cached),
        isA<AuthJoinRequestState>()
            .having((s) => s.request.isPending, 'en attente', true),
      ],
      verify: (_) => expect(depot.refreshCalls, 1),
    );

    blocTest<AuthBloc, AuthState>(
      'compte complet : une seule relecture, accès normal',
      build: () {
        depot.meAfterRefresh = _completeMe;
        return AuthBloc(authRepository: depot, isOnline: () => true);
      },
      act: (b) => b.add(const AuthCheckRequested()),
      expect: () => [const AuthLoading(), const AuthAuthenticated(_cached)],
    );

    blocTest<AuthBloc, AuthState>(
      '401 en ligne : déconnexion',
      build: () {
        depot.refreshError = AuthenticationException('Unauthorized');
        return AuthBloc(authRepository: depot, isOnline: () => true);
      },
      act: (b) => b.add(const AuthCheckRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthAuthenticated(_cached),
        const AuthUnauthenticated(),
      ],
      verify: (_) => expect(depot.logoutCalls, 1),
    );

    blocTest<AuthBloc, AuthState>(
      'hors ligne : la session en cache est gardée',
      build: () {
        depot.refreshError = AuthenticationException('Unauthorized');
        return AuthBloc(authRepository: depot, isOnline: () => false);
      },
      act: (b) => b.add(const AuthCheckRequested()),
      expect: () => [const AuthLoading(), const AuthAuthenticated(_cached)],
      verify: (_) => expect(depot.logoutCalls, 0),
    );

    blocTest<AuthBloc, AuthState>(
      'réseau coupé : pas de déconnexion',
      build: () {
        depot.refreshError = NetworkException('down');
        return AuthBloc(authRepository: depot, isOnline: () => true);
      },
      act: (b) => b.add(const AuthCheckRequested()),
      expect: () => [const AuthLoading(), const AuthAuthenticated(_cached)],
      verify: (_) => expect(depot.logoutCalls, 0),
    );
  });

  group('rattachement par code (bloc)', () {
    late _Depot depot;
    setUp(() => depot = _Depot()..me = _syncPendingMe);

    blocTest<AuthBloc, AuthState>(
      '200 joined : relecture de /auth/me puis entrée',
      build: () {
        depot
          ..meAfterRefresh = _completeMe
          ..joinResponse = JoinBusinessUnitResponse.fromJson({
            'status': 'joined',
            'businessUnitId': 'b1',
            'businessUnitCode': 'BRN-GOMBE',
            'businessUnitName': 'Agence Gombe',
          });
        return AuthBloc(authRepository: depot);
      },
      seed: () => const AuthBusinessUnitRequired(_cached),
      act: (b) => b.add(
        const AuthJoinBusinessUnitRequested(businessUnitCode: 'BRN-GOMBE'),
      ),
      expect: () => [
        const AuthJoinBusinessUnitInProgress(),
        const AuthAuthenticated(_cached),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      '200 mais session refusée à la relecture : déconnexion',
      build: () {
        depot
          ..refreshError = AuthenticationException('Unauthorized')
          ..joinResponse = JoinBusinessUnitResponse.fromJson({'status': 'joined'});
        return AuthBloc(authRepository: depot);
      },
      seed: () => const AuthBusinessUnitRequired(_cached),
      act: (b) => b.add(
        const AuthJoinBusinessUnitRequested(businessUnitCode: 'BRN-GOMBE'),
      ),
      expect: () => [
        const AuthJoinBusinessUnitInProgress(),
        const AuthUnauthenticated(),
      ],
      verify: (_) => expect(depot.logoutCalls, 1),
    );

    blocTest<AuthBloc, AuthState>(
      'vérification : toujours en attente, l écran reste avec un message',
      build: () {
        depot.mine = _pending;
        return AuthBloc(authRepository: depot);
      },
      seed: () => const AuthJoinRequestState(_cached, _pending),
      act: (b) => b.add(const AuthJoinRequestCheckRequested()),
      expect: () => [
        const AuthJoinRequestState(_cached, _pending, busy: true),
        isA<AuthJoinRequestState>()
            .having((s) => s.request.isPending, 'en attente', true)
            .having((s) => s.notice, 'message', contains('Toujours en attente')),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'écran de synchronisation : relecture sans entreprise, il reste affiché',
      build: () {
        depot.meAfterRefresh = _syncPendingMe;
        return AuthBloc(authRepository: depot);
      },
      seed: () => const AuthSyncPending(_cached),
      act: (b) => b.add(const AuthRefreshProfileRequested()),
      expect: () => [isA<AuthSyncPending>()],
    );
  });

  group('appel join-business-unit (contrat gestion)', () {
    test('202 : double enveloppe déballée, demande en attente, jamais en file', () async {
      final api = _Api()
        ..postResponse = {
          'success': true,
          'message': 'Operation successful',
          'data': {
            'success': true,
            'message': 'Demande envoyée à Acme.',
            'data': {
              'status': 'pending',
              'requestId': 'r1',
              'companyId': 'c1',
              'companyName': 'Acme',
            },
          },
        };
      final res = await AuthBackendService(apiClient: api).joinBusinessUnit('BRN-GOMBE');
      expect(api.lastEndpoint, 'settings-user-profile/company/join-business-unit');
      expect(api.lastBody, {'businessUnitCode': 'BRN-GOMBE'});
      expect(api.lastQueueOffline, isFalse);
      expect(res.isPending, isTrue);
      expect(res.message, 'Demande envoyée à Acme.');
      expect(res.toPendingRequest().companyName, 'Acme');
    });

    test('succès sans objet de données : succès gardé avec le message', () async {
      final api = _Api()
        ..postResponse = {'success': true, 'message': 'Unité rejointe.'};
      final res = await AuthBackendService(apiClient: api).joinBusinessUnit('BRN-1');
      expect(res.success, isTrue);
      expect(res.isPending, isFalse);
      expect(res.businessUnitCode, 'BRN-1');
      expect(res.message, 'Unité rejointe.');
    });
  });

  group('réponse /auth/me', () {
    test('compte sans entreprise : relève de la synchro, pas de saisie d unité', () {
      expect(_syncPendingMe.isSyncPending, isTrue);
      expect(_syncPendingMe.needsBusinessUnitJoin, isFalse);
    });

    test('employé sans unité dans une entreprise : doit rejoindre une unité', () {
      final me = AuthMeResponse.fromJson({
        'user': {'id': 'u1', 'email': 'a@b.c', 'role': 'cashier', 'companyId': 'c1'},
        'company': {'id': 'c1', 'name': 'Acme'},
      });
      expect(me.needsBusinessUnitJoin, isTrue);
    });

    test('administrateur sans unité : jamais bloqué', () {
      final me = AuthMeResponse.fromJson({
        'user': {'id': 'u1', 'email': 'a@b.c', 'role': 'admin', 'companyId': 'c1'},
        'company': {'id': 'c1', 'name': 'Acme'},
      });
      expect(me.needsBusinessUnitJoin, isFalse);
    });

    test('identité de l entreprise reprise de l entité Company', () {
      final me = AuthMeResponse.fromJson({
        'user': {'id': 'u1', 'email': 'a@b.c', 'role': 'user'},
        'company': {
          'id': 'c1',
          'name': 'Acme',
          'address': 'Av. du Commerce 12',
          'registrationNumber': 'CD/KIN/RCCM/1',
        },
      });
      final user = me.toUser();
      expect(user.companyId, 'c1');
      expect(user.companyName, 'Acme');
      expect(user.businessAddress, 'Av. du Commerce 12');
      expect(user.rccmNumber, 'CD/KIN/RCCM/1');
    });
  });
}
