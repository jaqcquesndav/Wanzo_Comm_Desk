import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/dashboard/models/operation_journal_entry.dart';
import 'package:wanzo/features/dashboard/utils/journal_reversal.dart';

OperationJournalEntry _entry(
  String id,
  OperationType type,
  double amount, {
  String currency = 'CDF',
  String doc = 'sale-1',
  String? productId,
  String? description,
}) => OperationJournalEntry(
  id: id,
  date: DateTime(2026, 10, 27, 8),
  description: description ?? 'Vente #sale-1',
  type: type,
  amount: amount,
  relatedDocumentId: doc,
  currencyCode: currency,
  productId: productId,
  isDebit: amount < 0,
  isCredit: amount >= 0,
  balanceAfter: 0,
);

void main() {
  var n = 0;
  String newId() => 'rev-${n++}';
  final at = DateTime(2026, 10, 27, 12);

  final venteComptant = [
    _entry('a', OperationType.saleCash, 10000),
    _entry('b', OperationType.cashIn, 10, currency: 'USD'),
    _entry('c', OperationType.stockOut, -4000, productId: 'p1'),
  ];

  test('vente annulée : chaque total de la pièce retombe à zéro', () {
    final reversals = journalReversalEntries(venteComptant, at: at, newId: newId);
    expect(reversals, hasLength(3));
    expect(reversals.every((e) => e.description.startsWith(kJournalReversalPrefix)), isTrue);
    expect(reversals.every((e) => e.date == at), isTrue);
    final all = [...venteComptant, ...reversals];
    expect(isJournalNetZero(all), isTrue);
    expect(journalNetByGroup(all).values.every((v) => v == 0), isTrue);
  });

  test('rejouer l\'annulation ne contre-passe pas deux fois', () {
    final first = journalReversalEntries(venteComptant, at: at, newId: newId);
    final again = journalReversalEntries([...venteComptant, ...first], at: at, newId: newId);
    expect(again, isEmpty);
  });

  test('rétablissement : les écritures d\'origine sont reprises', () {
    final reversals = journalReversalEntries(venteComptant, at: at, newId: newId);
    final cancelled = [...venteComptant, ...reversals];
    final again = journalReinstatementEntries(cancelled, at: at, newId: newId);
    expect(again, hasLength(3));
    final net = journalNetByGroup([...cancelled, ...again]);
    expect(net.values.fold<double>(0, (s, v) => s + v.abs()), 10000 + 10 + 4000);
    // Pas de reprise sur une pièce active (jamais annulée).
    expect(journalReinstatementEntries(venteComptant, at: at, newId: newId), isEmpty);
  });

  test('annuler, rétablir puis annuler encore : toujours soldée', () {
    final r1 = journalReversalEntries(venteComptant, at: at, newId: newId);
    final s1 = [...venteComptant, ...r1];
    final back = journalReinstatementEntries(s1, at: at, newId: newId);
    final s2 = [...s1, ...back];
    final r2 = journalReversalEntries(s2, at: at, newId: newId);
    expect(r2, isNotEmpty);
    expect(isJournalNetZero([...s2, ...r2]), isTrue);
  });
}
