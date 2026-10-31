import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/cancellation/audit_history_section.dart';
import 'package:wanzo/core/cancellation/document_cancellation.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/features/atelier/models/atelier_order.dart';
import 'package:wanzo/features/atelier/services/atelier_advance.dart';
import 'package:wanzo/features/atelier/services/atelier_archive.dart';
import 'package:wanzo/features/cash_session/cash_session_hooks.dart';
import 'package:wanzo/features/cash_session/models/cash_session.dart';
import 'package:wanzo/features/cash_session/services/cash_reentry_flags.dart';
import 'package:wanzo/features/cash_session/services/cash_session_service.dart';
import 'package:wanzo/features/inventory/models/product.dart';
import 'package:wanzo/features/inventory/models/stock_transaction.dart';
import 'package:wanzo/features/inventory/repositories/inventory_repository.dart';
import 'package:wanzo/features/inventory/services/inventory_api_service.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/sales/models/sale_item.dart';
import 'package:wanzo/features/sales/repositories/sales_repository.dart';

class _MemoryStore implements CashSessionStore {
  final rows = <String, Map<String, dynamic>>{};
  @override
  Future<List<Map<String, dynamic>>> loadAll() async => rows.values.toList();
  @override
  Future<void> save(String localId, Map<String, dynamic> json) async =>
      rows[localId] = json;
  @override
  Future<void> delete(String localId) async => rows.remove(localId);
}

/// Serveur produit simulé : DELETE répond toujours 204 ; le produit reste
/// lisible s'il a été désactivé.
class _FakeInventoryApi extends Fake implements InventoryApiService {
  bool keepsProduct = false;
  int deletes = 0;

  /// Réponse du DELETE : null = 204 d'un serveur ancien.
  ProductRemovalResult? removal;

  @override
  Future<ApiResponse<ProductRemovalResult?>> deleteProduct(String id) async {
    deletes++;
    return ApiResponse(success: true, statusCode: 200, message: 'ok', data: removal);
  }

  @override
  Future<ApiResponse<Product>> getProductById(String id) async {
    if (!keepsProduct) throw Exception('404');
    return ApiResponse(success: true, statusCode: 200, message: 'ok', data: _product());
  }
}

Product _product() {
  final now = DateTime(2026, 10, 27);
  return Product(
    id: 'p1',
    name: 'Riz 25 kg',
    category: ProductCategory.food,
    costPriceInCdf: 2500,
    sellingPriceInCdf: 3000,
    stockQuantity: 10,
    unit: ProductUnit.piece,
    createdAt: now,
    updatedAt: now,
    inputCurrencyCode: 'CDF',
    inputExchangeRate: 1,
    costPriceInInputCurrency: 2500,
    sellingPriceInInputCurrency: 3000,
    syncStatus: 'synced',
  );
}

AtelierOrder _order({
  AtelierOrderStatus status = AtelierOrderStatus.draft,
  double advance = 0,
  String? saleId,
}) => AtelierOrder(
  id: 'ord-1',
  customerId: 'c1',
  customerName: 'Mme Kavira',
  label: 'Robe wax',
  totalAmount: 100,
  advanceAmount: advance,
  currencyCode: 'CDF',
  exchangeRate: 1,
  status: status,
  saleId: saleId,
);

Sale _sale(String id, {SaleStatus status = SaleStatus.completed, String? customerId}) => Sale(
  id: id,
  date: DateTime(2026, 10, 27, 8),
  customerId: customerId,
  customerName: 'Client',
  items: const [],
  totalAmountInCdf: 5000,
  paidAmountInCdf: 5000,
  paymentMethod: 'cash',
  status: status,
  transactionCurrencyCode: 'CDF',
  syncStatus: 'synced',
);

