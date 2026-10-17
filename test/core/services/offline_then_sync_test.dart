// Mode hors ligne puis synchronisation, de bout en bout dans le client HTTP :
// une écriture faite sans réseau est conservée (jamais un faux succès), puis
// rejouée telle quelle au retour du réseau, une seule fois.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/services/api_service.dart';
import 'package:wanzo/core/services/offline_write_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool online;
  late int status;
  late List<http.Request> received;
  late ApiClient api;

  setUpAll(() {
    dotenv.testLoad(
      fileInput: 'API_GATEWAY_URL=http://localhost:8000\nENVIRONMENT=test',
    );
    Hive.init('${Directory.systemTemp.path}/wanzo_desk_offline_sync_test');
  });

  setUp(() async {
    await OfflineWriteQueue.instance.clear();
    online = false;
    status = 201;
    received = [];
    api = ApiClient.withHttpClient(
      MockClient((request) async {
        if (!online) throw const SocketException('reseau coupe');
        received.add(request);
        return http.Response(
          jsonEncode({
            'success': status < 300,
            'message': status < 300 ? 'ok' : 'refus',
            'data': {'id': 'srv-1'},
          }),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });

  test('ecriture hors ligne mise en file puis rejouee au retour du reseau', () async {
    // 1. Hors ligne : l'appelant est prévenu, rien n'est envoyé.
    await expectLater(
      api.post('spaces', body: {'name': 'Salle A'}, requiresAuth: true),
      throwsA(isA<OfflineQueuedException>()),
    );
    expect(await OfflineWriteQueue.instance.pendingCount(), 1);
    expect(OfflineWriteQueue.instance.pending.value, 1);
    expect(received, isEmpty);

    // 2. Retour du réseau : la même écriture part, une fois.
    online = true;
    final report = await api.replayPendingWrites();

    expect(report.replayed, 1);
    expect(report.remaining, 0);
    expect(received, hasLength(1));
    final sent = received.single;
    expect(sent.method, 'POST');
    expect(sent.url.path, endsWith('/commerce/api/v1/spaces'));
    expect(jsonDecode(sent.body), {'name': 'Salle A'});
    // Jamais d'en-tête « Bearer null » quand aucun jeton n'est disponible.
    expect(sent.headers['authorization'], isNull);
    expect(OfflineWriteQueue.instance.pending.value, 0);
  });

  test('l ordre des saisies est conserve au rejeu', () async {
    await expectLater(
      api.post('spaces', body: {'name': 'A'}),
      throwsA(isA<OfflineQueuedException>()),
    );
    await expectLater(
      api.patch('spaces/1', body: {'name': 'B'}),
      throwsA(isA<OfflineQueuedException>()),
    );
    await expectLater(
      api.delete('spaces/2'),
      throwsA(isA<OfflineQueuedException>()),
    );

    online = true;
    await api.replayPendingWrites();

    expect(received.map((r) => '${r.method} ${r.url.pathSegments.last}'), [
      'POST spaces',
      'PATCH 1',
      'DELETE 2',
    ]);
  });

  test('reseau retombe pendant le rejeu : pas de doublon dans la file', () async {
    await expectLater(
      api.post('spaces', body: {'name': 'A'}),
      throwsA(isA<OfflineQueuedException>()),
    );

    // Toujours hors ligne au moment du rejeu.
    final report = await api.replayPendingWrites();

    expect(report.replayed, 0);
    expect(report.remaining, 1);
    expect(await OfflineWriteQueue.instance.pendingCount(), 1);
  });

  test('session expiree au rejeu (401) : la saisie est gardee', () async {
    await expectLater(
      api.post('spaces', body: {'name': 'A'}),
      throwsA(isA<OfflineQueuedException>()),
    );

    online = true;
    status = 401;
    final report = await api.replayPendingWrites();

    expect(report.abandoned, 0);
    expect(report.remaining, 1);
  });

  test('refus definitif du serveur (400) : la saisie est abandonnee', () async {
    await expectLater(
      api.post('spaces', body: {'name': ''}),
      throwsA(isA<OfflineQueuedException>()),
    );

    online = true;
    status = 400;
    final report = await api.replayPendingWrites();

    expect(report.abandoned, 1);
    expect(report.remaining, 0);
  });

  test('queueOffline false : erreur reseau remontee, rien en file', () async {
    await expectLater(
      api.delete('suppliers/1', queueOffline: false),
      throwsA(isA<NetworkException>()),
    );
    expect(await OfflineWriteQueue.instance.pendingCount(), 0);
  });

  test('compte suspendu au rejeu : la saisie attend la reactivation', () {
    final suspendu = AuthorizationException(
      'Compte suspendu',
      responseBody: {'code': 'ACCOUNT_SUSPENDED', 'message': 'Suspendu'},
    );
    final droits = AuthorizationException(
      'Interdit',
      responseBody: {'message': 'Droits insuffisants'},
    );
    expect(ApiClient.isPermanentReplayFailure(suspendu), isFalse);
    expect(ApiClient.isPermanentReplayFailure(droits), isTrue);
    expect(
      ApiClient.isPermanentReplayFailure(
        NetworkException('coupure', endpoint: 'x'),
      ),
      isFalse,
    );
  });

  test('file generique : chemin relatif sans le prefixe de la base', () {
    const base = 'http://localhost:8000/commerce/api/v1';
    expect(
      ApiService.relativeEndpointPath(
        Uri.parse('$base/products/42'),
        base,
      ),
      'products/42',
    );
    expect(
      ApiService.relativeEndpointPath(
        Uri.parse('http://localhost:8000/notifications/1'),
        base,
      ),
      'notifications/1',
    );
  });
}
