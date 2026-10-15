import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wanzo/core/services/currency_service.dart';
import 'package:wanzo/features/dashboard/services/dashboard_api_service.dart';
import 'package:wanzo/features/sales/repositories/sales_repository.dart';
import 'package:wanzo/features/customer/repositories/customer_repository.dart';
import 'package:wanzo/features/transactions/repositories/transaction_repository.dart';
import 'package:wanzo/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/features/dashboard/models/dashboard_data.dart';
import 'package:bloc_test/bloc_test.dart';

// Les dépôts réels (Hive) sont couverts par customer_repository_test et
// transaction_repository_test ; ici, le service et le bloc du tableau de bord.
class MockSalesRepository extends Mock implements SalesRepository {}

class MockCustomerRepository extends Mock implements CustomerRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  final jour = DateTime(2025, 6, 7);
  final debut = DateTime(2025, 6, 7);
  final fin = DateTime(2025, 6, 7, 23, 59, 59);

  late MockSalesRepository ventes;
  late MockCustomerRepository clients;
  late MockTransactionRepository transactions;
  late CurrencyService taux;

  setUpAll(() => registerFallbackValue(CurrencyService()));

  setUp(() {
    ventes = MockSalesRepository();
    clients = MockCustomerRepository();
    transactions = MockTransactionRepository();
    taux = CurrencyService();

    when(() => ventes.getSalesByDateRange(debut, fin))
        .thenAnswer((_) async => []);
    when(() => ventes.getTotalReceivables()).thenAnswer((_) async => 5000.0);
    when(() => clients.getUniqueCustomersCountForDateRange(debut, fin))
        .thenAnswer((_) async => 10);
    // Sans dépôt de dépenses, le total vient des transactions (en CDF).
    when(
      () => transactions.getTotalExpensesForDateRange(
        debut,
        fin,
        currencyService: any(named: 'currencyService'),
      ),
    ).thenAnswer((_) async => 2000.0);
  });

  group('DashboardApiService', () {
    late DashboardApiService service;

    setUp(() {
      service = DashboardApiService(
        salesRepository: ventes,
        customerRepository: clients,
        transactionRepository: transactions,
        currencyService: taux,
      );
    });

    test('getDashboardData assemble les indicateurs du jour', () async {
      final response = await service.getDashboardData(jour);

      expect(response, isA<ApiResponse<DashboardData>>());
      expect(response.success, isTrue);
      expect(response.statusCode, 200);
      expect(response.data!.clientsServedToday, 10);
      expect(response.data!.receivables, 5000.0);
      expect(response.data!.expenses, 2000.0);
    });

    test('getClientsServedToday', () async {
      final response = await service.getClientsServedToday(jour);
      expect(response.success, isTrue);
      expect(response.data, 10);
    });

    test('getTotalReceivables', () async {
      final response = await service.getTotalReceivables();
      expect(response.success, isTrue);
      expect(response.data, 5000.0);
    });

    test('getExpensesToday', () async {
      final response = await service.getExpensesToday(jour);
      expect(response.success, isTrue);
      expect(response.data, 2000.0);
    });
  });

  group('DashboardBloc', () {
    blocTest<DashboardBloc, DashboardState>(
      'emits [DashboardLoading, DashboardLoaded] when LoadDashboardData is added',
      build: () => DashboardBloc(
        salesRepository: ventes,
        customerRepository: clients,
        transactionRepository: transactions,
        currencyService: taux,
      ),
      act: (bloc) => bloc.add(LoadDashboardData(date: jour)),
      expect: () => [isA<DashboardLoading>(), isA<DashboardLoaded>()],
    );
  });
}
