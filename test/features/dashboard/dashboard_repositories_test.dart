import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:wanzo/features/dashboard/services/dashboard_api_service.dart';
import 'package:wanzo/features/sales/repositories/sales_repository.dart';
import 'package:wanzo/features/customer/repositories/customer_repository.dart';
import 'package:wanzo/features/transactions/repositories/transaction_repository.dart';
import 'package:wanzo/features/expenses/repositories/expense_repository.dart';
import 'package:wanzo/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/features/dashboard/models/dashboard_data.dart';
import 'package:bloc_test/bloc_test.dart';

// Manual mock implementations
class MockSalesRepository extends Mock implements SalesRepository {}
class MockCustomerRepository extends Mock implements CustomerRepository {}
class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockExpenseRepository extends Mock implements ExpenseRepository {}
class MockDashboardApiService extends Mock implements DashboardApiService {}

void main() {
  // The import for the generated mocks will be added after running build_runner

  group('CustomerRepository Tests', () {
    late CustomerRepository customerRepository;
    late SalesRepository salesRepository;

    setUp(() {
      // Create a real instance for integration testing
      customerRepository = CustomerRepository();
      salesRepository = SalesRepository();
    });

    test('getUniqueCustomersCountForDateRange should return a number', () async {
      // Initialize repositories
      await customerRepository.init();
      await salesRepository.init();

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      // This should return a non-negative integer
      final count = await customerRepository.getUniqueCustomersCountForDateRange(
        startOfDay, endOfDay
      );

      expect(count, isA<int>());
      expect(count, greaterThanOrEqualTo(0));
    });
  });

  group('TransactionRepository Tests', () {
    late TransactionRepository transactionRepository;

    setUp(() {
      transactionRepository = TransactionRepository();
    });

    test('getTotalExpensesForDateRange should handle errors gracefully', () async {
      // Initialize repository
      await transactionRepository.init();

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      // This should not throw any exception and return a valid double
      final expenses = await transactionRepository.getTotalExpensesForDateRange(
        startOfDay, endOfDay
      );

      expect(expenses, isA<double>());
      expect(expenses, greaterThanOrEqualTo(0));
    });
  });

  group('DashboardApiService Tests', () {
    late SalesRepository mockSalesRepository;
    late CustomerRepository mockCustomerRepository;
    late TransactionRepository mockTransactionRepository;
    late ExpenseRepository mockExpenseRepository;
    late DashboardApiService dashboardApiService;

    setUp(() {      // Create mock repositories for unit testing
      mockSalesRepository = MockSalesRepository();
      mockCustomerRepository = MockCustomerRepository();
      mockTransactionRepository = MockTransactionRepository();
      mockExpenseRepository = MockExpenseRepository();

      // Create test dates to use as concrete values instead of 'any'
      final testDate = DateTime(2025, 6, 7);
      final startOfDay = DateTime(2025, 6, 7, 0, 0, 0);
      final endOfDay = DateTime(2025, 6, 7, 23, 59, 59);

      // Configure the mock repositories to return test data with concrete date parameters
      when(mockSalesRepository.getSalesByDateRange(startOfDay, endOfDay))
          .thenAnswer((_) async => []);
      when(mockSalesRepository.getTotalReceivables())
          .thenAnswer((_) async => 5000.0);
      when(mockCustomerRepository.getUniqueCustomersCountForDateRange(startOfDay, endOfDay))
          .thenAnswer((_) async => 10);
      when(mockTransactionRepository.getTotalExpensesForDateRange(startOfDay, endOfDay))
          .thenAnswer((_) async => 2000.0);

      // Create the service with mock repositories
      dashboardApiService = DashboardApiService(
        salesRepository: mockSalesRepository,
        customerRepository: mockCustomerRepository,
        transactionRepository: mockTransactionRepository,
        expenseRepository: mockExpenseRepository,
      );
    });

    test('getDashboardData should return a valid ApiResponse', () async {
      final response = await dashboardApiService.getDashboardData(DateTime.now());

      expect(response, isA<ApiResponse<DashboardData>>());
      expect(response.success, isTrue);
      expect(response.data, isNotNull);
      expect(response.statusCode, 200);
      
      if (response.data != null) {
        expect(response.data!.clientsServedToday, 10);
        expect(response.data!.receivables, 5000.0);
        expect(response.data!.expenses, 2000.0);
      }
    });

    test('getClientsServedToday should return a valid count', () async {
      final response = await dashboardApiService.getClientsServedToday(DateTime.now());

      expect(response, isA<ApiResponse<int>>());
      expect(response.success, isTrue);
      expect(response.data, 10);
    });

    test('getTotalReceivables should return a valid amount', () async {
      final response = await dashboardApiService.getTotalReceivables();

      expect(response, isA<ApiResponse<double>>());
      expect(response.success, isTrue);
      expect(response.data, 5000.0);
    });

    test('getExpensesToday should return a valid amount', () async {
      final response = await dashboardApiService.getExpensesToday(DateTime.now());

      expect(response, isA<ApiResponse<double>>());
      expect(response.success, isTrue);
      expect(response.data, 2000.0);
    });
  });

  group('DashboardBloc Tests', () {
    late DashboardApiService mockDashboardApiService;
    late DashboardBloc dashboardBloc;

    setUp(() {      mockDashboardApiService = MockDashboardApiService();

      // Configure the mock service to return test data with a specific date
      final testDate = DateTime(2025, 6, 7);
      when(mockDashboardApiService.getDashboardData(testDate))
          .thenAnswer((_) async => ApiResponse<DashboardData>(
                success: true,
                data: DashboardData(
                  salesTodayCdf: 10000.0,
                  salesTodayUsd: 50.0,
                  clientsServedToday: 15,
                  receivables: 8000.0,
                  expenses: 3000.0,
                ),
                message: 'Test data loaded',
                statusCode: 200,
              ));

      // Create the bloc with required repositories
      // The real repositories are passed but won't be used since we're mocking the service
      dashboardBloc = DashboardBloc(
        salesRepository: MockSalesRepository(),
        customerRepository: MockCustomerRepository(),
        transactionRepository: MockTransactionRepository(),
        expenseRepository: MockExpenseRepository(),
      );
    });

    tearDown(() {
      dashboardBloc.close();
    });    blocTest<DashboardBloc, DashboardState>(
      'emits [DashboardLoading, DashboardLoaded] when LoadDashboardData is added',
      build: () => dashboardBloc,
      act: (bloc) => bloc.add(LoadDashboardData(date: DateTime(2025, 6, 7))),
      expect: () => [
        isA<DashboardLoading>(),
        isA<DashboardLoaded>(),
      ],
    );
  });
}
