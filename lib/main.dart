import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Support SQLite pour Windows/Linux
import 'package:get_it/get_it.dart'; // Service locator pour accès global aux services

import 'package:wanzo/core/navigation/app_router.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/services/logging_service.dart';
import 'package:wanzo/core/services/app_initialization_service.dart';
import 'package:wanzo/core/utils/connectivity_service.dart';
import 'package:wanzo/core/services/database_service.dart';
import 'package:wanzo/core/utils/hive_setup.dart';
import 'package:wanzo/core/services/image_upload_service.dart';

import 'package:wanzo/core/services/sync_service.dart';
import 'package:wanzo/core/services/product_api_service.dart';
import 'package:wanzo/core/services/customer_api_service.dart';
import 'package:wanzo/core/services/sale_api_service.dart';
import 'package:wanzo/features/expenses/services/expense_api_service.dart'; // Added import for ExpenseApiService
import 'package:wanzo/features/adha/services/adha_api_service.dart'; // Added import for AdhaApiService
import 'package:wanzo/features/settings/services/settings_api_service.dart'; // Settings API Service
import 'package:wanzo/features/settings/services/financial_account_api_service.dart'; // Financial Account API Service
import 'package:wanzo/features/inventory/services/inventory_api_service.dart'; // Inventory API Service
import 'package:wanzo/features/sales/services/sales_api_service.dart'; // Sales API Service
import 'package:wanzo/features/customer/services/customer_api_service.dart'
    as customer_feature; // Customer Feature API Service
import 'package:wanzo/features/supplier/services/supplier_api_service.dart'; // Supplier API Service

import 'package:wanzo/features/auth/services/auth0_service.dart';
import 'package:wanzo/features/auth/services/auth_backend_service.dart';
import 'package:wanzo/features/auth/services/offline_auth_service.dart';
import 'package:wanzo/features/auth/services/desktop_auth_service.dart';
import 'package:wanzo/features/notifications/services/notification_service.dart';
import 'package:wanzo/features/security/services/local_security_service.dart';
import 'package:wanzo/features/offline/services/enhanced_offline_service.dart';
import 'package:wanzo/features/security/widgets/security_wrapper.dart';

import 'package:wanzo/features/auth/repositories/auth_repository.dart';
import 'package:wanzo/features/inventory/repositories/inventory_repository.dart';
import 'package:wanzo/features/sales/repositories/sales_repository.dart';
import 'package:wanzo/features/adha/repositories/adha_repository.dart';
import 'package:wanzo/features/customer/repositories/customer_repository.dart';
import 'package:wanzo/features/supplier/repositories/supplier_repository.dart';
import 'package:wanzo/features/settings/repositories/settings_repository.dart';
import 'package:wanzo/features/settings/repositories/financial_account_repository.dart';
import 'package:wanzo/features/notifications/repositories/notification_repository.dart';
import 'package:wanzo/features/dashboard/repositories/operation_journal_repository.dart';
import 'package:wanzo/features/expenses/repositories/expense_repository.dart';
import 'package:wanzo/features/financing/repositories/financing_repository.dart';
import 'package:wanzo/features/transactions/repositories/transaction_repository.dart';

import 'package:wanzo/core/services/currency_service.dart';
import 'package:wanzo/features/settings/presentation/cubit/currency_settings_cubit.dart';

import 'package:wanzo/features/auth/bloc/auth_bloc.dart';
import 'package:wanzo/features/inventory/bloc/inventory_bloc.dart';
import 'package:wanzo/features/sales/bloc/sales_bloc.dart';
import 'package:wanzo/features/adha/bloc/adha_bloc.dart';
import 'package:wanzo/features/customer/bloc/customer_bloc.dart';
import 'package:wanzo/utils/theme.dart'; // Add WanzoTheme import
import 'package:wanzo/features/supplier/bloc/supplier_bloc.dart';
import 'package:wanzo/features/settings/bloc/settings_bloc.dart';
import 'package:wanzo/features/settings/bloc/settings_state.dart';
import 'package:wanzo/features/settings/models/settings.dart';
import 'package:wanzo/features/settings/bloc/financial_account_bloc.dart';
import 'package:wanzo/features/notifications/bloc/notifications_bloc.dart';
import 'package:wanzo/features/dashboard/bloc/operation_journal_bloc.dart';
import 'package:wanzo/features/expenses/bloc/expense_bloc.dart';
import 'package:wanzo/features/financing/bloc/financing_bloc.dart';
import 'package:wanzo/features/dashboard/bloc/dashboard_bloc.dart';

