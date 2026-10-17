import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/features/auth/bloc/auth_bloc.dart';
import 'package:wanzo/features/auth/models/join_request.dart';
import 'package:wanzo/features/auth/models/user.dart';
import 'package:wanzo/features/auth/repositories/auth_repository.dart';
import 'package:wanzo/features/auth/screens/join_request_status_screen.dart';
import 'package:wanzo/features/auth/services/auth_backend_service.dart';
import 'package:wanzo/features/auth/services/join_request_service.dart';
import 'package:wanzo/features/users/screens/join_requests_screen.dart';

const _user = User(
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

const _refused = JoinRequest(
  id: 'r1',
  status: JoinRequestStatus.refused,
  companyName: 'Acme',
  businessUnitName: 'Agence Gombe',
  reason: 'Personne inconnue de l\'entreprise',
);

/// Dépôt factice : chaque réponse du serveur est réglable.
class _Depot implements AuthRepository {
  AuthMeResponse? me;
  JoinBusinessUnitResponse? joinResponse;
  Object? joinError;
  JoinRequest? mine;
  int cancelCalls = 0;

  @override
  AuthMeResponse? getLastAuthMeResponse() => me;

  @override
  Future<JoinBusinessUnitResponse> joinBusinessUnit(String code) async {
    if (joinError != null) throw joinError!;
    return joinResponse!;
  }

  @override
  Future<JoinRequest?> fetchMyJoinRequest() async => mine;

  @override
  Future<void> cancelMyJoinRequest() async => cancelCalls++;

  @override
  Future<User?> refreshUserProfile() async => _user;

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _AuthBlocFactice extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

/// Service factice des demandes (liste administrateur).
class _Service implements JoinRequestService {
  final List<JoinRequest> items;
  String? acceptedId;
  String? acceptedRole;
  String? refusedReason;

  _Service(this.items);

  @override
  Future<JoinRequestPage> list({
    String status = JoinRequestStatus.pending,
    int page = 1,
    int limit = 20,
  }) async {
    final filtered = status == JoinRequestStatus.all
        ? items
        : items.where((r) => r.status == status).toList();
    return JoinRequestPage(items: filtered, total: filtered.length, page: page, limit: limit);
  }

  @override
  Future<JoinRequest?> accept(String id, {String role = kDefaultGrantedRole}) async {
    acceptedId = id;
    acceptedRole = role;
    return null;
  }

  @override
  Future<JoinRequest?> refuse(String id, {String? reason}) async {
    refusedReason = reason;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Widget _app(AuthBloc bloc, Widget child) => MaterialApp(
  home: BlocProvider<AuthBloc>.value(value: bloc, child: child),
);

void main() {
  group('enveloppe de gestion', () {
    test('déballe la double enveloppe et garde le message du contrôleur', () {
      final response = {
        'success': true,
        'message': 'Operation successful',
        'statusCode': 202,
        'data': {
          'success': true,
          'message': 'Demande envoyée à Acme.',
          'data': {'status': 'pending', 'requestId': 'r1', 'companyName': 'Acme'},
        },
      };
      expect(unwrapGestionData(response), {'status': 'pending', 'requestId': 'r1', 'companyName': 'Acme'});
      expect(unwrapGestionMessage(response), 'Demande envoyée à Acme.');
    });

    test('GET mine sans demande renvoie null', () {
      expect(
        unwrapGestionData({'success': true, 'message': 'x', 'data': {'success': true, 'data': null}}),
        isNull,
      );
    });

    test('message serveur affiché tel quel, sinon message par code', () {
      expect(
        joinRequestErrorMessage(ServerException('Code ambigu, demandez le code COMP.',
            statusCode: 409, responseBody: {'message': 'Code ambigu, demandez le code COMP.'})),
        'Code ambigu, demandez le code COMP.',
      );
      expect(joinRequestErrorMessage(RateLimitException('Too many requests')), contains("Trop d'essais"));
      expect(joinRequestErrorMessage(NetworkException('down')), contains('Pas de connexion'));
    });
  });

  group('parcours du demandeur (bloc)', () {
    late _Depot depot;
    setUp(() => depot = _Depot()..me = _syncPendingMe);

    blocTest<AuthBloc, AuthState>(
      '202 : la demande créée ouvre l écran d attente',
      build: () {
        depot.joinResponse = JoinBusinessUnitResponse.fromJson({
          'status': 'pending',
          'requestId': 'r1',
          'companyId': 'c1',
          'companyName': 'Acme',
          'businessUnitId': 'b1',
          'businessUnitCode': 'BRN-GOMBE',
          'businessUnitName': 'Agence Gombe',
          'joinedCompany': false,
        }, message: 'Demande envoyée');
        return AuthBloc(authRepository: depot);
      },
      seed: () => const AuthSyncPending(_user),
      act: (b) => b.add(const AuthJoinBusinessUnitRequested(businessUnitCode: 'BRN-GOMBE')),
      expect: () => [
        const AuthJoinBusinessUnitInProgress(),
        isA<AuthJoinRequestState>()
            .having((s) => s.request.isPending, 'en attente', true)
            .having((s) => s.request.destinationLabel, 'destination', 'Acme (Agence Gombe)'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'code inconnu : message du serveur puis retour à l écran d origine',
      build: () {
        depot.joinError = NotFoundException('Code inconnu.', responseBody: {'message': 'Code inconnu.'});
        return AuthBloc(authRepository: depot);
      },
      seed: () => const AuthSyncPending(_user),
      act: (b) => b.add(const AuthJoinBusinessUnitRequested(businessUnitCode: 'XXX-1')),
      expect: () => [
        const AuthJoinBusinessUnitInProgress(),
        const AuthJoinBusinessUnitFailure('Code inconnu.', user: _user),
        const AuthSyncPending(_user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'acceptée : relecture de /auth/me et entrée dans l application',
      build: () {
        depot
          ..mine = const JoinRequest(id: 'r1', status: JoinRequestStatus.accepted, grantedRole: 'cashier')
          ..me = _completeMe;
        return AuthBloc(authRepository: depot);
      },
      seed: () => const AuthJoinRequestState(_user, _pending),
      act: (b) => b.add(const AuthJoinRequestCheckRequested()),
      expect: () => [
        const AuthJoinRequestState(_user, _pending, busy: true),
        const AuthAuthenticated(_user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'refusée : le motif arrive dans l état',
      build: () {
        depot.mine = _refused;
        return AuthBloc(authRepository: depot);
      },
      seed: () => const AuthJoinRequestState(_user, _pending),
      act: (b) => b.add(const AuthJoinRequestCheckRequested()),
      expect: () => [
        const AuthJoinRequestState(_user, _pending, busy: true),
        isA<AuthJoinRequestState>()
            .having((s) => s.request.isRefused, 'refusée', true)
            .having((s) => s.request.reason, 'motif', 'Personne inconnue de l\'entreprise'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'annulation : retour à l écran du compte sans entreprise',
      build: () => AuthBloc(authRepository: depot),
      seed: () => const AuthJoinRequestState(_user, _pending),
      act: (b) => b.add(const AuthJoinRequestCancelRequested()),
      expect: () => [
        const AuthJoinRequestState(_user, _pending, busy: true),
        isA<AuthSyncPending>(),
      ],
      verify: (_) => expect(depot.cancelCalls, 1),
    );
  });

  group('écran du demandeur', () {
    testWidgets('en attente : destination, Vérifier, Annuler, Aide et déconnexion', (tester) async {
      final bloc = _AuthBlocFactice();
      whenListen(bloc, const Stream<AuthState>.empty(),
          initialState: const AuthJoinRequestState(_user, _pending));
      await tester.pumpWidget(_app(bloc, const JoinRequestStatusScreen(autoCheckDelays: [])));

      expect(find.text('Demande envoyée à Acme (Agence Gombe)'), findsOneWidget);
      expect(find.text('Vérifier'), findsOneWidget);
      expect(find.text('Annuler la demande'), findsOneWidget);
      expect(find.text('Aide'), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);
    });

    testWidgets('refusée : motif affiché et saisie d un autre code', (tester) async {
      final bloc = _AuthBlocFactice();
      whenListen(bloc, const Stream<AuthState>.empty(),
          initialState: const AuthJoinRequestState(_user, _refused));
      await tester.pumpWidget(_app(bloc, const JoinRequestStatusScreen(autoCheckDelays: [])));

      expect(find.text('Demande refusée'), findsOneWidget);
      expect(find.text('Personne inconnue de l\'entreprise'), findsOneWidget);
      expect(find.byKey(const Key('join_code_field')), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);
    });
  });

  group('demandes côté administrateur', () {
    final demande = JoinRequest(
      id: 'r1',
      status: JoinRequestStatus.pending,
      businessUnitName: 'Agence Gombe',
      requester: const JoinRequester(email: 'amani@example.com', name: 'Amani Kabila'),
      createdAt: DateTime(2026, 10, 17),
    );

    testWidgets('liste en attente puis Accepter avec le rôle choisi', (tester) async {
      final service = _Service([
        demande,
        const JoinRequest(id: 'r2', status: JoinRequestStatus.refused,
            requester: JoinRequester(name: 'Autre')),
      ]);
      await tester.pumpWidget(MaterialApp(home: JoinRequestsScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Amani Kabila'), findsOneWidget);
      expect(find.text('Autre'), findsNothing); // filtre « En attente » par défaut

      await tester.tap(find.byKey(const Key('join_request_menu_r1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accepter').last);
      await tester.pumpAndSettle();

      expect(find.text('Employé'), findsOneWidget);
      await tester.tap(find.byKey(const Key('role_cashier')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('accept_confirm')));
      await tester.pumpAndSettle();

      expect(service.acceptedId, 'r1');
      expect(service.acceptedRole, 'cashier');
    });

    testWidgets('Accepter sans changer : rôle Employé par défaut', (tester) async {
      final service = _Service([demande]);
      await tester.pumpWidget(MaterialApp(home: JoinRequestsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('join_request_menu_r1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accepter').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accept_confirm')));
      await tester.pumpAndSettle();

      expect(service.acceptedRole, 'user');
    });

    testWidgets('Refuser avec un motif de la liste et une précision', (tester) async {
      final service = _Service([demande]);
      await tester.pumpWidget(MaterialApp(home: JoinRequestsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('join_request_menu_r1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refuser').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Demande en double'));
      await tester.enterText(find.byKey(const Key('refuse_detail')), 'Déjà inscrit');
      await tester.tap(find.byKey(const Key('refuse_confirm')));
      await tester.pumpAndSettle();

      expect(service.refusedReason, 'Demande en double. Déjà inscrit');
    });
  });
}
