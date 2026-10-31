import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/features/atelier/cubit/atelier_orders_cubit.dart';
import 'package:wanzo/features/atelier/models/atelier_order.dart';
import 'package:wanzo/features/atelier/services/atelier_api_service.dart';
import 'package:wanzo/features/atelier/services/atelier_archive.dart';

AtelierOrder _order(
  String id, {
  AtelierOrderStatus status = AtelierOrderStatus.paid,
  double advance = 0,
  DateTime? archivedAt,
}) => AtelierOrder(
  id: id,
  customerId: 'c1',
  label: 'Robe $id',
  totalAmount: 100,
  advanceAmount: advance,
  status: status,
  archivedAt: archivedAt,
);

/// Serveur atelier simulé.
class _FakeAtelierApi extends Fake implements AtelierApiService {
  List<AtelierOrder> orders = [];
  final archived = <String>[];
  final unarchived = <String>[];
  Object? archiveError;
  Object? deleteError;
  bool? lastIncludeArchived;

  @override
  Future<List<AtelierOrder>> getOrders({
    String? businessUnitId,
    String? status,
    String? customerId,
    String? metier,
    String? vehicleId,
    int? limit,
    int? offset,
    bool includeArchived = false,
  }) async {
    lastIncludeArchived = includeArchived;
    return orders;
  }

  @override
  Future<AtelierOrder> archiveOrder(String id) async {
    archived.add(id);
    if (archiveError != null) throw archiveError!;
    final o = orders.firstWhere((o) => o.id == id);
    return o.copyWith(archivedAt: DateTime(2026, 10, 30), archivedByName: 'Marie');
  }

  @override
  Future<AtelierOrder> unarchiveOrder(String id) async {
    unarchived.add(id);
    return orders.firstWhere((o) => o.id == id).copyWith(clearArchive: true);
  }

  @override
  Future<void> deleteOrder(String id) async {
    if (deleteError != null) throw deleteError!;
  }
}

void main() {
  late _FakeAtelierApi api;
  late AtelierOrdersCubit cubit;

  setUpAll(() async {
    final dossier = await Directory.systemTemp.createTemp('wanzo_atelier_arch_');
    Hive.init(dossier.path);
  });

  setUp(() async {
    api = _FakeAtelierApi();
    cubit = AtelierOrdersCubit(api);
    AtelierArchive.instance.resetForTest();
    if (Hive.isBoxOpen(AtelierArchive.boxName)) {
      await Hive.box(AtelierArchive.boxName).clear();
    }
  });

  tearDown(() => cubit.close());

  test('archivedAt et archivedBy lus sur la fiche du serveur', () {
    final o = AtelierOrder.fromJson({
      'id': 'o1',
      'customerId': 'c1',
      'label': 'Robe',
      'status': 'paid',
      'archivedAt': '2026-10-30T10:00:00.000Z',
      'archivedBy': {'id': 'u1', 'email': 'marie@x.cd', 'name': 'Marie'},
    });
    expect(o.isArchived, isTrue);
    expect(o.archivedByName, 'Marie');
    // Aller-retour du cache local.
    expect(AtelierOrder.fromJson(o.toJson()).isArchived, isTrue);
  });

  test('le tableau lit aussi les fiches archivées', () async {
    await cubit.load();
    expect(api.lastIncludeArchived, isTrue);
  });

  test('archiver puis désarchiver passent par le serveur', () async {
    api.orders = [_order('o1')];
    await cubit.load();
    expect(await cubit.archiveOrder('o1'), isNull);
    expect(api.archived, ['o1']);
    expect(cubit.state.orders.single.isArchived, isTrue);
    expect(cubit.state.orders.single.archivedByName, 'Marie');

    expect(await cubit.unarchiveOrder('o1'), isNull);
    expect(api.unarchived, ['o1']);
    expect(cubit.state.orders.single.isArchived, isFalse);
  });

  test('hors ligne : l\'archivage part en file, la fiche reste archivée', () async {
    api.orders = [_order('o1')];
    await cubit.load();
    api.archiveError = OfflineQueuedException(endpoint: 'atelier/orders/o1/archive');
    final err = await cubit.archiveOrder('o1');
    expect(err, isA<OfflineQueuedException>());
    expect(cubit.state.orders.single.isArchived, isTrue);
  });

  test('refus du serveur : la fiche reprend son état', () async {
    api.orders = [_order('o1')];
    await cubit.load();
    api.archiveError = AuthorizationException('Interdit');
    await cubit.archiveOrder('o1');
    expect(cubit.state.orders.single.isArchived, isFalse);
    expect(cubit.state.error, 'Interdit');
  });

  test('migration : l\'archive de l\'appareil passe au serveur une fois', () async {
    await AtelierArchive.instance.archive('o1');
    await AtelierArchive.instance.archive('o2');
    api.orders = [
      _order('o1'),
      // Déjà archivée sur le serveur : rien à envoyer.
      _order('o2', archivedAt: DateTime(2026, 10, 29)),
    ];
    await cubit.load();
    expect(api.archived, ['o1']);
    expect(AtelierArchive.instance.archived.value, isEmpty);
    expect(cubit.state.orders.every((o) => o.isArchived), isTrue);

    // Second chargement : plus rien à migrer.
    await cubit.load();
    expect(api.archived, ['o1']);
  });

  test('suppression refusée en 409 : message du serveur, fiche conservée', () async {
    api.orders = [_order('o1', status: AtelierOrderStatus.draft)];
    await cubit.load();
    api.deleteError = ServerException(
      'Fiche avec avance encaissée : archivez-la.',
      statusCode: 409,
    );
    final err = await cubit.deleteOrder('o1');
    expect(err, isA<ApiException>());
    expect(cubit.state.error, 'Fiche avec avance encaissée : archivez-la.');
    expect(cubit.state.orders.single.id, 'o1');
  });
}
