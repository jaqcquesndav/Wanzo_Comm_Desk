import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/features/atelier/cubit/atelier_orders_cubit.dart';
import 'package:wanzo/features/atelier/models/atelier_order.dart';
import 'package:wanzo/features/atelier/repositories/atelier_order_cache.dart';
import 'package:wanzo/features/atelier/services/atelier_api_service.dart';

/// Le serveur sert les fiches par pages (limit/offset) : le board lit la
/// premiere page puis « Charger plus » demande la suivante.
class _FakeApi implements AtelierApiService {
  _FakeApi(this.total);
  final int total;
  final calls = <Map<String, int?>>[];

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
    calls.add({'limit': limit, 'offset': offset});
    final start = offset ?? 0;
    final end = (start + (limit ?? 200)).clamp(0, total);
    return [
      for (var i = start; i < end; i++)
        AtelierOrder(id: 'o$i', customerId: 'c', label: 'Fiche $i'),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryCache extends AtelierOrderCache {
  List<AtelierOrder> saved = const [];
  @override
  Future<void> save(String? businessUnitId, List<AtelierOrder> orders,
      {String? metier}) async {
    saved = orders;
  }

  @override
  Future<List<AtelierOrder>> load(String? businessUnitId,
          {String? metier}) async =>
      saved;
}

void main() {
  // Le chargement migre l'ancienne archive locale (boîte Hive).
  setUpAll(() async {
    final dossier = await Directory.systemTemp.createTemp('wanzo_atelier_pages_');
    Hive.init(dossier.path);
  });

  test('premiere page puis Charger plus jusqu a la fin', () async {
    final api = _FakeApi(5);
    final cubit = AtelierOrdersCubit(api, cache: _MemoryCache(), pageSize: 2);

    await cubit.load();
    expect(cubit.state.orders.map((o) => o.id), ['o0', 'o1']);
    expect(cubit.state.hasMore, isTrue);

    await cubit.loadMore();
    await cubit.loadMore();
    expect(cubit.state.orders.length, 5);
    expect(cubit.state.hasMore, isFalse);
    expect(api.calls.map((c) => c['offset']), [null, 2, 4]);
    expect(api.calls.every((c) => c['limit'] == 2), isTrue);

    // Fin atteinte : plus aucun appel.
    await cubit.loadMore();
    expect(api.calls.length, 3);
    await cubit.close();
  });

  test('une page courte signale la fin des la premiere lecture', () async {
    final cubit = AtelierOrdersCubit(_FakeApi(1), cache: _MemoryCache(), pageSize: 2);
    await cubit.load();
    expect(cubit.state.hasMore, isFalse);
    await cubit.close();
  });
}
