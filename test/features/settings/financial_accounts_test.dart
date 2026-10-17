import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/features/settings/bloc/financial_account_bloc.dart';
import 'package:wanzo/features/settings/bloc/financial_account_event.dart';
import 'package:wanzo/features/settings/bloc/financial_account_state.dart';
import 'package:wanzo/features/settings/models/financial_account.dart';
import 'package:wanzo/features/settings/models/settings.dart';
import 'package:wanzo/features/settings/repositories/financial_account_repository.dart';
import 'package:wanzo/features/settings/repositories/settings_repository.dart';
import 'package:wanzo/features/settings/services/financial_account_api_service.dart';
import 'package:wanzo/features/settings/services/financial_account_pin_store.dart';

/// Comptes financiers : écritures envoyées au serveur, file hors ligne,
/// refus affiché et annulé, synchronisation par fusion, PIN jamais envoyé.

final _t = DateTime(2026, 10, 17);

FinancialAccount _mm(String id, {String phone = '+243810000001', bool def = false, String? pin}) =>
    FinancialAccount(
      id: id,
      type: FinancialAccountType.mobileMoney,
      accountName: 'Caisse $id',
      isDefault: def,
      createdAt: _t,
      updatedAt: _t,
      mobileMoneyProvider: MobileMoneyProvider.mpesa,
      phoneNumber: phone,
      accountHolderName: 'Amani',
      encryptedPin: pin,
    );

/// Service API factice : chaque appel est noté, la réponse est réglable.
class _Api implements FinancialAccountApiService {
  final calls = <String>[];
  Object? error;
  List<FinancialAccount> serverAccounts = [];
  List<Map<String, dynamic>> sentBodies = [];

  Never _throw() => throw error!;

  @override
  Future<ApiResponse<FinancialAccount>> createFinancialAccount(FinancialAccount a) async {
    calls.add('POST ${a.id}');
    sentBodies.add(a.toJson());
    if (error != null) _throw();
    return ApiResponse(success: true, data: a.copyWith(accountName: '${a.accountName} (serveur)'));
  }

  @override
  Future<ApiResponse<FinancialAccount>> updateFinancialAccount(String id, FinancialAccount a) async {
    calls.add('PUT $id');
    sentBodies.add(a.toJson());
    if (error != null) _throw();
    return ApiResponse(success: true, data: a);
  }

  @override
  Future<ApiResponse<void>> deleteFinancialAccount(String id) async {
    calls.add('DELETE $id');
    if (error != null) _throw();
    return ApiResponse(success: true);
  }

  @override
  Future<ApiResponse<FinancialAccount>> setDefaultAccount(String id) async {
    calls.add('PUT $id/set-default');
    if (error != null) _throw();
    return ApiResponse(success: true);
  }

  @override
  Future<ApiResponse<List<FinancialAccount>>> getFinancialAccounts({
    int? page,
    int? limit,
    FinancialAccountType? type,
  }) async {
    calls.add('GET');
    if (error != null) _throw();
    return ApiResponse(success: true, data: serverAccounts);
  }

