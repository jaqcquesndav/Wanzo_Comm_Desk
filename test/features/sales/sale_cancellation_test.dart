import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/cancellation/document_cancellation.dart';
import 'package:wanzo/core/cancellation/pending_cancellations.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/sales/models/sale_item.dart';
import 'package:wanzo/features/sales/repositories/sales_repository.dart';
import 'package:wanzo/features/sales/services/sale_dto.dart';
import 'package:wanzo/features/sales/services/sales_api_service.dart';

/// Serveur simulé : compte les appels, peut être coupé ou refuser.
class _FakeSalesApi extends Fake implements SalesApiService {
  Object? cancelError;
  Object? restoreError;
  int cancelCalls = 0;
  int restoreCalls = 0;
  int createCalls = 0;
  String? lastReason;
  String? duplicateOf;

  @override
  Future<ApiResponse<Sale>> cancelSale(String id, {required String reason}) async {
    cancelCalls++;
    lastReason = reason;
    if (cancelError != null) throw cancelError!;
    return ApiResponse(
      success: true,
      statusCode: 200,
      message: 'ok',
      data: _sale(id, status: SaleStatus.cancelled).copyWith(
        cancelledByName: 'Serveur',
        cancelReason: reason,
        cancelledAt: DateTime(2026, 10, 27, 9),
      ),
    );
  }

  @override
  Future<ApiResponse<Sale>> restoreSale(String id, {String? reason}) async {
    restoreCalls++;
    if (restoreError != null) throw restoreError!;
    return ApiResponse(
      success: true,
      statusCode: 200,
      message: 'ok',
      data: _sale(id, status: SaleStatus.completed),
    );
  }

  @override
  Future<ApiResponse<Sale>> createSale(Sale sale) async {
    createCalls++;
    return ApiResponse(
      success: true,
      statusCode: 201,
      message: 'ok',
      data: sale.copyWith(id: 'srv-$createCalls', possibleDuplicateOf: duplicateOf),
    );
  }

  @override
  Future<ApiResponse<List<Sale>>> getAllSalesPaged({int pageSize = 100}) async =>
      ApiResponse(success: true, statusCode: 200, message: 'ok', data: const []);
}

Sale _sale(
  String id, {
  SaleStatus status = SaleStatus.completed,
  String? syncStatus = 'synced',
  double total = 5000,
  double paid = 5000,
}) => Sale(
  id: id,
  date: DateTime(2026, 10, 27, 8),
  customerName: 'Client',
  items: const [],
  totalAmountInCdf: total,
  paidAmountInCdf: paid,
  paymentMethod: 'cash',
  status: status,
  transactionCurrencyCode: 'CDF',
  syncStatus: syncStatus,
);

Future<void> _clearBoxes() async {
  await Hive.box<Sale>('sales').clear();
  if (Hive.isBoxOpen(PendingCancellations.boxName)) {
    await Hive.box(PendingCancellations.boxName).clear();
  }
  PendingCancellations.instance.resetForTest();
}

