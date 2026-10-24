import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:wanzo/core/enums/business_unit_enums.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/services/image_upload_service.dart';
import 'package:wanzo/features/inventory/models/product.dart';
import 'package:wanzo/features/inventory/models/stock_transaction.dart';
import 'package:wanzo/features/inventory/repositories/inventory_repository.dart';
import 'package:wanzo/features/inventory/services/inventory_api_service.dart';
import 'package:wanzo/features/inventory/services/restock_awaiting_expense.dart';

/// Un appel HTTP enregistré par le client factice.
class _Appel {
  final String methode;
  final String chemin;
  final dynamic corps;
  final Map<Symbol, dynamic> options;
  _Appel(this.methode, this.chemin, this.corps, this.options);
}

/// Client HTTP factice : enregistre chaque appel et répond selon [repondre].
class _ClientFactice implements ApiClient {
  final List<_Appel> appels = [];
  dynamic Function(_Appel appel) repondre = (_) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    const methodes = {
      #get: 'GET',
      #post: 'POST',
      #patch: 'PATCH',
      #put: 'PUT',
      #delete: 'DELETE',
    };
    final nom = invocation.memberName;
    if (!methodes.containsKey(nom)) return super.noSuchMethod(invocation);
    final appel = _Appel(
      methodes[nom]!,
      invocation.positionalArguments.first as String,
      invocation.namedArguments[#body],
      invocation.namedArguments,
    );
    appels.add(appel);
    return Future<dynamic>(() => repondre(appel));
  }
}

/// Aucun envoi d'image dans ces tests (évite Cloudinary et dotenv).
class _ImagesFactices implements ImageUploadService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _champsServeur = {
  'localId',
  'productId',
  'type',
  'quantity',
  'date',
  'referenceId',
  'notes',
  'unitCostPrice',
  'locationId',
  'expenseId',
};

Product _article({double stock = 10, String syncStatus = 'synced'}) {
  final now = DateTime(2026, 10, 17);
  return Product(
    id: 'p1',
    name: 'Riz 25 kg',
    category: ProductCategory.food,
    costPriceInCdf: 2500,
    sellingPriceInCdf: 3000,
    stockQuantity: stock,
    unit: ProductUnit.piece,
    createdAt: now,
    updatedAt: now,
    inputCurrencyCode: 'CDF',
    inputExchangeRate: 1,
    costPriceInInputCurrency: 2500,
    sellingPriceInInputCurrency: 3000,
    syncStatus: syncStatus,
  );
}

StockTransaction _mouvement(
  StockTransactionType type,
  double quantite, {
  String? referenceId,
}) =>
    StockTransaction(
      id: '',
      productId: 'p1',
      type: type,
      quantity: quantite,
      date: DateTime.utc(2026, 10, 17, 9),
      referenceId: referenceId,
      notes: 'Mouvement',
      unitCostInCdf: 2500,
      totalValueInCdf: 2500 * quantite.abs(),
      currencyCode: 'CDF',
    );

