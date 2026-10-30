import 'dart:async';
import 'dart:io';

import 'package:hive/hive.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/cancellation/document_cancellation.dart';
import 'package:wanzo/features/cash_session/services/cash_session_service.dart';
import 'package:wanzo/features/dashboard/bloc/operation_journal_bloc.dart';
import 'package:wanzo/features/dashboard/repositories/operation_journal_repository.dart';
import 'package:wanzo/features/inventory/repositories/inventory_repository.dart';
import 'package:wanzo/features/sales/bloc/sales_bloc.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/sales/repositories/sales_repository.dart';

Sale _sale(String id, {SaleStatus status = SaleStatus.completed, double total = 5000}) => Sale(
  id: id,
  localId: id,
  date: DateTime(2026, 10, 27, 8),
  customerName: 'Client',
  items: const [],
  totalAmountInCdf: total,
  paidAmountInCdf: total,
  paymentMethod: 'cash',
  status: status,
  transactionCurrencyCode: 'CDF',
  syncStatus: 'synced',
);

class _FakeRepo extends Fake implements SalesRepository {
  final sales = <String, Sale>{};
  int addCalls = 0;
  Completer<void>? addGate;
  String? lastReason;

  @override
  Future<Sale> addSale(Sale sale) async {
    addCalls++;
    await addGate?.future;
    final saved = sale.copyWith(id: 'srv-$addCalls', syncStatus: 'synced');
    sales[saved.id] = saved;
    return saved;
  }

  @override
  Future<List<Sale>> getAllSales({
    bool syncWithApi = false,
    bool includeCancelled = false,
  }) async =>
      includeCancelled
          ? sales.values.toList()
          : SalesRepository.activeOnly(sales.values);

  @override
  Future<Sale?> getSaleById(String id) async => sales[id];

  @override
  Future<CancellationOutcome<Sale>> cancelSale(
    Sale sale,
    String reason, {
    String? actorName,
    String? actorId,
  }) async {
    lastReason = reason;
    final cancelled = sale.copyWith(
      status: SaleStatus.cancelled,
      cancelReason: reason,
      cancelledByName: actorName,
    );
    sales[sale.id] = cancelled;
    return CancellationOutcome(document: cancelled, synced: false, message: 'en file');
  }

  @override
  Future<CancellationOutcome<Sale>> restoreSale(Sale sale, {String? reason}) async {
    final restored = sale.copyWith(status: SaleStatus.completed, clearCancellation: true);
    sales[sale.id] = restored;
    return CancellationOutcome(document: restored, synced: true, message: 'Vente rétablie.');
  }
}

class _FakeJournal extends Fake implements OperationJournalRepository {
  final reversed = <Set<String?>>[];
  final reinstated = <Set<String?>>[];

  @override
  Future<int> reverseDocument(Iterable<String?> documentIds) async {
    reversed.add(documentIds.toSet());
    return 1;
  }

  @override
  Future<int> reinstateDocument(Iterable<String?> documentIds) async {
    reinstated.add(documentIds.toSet());
    return 1;
  }
}

class _FakeInventory extends Fake implements InventoryRepository {}

/// Caisse en mémoire : aucune caisse ouverte, rien n'est lu sur disque.
class _MemoryStore implements CashSessionStore {
  @override
  Future<List<Map<String, dynamic>>> loadAll() async => const [];
  @override
  Future<void> save(String localId, Map<String, dynamic> json) async {}
  @override
  Future<void> delete(String localId) async {}
}

void main() {
  late _FakeRepo repo;
  late _FakeJournal journal;
  late OperationJournalBloc journalBloc;
  late SalesBloc bloc;

  setUpAll(() async {
    // Marqueurs locaux (encaissement à reprendre) : une boîte Hive.
    final dossier = await Directory.systemTemp.createTemp('wanzo_bloc_');
    Hive.init(dossier.path);
  });

  setUp(() {
    CashSessionService.instance = CashSessionService(
      store: _MemoryStore(),
      sender: (_, __) async {},
    );
    repo = _FakeRepo();
    journal = _FakeJournal();
    journalBloc = OperationJournalBloc(repository: journal);
    bloc = SalesBloc(
      salesRepository: repo,
      operationJournalBloc: journalBloc,
      journalRepository: journal,
      inventoryRepository: _FakeInventory(),
    );
  });

  tearDown(() async {
    await bloc.close();
    await journalBloc.close();
  });

  test('totaux : seules les ventes actives comptent, les annulées à part', () {
    final state = salesLoadedFrom([
      _sale('a', total: 1000),
      _sale('b', total: 2000, status: SaleStatus.cancelled),
      _sale('c', total: 500, status: SaleStatus.pending),
    ]);
    expect(state.sales.map((s) => s.id), ['a', 'c']);
    expect(state.cancelledSales.map((s) => s.id), ['b']);
    expect(state.totalAmountInCdf, 1500);
  });

  test('double appui : deux AddSale du même localId, un seul enregistrement', () async {
    repo.addGate = Completer<void>();
    final draft = _sale('').copyWith(localId: 'L-1', syncStatus: 'pending');
    bloc.add(AddSale(draft));
    bloc.add(AddSale(draft));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    repo.addGate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(repo.addCalls, 1);
  });

  test('annulation : état publié, journal contre-passé, vente gardée à part', () async {
    repo.sales['s1'] = _sale('s1');
    final states = <SalesState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(CancelSale(sale: repo.sales['s1']!, reason: 'Doublon', actorName: 'Marie'));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final done = states.whereType<SaleCancellationDone>().single;
    expect(done.sale.isCancelled, isTrue);
    expect(done.sale.cancelReason, 'Doublon');
    expect(journal.reversed.single, containsAll(['s1']));
    final loaded = states.whereType<SalesLoaded>().last;
    expect(loaded.sales, isEmpty);
    expect(loaded.cancelledSales.single.id, 's1');
    await sub.cancel();
  });

  test('vente déjà annulée : pas de seconde contre-passation', () async {
    repo.sales['s1'] = _sale('s1', status: SaleStatus.cancelled);
    bloc.add(CancelSale(sale: repo.sales['s1']!, reason: 'Doublon'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(journal.reversed, isEmpty);
  });

  test('rétablissement : écritures reprises, vente de nouveau active', () async {
    repo.sales['s1'] = _sale('s1', status: SaleStatus.cancelled);
    final states = <SalesState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(RestoreSale(sale: repo.sales['s1']!));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final done = states.whereType<SaleCancellationDone>().single;
    expect(done.restored, isTrue);
    expect(journal.reinstated.single, contains('s1'));
    expect(states.whereType<SalesLoaded>().last.sales.single.id, 's1');
    await sub.cancel();
  });

  test('changer le statut en « annulée » sans motif est refusé', () async {
    repo.sales['s1'] = _sale('s1');
    final states = <SalesState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(const UpdateSaleStatus('s1', SaleStatus.cancelled));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(states.single, isA<SalesError>());
    expect(repo.sales['s1']!.isCancelled, isFalse);
    await sub.cancel();
  });
}
