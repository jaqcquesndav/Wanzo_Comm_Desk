import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/utils/connectivity_service.dart';
import 'package:wanzo/features/dashboard/bloc/operation_journal_bloc.dart';
import 'package:wanzo/features/dashboard/models/journal_filter.dart';
import 'package:wanzo/features/dashboard/models/operation_journal_entry.dart';
import 'package:wanzo/features/dashboard/repositories/operation_journal_repository.dart';

OperationJournalEntry entry(
  String id,
  DateTime date,
  OperationType type,
  double amount, {
  String? method,
  String currency = 'CDF',
  String? doc,
  String? sourceLocalId,
}) => OperationJournalEntry(
  id: id,
  date: date,
  description: 'Ligne $id',
  type: type,
  amount: amount,
  paymentMethod: method,
  currencyCode: currency,
  isDebit: amount < 0,
  isCredit: amount > 0,
  balanceAfter: 0,
  relatedDocumentId: doc,
  sourceLocalId: sourceLocalId,
);

class _FakeConnectivity extends Fake implements ConnectivityService {
  @override
  bool get isConnected => false;
}

/// Dépôt factice : renvoie la période demandée parmi [rows] (même règle que
/// le vrai dépôt : bornes comprises, rapprochement local / serveur).
class _FakeRepo extends Fake implements OperationJournalRepository {
  _FakeRepo(this.rows);
  final List<OperationJournalEntry> rows;
  final calls = <List<DateTime>>[];

  @override
  Future<List<OperationJournalEntry>> getOperations(
    DateTime startDate,
    DateTime endDate,
  ) async {
    calls.add([startDate, endDate]);
    return reconcileJournalEntries(
      rows.where((e) => !e.date.isBefore(startDate) && !e.date.isAfter(endDate)),
    );
  }

  @override
  Future<Map<String, Map<String, double>>> getOpeningBalancesByType(
    DateTime forDate, {
    bool Function(OperationJournalEntry entry)? where,
  }) async {
    final cash = <String, double>{'CDF': 0, 'USD': 0};
    for (final e in reconcileJournalEntries(rows)) {
      if (!e.date.isBefore(forDate)) continue;
      if (where != null && !where(e)) continue;
      if (e.type.impactsCash) {
        cash[e.currencyCode ?? 'CDF'] = (cash[e.currencyCode ?? 'CDF'] ?? 0) + e.amount;
      }
    }
    return {
      'cash': cash,
      'sales': {'CDF': 0, 'USD': 0},
      'stock': {'CDF': 0, 'USD': 0},
    };
  }
}

