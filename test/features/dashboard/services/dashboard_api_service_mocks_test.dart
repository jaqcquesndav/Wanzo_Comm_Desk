import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/dashboard/services/dashboard_api_service.dart';
import 'package:wanzo/features/sales/repositories/sales_repository.dart';
import 'package:wanzo/features/customer/repositories/customer_repository.dart';
import 'package:wanzo/features/transactions/repositories/transaction_repository.dart';
import 'package:wanzo/features/expenses/repositories/expense_repository.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/expenses/models/expense.dart';

// Manual mock implementations
class MockSalesRepository implements SalesRepository {
  // Use different field names to avoid conflicts
  Future<List<Sale>> Function(DateTime, DateTime)? _mockGetSalesByDateRange;
  Future<double> Function()? _mockGetTotalReceivables;

  // Set mock implementations
  void setupGetSalesByDateRange(Future<List<Sale>> Function(DateTime, DateTime) mock) {
    _mockGetSalesByDateRange = mock;
  }
  
  void setupGetTotalReceivables(Future<double> Function() mock) {
    _mockGetTotalReceivables = mock;
  }

  @override
  Future<List<Sale>> getSalesByDateRange(DateTime startDate, DateTime endDate) {
    if (_mockGetSalesByDateRange != null) {
      return _mockGetSalesByDateRange!(startDate, endDate);
    }
    throw UnimplementedError('getSalesByDateRange not implemented');
  }
  
  @override
  Future<double> getTotalReceivables() {
    if (_mockGetTotalReceivables != null) {
      return _mockGetTotalReceivables!();
    }
    throw UnimplementedError('getTotalReceivables not implemented');
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName} is not implemented');
  }
}

class MockCustomerRepository implements CustomerRepository {
  // Use field name that doesn't conflict with method name
  Future<int> Function(DateTime, DateTime)? _mockGetUniqueCustomersCountForDateRange;

  void setupGetUniqueCustomersCountForDateRange(Future<int> Function(DateTime, DateTime) mock) {
    _mockGetUniqueCustomersCountForDateRange = mock;
  }

  @override
  Future<int> getUniqueCustomersCountForDateRange(DateTime startDate, DateTime endDate) {
    if (_mockGetUniqueCustomersCountForDateRange != null) {
      return _mockGetUniqueCustomersCountForDateRange!(startDate, endDate);
    }
    throw UnimplementedError('getUniqueCustomersCountForDateRange not implemented');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName} is not implemented');
  }
}

class MockTransactionRepository implements TransactionRepository {
  // Use field name that doesn't conflict with method name
  Future<double> Function(DateTime, DateTime)? _mockGetTotalExpensesForDateRange;

  void setupGetTotalExpensesForDateRange(Future<double> Function(DateTime, DateTime) mock) {
    _mockGetTotalExpensesForDateRange = mock;
  }

  @override
  Future<double> getTotalExpensesForDateRange(DateTime startDate, DateTime endDate) {
    if (_mockGetTotalExpensesForDateRange != null) {
      return _mockGetTotalExpensesForDateRange!(startDate, endDate);
    }
    throw UnimplementedError('getTotalExpensesForDateRange not implemented');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName} is not implemented');
  }
}

class MockExpenseRepository implements ExpenseRepository {
  // Use field name that doesn't conflict with method name
  Future<List<Expense>> Function(DateTime, DateTime)? _mockGetExpensesByDateRange;

  void setupGetExpensesByDateRange(Future<List<Expense>> Function(DateTime, DateTime) mock) {
    _mockGetExpensesByDateRange = mock;
  }

  @override
  Future<List<Expense>> getExpensesByDateRange(DateTime startDate, DateTime endDate) {
    if (_mockGetExpensesByDateRange != null) {
      return _mockGetExpensesByDateRange!(startDate, endDate);
    }
    throw UnimplementedError('getExpensesByDateRange not implemented');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName} is not implemented');
  }
}

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

      // Setup the mock methods
      mockSalesRepository.setupGetSalesByDateRange((start, end) async => mockSales);
      mockCustomerRepository.setupGetUniqueCustomersCountForDateRange((start, end) async => 2);
      mockSalesRepository.setupGetTotalReceivables(() async => 25000.0);
      mockExpenseRepository.setupGetExpensesByDateRange((start, end) async => []);

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
      // Arrange - setup mock to throw exception
      mockSalesRepository.setupGetSalesByDateRange((start, end) async => throw Exception('Database error'));

      // Act
      final result = await dashboardApiService.getDashboardData(testDate);

      // Assert
      expect(result.success, false);
      expect(result.statusCode, 500);
      expect(result.data, isNull);
      expect(result.error, contains('Exception: Database error'));
    });    test('getSalesToday returns correct sales amounts', () async {
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

      mockSalesRepository.setupGetSalesByDateRange((start, end) async => mockSales);

      // Act
      final result = await dashboardApiService.getSalesToday(testDate);

      // Assert
      expect(result.success, true);
      expect(result.data!['cdf'], 15000.0);
      expect(result.data!['usd'], 5.0);
    });

    test('getClientsServedToday returns correct count', () async {
      // Arrange
      mockCustomerRepository.setupGetUniqueCustomersCountForDateRange((start, end) async => 3);

      // Act
      final result = await dashboardApiService.getClientsServedToday(testDate);

      // Assert
      expect(result.success, true);
      expect(result.data, 3);
    });

    test('getTotalReceivables returns correct amount', () async {
      // Arrange
      mockSalesRepository.setupGetTotalReceivables(() async => 30000.0);

      // Act
      final result = await dashboardApiService.getTotalReceivables();

      // Assert
      expect(result.success, true);
      expect(result.data, 30000.0);
    });

    test('getExpensesToday returns correct expenses', () async {
      // Arrange
      mockExpenseRepository.setupGetExpensesByDateRange((start, end) async => []);

      // Act
      final result = await dashboardApiService.getExpensesToday(testDate);

      // Assert
      expect(result.success, true);
      expect(result.data, 0.0);
    });
  });
}
