// Test de fumee de la composition de l'application (WanzoApp).
//
// main() initialise Auth0, le stockage securise, la connectivite et Hive sur
// le disque de l'appareil : rien de cela n'existe dans un test unitaire. On
// verifie donc ce qui peut l'etre de facon deterministe : WanzoApp se monte
// avec exactement les cles de depots, BLoCs et services que main() fournit,
// expose chacun aux ecrans par son type, et demarre sur l'ecran de demarrage
// qui demande la verification d'authentification.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/services/currency_service.dart';
import 'package:wanzo/core/services/sync_service.dart';
import 'package:wanzo/core/utils/connectivity_service.dart';
import 'package:wanzo/features/adha/bloc/adha_bloc.dart';
import 'package:wanzo/features/adha/bloc/adha_event.dart';
import 'package:wanzo/features/adha/bloc/adha_state.dart';
import 'package:wanzo/features/adha/repositories/adha_repository.dart';
import 'package:wanzo/features/auth/bloc/auth_bloc.dart';
import 'package:wanzo/features/auth/repositories/auth_repository.dart';
import 'package:wanzo/features/auth/screens/auth0_info_screen.dart';
import 'package:wanzo/features/auth/screens/splash_screen.dart';
import 'package:wanzo/features/business_unit/bloc/business_unit_bloc.dart';
import 'package:wanzo/features/business_unit/bloc/business_unit_event.dart';
import 'package:wanzo/features/business_unit/bloc/business_unit_state.dart';
import 'package:wanzo/features/business_unit/repositories/business_unit_repository.dart';
import 'package:wanzo/features/customer/bloc/customer_bloc.dart';
import 'package:wanzo/features/customer/bloc/customer_event.dart';
import 'package:wanzo/features/customer/bloc/customer_state.dart';
import 'package:wanzo/features/customer/repositories/customer_repository.dart';
import 'package:wanzo/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:wanzo/features/dashboard/bloc/operation_journal_bloc.dart';
import 'package:wanzo/features/dashboard/repositories/operation_journal_repository.dart';
import 'package:wanzo/features/expenses/bloc/expense_bloc.dart';
import 'package:wanzo/features/expenses/repositories/expense_repository.dart';
import 'package:wanzo/features/inventory/bloc/inventory_bloc.dart';
import 'package:wanzo/features/inventory/bloc/inventory_event.dart';
import 'package:wanzo/features/inventory/bloc/inventory_state.dart';
import 'package:wanzo/features/inventory/repositories/inventory_repository.dart';
import 'package:wanzo/features/notifications/bloc/notifications_bloc.dart';
import 'package:wanzo/features/notifications/repositories/notification_repository.dart';
import 'package:wanzo/features/notifications/services/notification_service.dart';
import 'package:wanzo/features/sales/bloc/sales_bloc.dart';
import 'package:wanzo/features/sales/repositories/sales_repository.dart';
import 'package:wanzo/features/settings/bloc/financial_account_bloc.dart';
import 'package:wanzo/features/settings/bloc/financial_account_event.dart';
import 'package:wanzo/features/settings/bloc/financial_account_state.dart';
import 'package:wanzo/features/settings/bloc/settings_bloc.dart';
import 'package:wanzo/features/settings/bloc/settings_event.dart';
import 'package:wanzo/features/settings/bloc/settings_state.dart';
import 'package:wanzo/features/settings/presentation/cubit/currency_settings_cubit.dart';
import 'package:wanzo/features/settings/repositories/financial_account_repository.dart';
import 'package:wanzo/features/settings/repositories/settings_repository.dart';
import 'package:wanzo/features/supplier/bloc/supplier_bloc.dart';
import 'package:wanzo/features/supplier/bloc/supplier_event.dart';
import 'package:wanzo/features/supplier/bloc/supplier_state.dart';
import 'package:wanzo/features/supplier/repositories/supplier_repository.dart';
import 'package:wanzo/features/transactions/repositories/transaction_repository.dart';
import 'package:wanzo/main.dart';

// BLoCs simules : l'etat initial est fixe, aucun depot n'est sollicite.
class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {
  final List<AuthEvent> addedEvents = [];

  @override
  void add(AuthEvent event) => addedEvents.add(event);
}

