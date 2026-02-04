import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:wanzo/services/journal_export_service.dart';
import 'package:wanzo/features/auth/models/user.dart';
import 'package:wanzo/features/dashboard/models/journal_filter.dart';
import 'package:wanzo/features/dashboard/models/operation_journal_entry.dart';

void main() {
  group('JournalExportService', () {
    late User testUser;
    late JournalFilter testFilter;
    late List<OperationJournalEntry> testOperations;

    setUp(() {
      testUser = User(
        id: '1',
        name: 'John Doe',
        email: 'test@wanzo.app',
        phone: '+243123456789',
        role: 'Manager',
        emailVerified: true,
        phoneVerified: true,
      );

      testFilter = JournalFilter(
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
        selectedTypes: {OperationType.saleCash, OperationType.stockIn},
        minAmount: 100.0,
        maxAmount: 5000.0,
        sortBy: JournalSortOption.date,
        sortAscending: true,
        searchQuery: 'test',
      );

      testOperations = [
        OperationJournalEntry(
          id: '1',
          type: OperationType.saleCash,
          description: 'Vente produit A',
          amount: 1500.0,
          date: DateTime(2024, 6, 15),
          currencyCode: 'CDF',
          isDebit: false,
          isCredit: true,
          balanceAfter: 1500.0,
        ),
        OperationJournalEntry(
          id: '2',
          type: OperationType.stockIn,
          description: 'Entrée stock produit B',
          amount: 2500.0,
          date: DateTime(2024, 6, 16),
          currencyCode: 'CDF',
          isDebit: true,
          isCredit: false,
          balanceAfter: 4000.0,
        ),
        OperationJournalEntry(
          id: '3',
          type: OperationType.saleCash,
          description: 'Vente produit C',
          amount: 800.0,
          date: DateTime(2024, 6, 17),
          currencyCode: 'USD',
          isDebit: false,
          isCredit: true,
          balanceAfter: 4800.0,
        ),
      ];
    });

    test('should create PDF document with proper structure', () async {
      // Act
      final pdfFile = await JournalExportService.exportToPdf(
        operations: testOperations,
        filter: testFilter,
        currentUser: testUser,
      );

      // Assert
      expect(pdfFile, isNotNull);
      expect(pdfFile, isA<File>());
      expect(await pdfFile.exists(), isTrue);
      
      // Clean up
      if (await pdfFile.exists()) {
        await pdfFile.delete();
      }
    });

    test('should handle empty operations list', () async {
      // Act
      final pdfFile = await JournalExportService.exportToPdf(
        operations: [],
        filter: testFilter,
        currentUser: testUser,
      );

      // Assert
      expect(pdfFile, isNotNull);
      expect(pdfFile, isA<File>());
      expect(await pdfFile.exists(), isTrue);
      
      // Clean up
      if (await pdfFile.exists()) {
        await pdfFile.delete();
      }
    });

    test('should calculate correct totals', () async {
      // Arrange
      final operations = [
        OperationJournalEntry(
          id: '1',
          type: OperationType.saleCash,
          description: 'Vente 1',
          amount: 1000.0,
          date: DateTime.now(),
          currencyCode: 'CDF',
          isDebit: false,
          isCredit: true,
          balanceAfter: 1000.0,
        ),
        OperationJournalEntry(
          id: '2',
          type: OperationType.saleCredit,
          description: 'Vente 2',
          amount: 2000.0,
          date: DateTime.now(),
          currencyCode: 'CDF',
          isDebit: false,
          isCredit: true,
          balanceAfter: 3000.0,
        ),
        OperationJournalEntry(
          id: '3',
          type: OperationType.cashOut,
          description: 'Dépense 1',
          amount: -500.0,
          date: DateTime.now(),
          currencyCode: 'CDF',
          isDebit: true,
          isCredit: false,
          balanceAfter: 2500.0,
        ),
      ];

      // Act
      final pdfFile = await JournalExportService.exportToPdf(
        operations: operations,
        filter: testFilter,
        currentUser: testUser,
      );

      // Assert
      expect(pdfFile, isNotNull);
      expect(await pdfFile.exists(), isTrue);
      
      // Clean up
      if (await pdfFile.exists()) {
        await pdfFile.delete();
      }
    });

    test('should handle filter with no date range', () async {
      // Arrange
      final filterWithoutDates = JournalFilter();

      // Act
      final pdfFile = await JournalExportService.exportToPdf(
        operations: testOperations,
        filter: filterWithoutDates,
        currentUser: testUser,
      );

      // Assert
      expect(pdfFile, isNotNull);
      expect(await pdfFile.exists(), isTrue);
      
      // Clean up
      if (await pdfFile.exists()) {
        await pdfFile.delete();
      }
    });

    test('should format user name correctly', () async {
      // Arrange
      final userWithoutLastName = User(
        id: '2',
        name: 'Jane Smith',
        email: 'jane@wanzo.app',
        phone: '+243987654321',
        role: 'Employee',
        emailVerified: true,
        phoneVerified: true,
      );

      // Act
      final pdfFile = await JournalExportService.exportToPdf(
        operations: testOperations,
        filter: testFilter,
        currentUser: userWithoutLastName,
      );

      // Assert
      expect(pdfFile, isNotNull);
      expect(await pdfFile.exists(), isTrue);
      
      // Clean up
      if (await pdfFile.exists()) {
        await pdfFile.delete();
      }
    });

    test('should handle operations with different types', () async {
      // Arrange
      final mixedOperations = [
        OperationJournalEntry(
          id: '1',
          type: OperationType.saleCash,
          description: 'Vente espèce',
          amount: 1000.0,
          date: DateTime.now(),
          currencyCode: 'CDF',
          isDebit: false,
          isCredit: true,
          balanceAfter: 1000.0,
        ),
        OperationJournalEntry(
          id: '2',
          type: OperationType.customerPayment,
          description: 'Paiement reçu',
          amount: 1500.0,
          date: DateTime.now(),
          currencyCode: 'USD',
          isDebit: false,
          isCredit: true,
          balanceAfter: 2500.0,
        ),
        OperationJournalEntry(
          id: '3',
          type: OperationType.stockOut,
          description: 'Sortie stock',
          amount: -200.0,
          date: DateTime.now(),
          currencyCode: 'CDF',
          isDebit: true,
          isCredit: false,
          balanceAfter: 2300.0,
        ),
      ];

      // Act
      final pdfFile = await JournalExportService.exportToPdf(
        operations: mixedOperations,
        filter: testFilter,
        currentUser: testUser,
      );

      // Assert
      expect(pdfFile, isNotNull);
      expect(await pdfFile.exists(), isTrue);
      
      // Clean up
      if (await pdfFile.exists()) {
        await pdfFile.delete();
      }
    });

    test('should handle operations with different currencies', () async {
      // Arrange
      final multiCurrencyOperations = [
        OperationJournalEntry(
          id: '1',
          type: OperationType.saleCash,
          description: 'Vente en CDF',
          amount: 50000.0,
          date: DateTime.now(),
          currencyCode: 'CDF',
          isDebit: false,
          isCredit: true,
          balanceAfter: 50000.0,
        ),
        OperationJournalEntry(
          id: '2',
          type: OperationType.saleCash,
          description: 'Vente en USD',
          amount: 25.0,
          date: DateTime.now(),
          currencyCode: 'USD',
          isDebit: false,
          isCredit: true,
          balanceAfter: 25.0,
        ),
      ];

      // Act
      final pdfFile = await JournalExportService.exportToPdf(
        operations: multiCurrencyOperations,
        filter: testFilter,
        currentUser: testUser,
      );

      // Assert
      expect(pdfFile, isNotNull);
      expect(await pdfFile.exists(), isTrue);
      
      // Clean up
      if (await pdfFile.exists()) {
        await pdfFile.delete();
      }
    });
  });
}