void main() {
  group('Période (jours locaux, bornes comprises)', () {
    final filter = JournalFilter(
      startDate: DateTime(2026, 10, 20),
      endDate: DateTime(2026, 10, 20),
    );

    test('le jour de fin est compris jusqu\'à 23:59:59.999', () {
      expect(filter.matches(entry('a', DateTime(2026, 10, 20, 0, 0), OperationType.saleCash, 1)), isTrue);
      expect(filter.matches(entry('b', DateTime(2026, 10, 20, 23, 30), OperationType.saleCash, 1)), isTrue);
      expect(filter.matches(entry('c', DateTime(2026, 10, 20, 23, 59, 59, 999), OperationType.saleCash, 1)), isTrue);
      expect(filter.matches(entry('d', DateTime(2026, 10, 21), OperationType.saleCash, 1)), isFalse);
      expect(filter.matches(entry('e', DateTime(2026, 10, 19, 23, 59, 59), OperationType.saleCash, 1)), isFalse);
    });

    test('une heure serveur UTC est rangée dans son jour LOCAL', () {
      // Vente à 23:30 à Goma (UTC+2) = 21:30 UTC : le jour retenu est le
      // jour local de cet instant, quel que soit le fuseau de la machine.
      final instant = DateTime.utc(2026, 10, 20, 21, 30);
      final parsed = OperationJournalEntry.fromJson({
        'id': 'sale-1',
        'date': instant.toIso8601String(),
        'description': 'Vente',
        'type': 'saleCash',
        'amount': 10,
        'currencyCode': 'CDF',
      });
      expect(parsed.date.isUtc, isFalse, reason: 'date ramenée en heure locale');
      final localDay = instant.toLocal();
      final sameDay = JournalFilter(startDate: localDay, endDate: localDay);
      final nextDay = JournalFilter(
        startDate: localDay.add(const Duration(days: 1)),
        endDate: localDay.add(const Duration(days: 1)),
      );
      expect(sameDay.matches(parsed), isTrue);
      expect(nextDay.matches(parsed), isFalse);
    });

    test('la fin de période ignore l\'heure transmise (jour entier)', () {
      final f = JournalFilter(startDate: DateTime(2026, 10, 1, 15), endDate: DateTime(2026, 10, 31));
      expect(f.periodStart, DateTime(2026, 10, 1));
      expect(f.periodEnd, DateTime(2026, 10, 31, 23, 59, 59, 999));
    });
  });

  group('Vues Caisse et Comptabilité', () {
    final day = DateTime(2026, 10, 20, 10);
    final rows = [
      entry('sale', day, OperationType.saleCash, 50000, method: 'Espèces'),
      entry('cash', day, OperationType.cashIn, 50000, method: 'Espèces'),
      entry('momo', day, OperationType.cashIn, 20000, method: 'mobile_money'),
      entry('dep', day, OperationType.cashOut, -8000, method: 'N/A'),
      entry('vir', day, OperationType.supplierPayment, -5000, method: 'Virement'),
      entry('stock', day, OperationType.stockOut, -30000),
      entry('due', day, OperationType.other, -4000),
    ];

    test('Caisse : espèces seulement (moyen absent ou N/A = espèces)', () {
      final f = JournalFilter.forView(JournalView.cash);
      expect(rows.where(f.matches).map((e) => e.id), ['cash', 'dep']);
    });

    test('Comptabilité : tout sauf les mouvements de stock, tous moyens', () {
      final f = JournalFilter.forView(JournalView.accounting);
      expect(rows.where(f.matches).map((e) => e.id), ['sale', 'cash', 'momo', 'dep', 'vir', 'due']);
    });

    test('moyens de paiement reconnus', () {
      expect(isCashPaymentMethod('Espèces'), isTrue);
      expect(isCashPaymentMethod('Espèce'), isTrue);
      expect(isCashPaymentMethod('cash'), isTrue);
      expect(isCashPaymentMethod(null), isTrue);
      expect(isCashPaymentMethod('Mobile Money'), isFalse);
      expect(isCashPaymentMethod('credit'), isFalse);
      expect(isCashPaymentMethod('Virement'), isFalse);
    });
  });

  group('Rapprochement local / serveur', () {
    final day = DateTime(2026, 10, 20, 10);
    test('la ligne locale d\'une pièce publiée par le serveur est écartée', () {
      final merged = reconcileJournalEntries([
        entry('uuid-1', day, OperationType.saleCash, 10, doc: 'local-sale-1'),
        entry('uuid-2', day, OperationType.cashIn, 10, doc: 'local-sale-1'),
        entry('uuid-3', day, OperationType.cashOut, -5, doc: 'srv-exp-1'),
        entry('uuid-4', day, OperationType.cashOut, -7, doc: 'local-exp-9'),
        entry('sale-srv1', day, OperationType.saleCash, 10, doc: 'srv-sale-1', sourceLocalId: 'local-sale-1'),
        entry('expense-srv-exp-1', day, OperationType.cashOut, -5, doc: 'srv-exp-1'),
      ]);
      expect(merged.map((e) => e.id).toSet(), {'uuid-4', 'sale-srv1', 'expense-srv-exp-1'});
    });
  });

  group('Bloc : affichage = filtre = export', () {
    Future<void> settled(OperationJournalBloc bloc) async {
      final s = await bloc.stream.firstWhere(
        (s) => s is OperationJournalLoaded || s is OperationJournalError,
      );
      if (s is OperationJournalError) fail(s.message);
    }

    final rows = [
      entry('a', DateTime(2026, 10, 19, 23, 30), OperationType.cashIn, 1000, method: 'cash'),
      entry('b', DateTime(2026, 10, 20, 8), OperationType.cashIn, 2000, method: 'cash'),
      entry('c', DateTime(2026, 10, 20, 23, 30), OperationType.cashIn, 3000, method: 'mobile_money'),
      entry('d', DateTime(2026, 10, 20, 23, 45), OperationType.saleCredit, 9000),
      entry('e', DateTime(2026, 10, 21, 0, 15), OperationType.cashOut, -500, method: 'cash'),
    ];

    test('un filtre rapide garde la période, un changement de période garde la vue', () async {
      final repo = _FakeRepo(rows);
      final bloc = OperationJournalBloc(repository: repo, connectivityService: _FakeConnectivity());
      final states = <OperationJournalState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(LoadOperations(startDate: DateTime(2026, 10, 20), endDate: DateTime(2026, 10, 20)));
      await settled(bloc);
      var loaded = bloc.state as OperationJournalLoaded;
      expect(loaded.operations.map((e) => e.id).toSet(), {'b', 'c', 'd'});

      bloc.add(LoadOperationsWithFilter(filter: JournalFilter.forView(JournalView.cash)));
      await settled(bloc);
      loaded = bloc.state as OperationJournalLoaded;
      expect(loaded.operations.map((e) => e.id), ['b']);
      expect(loaded.startDate, DateTime(2026, 10, 20));
      expect(loaded.endDate, DateTime(2026, 10, 20, 23, 59, 59, 999));
      // Solde d'ouverture de la vue Caisse : espèces d'avant la période.
      expect(loaded.openingCashBalances['CDF'], 1000);
      // Ce que l'export recevra : la liste affichée, rien d'autre.
      expect(loaded.filteredOperations, same(loaded.operations));

      bloc.add(FilterPeriodChanged(newStartDate: DateTime(2026, 10, 19), newEndDate: DateTime(2026, 10, 21)));
      await settled(bloc);
      loaded = bloc.state as OperationJournalLoaded;
      expect(loaded.activeFilter!.view, JournalView.cash);
      expect(loaded.operations.map((e) => e.id).toSet(), {'a', 'b', 'e'});

      await sub.cancel();
      await bloc.close();
    });
  });
}
