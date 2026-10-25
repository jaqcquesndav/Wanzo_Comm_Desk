import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';
import 'package:wanzo/features/atelier/models/atelier_order.dart';
import 'package:wanzo/features/atelier/services/atelier_advance.dart';
import 'package:wanzo/features/cash_session/cash_access.dart';
import 'package:wanzo/features/cash_session/cash_session_hooks.dart';
import 'package:wanzo/features/cash_session/models/cash_session.dart';
import 'package:wanzo/features/cash_session/services/cash_session_report.dart';
import 'package:wanzo/features/cash_session/services/cash_session_service.dart';
import 'package:wanzo/features/dashboard/models/journal_filter.dart';
import 'package:wanzo/features/dashboard/models/operation_journal_entry.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/sales/models/sale_item.dart';
import 'package:wanzo/features/sales/services/sale_dto.dart';

class _MemoryStore implements CashSessionStore {
  final rows = <String, Map<String, dynamic>>{};
  @override
  Future<List<Map<String, dynamic>>> loadAll() async => rows.values.toList();
  @override
  Future<void> save(String localId, Map<String, dynamic> json) async => rows[localId] = json;
  @override
  Future<void> delete(String localId) async => rows.remove(localId);
}

const _a = CashSessionIdentity(companyId: 'co1', businessUnitId: 'bu1', userId: 'userA');
const _b = CashSessionIdentity(companyId: 'co1', businessUnitId: 'bu1', userId: 'userB');

Sale _sale({
  String id = 'sale-1',
  double total = 10,
  double paid = 10,
  String method = 'cash',
  String currency = 'USD',
  double rate = 2800,
}) {
  final r = currency == 'CDF' ? 1.0 : rate;
  return Sale(
    id: id,
    date: DateTime(2026, 10, 25, 10),
    customerName: 'Jean',
    items: [
      SaleItem(
        productId: 'p1',
        productName: 'Savon',
        quantity: 1,
        unitPrice: total,
        totalPrice: total,
        currencyCode: currency,
        exchangeRate: r,
        unitPriceInCdf: total * r,
        totalPriceInCdf: total * r,
        itemType: SaleItemType.product,
      ),
    ],
    totalAmountInCdf: total * r,
    paidAmountInCdf: paid * r,
    status: paid >= total ? SaleStatus.completed : SaleStatus.pending,
    paymentMethod: method,
    transactionCurrencyCode: currency,
    transactionExchangeRate: r,
    totalAmountInTransactionCurrency: total,
    paidAmountInTransactionCurrency: paid,
    businessUnitType: BusinessUnitType.pos,
  );
}