void main() {
  group('règle de sens et corps exact', () {
    test('seul l ajustement garde son signe, sinon le type décide', () {
      expect(_mouvement(StockTransactionType.damaged, 3).stockDelta, -3);
      expect(_mouvement(StockTransactionType.lost, -2).stockDelta, -2);
      expect(_mouvement(StockTransactionType.sale, -4).stockDelta, -4);
      expect(_mouvement(StockTransactionType.purchase, 5).stockDelta, 5);
      expect(_mouvement(StockTransactionType.adjustment, -4).stockDelta, -4);
      expect(_mouvement(StockTransactionType.adjustment, 6).stockDelta, 6);
    });

    test('corps : liste blanche du DTO, ajustement signé, coût nul omis', () {
      final ajustement =
          _mouvement(StockTransactionType.adjustment, -2).toApiPayload();
      expect(_champsServeur.containsAll(ajustement.keys), isTrue);
      expect(ajustement['quantity'], -2);
      expect(ajustement.containsKey('unitCostInCdf'), isFalse);
      expect(ajustement['unitCostPrice'], 2500);

      final perte = _mouvement(StockTransactionType.lost, -3).toApiPayload();
      expect(perte['quantity'], 3, reason: 'le type porte la sortie');

      final sansCout = StockTransaction(
        id: 'x',
        productId: 'p1',
        type: StockTransactionType.adjustment,
        quantity: 1,
        date: DateTime.utc(2026),
        unitCostInCdf: 0,
        totalValueInCdf: 0,
      ).toApiPayload();
      expect(sansCout.containsKey('unitCostPrice'), isFalse);
      expect(sansCout.containsKey('notes'), isFalse);
    });

    test('lecture serveur : décimaux en texte, page enveloppée', () async {
      final http = _ClientFactice()
        ..repondre = (_) => {
              'success': true,
              'data': {
                'data': [
                  {
                    'id': 's1',
                    'productId': 'p1',
                    'type': 'purchase',
                    'quantity': '10.00',
                    'unitCostPrice': '2500.00',
                    'date': '2026-10-17T09:00:00.000Z',
                  },
                ],
                'total': 1,
              },
            };
      final api = InventoryApiServiceImpl(
        http,
        imageUploadService: _ImagesFactices(),
      );
      final res = await api.getStockTransactions(productId: 'p1');
      expect(res.success, isTrue);
      expect(res.data!.single.quantity, 10);
      expect(res.data!.single.totalValueInCdf, 25000);
    });
  });

  group('voie serveur unique stock-transactions', () {
    late Directory dossier;
    late _ClientFactice http;
    late InventoryRepository repo;

    setUpAll(() {
      if (!Hive.isAdapterRegistered(22)) Hive.registerAdapter(ProductAdapter());
      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(ProductCategoryAdapter());
      }
      if (!Hive.isAdapterRegistered(21)) {
        Hive.registerAdapter(ProductUnitAdapter());
      }
      if (!Hive.isAdapterRegistered(33)) {
        Hive.registerAdapter(StockTransactionAdapter());
      }
      if (!Hive.isAdapterRegistered(32)) {
        Hive.registerAdapter(StockTransactionTypeAdapter());
      }
      if (!Hive.isAdapterRegistered(71)) {
        Hive.registerAdapter(BusinessUnitTypeAdapter());
      }
    });

    setUp(() async {
      dossier = await Directory.systemTemp.createTemp('wanzo_stock_');
      Hive.init(dossier.path);
      http = _ClientFactice();
      repo = InventoryRepository(
        apiService: InventoryApiServiceImpl(
          http,
          imageUploadService: _ImagesFactices(),
        ),
      );
      await repo.init();
    });

    tearDown(() async {
      await Hive.close();
      await dossier.delete(recursive: true);
    });

    Future<void> poserArticle(Product p) async {
      await Hive.box<Product>('products').put(p.id, p);
    }

    test('produit créé hors ligne : ses écritures en file attendent sa création',
        () async {
      await poserArticle(_article(syncStatus: 'pending'));
      expect(
        InventoryRepository.productAwaitingCreation(
            'PATCH', 'products/p1', {'name': 'x'}),
        isTrue,
      );
      expect(
        InventoryRepository.productAwaitingCreation(
            'POST', 'stock-transactions', {'productId': 'p1'}),
        isTrue,
      );
      await poserArticle(_article(syncStatus: 'synced'));
      expect(
        InventoryRepository.productAwaitingCreation(
            'PATCH', 'products/p1', {'name': 'x'}),
        isFalse,
      );
    });

    test('modifier un produit jamais envoyé : aucun PATCH (404 garanti)',
        () async {
      await poserArticle(_article(syncStatus: 'pending'));
      final maj = await repo.updateProduct(
        _article(syncStatus: 'pending').copyWith(name: 'Riz 50 kg'),
      );
      expect(http.appels, isEmpty);
      expect(maj.syncStatus, 'pending');
      expect(repo.getProductById('p1')!.name, 'Riz 50 kg');
    });

    test('mouvement envoyé avec son localId (dédupliqué au rejeu)', () async {
      await poserArticle(_article(stock: 10));
      http.repondre = (_) => {
            'success': true,
            'data': {'id': 'srv-1'},
          };
      await repo.recordStockMovement(
        _mouvement(StockTransactionType.damaged, 1),
      );
      final corps = http.appels.single.corps as Map;
      expect(corps['localId'], isNotEmpty);
    });

    test('retrait accepté : corps envoyé puis stock baissé', () async {
      await poserArticle(_article(stock: 10));
      http.repondre = (_) => {
            'success': true,
            'data': {'id': 'srv-42'},
          };

      final enregistre = await repo.recordStockMovement(
        _mouvement(StockTransactionType.adjustment, -3),
      );

      final post = http.appels.single;
      expect(post.methode, 'POST');
      expect(post.chemin, 'stock-transactions');
      final corps = post.corps as Map<String, dynamic>;
      expect(_champsServeur.containsAll(corps.keys), isTrue, reason: '$corps');
      expect(corps['type'], 'adjustment');
      expect(corps['quantity'], -3, reason: 'ajustement signé');
      expect(corps['productId'], 'p1');
      expect(enregistre.id, 'srv-42');
      expect(repo.getProductById('p1')!.stockQuantity, 7);
    });

    test('« endommagé » saisi en positif : le stock baisse', () async {
      await poserArticle(_article(stock: 10));
      http.repondre = (_) => {
            'success': true,
            'data': {'id': 'srv-1'},
          };
      await repo.recordStockMovement(
        _mouvement(StockTransactionType.damaged, 2),
      );
      expect((http.appels.single.corps as Map)['quantity'], 2);
      expect(repo.getProductById('p1')!.stockQuantity, 8);
    });

    test('refus serveur : rien sur l appareil, motif lisible', () async {
      await poserArticle(_article(stock: 10));
      http.repondre = (_) => throw BadRequestException(
            'Insufficient stock for product "Riz". Available: 1, Requested: 3',
          );

      await expectLater(
        repo.recordStockMovement(
          _mouvement(StockTransactionType.adjustment, -3),
        ),
        throwsA(
          isA<StockRefusedException>().having(
            (e) => e.message,
            'message',
            'Stock insuffisant sur le serveur pour cet article.',
          ),
        ),
      );
      expect(repo.getProductById('p1')!.stockQuantity, 10);
      expect(repo.getAllTransactions(), isEmpty);
    });

    test('hors ligne (mis en file) : appliqué sur l appareil', () async {
      await poserArticle(_article(stock: 10));
      http.repondre = (_) => throw OfflineQueuedException();
      await repo.recordStockMovement(
        _mouvement(StockTransactionType.lost, 1),
      );
      expect(repo.getProductById('p1')!.stockQuantity, 9);
      expect(repo.getProductById('p1')!.syncStatus, 'synced');
    });

    test('serveur indisponible : appliqué, fiche à renvoyer', () async {
      await poserArticle(_article(stock: 10));
      http.repondre = (_) => throw ServerException('boom', statusCode: 503);
      await repo.recordStockMovement(
        _mouvement(StockTransactionType.lost, 1),
      );
      expect(repo.getProductById('p1')!.stockQuantity, 9);
      expect(repo.getProductById('p1')!.syncStatus, 'pending_update');
    });

    test('article jamais envoyé : pas d appel, la création portera le stock',
        () async {
      await poserArticle(_article(stock: 10, syncStatus: 'pending'));
      await repo.recordStockMovement(
        _mouvement(StockTransactionType.lost, 1),
      );
      expect(http.appels, isEmpty);
      expect(repo.getProductById('p1')!.stockQuantity, 9);
    });

    test('création d article : stock initial compté une seule fois', () async {
      http.repondre = (_) => throw NetworkException('hors ligne');
      final cree = await repo.addProduct(_article(stock: 12));
      expect(cree.stockQuantity, 12);
      final initial = repo.getAllTransactions().single;
      expect(initial.type, StockTransactionType.initialStock);
      expect(initial.quantity, 12);
    });

    test('rafraîchissement : toutes les pages, purge après lecture complète',
        () async {
      await poserArticle(_article(stock: 1).copyWith(id: 'supprime'));
      await poserArticle(
        _article(stock: 1, syncStatus: 'pending').copyWith(id: 'local'),
      );
      Map<String, dynamic> json(String id) => {
            ..._article().copyWith(id: id).toJson(),
            'stockQuantity': 5,
          };
      http.repondre = (a) {
        final q = a.options[#queryParameters] as Map<String, String>;
        final page = int.parse(q['page']!);
        final n = page == 1 ? 200 : 3;
        return {
          'success': true,
          'data': {
            'data': [for (var i = 0; i < n; i++) json('srv-$page-$i')],
            'total': 203,
          },
        };
      };
      final liste = await repo.syncProductsFromApi();
      expect(http.appels.length, 2);
      expect(
        (http.appels.first.options[#queryParameters] as Map)['limit'],
        '200',
      );
      final ids = liste.map((p) => p.id).toSet();
      expect(ids.length, 204);
      expect(ids.contains('supprime'), isFalse);
      expect(ids.contains('local'), isTrue);
    });

    group('réapprovisionnement : dépense puis entrée liée', () {
      test('dépense sur le serveur : achat envoyé avec expenseId', () async {
        await poserArticle(_article(stock: 4));
        http.repondre = (_) => {
              'success': true,
              'data': {'id': 'mvt-1'},
            };
        await repo.recordStockMovement(
          _mouvement(
            StockTransactionType.purchase,
            6,
            referenceId: 'dep-srv-1',
          ),
          expenseId: 'dep-srv-1',
        );
        final corps = http.appels.single.corps as Map<String, dynamic>;
        expect(corps['type'], 'purchase');
        expect(corps['quantity'], 6);
        expect(corps['expenseId'], 'dep-srv-1',
            reason: 'le serveur ne passe que 311 / 6031');
        expect(corps['referenceId'], 'dep-srv-1');
        expect(repo.getProductById('p1')!.stockQuantity, 10);
      });

      test('dépense hors ligne : entrée retenue puis envoyée avec son id',
          () async {
        await poserArticle(_article(stock: 4));
        await repo.recordStockMovement(
          _mouvement(
            StockTransactionType.purchase,
            6,
            referenceId: 'dep-local-1',
          ),
          awaitingExpenseId: 'dep-local-1',
        );
        // Rien n'est parti : l'achat attend l'identifiant serveur.
        expect(http.appels, isEmpty);
        expect(repo.getProductById('p1')!.stockQuantity, 10);
        expect(await RestockAwaitingExpense.pendingFor('dep-local-1'),
            isNotNull);

        // La synchronisation des dépenses connaît l'id serveur : libération.
        http.repondre = (_) => {
              'success': true,
              'data': {'id': 'mvt-2'},
            };
        await RestockAwaitingExpense.release(
          'dep-local-1',
          'dep-srv-9',
          api: InventoryApiServiceImpl(
            http,
            imageUploadService: _ImagesFactices(),
          ),
        );
        final corps = http.appels.single.corps as Map<String, dynamic>;
        expect(http.appels.single.chemin, 'stock-transactions');
        expect(corps['expenseId'], 'dep-srv-9');
        expect(corps['referenceId'], 'dep-srv-9');
        expect(corps['type'], 'purchase');
        expect(await RestockAwaitingExpense.pendingFor('dep-local-1'), isNull);
        // Le stock local n'est pas recompté à la libération.
        expect(repo.getProductById('p1')!.stockQuantity, 10);
      });

      test('libération refusée : entrée gardée pour la prochaine synchro',
          () async {
        await poserArticle(_article(stock: 4));
        await repo.recordStockMovement(
          _mouvement(StockTransactionType.purchase, 6),
          awaitingExpenseId: 'dep-local-2',
        );
        http.repondre = (_) => throw BadRequestException('Product not found');
        await RestockAwaitingExpense.release(
          'dep-local-2',
          'dep-srv-2',
          api: InventoryApiServiceImpl(
            http,
            imageUploadService: _ImagesFactices(),
          ),
        );
        expect(await RestockAwaitingExpense.pendingFor('dep-local-2'),
            isNotNull);
      });
    });
  });
}
