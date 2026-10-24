import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/services/offline_write_queue.dart';

void main() {
  setUpAll(() {
    Hive.init('${Directory.systemTemp.path}/wanzo_test_hive');
  });

  setUp(() async {
    await OfflineWriteQueue.instance.clear();
  });

  test('une ecriture mise en file est rejouee dans l ordre', () async {
    await OfflineWriteQueue.instance.enqueue(
      method: 'POST', endpoint: 'spaces', body: {'name': 'Salle A'});
    await OfflineWriteQueue.instance.enqueue(
      method: 'PATCH', endpoint: 'spaces/1', body: {'name': 'Salle B'});
    expect(await OfflineWriteQueue.instance.pendingCount(), 2);

    final seen = <String>[];
    final report = await OfflineWriteQueue.instance.replay(
      send: (m, e, b, a) async => seen.add('$m $e'),
      isPermanentFailure: (_) => false,
    );

    expect(seen, ['POST spaces', 'PATCH spaces/1']);
    expect(report.replayed, 2);
    expect(report.remaining, 0);
  });

  test('un echec temporaire preserve l ordre et laisse la file intacte', () async {
    await OfflineWriteQueue.instance.enqueue(method: 'POST', endpoint: 'a');
    await OfflineWriteQueue.instance.enqueue(method: 'POST', endpoint: 'b');

    final report = await OfflineWriteQueue.instance.replay(
      send: (m, e, b, a) async => throw Exception('reseau coupe'),
      isPermanentFailure: (_) => false,
    );

    expect(report.replayed, 0);
    expect(report.remaining, 2);
  });

  test('un refus definitif est abandonne, la suite continue', () async {
    await OfflineWriteQueue.instance.enqueue(method: 'POST', endpoint: 'invalide');
    await OfflineWriteQueue.instance.enqueue(method: 'POST', endpoint: 'valide');

    final seen = <String>[];
    final report = await OfflineWriteQueue.instance.replay(
      send: (m, e, b, a) async {
        if (e == 'invalide') throw Exception('400');
        seen.add(e);
      },
      isPermanentFailure: (err) => err.toString().contains('400'),
    );

    expect(seen, ['valide']);
    expect(report.abandoned, 1);
    expect(report.replayed, 1);
    expect(report.remaining, 0);
  });

  // ── Ajouts desktop ────────────────────────────────────────────────────────

  test('deux rejeux simultanes n envoient chaque ecriture qu une fois', () async {
    await OfflineWriteQueue.instance.enqueue(method: 'POST', endpoint: 'ventes');

    var sent = 0;
    Future<void> send(String m, String e, dynamic b, bool a) async {
      sent++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    final reports = await Future.wait([
      OfflineWriteQueue.instance.replay(
        send: send,
        isPermanentFailure: (_) => false,
      ),
      OfflineWriteQueue.instance.replay(
        send: send,
        isPermanentFailure: (_) => false,
      ),
    ]);

    expect(sent, 1);
    expect(reports[0].replayed, 1);
    expect(identical(reports[0], reports[1]), isTrue);
    expect(await OfflineWriteQueue.instance.pendingCount(), 0);
  });

  test('une saisie faite sous une autre entreprise n est jamais envoyee', () async {
    await OfflineWriteQueue.instance.enqueue(
      method: 'POST', endpoint: 'a', scope: 'societe-A');
    await OfflineWriteQueue.instance.enqueue(
      method: 'POST', endpoint: 'b', scope: 'societe-B');

    final seen = <String>[];
    final report = await OfflineWriteQueue.instance.replay(
      send: (m, e, b, a) async => seen.add(e),
      isPermanentFailure: (_) => false,
      currentScope: 'societe-B',
    );

    expect(seen, ['b']);
    expect(report.abandoned, 1);
    expect(report.remaining, 0);
  });

  test('session pas encore connue : la file attend au lieu d envoyer', () async {
    await OfflineWriteQueue.instance.enqueue(
      method: 'POST', endpoint: 'a', scope: 'societe-A');

    final seen = <String>[];
    final report = await OfflineWriteQueue.instance.replay(
      send: (m, e, b, a) async => seen.add(e),
      isPermanentFailure: (_) => false,
      currentScope: null,
    );

    expect(seen, isEmpty);
    expect(report.remaining, 1);
  });

  test('le compteur du bandeau suit la file', () async {
    expect(OfflineWriteQueue.instance.pending.value, 0);
    await OfflineWriteQueue.instance.enqueue(method: 'POST', endpoint: 'a');
    await OfflineWriteQueue.instance.enqueue(method: 'POST', endpoint: 'b');
    expect(OfflineWriteQueue.instance.pending.value, 2);

    await OfflineWriteQueue.instance.replay(
      send: (m, e, b, a) async {},
      isPermanentFailure: (_) => false,
    );
    expect(OfflineWriteQueue.instance.pending.value, 0);
  });

  test("une ecriture qui vise un produit pas encore cree attend sa creation", () async {
    // Ordre réel en prod : mouvement de stock et PATCH d un produit créé
    // hors ligne partaient avant sa création (404 puis abandon définitif).
    await OfflineWriteQueue.instance.enqueue(
      method: "POST",
      endpoint: "stock-transactions",
      body: {"productId": "p-local", "quantity": 2},
    );
    await OfflineWriteQueue.instance.enqueue(
      method: "PATCH", endpoint: "products/p-local", body: {"name": "Riz"});
    await OfflineWriteQueue.instance.enqueue(
      method: "POST", endpoint: "customers", body: {"name": "Awa"});

    var produitCree = false;
    OfflineWriteQueue.waitsForPendingCreation = (m, e, b) {
      if (produitCree) return false;
      if (e.startsWith("products/p-local")) return true;
      return b is Map && b["productId"] == "p-local";
    };
    addTearDown(() => OfflineWriteQueue.waitsForPendingCreation = null);

    final seen = <String>[];
    var report = await OfflineWriteQueue.instance.replay(
      send: (m, e, b, a) async => seen.add("$m $e"),
      isPermanentFailure: (_) => true,
    );
    expect(seen, ["POST customers"]);
    expect(report.abandoned, 0);
    expect(report.remaining, 2);

    produitCree = true;
    seen.clear();
    report = await OfflineWriteQueue.instance.replay(
      send: (m, e, b, a) async => seen.add("$m $e"),
      isPermanentFailure: (_) => true,
    );
    expect(seen, ["POST stock-transactions", "PATCH products/p-local"]);
    expect(report.remaining, 0);
  });
}