import 'package:wanzo/features/settings/bloc/settings_event.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser sqflite_ffi pour Windows/Linux desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    debugPrint('Main: SQLite FFI initialized for desktop platform');
  }

  try {
    // 1. Chargement de la configuration (critique - doit être séquentiel)
    // En mode release, charge .env.production si disponible, sinon .env
    const bool isProduction = bool.fromEnvironment('dart.vm.product');
    final envFile = isProduction ? '.env.production' : '.env';

    try {
      await dotenv.load(fileName: envFile);
    } catch (e) {
      // Fallback sur .env si le fichier spécifique n'existe pas
      await dotenv.load(fileName: '.env');
    }

    // 2. Initialisation Hive en parallèle avec connectivity
    await Future.wait([_initializeHive(), _initializeConnectivity()]);

    // 3. Récupérer les services initialisés
    final syncStatusBox = Hive.box<String>('syncStatusBox');
    final connectivityService = ConnectivityService();

    final databaseService = DatabaseService();
    final secureStorage = const FlutterSecureStorage();

    // 4. Initialisation des services d'authentification
    final offlineAuthService = OfflineAuthService(
      secureStorage: secureStorage,
      databaseService: databaseService,
      connectivityService: connectivityService,
    );

    final auth0Service = Auth0Service(offlineAuthService: offlineAuthService);
    await auth0Service.init();

    // 4b. Initialisation du service d'authentification desktop (Windows/Linux)
    DesktopAuthService? desktopAuthService;
    // Vérification de la plateforme - Platform.* ne peut pas être appelé sur le web
    bool isDesktopPlatform = false;
    String platformName = 'web';

    if (!kIsWeb) {
      // Seulement accéder à Platform si on n'est pas sur le web
      isDesktopPlatform = Platform.isWindows || Platform.isLinux;
      platformName = Platform.operatingSystem;
    }

    debugPrint(
      'Main: kIsWeb=$kIsWeb, Platform=$platformName, isDesktopPlatform=$isDesktopPlatform',
    );

    if (isDesktopPlatform) {
      desktopAuthService = DesktopAuthService(
        offlineAuthService: offlineAuthService,
      );
      await desktopAuthService.init();
      debugPrint(
        'Main: DesktopAuthService initialisé pour authentification native',
      );
    } else {
      debugPrint(
        'Main: Plateforme non-desktop (web/mobile/macOS), desktopAuthService sera null',
      );
    }

    // 5. Initialisation complète des services de production
    await AppInitializationService.instance.initialize(
      auth0Service: auth0Service,
      enableErrorReporting: true,
      enablePerformanceMonitoring: true,
    );

    final logger = LoggingService.instance;
    logger.info(
      'Starting Wanzo application',
      context: {
        'version': '1.0.0', // TODO: Récupérer depuis pubspec.yaml
        'environment': dotenv.env['ENVIRONMENT'] ?? 'production',
      },
    );

    // 6. Initialisation de l'API client avec Auth0Service
    final apiClient = ApiClient();
    ApiClient.configure(auth0Service: auth0Service);

    // 6.1 Enregistrer AuthBackendService dans GetIt pour accès par DesktopAuthService
    final authBackendService = AuthBackendService(apiClient: apiClient);
    if (!GetIt.instance.isRegistered<AuthBackendService>()) {
      GetIt.instance.registerSingleton<AuthBackendService>(authBackendService);
    }

    // 7. Initialisation des services API (léger, pas de I/O)
    final productApiService = ProductApiService(apiClient: apiClient);
    final customerApiService = CustomerApiService(apiClient: apiClient);
    final saleApiService = SaleApiService(apiClient: apiClient);
    final imageUploadService = ImageUploadService();
    final expenseApiService = ExpenseApiServiceImpl(
      apiClient,
      imageUploadService,
    );
    final adhaApiService = AdhaApiService(apiClient);

    // Services API pour Inventory et Sales (synchronisation)
    final inventoryApiService = InventoryApiServiceImpl(apiClient);
    final salesApiService = SalesApiService(apiClient: apiClient);

    // Services API pour Customer et Supplier (synchronisation)
    final customerFeatureApiService = customer_feature.CustomerApiService(
      apiClient: apiClient,
    );
    final supplierApiService = SupplierApiServiceImpl(apiClient);

    // Services API pour Settings (nouveaux)
    final settingsApiService = SettingsApiService(auth0Service: auth0Service);
    final financialAccountApiService = FinancialAccountApiService(
      apiClient: apiClient,
    );

    logger.info('API services initialized (including Settings API services)');

    // 8. Initialisation des services de notification
    final notificationService = NotificationService();

    // 9. Initialisation des repositories en parallèle où possible
    final repositories = await _initializeRepositoriesOptimized(
      auth0Service: auth0Service,
      desktopAuthService: desktopAuthService,
      notificationService: notificationService,
      expenseApiService: expenseApiService,
      adhaApiService: adhaApiService,
      settingsApiService: settingsApiService,
      financialAccountApiService: financialAccountApiService,
      inventoryApiService: inventoryApiService,
      salesApiService: salesApiService,
      customerApiService: customerFeatureApiService,
      supplierApiService: supplierApiService,
    );

    logger.info('Repositories initialized');

    // 10. Initialisation des services métier en parallèle
    final currencyService = CurrencyService();

    // Récupérer le repository du journal des opérations pour le SyncService
    final operationJournalRepo =
        repositories['operationJournal'] as OperationJournalRepository?;

    final syncService = SyncService(
      productApiService: productApiService,
      customerApiService: customerApiService,
      saleApiService: saleApiService,
      syncStatusBox: syncStatusBox,
      expenseApiService:
          expenseApiService, // AJOUTÉ: Pour synchroniser les dépenses
      operationJournalRepository:
          operationJournalRepo, // AJOUTÉ: Passer le repository pour sync des opérations
    );

    // Enregistrer SyncService dans GetIt pour accès global (notamment depuis le sidebar)
    if (!GetIt.instance.isRegistered<SyncService>()) {
      GetIt.instance.registerSingleton<SyncService>(syncService);
    }

    // Initialiser en parallèle: syncService, localSecurity, enhancedOffline, currencyService
    final localSecurityService = LocalSecurityService.instance;
    final enhancedOfflineService = EnhancedOfflineService.instance;

    await Future.wait([
      syncService.init(),
      localSecurityService.init(),
      enhancedOfflineService.init(),
      currencyService.loadSettings(),
    ]);

    logger.info('Business services initialized');
    logger.info('Security and offline services initialized');

    // 11. Initialisation des BLoCs (création rapide, pas de I/O lourd)
    final blocs = _initializeBlocsSync(
      repositories,
      notificationService,
      currencyService,
    );

    logger.info('BLoCs initialized');

    // 12. Lancement de l'application IMMÉDIATEMENT
    // Les chargements de données se feront après le premier frame
    runApp(
      WanzoApp(
        repositories: repositories,
        blocs: blocs,
        services: {
          'connectivity': connectivityService,
          'sync': syncService,
          'currency': currencyService,
          'notification': notificationService,
          'localSecurity': localSecurityService,
          'enhancedOffline': enhancedOfflineService,
        },
      ),
    );

    logger.info('Application launched successfully');

    // 13. Chargement différé des données après le premier frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Charger les paramètres de devise dans le cubit (si pas déjà fait)
      final currencySettingsCubit =
          blocs['currencySettings'] as CurrencySettingsCubit;
      await currencySettingsCubit.loadSettings();
    });
  } catch (error, stackTrace) {
    // Gestion d'erreur critique au démarrage
    debugPrint('Critical error during app initialization: $error');
    debugPrint('StackTrace: $stackTrace');

    // Si le logging est initialisé, utiliser le service
    if (LoggingService.instance.isInitialized) {
      LoggingService.instance.critical(
        'Application startup failed',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Afficher un écran d'erreur minimal
    runApp(CriticalErrorApp(error: error.toString()));
  }
}

/// Initialise Hive (adapters et boxes)
Future<void> _initializeHive() async {
  await Hive.initFlutter();
  await initializeHiveAdapters();
  await openHiveBoxes();
}

/// Initialise le service de connectivité
Future<void> _initializeConnectivity() async {
  final connectivityService = ConnectivityService();
  await connectivityService.init();
}

/// Initialise tous les repositories de manière optimisée (parallèle où possible)
Future<Map<String, dynamic>> _initializeRepositoriesOptimized({
  required Auth0Service auth0Service,
  required DesktopAuthService? desktopAuthService,
  required NotificationService notificationService,
  required ExpenseApiServiceImpl expenseApiService,
  required AdhaApiService adhaApiService,
  required SettingsApiService settingsApiService,
  required FinancialAccountApiService financialAccountApiService,
  required InventoryApiService inventoryApiService,
  required SalesApiService salesApiService,
  required customer_feature.CustomerApiService customerApiService,
  required SupplierApiService supplierApiService,
}) async {
  final logger = LoggingService.instance;
  final repositories = <String, dynamic>{};

  try {
    // Phase 1: Repositories avec leurs services API injectés
    final authRepository = AuthRepository(
      auth0Service: auth0Service,
      desktopAuthService: desktopAuthService,
    );
    final settingsRepository = SettingsRepository(
      apiService: settingsApiService,
    );
    final financialAccountRepository = FinancialAccountRepository(
      apiService: financialAccountApiService,
    );
    final inventoryRepository = InventoryRepository(
      apiService: inventoryApiService,
    );
    final salesRepository = SalesRepository(apiService: salesApiService);
    final customerRepository = CustomerRepository(
      apiService: customerApiService,
    );
    final supplierRepository = SupplierRepository(
      apiService: supplierApiService,
    );
    final notificationRepository = NotificationRepository();
    final operationJournalRepository = OperationJournalRepository();
    final financingRepository = FinancingRepository();
    final transactionRepository = TransactionRepository();
    final adhaRepository = AdhaRepository(apiService: adhaApiService);
    final expenseRepository = ExpenseRepository(
      expenseApiService: expenseApiService,
    );

    // Initialiser en parallèle tous les repositories indépendants
    await Future.wait([
      authRepository.init(),
      settingsRepository.init(),
      financialAccountRepository.init(),
      inventoryRepository.init(),
      salesRepository.init(),
      customerRepository.init(),
      supplierRepository.init(),
      notificationRepository.init(),
      operationJournalRepository.init(),
      financingRepository.init(),
      transactionRepository.init(),
      adhaRepository.init(),
      expenseRepository.init(),
    ]);

    // Ajouter au map
    repositories['auth'] = authRepository;
    repositories['settings'] = settingsRepository;
    repositories['financialAccount'] = financialAccountRepository;
    repositories['inventory'] = inventoryRepository;
    repositories['sales'] = salesRepository;
    repositories['customer'] = customerRepository;
    repositories['supplier'] = supplierRepository;
    repositories['notification'] = notificationRepository;
    repositories['operationJournal'] = operationJournalRepository;
    repositories['financing'] = financingRepository;
    repositories['transaction'] = transactionRepository;
    repositories['adha'] = adhaRepository;
    repositories['expense'] = expenseRepository;

    // Initialiser le service de notification avec les settings (dépendance)
    await notificationService.init(await settingsRepository.getSettings());

    logger.info(
      'All repositories initialized successfully',
      context: {
        'count': repositories.length,
        'repositories': repositories.keys.toList(),
      },
    );

    return repositories;
  } catch (error, stackTrace) {
    logger.error(
      'Failed to initialize repositories',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

/// Initialise tous les BLoCs de manière synchrone (pas de await)
/// pour éviter de bloquer le main thread
Map<String, dynamic> _initializeBlocsSync(
  Map<String, dynamic> repositories,
  NotificationService notificationService,
  CurrencyService currencyService,
) {
  final logger = LoggingService.instance;
  final blocs = <String, dynamic>{};

  final authBloc = AuthBloc(
    authRepository: repositories['auth'] as AuthRepository,
  );
  blocs['auth'] = authBloc;

  final operationJournalBloc = OperationJournalBloc(
    repository: repositories['operationJournal'] as OperationJournalRepository,
  );
  blocs['operationJournal'] = operationJournalBloc;

  final inventoryBloc = InventoryBloc(
    inventoryRepository: repositories['inventory'] as InventoryRepository,
    notificationService: notificationService,
    operationJournalBloc: operationJournalBloc,
  );
  blocs['inventory'] = inventoryBloc;

  final salesBloc = SalesBloc(
    salesRepository: repositories['sales'] as SalesRepository,
    operationJournalBloc: operationJournalBloc,
    journalRepository:
        repositories['operationJournal'] as OperationJournalRepository,
    inventoryRepository: repositories['inventory'] as InventoryRepository,
  );
  blocs['sales'] = salesBloc;

  final adhaBloc = AdhaBloc(
    adhaRepository: repositories['adha'] as AdhaRepository,
    authRepository: repositories['auth'] as AuthRepository,
    operationJournalRepository:
        repositories['operationJournal'] as OperationJournalRepository,
  );
  blocs['adha'] = adhaBloc;

  final customerBloc = CustomerBloc(
    customerRepository: repositories['customer'] as CustomerRepository,
  );
  blocs['customer'] = customerBloc;

  final supplierBloc = SupplierBloc(
    supplierRepository: repositories['supplier'] as SupplierRepository,
  );
  blocs['supplier'] = supplierBloc;

  final settingsBloc = SettingsBloc(
    settingsRepository: repositories['settings'] as SettingsRepository,
  )..add(const LoadSettings());
  blocs['settings'] = settingsBloc;

  final financialAccountBloc = FinancialAccountBloc(
    repository: repositories['financialAccount'] as FinancialAccountRepository,
  );
  blocs['financialAccount'] = financialAccountBloc;

  final expenseBloc = ExpenseBloc(
    expenseRepository: repositories['expense'] as ExpenseRepository,
    operationJournalBloc: operationJournalBloc,
  );
  blocs['expense'] = expenseBloc;

  // CurrencySettingsCubit - le loadSettings sera appelé après le premier frame
  final currencySettingsCubit = CurrencySettingsCubit(currencyService);
  blocs['currencySettings'] = currencySettingsCubit;

  final notificationsBloc = NotificationsBloc(notificationService);
  blocs['notifications'] = notificationsBloc;

  final financingBloc = FinancingBloc(
    financingRepository: repositories['financing'] as FinancingRepository,
    operationJournalBloc: operationJournalBloc,
  );
  blocs['financing'] = financingBloc;

  final dashboardBloc = DashboardBloc(
    salesRepository: repositories['sales'] as SalesRepository,
    customerRepository: repositories['customer'] as CustomerRepository,
    transactionRepository: repositories['transaction'] as TransactionRepository,
  );
  blocs['dashboard'] = dashboardBloc;

  logger.info(
    'All BLoCs initialized successfully (sync)',
    context: {'count': blocs.length, 'blocs': blocs.keys.toList()},
  );

  return blocs;
}

/// Application complète avec tous les services de production
class WanzoApp extends StatelessWidget {
  final Map<String, dynamic> repositories;
  final Map<String, dynamic> blocs;
  final Map<String, dynamic> services;

  const WanzoApp({
    super.key,
    required this.repositories,
    required this.blocs,
    required this.services,
  });

  @override
  Widget build(BuildContext context) {
    // Créer l'AppRouter avec le AuthBloc
    final appRouter = AppRouter(authBloc: blocs['auth'] as AuthBloc);

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: blocs['auth'] as AuthBloc),
        BlocProvider<InventoryBloc>.value(
          value: blocs['inventory'] as InventoryBloc,
        ),
        BlocProvider<SalesBloc>.value(value: blocs['sales'] as SalesBloc),
        BlocProvider<AdhaBloc>.value(value: blocs['adha'] as AdhaBloc),
        BlocProvider<CustomerBloc>.value(
          value: blocs['customer'] as CustomerBloc,
        ),
        BlocProvider<SupplierBloc>.value(
          value: blocs['supplier'] as SupplierBloc,
        ),
        BlocProvider<SettingsBloc>.value(
          value: blocs['settings'] as SettingsBloc,
        ),
        BlocProvider<FinancialAccountBloc>.value(
          value: blocs['financialAccount'] as FinancialAccountBloc,
        ),
        BlocProvider<OperationJournalBloc>.value(
          value: blocs['operationJournal'] as OperationJournalBloc,
        ),
        BlocProvider<ExpenseBloc>.value(value: blocs['expense'] as ExpenseBloc),
        BlocProvider<FinancingBloc>.value(
          value: blocs['financing'] as FinancingBloc,
        ),
        BlocProvider<DashboardBloc>.value(
          value: blocs['dashboard'] as DashboardBloc,
        ),
        BlocProvider<NotificationsBloc>.value(
          value: blocs['notifications'] as NotificationsBloc,
        ),
        BlocProvider<CurrencySettingsCubit>.value(
          value: blocs['currencySettings'] as CurrencySettingsCubit,
        ),
      ],
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AuthRepository>.value(
            value: repositories['auth'] as AuthRepository,
          ),
          RepositoryProvider<InventoryRepository>.value(
            value: repositories['inventory'] as InventoryRepository,
          ),
          RepositoryProvider<SalesRepository>.value(
            value: repositories['sales'] as SalesRepository,
          ),
          RepositoryProvider<AdhaRepository>.value(
            value: repositories['adha'] as AdhaRepository,
          ),
          RepositoryProvider<CustomerRepository>.value(
            value: repositories['customer'] as CustomerRepository,
          ),
          RepositoryProvider<SupplierRepository>.value(
            value: repositories['supplier'] as SupplierRepository,
          ),
          RepositoryProvider<SettingsRepository>.value(
            value: repositories['settings'] as SettingsRepository,
          ),
          RepositoryProvider<FinancialAccountRepository>.value(
            value:
                repositories['financialAccount'] as FinancialAccountRepository,
          ),
          RepositoryProvider<OperationJournalRepository>.value(
            value:
                repositories['operationJournal'] as OperationJournalRepository,
          ),
          RepositoryProvider<ExpenseRepository>.value(
            value: repositories['expense'] as ExpenseRepository,
          ),
          RepositoryProvider<FinancingRepository>.value(
            value: repositories['financing'] as FinancingRepository,
          ),
          RepositoryProvider<NotificationRepository>.value(
            value: repositories['notification'] as NotificationRepository,
          ),
          RepositoryProvider<TransactionRepository>.value(
            value: repositories['transaction'] as TransactionRepository,
          ),
          RepositoryProvider<CurrencyService>.value(
            value: services['currency'] as CurrencyService,
          ),
          RepositoryProvider<NotificationService>.value(
            value: services['notification'] as NotificationService,
          ),
          RepositoryProvider<ConnectivityService>.value(
            value: services['connectivity'] as ConnectivityService,
          ),
          RepositoryProvider<SyncService>.value(
            value: services['sync'] as SyncService,
          ),
        ],
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            // Détermine le thème à utiliser
            ThemeMode themeMode = ThemeMode.system;
            Locale? locale;

            if (settingsState is SettingsLoaded) {
              switch (settingsState.settings.themeMode) {
                case AppThemeMode.light:
                  themeMode = ThemeMode.light;
                  break;
                case AppThemeMode.dark:
                  themeMode = ThemeMode.dark;
                  break;
                case AppThemeMode.system:
                  themeMode = ThemeMode.system;
                  break;
              }

              // Détermine la langue à utiliser
              locale = Locale(
                settingsState.settings.language,
                settingsState.settings.language == 'fr' ? 'FR' : 'US',
              );
            }

            return SecurityWrapper(
              child: MaterialApp.router(
                title: 'Wanzo - Gestion de Stock',
                debugShowCheckedModeBanner: false,
                routerConfig: appRouter.router,
                theme: WanzoTheme.lightTheme, // Use your custom light theme
                darkTheme: WanzoTheme.darkTheme, // Use your custom dark theme
                themeMode: themeMode, // Use settings-based theme mode
                locale: locale, // Use settings-based locale
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('fr', 'FR'),
                  Locale('en', 'US'),
                  Locale('sw', 'TZ'), // Add Swahili support
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Écran d'erreur critique pour les erreurs de démarrage
class CriticalErrorApp extends StatelessWidget {
  final String error;

  const CriticalErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wanzo - Erreur',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.red[50],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red[700]),
                const SizedBox(height: 20),
                Text(
                  'Erreur de démarrage',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'L\'application n\'a pas pu démarrer correctement.',
                  style: TextStyle(fontSize: 16, color: Colors.red[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.red[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    // Redémarrer l'application
                    // Note: Dans un cas réel, vous pourriez vouloir relancer main()
                    SystemNavigator.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Fermer l\'application'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthObserver extends NavigatorObserver {
  final AuthBloc authBloc;

  AuthObserver(this.authBloc);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    authBloc.add(
      const AuthCheckRequested(),
    ); // Corrected: Use AuthCheckRequested
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    authBloc.add(
      const AuthCheckRequested(),
    ); // Corrected: Use AuthCheckRequested
  }
}

// Helper function to show a loading dialog (optional)
void showLoadingDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      );
    },
  );
}

// Helper function to hide the loading dialog (optional)
void hideLoadingDialog(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}
