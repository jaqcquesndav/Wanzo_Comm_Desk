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

void main() {
  late List<MapEntry<String, Map<String, dynamic>>> sent;
  late CashSessionService service;

  setUp(() {
    sent = [];
    service = CashSessionService(
      store: _MemoryStore(),
      sender: (endpoint, body) async => sent.add(MapEntry(endpoint, body)),
    );
  });

  CashMovement movement(CashMovementKind kind, double amount, String ref) => CashMovement(
    at: DateTime(2026, 10, 27, 10),
    kind: kind,
    method: 'cash',
    currency: 'CDF',
    amount: amount,
    label: ref,
    ref: ref,
  );

  test('vente annulée : encaissement contre-passé, ticket Z sans elle', () async {
    await service.open({'CDF': 10000});
    await service.recordMovement(movement(CashMovementKind.sale, 5000, 'v1'));
    await service.recordMovement(movement(CashMovementKind.sale, 2000, 'v2'));
    expect(await service.reverseSale({'v1'}), isTrue);
    final s = service.current.value!;
    expect(s.expectedCash()['CDF'], 12000);
    expect(s.salesCount, 1);
    expect(s.receiptsByMethod()[CashMethodGroup.cash], {'CDF': 2000.0});
    expect(await service.reverseSale({'v1'}), isFalse, reason: 'pas deux fois');
  });

  test('dépense annulée : sortie contre-passée, espèces attendues rétablies', () async {
    await service.open({'CDF': 10000});
    await service.recordMovement(movement(CashMovementKind.expense, -3000, 'd1'));
    expect(service.current.value!.expectedCash()['CDF'], 7000);

    expect(await service.reverseExpense({'d1', ''}), isTrue);
    final s = service.current.value!;
    expect(s.expectedCash()['CDF'], 10000);
    expect(s.totalOf(CashMovementKind.expense), {'CDF': 0.0});
    expect(await service.reverseExpense({'d1'}), isFalse, reason: 'pas deux fois');
  });

  test('dépense annulée après la clôture : écart recalculé, correction envoyée', () async {
    final opened = await service.open({'CDF': 10000});
    await service.recordMovement(movement(CashMovementKind.expense, -3000, 'd1'));
    await service.close({'CDF': 7000});
    expect(await service.reverseExpense({'d1'}, label: 'Dépense annulée : d1'), isTrue);
    final closed = (await service.history()).single;
    expect(closed.expected, {'CDF': 10000.0});
    expect(closed.difference, {'CDF': -3000.0});
    expect(sent.last.key, 'cash-sessions/${opened.localId}/corrections');
    expect(zTicketLines(closed).join('\n'), contains('Ecart CDF'));
  });
}