void main() {
  late _MemoryStore store;
  late List<MapEntry<String, Map<String, dynamic>>> sent;
  late CashSessionIdentity who;

  CashSessionService svc({
    CashSessionSender? sender,
    CashDepositSender? depositSender,
    CashHistoryFetcher? history,
    CashUnitScope Function()? unitScope,
  }) => CashSessionService(
    store: store,
    identity: () => who,
    sender: sender ?? (endpoint, body) async => sent.add(MapEntry(endpoint, body)),
    depositSender: depositSender ?? (_) async {},
    fetcher: () async => null,
    historyFetcher: history ?? (_, __) async => null,
    unitScope: unitScope ?? () => const CashUnitScope(),
    rates: (code) async => code == 'USD' ? 2800 : null,
  );

  setUp(() {
    store = _MemoryStore();
    sent = [];
    who = _a;
  });

  group('1. session liée à l entreprise, l unité et la personne', () {
    test('poste partagé : les ventes de B ne vont jamais dans la caisse de A', () async {
      final service = svc();
      final sa = await service.open({'CDF': 1000});
      expect(sa.userId, 'userA');
      expect(sa.companyId, 'co1');
      expect(sa.businessUnitId, 'bu1');

      // B se connecte sur le même poste : il ne voit pas la caisse de A.
      who = _b;
      await service.load();
      expect(service.current.value, isNull);
      expect(
        await service.recordMovement(
          CashMovement(at: DateTime.now(), kind: CashMovementKind.sale, method: 'cash', currency: 'CDF', amount: 500, label: 'Vente B'),
        ),
        isFalse,
      );
      final sb = await service.open({'CDF': 200});
      await service.recordMovement(
        CashMovement(at: DateTime.now(), kind: CashMovementKind.sale, method: 'cash', currency: 'CDF', amount: 500, label: 'Vente B'),
      );
      expect(service.current.value!.localId, sb.localId);

      // Retour de A : sa caisse est intacte.
      who = _a;
      await service.load();
      expect(service.current.value!.localId, sa.localId);
      expect(service.current.value!.movements, isEmpty);
      expect(service.current.value!.expectedCash()['CDF'], 1000);
    });

    test('ancienne session sans propriétaire : affectée une fois à l utilisateur connecté', () async {
      store.rows['old'] = {
        'localId': 'old',
        'status': 'open',
        'openedAt': DateTime(2026, 10, 24).toIso8601String(),
        'openingFloat': {'CDF': 5000},
      };
      final service = svc();
      await service.load();
      expect(service.current.value?.localId, 'old');
      expect(store.rows['old']!['userId'], 'userA');
      // B ne la récupère pas ensuite.
      who = _b;
      await service.load();
      expect(service.current.value, isNull);
    });
  });

  group('2 et 3. acomptes', () {
    test('avance atelier encaissée UNE fois, le règlement ne facture que le reste', () async {
      final service = svc();
      CashSessionService.instance = service;
      await service.open({'USD': 0, 'CDF': 0});
      const order = AtelierOrder(
        id: 'ord-1',
        customerId: 'c1',
        customerName: 'Mme Kavira',
        label: 'Robe wax',
        totalAmount: 100,
        advanceAmount: 30,
        currencyCode: 'USD',
        exchangeRate: 2800,
      );
      final aEncaisser = atelierAdvanceToCollect(newAdvance: 30);
      expect(aEncaisser, 30);
      final vente = atelierAdvanceSale(order: order, amount: aEncaisser, paymentMethod: 'cash');
      expect(vente.paidAmountInCdf, vente.totalAmountInCdf);
      expect(vente.paidAmountInTransactionCurrency, 30);
      await CashSessionHooks.onSale(vente.copyWith(id: 'adv-1'));

      // Commande rouverte sans changer l'avance : rien de plus.
      expect(atelierAdvanceToCollect(newAdvance: 30, previousAdvance: 30), 0);
      // Règlement final : le reste seulement, jamais l'avance une 2e fois.
      expect(atelierAmountToBill(order), 70);
      expect(atelierAmountToBill(order.copyWith(advanceAmount: 100)), 0);

      final s = service.current.value!;
      expect(s.expectedCash()['USD'], 30);
      expect(s.creditGranted(), isEmpty);
    });

    test('acompte Mobile Money d une vente à crédit : hors espèces', () async {
      final service = svc();
      CashSessionService.instance = service;
      await service.open({'CDF': 1000});
      final credit = _sale(total: 10, paid: 4, method: 'credit');
      await CashSessionHooks.onSale(credit, downPaymentMethod: 'mobile_money');
      final s = service.current.value!;
      expect(s.expectedCash()['USD'] ?? 0, 0, reason: 'le Mobile Money ne gonfle pas le tiroir');
      expect(s.receiptsByMethod()[CashMethodGroup.mobileMoney], {'USD': 4.0});
      // Sans moyen saisi : espèces (valeur par défaut de l'écran).
      expect(cashMovementForSale(credit)!.method, 'cash');
    });
  });

  group('4. envoi hors ligne fiable', () {
    test('rejeu après 5xx : la clôture reste en attente puis part', () async {
      var down = true;
      final service = svc(
        sender: (endpoint, body) async {
          if (down) throw const CashSyncDeferred('503 Service Unavailable');
          sent.add(MapEntry(endpoint, body));
          return null;
        },
      );
      final s = await service.open({'CDF': 1000});
      await service.close({'CDF': 1000});
      var stored = CashSession.fromJson(store.rows[s.localId]!);
      expect(stored.pendingSync.map((p) => p.kind), ['open', 'close']);
      expect(service.pendingCount.value, 2);

      down = false;
      await service.syncPending();
      stored = CashSession.fromJson(store.rows[s.localId]!);
      expect(stored.pendingSync, isEmpty);
      expect(sent.map((e) => e.key), ['cash-sessions', 'cash-sessions/${s.localId}/close']);
      expect(service.pendingCount.value, 0);
    });

    test('dépôt rejoué : même localId ; refusé au rejeu : non comptabilisé', () async {
      final bodies = <Map<String, dynamic>>[];
      var mode = 'down';
      final service = svc(
        depositSender: (body) async {
          bodies.add(body);
          if (mode == 'down') throw const CashSyncDeferred('délai dépassé');
          if (mode == 'refuse') throw const CashDepositRefused('Compte financier introuvable');
        },
      );
      await service.open({'CDF': 100000});
      final m = await service.addBankDeposit(amount: 50000, currency: 'CDF', accountId: 'b1', accountName: 'Banque');
      await service.syncPending();
      expect(bodies.length, 2);
      expect(bodies.map((b) => b['localId']).toSet(), {m.ref});

      mode = 'refuse';
      await service.syncPending();
      expect(bodies.last['localId'], m.ref);
      final s = service.current.value!;
      expect(s.pendingSync, isEmpty);
      expect(s.notPostedDeposits.single.syncIssue, contains('introuvable'));
      expect(service.serverRefusal.value, contains('non comptabilisé'));
      final closed = await service.close({'CDF': 50000});
      expect(zTicketLines(closed, width: 40).join('\n'), contains('NON COMPTABILISE'));
    });
  });

  test('5. reverseSale : chaque règlement contre-passé dans sa propre session', () async {
    final service = svc();
    final s1 = await service.open({'CDF': 0});
    await service.recordMovement(
      CashMovement(at: DateTime.now(), kind: CashMovementKind.sale, method: 'cash', currency: 'CDF', amount: 4000, label: 'Vente', ref: 'v1'),
    );
    await service.close({'CDF': 4000});
    final s2 = await service.open({'CDF': 0});
    await service.recordMovement(
      CashMovement(at: DateTime.now(), kind: CashMovementKind.customerPayment, method: 'cash', currency: 'CDF', amount: 6000, label: 'Règlement', ref: 'v1'),
    );
    expect(await service.reverseSale({'v1'}), isTrue);
    final first = CashSession.fromJson(store.rows[s1.localId]!);
    expect(first.expected, {'CDF': 0.0});
    expect(first.difference, {'CDF': 4000.0});
    expect(service.current.value!.localId, s2.localId);
    expect(service.current.value!.expectedCash()['CDF'], 0);
    expect(sent.any((e) => e.key == 'cash-sessions/${s1.localId}/corrections'), isTrue);
    expect(await service.reverseSale({'v1'}), isFalse, reason: 'pas deux fois');
  });

  test('6. crédit accordé : ligne du rapport, jamais dans les espèces', () async {
    final service = svc();
    CashSessionService.instance = service;
    await service.open({'CDF': 1000});
    await CashSessionHooks.onSale(_sale(id: 'c1', total: 20000, paid: 0, method: 'credit', currency: 'CDF'));
    final s = service.current.value!;
    expect(s.creditGranted(), {'CDF': 20000.0});
    expect(s.expectedCash()['CDF'], 1000);
    expect(s.salesCount, 1);
    final closed = await service.close({'CDF': 1000});
    final lines = zTicketLines(closed, width: 40);
    expect(lines.any((l) => l.startsWith('Credit accorde') && l.endsWith(cashAmount(20000, 'CDF'))), isTrue, reason: lines.join('\n'));
    expect((sent.last.value['summary'] as Map)['creditGranted'], {'CDF': 20000.0});
  });

  test('7. journal : vente USD en USD, fonds, dépôt et mouvements manuels', () async {
    final entries = <OperationJournalEntry>[];
    final service = svc()..journal = (e) async => entries.add(e);
    await service.open({'CDF': 5000, 'USD': 20});
    await service.addManual(entry: true, amount: 10, currency: 'USD', reason: 'Apport');
    await service.addManual(entry: false, amount: 1000, currency: 'CDF', reason: 'Retrait');
    await service.addBankDeposit(amount: 2000, currency: 'CDF', accountId: 'b1', accountName: 'Banque');
    expect(entries.map((e) => '${e.type.name}:${e.currencyCode}:${e.amount}'), [
      'cashIn:CDF:5000.0',
      'cashIn:USD:20.0',
      'cashIn:USD:10.0',
      'cashOut:CDF:-1000.0',
      'cashOut:CDF:-2000.0',
    ]);
    expect(entries.every((e) => isCashPaymentMethod(e.paymentMethod)), isTrue);
    final usd = saleCashJournalAmount(_sale(total: 10, paid: 10));
    expect(usd.currency, 'USD');
    expect(usd.amount, 10);
  });

  test('contrat serveur : mouvement manuel, clôture avec taux et mouvements joints', () async {
    final service = svc();
    final s = await service.open({'CDF': 10000, 'USD': 10});
    await service.addManual(entry: true, amount: 5, currency: 'USD', reason: 'Apport');
    final mv = sent.last;
    expect(mv.key, 'cash-sessions/${s.localId}/movements');
    expect(mv.value['kind'], 'manual_in');
    expect(mv.value['amount'], 5.0);
    expect(mv.value['currency'], 'USD');
    expect(mv.value['exchangeRate'], 2800);
    expect(mv.value['reason'], 'Apport');
    expect(mv.value['at'], endsWith('Z'));
    expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(mv.value['localId'] as String), isTrue);
    await expectLater(service.addManual(entry: false, amount: 1, currency: 'CDF', reason: ' '), throwsArgumentError);
    await service.close({'CDF': 10000, 'USD': 15});
    final close = sent.last.value;
    expect(close['exchangeRates'], {'USD': 2800});
    expect((close['manualMovements'] as List).single['localId'], mv.value['localId']);
  });

  test('contrat serveur : 403 CASH_ACCESS_DENIED et CASH_SESSION_OTHER_UNIT, motifs clairs', () async {
    expect(
      cashRefusalMessage(AuthorizationException('Forbidden', responseBody: {'code': kCashSessionOtherUnit})),
      contains('autre unité'),
    );
    expect(
      cashRefusalMessage(AuthorizationException('Forbidden', responseBody: {'code': kCashAccessDenied})),
      contains('réservée'),
    );
    final service = svc(
      sender: (endpoint, body) async => throw CashSessionRefused(
        cashRefusalMessage(AuthorizationException('Forbidden', responseBody: {'code': kCashSessionOtherUnit})),
      ),
    );
    await service.open({'CDF': 0});
    expect(service.serverRefusal.value, contains('autre unité'));
  });

  test('8. historique : serveur fusionné avec l appareil, sans doublon', () async {
    final service = svc(
      history: (page, limit) async => CashHistoryPage([
        {
          'id': '00000000-0000-4000-8000-0000000000aa',
          'localId': 'other-device',
          'status': 'closed',
          'openedAt': '2026-10-20T06:00:00.000Z',
          'closedAt': '2026-10-20T18:00:00.000Z',
          'counted': {'CDF': 1000},
          'difference': {'CDF': 0},
          'summary': {'salesCount': 7},
        },
      ], 1),
    );
    final local = await service.open({'CDF': 0});
    await service.close({'CDF': 0});
    await service.refreshServerHistory();
    final all = await service.history();
    expect(all.map((s) => s.localId).toSet(), {local.localId, 'other-device'});
    final remote = all.firstWhere((s) => s.fromServer);
    expect(remote.salesCount, 7);
    expect(service.hasMoreServerHistory, isFalse);
  });

  test('9. date de vente envoyée en UTC (Z), relue en heure locale', () {
    final dto = saleToApiDto(_sale());
    expect(dto['date'], endsWith('Z'));
    expect(DateTime.parse(dto['date'] as String), DateTime(2026, 10, 25, 10).toUtc());
    final back = Sale.fromJson({...dto, 'id': 's1', 'items': [], 'customerName': 'Jean'});
    expect(back.date.isUtc, isFalse);
    expect(back.date, DateTime(2026, 10, 25, 10));
  });

  test('10. clôture déjà faite par un responsable : signalée avec l écart', () async {
    final service = svc(
      sender: (endpoint, body) async {
        if (endpoint.endsWith('/close')) {
          return {
            'success': true,
            'data': {
              'status': 'closed',
              'openedAt': '2026-10-25T06:00:00.000Z',
              'closedAt': '2026-10-25T17:00:00.000Z',
              'closedBy': 'manager-1',
              'closedByName': 'Mme Responsable',
              'counted': {'CDF': 9000},
              'difference': {'CDF': -1000},
            },
          };
        }
        return null;
      },
    );
    await service.open({'CDF': 10000});
    final closed = await service.close({'CDF': 10000});
    expect(closed.serverClosure, isNotNull);
    expect(closed.serverClosure!['closedByName'], 'Mme Responsable');
    expect(closed.serverClosure!['countGap'], {'CDF': 1000.0});
    expect(service.closedElsewhere.value?.localId, closed.localId);
    expect(zTicketLines(closed).join('\n'), contains('DEJA CLOTUREE'));
  });

  group('11. accès par rôle et par unité', () {
    test('vendeur ou autre rôle : caisse invisible', () {
      for (final r in ['sales', 'staff', 'manager', 'commerce_manager', 'inventory_manager', 'customer_support', null, '']) {
        expect(canAccessCashSession(r), isFalse, reason: '$r');
      }
      expect(visibleJournalViews(false), isNot(contains(JournalView.cash)));
      for (final r in ['admin', 'super_admin', 'superadmin', 'sme_admin', 'sme_owner', 'owner', 'accountant', 'avec_treasurer', 'cashier']) {
        expect(canAccessCashSession(r), isTrue, reason: r);
      }
      expect(visibleJournalViews(true), contains(JournalView.cash));
    });

    test('caissier d unité : seulement son unité ; admin : toutes', () async {
      final locked = cashUnitScopeFor(role: 'cashier', businessUnitId: 'bu1', companyId: 'co1', unitType: BusinessUnitType.pos);
      expect(locked.lockedUnitId, 'bu1');
      expect(cashUnitScopeFor(role: 'cashier', businessUnitId: 'co1', companyId: 'co1').isLocked, isFalse,
          reason: 'caissier de l entreprise générale');
      // Même règle que le serveur (403 CASH_SESSION_OTHER_UNIT) : à la
      // racine on voit toutes les unités, rattaché à une unité on voit la
      // sienne, quel que soit le rôle de caisse.
      expect(cashUnitScopeFor(role: 'admin', businessUnitId: null, companyId: 'co1').isLocked, isFalse);
      expect(cashUnitScopeFor(role: 'accountant', businessUnitId: 'root', companyId: 'co1', unitType: BusinessUnitType.company).isLocked, isFalse);
      expect(cashUnitScopeFor(role: 'accountant', businessUnitId: 'bu1', companyId: 'co1', unitType: BusinessUnitType.branch).lockedUnitId, 'bu1');

      Future<CashHistoryPage?> server(int page, int limit) async => CashHistoryPage([
        for (final bu in ['bu1', 'bu2', null])
          {
            'id': 'srv-${bu ?? 'root'}',
            'status': 'closed',
            'companyId': 'co1',
            'businessUnitId': bu,
            'openedAt': '2026-10-20T06:00:00.000Z',
            'closedAt': '2026-10-20T18:00:00.000Z',
          },
      ], 1);

      final cashier = svc(history: server, unitScope: () => locked);
      await cashier.refreshServerHistory();
      expect((await cashier.history()).map((s) => s.businessUnitId).toSet(), {'bu1'});

      final admin = svc(history: server, unitScope: () => const CashUnitScope());
      await admin.refreshServerHistory();
      expect((await admin.history()).length, 3);
      expect((await admin.history(unitFilter: 'bu2')).single.businessUnitId, 'bu2');
      expect((await admin.history(unitFilter: kCashRootUnit)).single.localId, 'srv-root');
      expect(await admin.historyUnits(), {'bu1', 'bu2', kCashRootUnit});
    });
  });
}
