// Synchronisation : le serveur plafonne ses listes (10 par défaut). La
// synchro doit lire toutes les pages, et ne purger le local qu'après une
// lecture complète.

import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/core/services/sync_service.dart';

void main() {
  test('lit toutes les pages jusqu a une page incomplete', () async {
    final pages = <int>[];
    final result = await SyncService.fetchAllPages<int>((page, limit) async {
      pages.add(page);
      final count = page < 3 ? limit : 4;
      return ApiResponse(
        success: true,
        data: List.generate(count, (i) => page * 1000 + i),
      );
    }, pageSize: 10);

    expect(pages, [1, 2, 3]);
    expect(result.response.success, isTrue);
    expect(result.response.data, hasLength(24));
    expect(result.completed, isTrue);
  });

  test('echec en cours de route : donnees partielles, pas de purge', () async {
    final result = await SyncService.fetchAllPages<int>((page, limit) async {
      if (page == 2) return ApiResponse(success: false, message: 'coupure');
      return ApiResponse(success: true, data: List.filled(limit, page));
    }, pageSize: 10);

    expect(result.response.success, isTrue);
    expect(result.response.data, hasLength(10));
    expect(result.completed, isFalse);
  });

  test('echec des la premiere page : echec signale', () async {
    final result = await SyncService.fetchAllPages<int>(
      (page, limit) async => ApiResponse(success: false, message: 'hors ligne'),
    );

    expect(result.response.success, isFalse);
    expect(result.response.data, isNull);
    expect(result.completed, isFalse);
  });

  test('plafond de pages atteint : jamais considere comme complet', () async {
    final result = await SyncService.fetchAllPages<int>(
      (page, limit) async => ApiResponse(success: true, data: List.filled(limit, 1)),
      pageSize: 5,
      maxPages: 3,
    );

    expect(result.response.data, hasLength(15));
    expect(result.completed, isFalse);
  });
}
