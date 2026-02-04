import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/features/dashboard/models/operation_journal_entry.dart';
import 'package:wanzo/features/dashboard/repositories/operation_journal_repository.dart';
import 'package:wanzo/core/services/api_service.dart'; // Added import
import 'package:mocktail/mocktail.dart';
import 'dart:io';

class MockApiService extends Mock implements ApiService {}

void main() {
  group('OperationJournalRepository Persistence', () {
    late OperationJournalRepository repository;
    late Directory tempDir;
    late MockApiService mockApiService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp();
      Hive.init(tempDir.path);

      // Register adapters
      if (!Hive.isAdapterRegistered(30)) {
        Hive.registerAdapter(OperationTypeAdapter());
      }
      if (!Hive.isAdapterRegistered(31)) {
        Hive.registerAdapter(OperationJournalEntryAdapter());
      }

      mockApiService = MockApiService();
      repository = OperationJournalRepository(apiService: mockApiService);
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('should persist operation and retrieve it after restart', () async {
      // 1. Initialize repository
      await repository.init();

      // 2. Add an operation
      final entry = OperationJournalEntry(
        id: 'test-id-1',
        date: DateTime.now(),
        description: 'Test Operation',
        type: OperationType.saleCash,
        amount: 100.0,
        currencyCode: 'CDF',
        isDebit: false,
        isCredit: true,
        balanceAfter: 100.0,
        balancesByCurrency: {'CDF': 100.0},
      );

      await repository.addOperation(entry);

      // 3. Verify it's in memory
      var operations = await repository.getOperations(
        DateTime.now().subtract(const Duration(days: 1)),
        DateTime.now().add(const Duration(days: 1)),
      );
      expect(operations.length, 1);
      expect(operations.first.id, 'test-id-1');

      // 4. Simulate app restart (close box and re-init repository)
      // We can't easily "close" the repository, but we can create a new one
      // and init it. Since Hive box is persistent in tempDir, it should load.

      // Close the box to simulate app close (optional, but good practice)
      // await Hive.box<OperationJournalEntry>('operation_journal_entries').close();

      final newRepository = OperationJournalRepository(
        apiService: mockApiService,
      );
      await newRepository.init();

      // 5. Verify data is loaded
      operations = await newRepository.getOperations(
        DateTime.now().subtract(const Duration(days: 1)),
        DateTime.now().add(const Duration(days: 1)),
      );

      expect(operations.length, 1);
      expect(operations.first.id, 'test-id-1');
      expect(operations.first.description, 'Test Operation');
    });
  });
}
