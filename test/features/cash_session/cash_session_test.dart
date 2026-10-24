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
}