class _MockInventoryBloc extends MockBloc<InventoryEvent, InventoryState>
    implements InventoryBloc {}

class _MockSalesBloc extends MockBloc<SalesEvent, SalesState>
    implements SalesBloc {}

class _MockAdhaBloc extends MockBloc<AdhaEvent, AdhaState>
    implements AdhaBloc {}

class _MockCustomerBloc extends MockBloc<CustomerEvent, CustomerState>
    implements CustomerBloc {}

class _MockSupplierBloc extends MockBloc<SupplierEvent, SupplierState>
    implements SupplierBloc {}

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _MockFinancialAccountBloc
    extends MockBloc<FinancialAccountEvent, FinancialAccountState>
    implements FinancialAccountBloc {}

class _MockOperationJournalBloc
    extends MockBloc<OperationJournalEvent, OperationJournalState>
    implements OperationJournalBloc {}

class _MockExpenseBloc extends MockBloc<ExpenseEvent, ExpenseState>
    implements ExpenseBloc {}

class _MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

class _MockNotificationsBloc
    extends MockBloc<NotificationsEvent, NotificationsState>
    implements NotificationsBloc {}

class _MockCurrencySettingsCubit extends MockCubit<CurrencySettingsState>
    implements CurrencySettingsCubit {}

class _MockBusinessUnitBloc
    extends MockBloc<BusinessUnitEvent, BusinessUnitState>
    implements BusinessUnitBloc {}

// Depots et services factices : l'ecran de demarrage ne les appelle pas.
class _FakeAuthRepository extends Fake implements AuthRepository {}

class _FakeSettingsRepository extends Fake implements SettingsRepository {}

class _FakeFinancialAccountRepository extends Fake
    implements FinancialAccountRepository {}

class _FakeInventoryRepository extends Fake implements InventoryRepository {}

class _FakeSalesRepository extends Fake implements SalesRepository {}

class _FakeAdhaRepository extends Fake implements AdhaRepository {}

class _FakeCustomerRepository extends Fake implements CustomerRepository {}

class _FakeSupplierRepository extends Fake implements SupplierRepository {}

class _FakeNotificationRepository extends Fake
    implements NotificationRepository {}

class _FakeOperationJournalRepository extends Fake
    implements OperationJournalRepository {}

class _FakeExpenseRepository extends Fake implements ExpenseRepository {}


class _FakeTransactionRepository extends Fake
    implements TransactionRepository {}

class _FakeBusinessUnitRepository extends Fake
    implements BusinessUnitRepository {}

class _FakeConnectivityService extends Fake implements ConnectivityService {}

class _FakeSyncService extends Fake implements SyncService {}

class _FakeNotificationService extends Fake implements NotificationService {}

B _bloc<B extends BlocBase<S>, S>(B bloc, S initialState) {
  whenListen<S>(bloc, const Stream.empty(), initialState: initialState);
  return bloc;
}