  @override
  Future<ApiResponse<List<FinancialAccount>>> syncAccounts(List<FinancialAccount> local) async {
    calls.add('SYNC ${local.length}');
    sentBodies.addAll(local.map((a) => a.toJson()));
    if (error != null) _throw();
    return ApiResponse(success: true, data: local);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Coffre factice (pas de canal natif en test).
class _Pins extends FinancialAccountPinStore {
  final saved = <String, String>{};
  @override
  Future<void> save(String accountId, String pin) async => saved[accountId] = pin;
  @override
  Future<void> remove(String accountId) async => saved.remove(accountId);
}

/// Client HTTP factice pour le contrat de lecture.
class _Http implements ApiClient {
  dynamic getResponse;
  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool requiresAuth = false,
    bool bypassCircuitBreaker = false,
    bool includeBusinessContext = false,
  }) async => getResponse;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  late Directory dir;
  late Box<FinancialAccount> box;
  late _Api api;
  late _Pins pins;
  late FinancialAccountRepository repo;
  var n = 0;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('wanzo_desk_fin_accounts');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(45)) Hive.registerAdapter(FinancialAccountAdapter());
    if (!Hive.isAdapterRegistered(43)) Hive.registerAdapter(FinancialAccountTypeAdapter());
    if (!Hive.isAdapterRegistered(44)) Hive.registerAdapter(MobileMoneyProviderAdapter());
    if (!Hive.isAdapterRegistered(46)) Hive.registerAdapter(FinancialInstitutionAdapter());
  });

  setUp(() async {
    box = await Hive.openBox<FinancialAccount>('fa_${n++}');
    api = _Api();
    pins = _Pins();
    repo = FinancialAccountRepository(apiService: api, pinStore: pins);
    await repo.init(box: box);
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('la box est celle lue par l écran', () {
    expect(FinancialAccountRepository.accountsBoxName, 'financial_accounts');
  });

  group('écritures', () {
    test('ajout : envoyé au serveur, réponse du serveur gardée, PIN jamais envoyé', () async {
      final outcome = await repo.addAccount(_mm('a1'), pin: '4321');
      expect(outcome, FinancialAccountWriteOutcome.synced);
      expect(api.calls, ['POST a1']);
      expect(api.sentBodies.single.containsKey('encryptedPin'), isFalse);
      expect(repo.getAccountById('a1')!.accountName, 'Caisse a1 (serveur)');
      expect(repo.getAccountById('a1')!.encryptedPin, isNull);
      expect(pins.saved['a1'], '4321');
    });

    test('réseau coupé : gardé sur le poste, signalé en file', () async {
      api.error = OfflineQueuedException();
      final outcome = await repo.addAccount(_mm('a1'));
      expect(outcome, FinancialAccountWriteOutcome.queuedOffline);
      expect(repo.getAccountById('a1'), isNotNull);
    });

    test('refus du serveur : message du serveur, ajout annulé', () async {
      api.error = AuthorizationException(
        'Forbidden',
        responseBody: {'message': 'Seuls le propriétaire, un gérant ou le comptable peuvent modifier.'},
      );
      await expectLater(
        repo.addAccount(_mm('a1')),
        throwsA(
          isA<FinancialAccountRejectedException>().having(
            (e) => e.message,
            'message',
            contains('Seuls le propriétaire'),
          ),
        ),
      );
      expect(repo.getAccountById('a1'), isNull);
    });

    test('mise à jour, défaut et suppression partent au serveur', () async {
      await repo.addAccount(_mm('a1', def: true));
      await repo.addAccount(_mm('a2', phone: '+243810000002'));
      await repo.updateAccount(_mm('a2', phone: '+243810000002').copyWith(accountName: 'Renommé'));
      await repo.setDefaultAccount('a2');
      await repo.deleteAccount('a1');
      expect(api.calls, ['POST a1', 'POST a2', 'PUT a2', 'PUT a2/set-default', 'DELETE a1']);
      expect(repo.getAccountById('a1'), isNull);
      expect(repo.getAccountById('a2')!.isDefault, isTrue);
    });

    test('suppression refusée : le compte revient', () async {
      await repo.addAccount(_mm('a1'));
      api.error = BadRequestException('x', responseBody: {'message': 'Compte financier introuvable'});
      await expectLater(repo.deleteAccount('a1'), throwsA(isA<FinancialAccountRejectedException>()));
      expect(repo.getAccountById('a1'), isNotNull);
    });
  });

  group('synchronisation', () {
    test('fusion sans suppression : un compte local absent du serveur reste', () async {
      await box.put('local', _mm('local'));
      api.serverAccounts = [_mm('srv', phone: '+243810000009')];
      final all = await repo.fullSync();
      expect(all.map((a) => a.id).toSet(), {'local', 'srv'});
      expect(api.calls, ['SYNC 1', 'GET']);
    });

    test('rôle en lecture seule (403 à l envoi) : reçoit quand même les comptes', () async {
      await box.put('local', _mm('local'));
      final failingOnce = _ApiForbiddenSync()..serverAccounts = [_mm('srv', phone: '+243810000009')];
      final r = FinancialAccountRepository(apiService: failingOnce, pinStore: pins);
      await r.init(box: box);
      final all = await r.fullSync();
      expect(all.map((a) => a.id), contains('srv'));
    });

    test('ancien PIN en clair dans Hive : déplacé dans le coffre puis effacé', () async {
      final legacy = await Hive.openBox<FinancialAccount>('fa_legacy');
      await legacy.put('old', _mm('old', pin: 'encrypted_9876'));
      final r = FinancialAccountRepository(pinStore: pins);
      await r.init(box: legacy);
      expect(r.getAccountById('old')!.encryptedPin, isNull);
      expect(pins.saved['old'], '9876');
    });
  });

  group('bloc', () {
    blocTest<FinancialAccountBloc, FinancialAccountState>(
      'chargement : liste locale puis synchronisation déclenchée',
      build: () {
        api.serverAccounts = [_mm('srv')];
        return FinancialAccountBloc(repository: repo, listenToConnectivity: false);
      },
      act: (b) => b.add(const LoadFinancialAccounts()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        const FinancialAccountLoading(),
        isA<FinancialAccountLoaded>().having((s) => s.accounts.length, 'local', 0),
        isA<FinancialAccountLoaded>().having((s) => s.accounts.single.id, 'serveur', 'srv'),
      ],
      verify: (_) => expect(api.calls, contains('GET')),
    );

    blocTest<FinancialAccountBloc, FinancialAccountState>(
      'retour du réseau : synchronisation relancée',
      build: () => FinancialAccountBloc(
        repository: repo,
        onlineChanges: Stream<bool>.fromIterable([false, true]),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (_) => expect(api.calls, contains('GET')),
    );

    blocTest<FinancialAccountBloc, FinancialAccountState>(
      'refus du serveur : message affiché, la liste reste',
      build: () {
        api.error = AuthorizationException('Forbidden', responseBody: {'message': 'Refusé.'});
        return FinancialAccountBloc(repository: repo, listenToConnectivity: false);
      },
      act: (b) => b.add(AddFinancialAccount(_mm('a1'))),
      wait: const Duration(milliseconds: 200),
      expect: () => [
        const FinancialAccountError('Refusé.'),
        isA<FinancialAccountLoaded>().having((s) => s.accounts, 'vide', isEmpty),
      ],
    );

    blocTest<FinancialAccountBloc, FinancialAccountState>(
      'hors ligne : succès signalé avec l envoi différé',
      build: () {
        api.error = OfflineQueuedException();
        return FinancialAccountBloc(repository: repo, listenToConnectivity: false);
      },
      act: (b) => b.add(AddFinancialAccount(_mm('a1'))),
      wait: const Duration(milliseconds: 200),
      expect: () => [
        isA<FinancialAccountOperationSuccess>()
            .having((s) => s.message, 'message', contains('retour du réseau')),
        isA<FinancialAccountLoaded>(),
      ],
    );
  });

  group('contrat serveur', () {
    test('GET : {items,total,page,limit} dans l enveloppe gestion', () async {
      final http = _Http()
        ..getResponse = {
          'success': true,
          'message': 'Operation successful',
          'data': {
            'items': [
              {
                'id': 'srv',
                'type': 'bankAccount',
                'accountName': 'Banque',
                'isDefault': true,
                'createdAt': '2026-10-01T00:00:00.000Z',
                'updatedAt': '2026-10-01T00:00:00.000Z',
                'bankAccountNumber': '0001',
                'bankName': 'Banque inconnue',
                'status': 'active',
              },
            ],
            'total': 1,
            'page': 1,
            'limit': 200,
          },
        };
      final res = await FinancialAccountApiService(apiClient: http).getFinancialAccounts();
      expect(res.data!.single.id, 'srv');
      expect(res.data!.single.bankInstitution, isNull);
    });

    test('toJson ne contient jamais le PIN', () {
      expect(_mm('x', pin: 'encrypted_1').toJson().containsKey('encryptedPin'), isFalse);
    });

    test('empreinte de PIN salée par compte, jamais le PIN', () {
      final a = FinancialAccountPinStore.fingerprint('a1', '1234');
      expect(a, isNot(contains('1234')));
      expect(a, isNot(FinancialAccountPinStore.fingerprint('a2', '1234')));
    });
  });

  group('profil entreprise envoyé au serveur', () {
    test('logo local et liens vides jamais envoyés', () {
      const s = Settings(
        companyName: 'Acme',
        companyLogo: 'C:/Users/x/company_logo.png',
        socialMediaLinks: {'facebook': '', 'linkedin': ' https://linkedin.com/acme '},
        activeCurrency: Currency.CDF,
      );
      final body = SettingsRepository.mapSettingsToApi(s);
      expect(body.containsKey('companyLogoUrl'), isFalse);
      expect(body['socialMediaLinks'], {'linkedin': 'https://linkedin.com/acme'});
    });

    test('logo web envoyé ; aucun lien rempli : clé absente', () {
      const s = Settings(
        companyLogo: 'https://res.cloudinary.com/x/logo.png',
        socialMediaLinks: {'facebook': ' '},
      );
      final body = SettingsRepository.mapSettingsToApi(s);
      expect(body['companyLogoUrl'], 'https://res.cloudinary.com/x/logo.png');
      expect(body.containsKey('socialMediaLinks'), isFalse);
    });
  });
}

/// L'envoi (POST sync) est refusé en 403, la lecture passe.
class _ApiForbiddenSync extends _Api {
  @override
  Future<ApiResponse<List<FinancialAccount>>> syncAccounts(List<FinancialAccount> local) async {
    throw AuthorizationException('Forbidden');
  }
}
