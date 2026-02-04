import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:wanzo/features/dashboard/services/dashboard_api_service.dart';
import 'package:wanzo/features/sales/repositories/sales_repository.dart';
import 'package:wanzo/features/customer/repositories/customer_repository.dart';
import 'package:wanzo/features/transactions/repositories/transaction_repository.dart';
import 'package:wanzo/features/expenses/repositories/expense_repository.dart';
import 'package:wanzo/features/sales/models/sale.dart';

// Classes Mock manuelles
class MockSalesRepository extends Mock implements SalesRepository {}
class MockCustomerRepository extends Mock implements CustomerRepository {}
class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockExpenseRepository extends Mock implements ExpenseRepository {}

void main() {
  late MockSalesRepository mockSalesRepository;
  late MockCustomerRepository mockCustomerRepository;
  late MockTransactionRepository mockTransactionRepository;
  late MockExpenseRepository mockExpenseRepository;
  late DashboardApiService dashboardApiService;

  setUp(() {
    mockSalesRepository = MockSalesRepository();
    mockCustomerRepository = MockCustomerRepository();
    mockTransactionRepository = MockTransactionRepository();
    mockExpenseRepository = MockExpenseRepository();

    dashboardApiService = DashboardApiService(
      salesRepository: mockSalesRepository,
      customerRepository: mockCustomerRepository,
      transactionRepository: mockTransactionRepository,
      expenseRepository: mockExpenseRepository,
    );
  });

  group('DashboardApiService', () {
    final testDate = DateTime(2025, 6, 7);
    final startOfDay = DateTime(2025, 6, 7, 0, 0, 0);
    final endOfDay = DateTime(2025, 6, 7, 23, 59, 59);

    test('getDashboardData returns correct data on success', () async {
      // Arrange
      final mockSales = [
        Sale(
          id: '1',
          date: testDate,
          customerName: 'Test Customer',
          items: [],
          totalAmountInCdf: 15000,
          paidAmountInCdf: 15000,
          status: SaleStatus.completed,
          transactionCurrencyCode: 'CDF',
        ),
        Sale(
          id: '2',
          date: testDate,
          customerName: 'Test Customer 2',
          items: [],
          totalAmountInCdf: 5000,
          paidAmountInCdf: 5000,
          status: SaleStatus.completed,
          transactionCurrencyCode: 'USD',
          totalAmountInTransactionCurrency: 5.0,
        ),
      ];

      when(mockSalesRepository.getSalesByDateRange(startOfDay, endOfDay))
          .thenAnswer((_) async => mockSales);
      when(mockCustomerRepository.getUniqueCustomersCountForDateRange(startOfDay, endOfDay))
          .thenAnswer((_) async => 2);
      when(mockSalesRepository.getTotalReceivables())
          .thenAnswer((_) async => 25000.0);
      when(mockExpenseRepository.getExpensesByDateRange(startOfDay, endOfDay))
          .thenAnswer((_) async => []);

      // Act
      final result = await dashboardApiService.getDashboardData(testDate);

      // Assert
      expect(result.success, true);
      expect(result.statusCode, 200);
      expect(result.data, isNotNull);
      expect(result.data!.salesTodayCdf, 15000.0);
      expect(result.data!.salesTodayUsd, 5.0);
      expect(result.data!.clientsServedToday, 2);
      expect(result.data!.receivables, 25000.0);
      expect(result.data!.expenses, 0.0);
    });

    test('getDashboardData handles errors gracefully', () async {
      // Arrange
      when(mockSalesRepository.getSalesByDateRange(startOfDay, endOfDay))
          .thenThrow(Exception('Database error'));

      // Act
      final result = await dashboardApiService.getDashboardData(testDate);

      // Assert
      expect(result.success, false);
      expect(result.statusCode, 500);
      expect(result.data, isNull);
      expect(result.error, contains('Exception: Database error'));
    });

    test('getSalesToday returns correct sales amounts', () async {
      // Arrange
      final mockSales = [
        Sale(
          id: '1',
          date: testDate,
          customerName: 'Test Customer',
          items: [],
          totalAmountInCdf: 15000,
          paidAmountInCdf: 15000,
          status: SaleStatus.completed,
          transactionCurrencyCode: 'CDF',
        ),
        Sale(
          id: '2',
          date: testDate,
          customerName: 'Test Customer 2',
          items: [],
          totalAmountInCdf: 5000,
          paidAmountInCdf: 5000,
          status: SaleStatus.completed,
          transactionCurrencyCode: 'USD',
          totalAmountInTransactionCurrency: 5.0,
        ),
      ];

      when(mockSalesRepository.getSalesByDateRange(startOfDay, endOfDay))
          .thenAnswer((_) async => mockSales);

      // Act
      final result = await dashboardApiService.getSalesToday(testDate);

      // Assert
      expect(result.success, true);
      expect(result.data!['cdf'], 15000.0);
      expect(result.data!['usd'], 5.0);
    });

    test('getClientsServedToday returns correct count', () async {
      // Arrange
      when(mockCustomerRepository.getUniqueCustomersCountForDateRange(startOfDay, endOfDay))
          .thenAnswer((_) async => 3);

      // Act
      final result = await dashboardApiService.getClientsServedToday(testDate);

      // Assert
      expect(result.success, true);
      expect(result.data, 3);
    });

    test('getTotalReceivables returns correct amount', () async {
      // Arrange
      when(mockSalesRepository.getTotalReceivables())
          .thenAnswer((_) async => 30000.0);

      // Act
      final result = await dashboardApiService.getTotalReceivables();

      // Assert
      expect(result.success, true);
      expect(result.data, 30000.0);
    });

    test('getExpensesToday returns correct expenses', () async {
      // Arrange
      when(mockExpenseRepository.getExpensesByDateRange(startOfDay, endOfDay))
          .thenAnswer((_) async => []);

      // Act
      final result = await dashboardApiService.getExpensesToday(testDate);

      // Assert
      expect(result.success, true);
      expect(result.data, 0.0);
    });
  });
}
