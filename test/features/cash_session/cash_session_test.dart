import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/cash_session/models/cash_session.dart';
import 'package:wanzo/features/cash_session/services/cash_session_report.dart';
import 'package:wanzo/features/cash_session/services/cash_session_service.dart';

class _MemoryStore implements CashSessionStore {
  final rows = <String, Map<String, dynamic>>{};
  @override
  Future<List<Map<String, dynamic>>> loadAll() async => rows.values.toList();
  @override
  Future<void> save(String localId, Map<String, dynamic> json) async => rows[localId] = json;
  @override
  Future<void> delete(String localId) async => rows.remove(localId);
}

CashMovement sale(double amount, {String method = 'Espèces', String currency = 'CDF'}) => CashMovement(
  at: DateTime(2026, 10, 24, 10),
  kind: CashMovementKind.sale,
  method: method,
  currency: currency,
  amount: amount,
  label: 'Vente',
);

void main() {
  late _MemoryStore store;
  late List<MapEntry<String, Map<String, dynamic>>> sent;
  late CashSessionService service;

  setUp(() {
    store = _MemoryStore();
    sent = [];
    service = CashSessionService(
      store: store,
      sender: (endpoint, body) async => sent.add(MapEntry(endpoint, body)),
    );
  });

  test('ouverture : fonds par devise, une seule caisse ouverte, envoi en file', () async {
    final s = await service.open({'CDF': 50000, 'USD': 0});
    expect(s.openingFloat, {'CDF': 50000.0});
    expect(service.current.value, isNotNull);
    expect(sent.single.key, 'cash-sessions');
    expect(sent.single.value['localId'], s.localId);
    await expectLater(service.open({'CDF': 1}), throwsStateError);
  });

  test('théorique = fonds + espèces encaissées - dépenses et sorties ; Mobile Money hors tiroir', () async {
    await service.open({'CDF': 50000, 'USD': 20});
    await service.recordMovement(sale(30000));
    await service.recordMovement(sale(10, currency: 'USD'));
    await service.recordMovement(sale(15000, method: 'Mobile Money'));
    await service.recordMovement(
      CashMovement(
        at: DateTime(2026, 10, 24, 12),
        kind: CashMovementKind.expense,
        method: 'N/A',
        currency: 'CDF',
        amount: -8000,
        label: 'Transport',
      ),
    );
    await service.addManual(entry: false, amount: 20000, currency: 'CDF', reason: 'Dépôt en banque');
    final s = service.current.value!;
    expect(s.expectedCash(), {'CDF': 52000.0, 'USD': 30.0});
    final receipts = s.receiptsByMethod();
    expect(receipts[CashMethodGroup.cash], {'CDF': 30000.0, 'USD': 10.0});
    expect(receipts[CashMethodGroup.mobileMoney], {'CDF': 15000.0});
    expect(s.salesCount, 3);
  });

  test('clôture : écart calculé, motif exigé, ouverture jointe, historique', () async {
    final opened = await service.open({'CDF': 10000});
    await service.recordMovement(sale(5000));
    await expectLater(service.close({'CDF': 14000}), throwsArgumentError);
    final closed = await service.close({'CDF': 14000}, reason: 'Erreur de monnaie');
    expect(closed.difference, {'CDF': -1000.0});
    expect(closed.isOpen, isFalse);
    expect(service.current.value, isNull);
    final close = sent.last;
    expect(close.key, 'cash-sessions/${opened.localId}/close');
    expect(close.value['counted'], {'CDF': 14000.0});
    expect(close.value['open']['localId'], opened.localId);
    expect((await service.history()).single.localId, opened.localId);
    // Le rapport Z reprend théorique, compté, écart et motif.
    final lines = zTicketLines(closed).join('\n');
    expect(lines, contains('Ecart CDF'));
    expect(lines, contains('Erreur de monnaie'));
  });

  test('sans caisse ouverte, un mouvement n\'est pas rattaché (pas de blocage)', () async {
    expect(await service.recordMovement(sale(1000)), isFalse);
  });

  test('reprise après redémarrage : la caisse ouverte est relue', () async {
    await service.open({'CDF': 1000});
    final again = CashSessionService(store: store, sender: (_, __) async {});
    await again.load();
    expect(again.current.value, isNotNull);
  });

  test('moyens de paiement regroupés', () {
    expect(cashMethodGroupOf('Espèces'), CashMethodGroup.cash);
    expect(cashMethodGroupOf('mobile_money'), CashMethodGroup.mobileMoney);
    expect(cashMethodGroupOf('Carte bancaire'), CashMethodGroup.card);
    expect(cashMethodGroupOf('credit'), CashMethodGroup.credit);
    expect(cashMethodGroupOf('Virement bancaire'), CashMethodGroup.other);
  });

  test('409 : ouverture locale annulée, message clair, reprise de la session du serveur', () async {
    final server = {
      'id': '00000000-0000-4000-8000-000000000001',
      'localId': 'srv-L1',
      'status': 'open',
      'openedAt': '2026-10-24T05:00:00.000Z',
      'openingFloat': {'CDF': 20000},
    };
    final conflicted = CashSessionService(
      store: store,
      sender: (endpoint, body) async => throw CashSessionConflict(server),
      fetcher: () async => server,
    );
    await expectLater(
      conflicted.open({'CDF': 1000}),
      throwsA(isA<CashSessionConflict>().having((e) => e.message, 'message', contains('Clôturez-la ou reprenez-la'))),
    );
    expect(conflicted.current.value, isNull);
    expect(store.rows, isEmpty);
    expect(await conflicted.serverConflict(), isNotNull);
    final resumed = await conflicted.resume(server);
    expect(resumed.localId, 'srv-L1');
    expect(resumed.openingFloat, {'CDF': 20000.0});
    expect(await conflicted.serverConflict(), isNull);
  });

  test('vente annulée : contre-passée dans la caisse ouverte, théorique et rapport justes', () async {
    await service.open({'CDF': 10000});
    await service.recordMovement(
      CashMovement(
        at: DateTime(2026, 10, 24, 10),
        kind: CashMovementKind.sale,
        method: 'Espèces',
        currency: 'CDF',
        amount: 5000,
        label: 'Vente #abc',
        ref: 'sale-1',
      ),
    );
    expect(await service.reverseSale({'sale-1', 'local-1'}), isTrue);
    expect(await service.reverseSale({'sale-1'}), isFalse, reason: 'pas deux fois');
    final s = service.current.value!;
    expect(s.expectedCash()['CDF'], 10000);
    expect(s.salesCount, 0);
    expect(s.receiptsByMethod()[CashMethodGroup.cash], {'CDF': 0.0});
  });

  test('vente supprimée après la clôture : écart recalculé et correction envoyée', () async {
    final opened = await service.open({'CDF': 10000});
    await service.recordMovement(
      CashMovement(
        at: DateTime(2026, 10, 24, 10),
        kind: CashMovementKind.sale,
        method: 'cash',
        currency: 'CDF',
        amount: 5000,
        label: 'Vente #abc',
        ref: 'local-1',
      ),
    );
    await service.close({'CDF': 15000});
    expect(await service.reverseSale({'srv-1', 'local-1'}, label: 'Vente annulée #abc'), isTrue);
    final closed = (await service.history()).single;
    expect(closed.expected, {'CDF': 10000.0});
    expect(closed.difference, {'CDF': 5000.0});
    expect(sent.last.key, 'cash-sessions/${opened.localId}/corrections');
    expect(sent.last.value['expected'], {'CDF': 10000.0});
    expect(zTicketLines(closed).join('\n'), contains('Ecart CDF'));
  });
}