void main() {
  late _FakeSalesApi api;
  late SalesRepository repo;

  setUpAll(() async {
    Hive.init('${Directory.systemTemp.path}/wanzo_test_sale_cancellation');
    if (!Hive.isAdapterRegistered(SaleAdapter().typeId)) {
      Hive.registerAdapter(SaleAdapter());
    }
    if (!Hive.isAdapterRegistered(SaleItemAdapter().typeId)) {
      Hive.registerAdapter(SaleItemAdapter());
    }
    if (!Hive.isAdapterRegistered(SaleItemTypeAdapter().typeId)) {
      Hive.registerAdapter(SaleItemTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(SaleStatusAdapter().typeId)) {
      Hive.registerAdapter(SaleStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(BusinessUnitTypeAdapter().typeId)) {
      Hive.registerAdapter(BusinessUnitTypeAdapter());
    }
  });

  setUp(() async {
    api = _FakeSalesApi();
    repo = SalesRepository(apiService: api);
    await repo.init();
    await _clearBoxes();
  });

  Future<Box<Sale>> box() async => Hive.box<Sale>('sales');

  test('annulation : la vente reste en cache au statut annulé, hors des totaux', () async {
    await (await box()).put('s1', _sale('s1'));
    await (await box()).put('s2', _sale('s2', total: 3000, paid: 0, status: SaleStatus.pending));

    final outcome = await repo.cancelSale(
      (await repo.getSaleById('s1'))!,
      'Doublon',
      actorName: 'Marie',
    );

    expect(outcome.synced, isTrue);
    expect(api.cancelCalls, 1);
    expect(api.lastReason, 'Doublon');
    final stored = (await box()).get('s1');
    expect(stored, isNotNull, reason: 'jamais retirée du cache');
    expect(stored!.isCancelled, isTrue);
    expect(stored.cancelReason, 'Doublon');

    expect((await repo.getAllSales()).map((s) => s.id), ['s2']);
    expect(
      (await repo.getAllSales(includeCancelled: true)).map((s) => s.id).toSet(),
      {'s1', 's2'},
    );
    expect(
      (await repo.getSalesByDateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31)))
          .map((s) => s.id),
      ['s2'],
    );
    expect(await repo.calculateTotalSales(DateTime(2026, 10, 1), DateTime(2026, 10, 31)), 3000);
    expect(await repo.getSalesCount(), 1);
  });

  test('motif obligatoire : refusé sans appel au serveur', () async {
    await (await box()).put('s1', _sale('s1'));
    await expectLater(repo.cancelSale(_sale('s1'), 'ab'), throwsStateError);
    expect(api.cancelCalls, 0);
    expect((await box()).get('s1')!.isCancelled, isFalse);
  });

  test('hors ligne : l\'annulation entre dans la file et est rejouée', () async {
    await (await box()).put('s1', _sale('s1'));
    api.cancelError = NetworkException('coupure');

    final outcome = await repo.cancelSale(_sale('s1'), 'Erreur de saisie');
    expect(outcome.synced, isFalse);
    expect((await box()).get('s1')!.isCancelled, isTrue);
    expect(
      PendingCancellations.instance.isPending(CancellableDocument.sale, 's1'),
      isTrue,
    );

    // Retour du réseau : la file part, une seule fois.
    api.cancelError = null;
    await repo.flushPendingCancellations();
    expect(api.cancelCalls, 2);
    expect(api.lastReason, 'Erreur de saisie');
    expect(
      PendingCancellations.instance.isPending(CancellableDocument.sale, 's1'),
      isFalse,
    );
    await repo.flushPendingCancellations();
    expect(api.cancelCalls, 2, reason: 'rien à rejouer');
  });

  test('vente jamais envoyée : annulation en file, partie après la création', () async {
    final local = _sale('loc-1', syncStatus: 'pending');
    await (await box()).put('loc-1', local);

    await repo.cancelSale(local, 'Client a renoncé');
    expect(api.cancelCalls, 0, reason: 'le serveur ne connaît pas encore la vente');
    // Créée avec son statut d'origine, pas « annulée ».
    expect(saleStatusForApi((await box()).get('loc-1')!), 'completed');

    await repo.flushPendingCancellations();
    expect(api.cancelCalls, 0, reason: 'attend la création');

    // La synchronisation crée la vente sous l'identifiant serveur.
    await (await box()).delete('loc-1');
    await (await box()).put('srv-9', local.copyWith(id: 'srv-9', syncStatus: 'synced'));
    await PendingCancellations.instance.rekey(CancellableDocument.sale, 'loc-1', 'srv-9');
    await repo.flushPendingCancellations();
    expect(api.cancelCalls, 1);
  });

  test('refus du serveur (droits) : la vente reprend son état, rien en file', () async {
    await (await box()).put('s1', _sale('s1'));
    api.cancelError = AuthorizationException('Interdit');
    await expectLater(repo.cancelSale(_sale('s1'), 'Doublon'), throwsStateError);
    expect((await box()).get('s1')!.isCancelled, isFalse);
    expect(
      PendingCancellations.instance.isPending(CancellableDocument.sale, 's1'),
      isFalse,
    );
  });

  test('idempotent : annuler deux fois n\'appelle le serveur qu\'une fois', () async {
    await (await box()).put('s1', _sale('s1'));
    await repo.cancelSale(_sale('s1'), 'Doublon');
    final again = await repo.cancelSale(_sale('s1'), 'Doublon');
    expect(api.cancelCalls, 1);
    expect(again.document.isCancelled, isTrue);
  });

  test('rétablissement : serveur appelé, la vente revient dans les totaux', () async {
    await (await box()).put('s1', _sale('s1'));
    await repo.cancelSale(_sale('s1'), 'Doublon');
    final outcome = await repo.restoreSale((await box()).get('s1')!);
    expect(api.restoreCalls, 1);
    expect(outcome.document.isCancelled, isFalse);
    expect((await repo.getAllSales()).map((s) => s.id), ['s1']);
  });

  test('rétablir une annulation encore en file : on l\'oublie, sans serveur', () async {
    await (await box()).put('s1', _sale('s1'));
    api.cancelError = NetworkException('coupure');
    await repo.cancelSale(_sale('s1'), 'Doublon');

    final outcome = await repo.restoreSale((await box()).get('s1')!);
    expect(api.restoreCalls, 0);
    expect(outcome.document.isCancelled, isFalse);
    expect(outcome.document.status, SaleStatus.completed);
    expect(
      PendingCancellations.instance.isPending(CancellableDocument.sale, 's1'),
      isFalse,
    );
  });

  test('rétablissement refusé (409) : message clair', () async {
    await (await box()).put('s1', _sale('s1'));
    await repo.cancelSale(_sale('s1'), 'Doublon');
    api.restoreError = ServerException('La vente n\'est pas annulée', statusCode: 409);
    await expectLater(
      repo.restoreSale((await box()).get('s1')!),
      throwsA(isA<StateError>()),
    );
  });

  test('double appui : même localId, une seule vente créée', () async {
    final saisie = _sale('', syncStatus: null).copyWith(localId: 'L-1');
    final first = await repo.addSale(saisie);
    final second = await repo.addSale(saisie);
    expect(api.createCalls, 1);
    expect(second.id, first.id);
    expect((await box()).length, 1);
  });

  test('doublon possible signalé par le serveur : porté par la vente rendue', () async {
    api.duplicateOf = 'srv-0';
    final saved = await repo.addSale(_sale('', syncStatus: null).copyWith(localId: 'L-2'));
    expect(saved.possibleDuplicateOf, 'srv-0');
    expect((await box()).get(saved.id)!.possibleDuplicateOf, isNull, reason: 'jamais conservé');
  });
}
