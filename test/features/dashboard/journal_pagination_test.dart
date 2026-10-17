import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/dashboard/repositories/operation_journal_repository.dart';

/// Pagination du journal : le backend (ListBusinessOperationsDto) renvoie 10
/// éléments par défaut ; l'app doit demander toutes les pages.
void main() {
  /// Réponse telle que reçue après ApiResponseInterceptor :
  /// {success, data: {status, data: {items, totalItems, totalPages, currentPage}}}.
  Map<String, dynamic> envelope(List<Map<String, dynamic>> items, int page, int totalPages) => {
    'success': true,
    'data': {
      'status': 'success',
      'data': {
        'items': items,
        'totalItems': 0,
        'totalPages': totalPages,
        'currentPage': page,
      },
    },
  };

  List<Map<String, dynamic>> items(int from, int count) =>
      [for (var i = from; i < from + count; i++) {'id': 'op-$i'}];

  test('toutes les pages sont lues, avec page et limit envoyés', () async {
    final queries = <Map<String, dynamic>>[];
    final result = await fetchAllJournalPages(
      (query) async {
        queries.add(query);
        final page = query['page'] as int;
        // 2 pages pleines puis une page incomplète.
        if (page < 3) return envelope(items((page - 1) * 3, 3), page, 3);
        return envelope(items(6, 1), page, 3);
      },
      {'dateFrom': 'a', 'dateTo': 'b'},
      pageSize: 3,
    );

    expect(result!.length, 7);
    expect(queries.length, 3);
    expect(queries.first, {'dateFrom': 'a', 'dateTo': 'b', 'page': 1, 'limit': 3});
    expect(queries.last['page'], 3);
  });

  test('arrêt à totalPages même si la dernière page est pleine', () async {
    var calls = 0;
    final result = await fetchAllJournalPages(
      (query) async {
        calls++;
        return envelope(items(calls * 10, 2), calls, 2);
      },
      const {},
      pageSize: 2,
    );
    expect(calls, 2);
    expect(result!.length, 4);
  });

  test('réponse sans liste : null, l\'appelant garde le cache local', () async {
    final result = await fetchAllJournalPages(
      (query) async => <String, dynamic>{},
      const {},
    );
    expect(result, isNull);
  });

  test('une erreur sur une page suivante remonte (pas de cache partiel)',
      () async {
    expect(
      fetchAllJournalPages(
        (query) async {
          if (query['page'] == 2) throw Exception('réseau');
          return envelope(items(0, 2), 1, 5);
        },
        const {},
        pageSize: 2,
      ),
      throwsException,
    );
  });
}