void main() {
  late _MockAuthBloc authBloc;
  late StreamController<AuthState> authStates;
  late Map<String, dynamic> repositories;
  late Map<String, dynamic> blocs;
  late Map<String, dynamic> services;

  // main() charge .env avant de construire l'application ; l'ApiClient lu
  // par la banniere d'abonnement en depend. Aucun serveur n'est joint : les
  // requetes HTTP sont bloquees par l'environnement de test.
  setUpAll(() {
    dotenv.testLoad(
      fileInput: 'API_GATEWAY_URL=http://localhost:8000\nENVIRONMENT=test',
    );
  });

  setUp(() {
    authStates = StreamController<AuthState>.broadcast();
    authBloc = _MockAuthBloc();
    whenListen<AuthState>(
      authBloc,
      authStates.stream,
      initialState: const AuthInitial(),
    );

    // Memes cles que main() (initializeRepositories / initializeBlocs).
    repositories = {
      'auth': _FakeAuthRepository(),
      'settings': _FakeSettingsRepository(),
      'financialAccount': _FakeFinancialAccountRepository(),
      'inventory': _FakeInventoryRepository(),
      'sales': _FakeSalesRepository(),
      'customer': _FakeCustomerRepository(),
      'supplier': _FakeSupplierRepository(),
      'notification': _FakeNotificationRepository(),
      'operationJournal': _FakeOperationJournalRepository(),
      'transaction': _FakeTransactionRepository(),
      'adha': _FakeAdhaRepository(),
      'expense': _FakeExpenseRepository(),
      'businessUnit': _FakeBusinessUnitRepository(),
    };
    blocs = {
      'auth': authBloc,
      'operationJournal': _bloc(
        _MockOperationJournalBloc(),
        const OperationJournalInitial(),
      ),
      'inventory': _bloc(_MockInventoryBloc(), const InventoryInitial()),
      'sales': _bloc(_MockSalesBloc(), const SalesInitial()),
      'adha': _bloc(_MockAdhaBloc(), const AdhaInitial()),
      'customer': _bloc(_MockCustomerBloc(), const CustomerInitial()),
      'supplier': _bloc(_MockSupplierBloc(), const SupplierInitial()),
      'settings': _bloc(_MockSettingsBloc(), const SettingsInitial()),
      'financialAccount': _bloc(
        _MockFinancialAccountBloc(),
        const FinancialAccountInitial(),
      ),
      'expense': _bloc(_MockExpenseBloc(), const ExpenseInitial()),
      'currencySettings': _bloc(
        _MockCurrencySettingsCubit(),
        CurrencySettingsState.initial(),
      ),
      'notifications': _bloc(_MockNotificationsBloc(), NotificationsInitial()),
      'dashboard': _bloc(_MockDashboardBloc(), DashboardInitial()),
      'businessUnit': _bloc(
        _MockBusinessUnitBloc(),
        const BusinessUnitInitial(),
      ),
    };
    services = {
      'connectivity': _FakeConnectivityService(),
      'currency': CurrencyService(),
      'notification': _FakeNotificationService(),
      'sync': _FakeSyncService(),
    };
  });

  tearDown(() async {
    await authStates.close();
  });

  /// Demonte l'application puis laisse expirer les delais de l'ecran de
  /// demarrage (garde-fou de 10 s), pour ne laisser aucun minuteur actif.
  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  }

  testWidgets('WanzoApp demarre sur l ecran de demarrage', (tester) async {
    await tester.pumpWidget(
      WanzoApp(repositories: repositories, blocs: blocs, services: services),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(SplashScreen), findsOneWidget);
    // L'ecran de demarrage lance la verification de session
    expect(authBloc.addedEvents, [const AuthCheckRequested()]);

    await unmountApp(tester);
  });

  testWidgets('chaque depot, BLoC et service est expose par son type', (
    tester,
  ) async {
    await tester.pumpWidget(
      WanzoApp(repositories: repositories, blocs: blocs, services: services),
    );
    await tester.pump();

    final context = tester.element(find.byType(SplashScreen));
    expect(context.read<AuthBloc>(), same(authBloc));
    expect(context.read<BusinessUnitBloc>(), same(blocs['businessUnit']));
    expect(
      context.read<CurrencySettingsCubit>(),
      same(blocs['currencySettings']),
    );
    expect(context.read<DashboardBloc>(), same(blocs['dashboard']));
    expect(context.read<SyncService>(), same(services['sync']));
    expect(context.read<CurrencyService>(), same(services['currency']));
    expect(
      context.read<BusinessUnitRepository>(),
      same(repositories['businessUnit']),
    );
    expect(
      context.read<TransactionRepository>(),
      same(repositories['transaction']),
    );

    await unmountApp(tester);
  });

  testWidgets('une session en echec mene a l ecran d information Auth0', (
    tester,
  ) async {
    // Fenêtre de poste de travail (l'écran d'information Auth0 desktop est
    // conçu pour un ordinateur, pas pour la surface 800x600 par défaut).
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      WanzoApp(repositories: repositories, blocs: blocs, services: services),
    );
    await tester.pump();

    // Le routeur relit l'etat du BLoC a chaque emission
    whenListen<AuthState>(
      authBloc,
      authStates.stream,
      initialState: const AuthFailure('Session expiree'),
    );
    authStates.add(const AuthFailure('Session expiree'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(Auth0InfoScreen), findsOneWidget);

    await unmountApp(tester);
  });
}