void main() {
  late Directory dossier;

  setUpAll(() async {
    dossier = await Directory.systemTemp.createTemp('wanzo_followups_');
    Hive.init(dossier.path);
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
    if (!Hive.isAdapterRegistered(ProductAdapter().typeId)) {
      Hive.registerAdapter(ProductAdapter());
    }
    if (!Hive.isAdapterRegistered(ProductCategoryAdapter().typeId)) {
      Hive.registerAdapter(ProductCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(ProductUnitAdapter().typeId)) {
      Hive.registerAdapter(ProductUnitAdapter());
    }
    if (!Hive.isAdapterRegistered(StockTransactionAdapter().typeId)) {
      Hive.registerAdapter(StockTransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(StockTransactionTypeAdapter().typeId)) {
      Hive.registerAdapter(StockTransactionTypeAdapter());
    }
  });

  group('fiche atelier : supprimer ou archiver', () {
    test('seul un brouillon sans encaissement se supprime', () {
      expect(atelierOrderDeletable(_order()), isTrue);
      expect(atelierOrderDeletable(_order(status: AtelierOrderStatus.cancelled)), isTrue);
      expect(atelierOrderDeletable(_order(advance: 30)), isFalse, reason: 'avance encaissée');
      expect(atelierOrderDeletable(_order(status: AtelierOrderStatus.paid)), isFalse);
      expect(
        atelierOrderDeletable(_order(status: AtelierOrderStatus.cancelled, saleId: 's1')),
        isFalse,
      );
      expect(atelierOrderDeletable(_order(status: AtelierOrderStatus.sewing)), isFalse);
    });

    test('archiver puis désarchiver, conservé sur l\'appareil', () async {
      AtelierArchive.instance.resetForTest();
      await AtelierArchive.instance.archive('ord-1');
      expect(AtelierArchive.instance.isArchived('ord-1'), isTrue);
      AtelierArchive.instance.resetForTest();
      await AtelierArchive.instance.load();
      expect(AtelierArchive.instance.isArchived('ord-1'), isTrue, reason: 'relu du disque');
      await AtelierArchive.instance.unarchive('ord-1');
      expect(AtelierArchive.instance.isArchived('ord-1'), isFalse);
    });
  });

  group('avance atelier : jamais encaissée deux fois', () {
    test('même commande et même cumul : même localId', () {
      final a = atelierAdvanceLocalId(_order(advance: 30), 30);
      expect(a, atelierAdvanceLocalId(_order(advance: 30), 30));
      expect(a, isNot(atelierAdvanceLocalId(_order(advance: 50), 50)));
      expect(a.length, lessThanOrEqualTo(50), reason: 'colonne localId du serveur');
      final vente = atelierAdvanceSale(order: _order(advance: 30), amount: 30, paymentMethod: 'cash');
      expect(vente.localId, a);
    });
  });

  group('fiche client : ventes annulées à part', () {
    test('listées séparément, hors des ventes du client', () async {
      final repo = SalesRepository();
      await repo.init();
      final box = Hive.box<Sale>('sales');
      await box.clear();
      await box.put('a', _sale('a', customerId: 'c1'));
      await box.put('b', _sale('b', customerId: 'c1', status: SaleStatus.cancelled));
      await box.put('c', _sale('c', customerId: 'c2', status: SaleStatus.cancelled));
      expect((await repo.getSalesByCustomer('c1')).map((s) => s.id), ['a']);
      expect((await repo.getCancelledSalesByCustomer('c1')).map((s) => s.id), ['b']);
    });
  });

  group('vente rétablie encaissée en espèces', () {
    late CashSessionService service;

    setUp(() {
      service = CashSessionService(store: _MemoryStore(), sender: (_, __) async {});
      CashSessionService.instance = service;
      CashReentryFlags.instance.resetForTest();
    });

    test('caisse ouverte : l\'encaissement y est repris', () async {
      await service.open({'CDF': 10000});
      final ok = await cashSessionOnSaleRestored(_sale('v1'));
      expect(ok, isTrue);
      final s = service.current.value!;
      expect(s.expectedCash()['CDF'], 15000);
      expect(s.movements.single.kind, CashMovementKind.sale);
      expect(CashReentryFlags.instance.isFlagged('v1'), isFalse);
    });

    test('aucune caisse ouverte : « Encaissement à reprendre en caisse »', () async {
      final ok = await cashSessionOnSaleRestored(_sale('v2'));
      expect(ok, isFalse);
      expect(CashReentryFlags.instance.isFlagged('v2'), isTrue);
      // La caisse s'ouvre : la reprise lève le signalement.
      await service.open({'CDF': 0});
      expect(await cashSessionOnSaleRestored(_sale('v2')), isTrue);
      expect(CashReentryFlags.instance.isFlagged('v2'), isFalse);
    });

    test('vente à crédit sans acompte : rien à reprendre', () async {
      final credit = _sale('v3').copyWith(paidAmountInCdf: 0, paymentMethod: 'credit');
      expect(await cashSessionOnSaleRestored(credit), isTrue);
      expect(CashReentryFlags.instance.isFlagged('v3'), isFalse);
    });
  });

  group('produit vendu : désactivé, jamais supprimé', () {
    late _FakeInventoryApi api;
    late InventoryRepository repo;

    setUp(() async {
      api = _FakeInventoryApi();
      repo = InventoryRepository(apiService: api);
      await repo.init();
      await Hive.box<Product>('products').clear();
      await Hive.box<StockTransaction>('stock_transactions').clear();
      await Hive.box<Product>('products').put('p1', _product());
    });

    test('sans historique : supprimé', () async {
      expect(repo.productHasHistory('p1'), isFalse);
      expect(await repo.deleteProduct('p1'), isFalse);
      expect(Hive.box<Product>('products').get('p1'), isNull);
    });

    test('vendu : désactivé par le serveur, mouvements conservés', () async {
      await Hive.box<StockTransaction>('stock_transactions').put(
        't1',
        StockTransaction(
          id: 't1',
          productId: 'p1',
          type: StockTransactionType.sale,
          quantity: -2,
          date: DateTime(2026, 10, 27),
          unitCostInCdf: 2500,
          totalValueInCdf: 5000,
        ),
      );
      api.keepsProduct = true;
      expect(repo.productHasHistory('p1'), isTrue);
      expect(await repo.deleteProduct('p1'), isTrue);
      final kept = Hive.box<Product>('products').get('p1');
      expect(kept?.isActive, isFalse, reason: 'gardé, marqué inactif');
      expect(repo.getAllProducts().map((p) => p.id), isEmpty, reason: 'plus vendable');
      expect(repo.getInactiveProducts().map((p) => p.id), ['p1']);
      expect(Hive.box<StockTransaction>('stock_transactions').get('t1'), isNotNull);
    });
  });

  group('produit : réponse deleted et deactivated', () {
    test('200 lu directement, sans relire le produit', () async {
      final api = _FakeInventoryApi()
        ..removal = const ProductRemovalResult(deleted: false, deactivated: true);
      final repo = InventoryRepository(apiService: api);
      await repo.init();
      await Hive.box<Product>('products').clear();
      await Hive.box<Product>('products').put('p1', _product());
      // keepsProduct reste faux : un 204 aurait conclu « supprimé ».
      expect(await repo.deleteProduct('p1'), isTrue);
      expect(Hive.box<Product>('products').get('p1')!.isActive, isFalse);
    });

    test('lecture tolérante de la réponse', () {
      expect(ProductRemovalResult.fromResponse(null), isNull, reason: '204');
      final r = ProductRemovalResult.fromResponse({
        'success': true,
        'data': {'deleted': true, 'deactivated': false},
      })!;
      expect(r.deleted, isTrue);
      expect(r.deactivated, isFalse);
      final json = {..._product().toJson(), 'deactivatedAt': '2026-10-30T10:00:00Z'};
      expect(Product.fromJson(json).isActive, isFalse);
    });
  });

  group('historique d\'audit', () {
    test('réponse paginée, même ré-enveloppée', () {
      final events = parseAuditEvents({
        'success': true,
        'data': {
          'data': [
            {
              'action': 'cancel',
              'actorEmail': 'marie@x.cd',
              'reason': 'Doublon',
              'createdAt': '2026-10-27T09:00:00.000Z',
            },
            {'action': 'restore', 'actorEmail': 'paul@x.cd'},
          ],
          'total': 2,
          'page': 1,
          'pageSize': 50,
          'totalPages': 1,
        },
      });
      expect(events.map((e) => e.label), ['Annulation', 'Rétablissement']);
      expect(events.first.actor, 'marie@x.cd');
      expect(events.first.reason, 'Doublon');
      expect(events.first.at, isNotNull);
    });

    test('réservé à l\'administrateur et au comptable', () {
      expect(canViewAuditHistory('admin'), isTrue);
      expect(canViewAuditHistory('accountant'), isTrue);
      expect(canViewAuditHistory('manager'), isFalse);
      expect(canViewAuditHistory('cashier'), isFalse);
    });

    testWidgets('section repliée, chargée à l\'ouverture', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AuditHistorySection(
                entityType: 'sale',
                entityId: 's1',
                fetch: (q) async {
                  calls++;
                  expect(q['entityType'], 'sale');
                  expect(q['entityId'], 's1');
                  return {
                    'data': [
                      {'action': 'cancel', 'actorEmail': 'marie@x.cd', 'reason': 'Doublon'},
                    ],
                  };
                },
              ),
            ),
          ),
        ),
      );
      expect(calls, 0, reason: 'rien tant que la section est fermée');
      await tester.tap(find.text('Historique'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Annulation par marie@x.cd'), findsOneWidget);
      expect(find.text('Motif : Doublon'), findsOneWidget);
    });
  });
}
