import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/auth0_redirect_screen.dart';
import '../../features/auth/screens/auth0_info_screen.dart';
import '../../features/auth/screens/sync_pending_screen.dart';
import '../../features/auth/screens/join_business_unit_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/inventory/models/product.dart';
import '../../features/inventory/screens/add_product_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/inventory/screens/product_details_screen.dart';
import '../../features/sales/screens/add_sale_screen.dart';
import '../../features/sales/screens/sales_list_screen.dart';
import '../../features/adha/screens/adha_screen.dart';
import '../../features/customer/models/customer.dart';
import '../../features/customer/screens/add_customer_screen.dart';
import '../../features/customer/screens/customer_details_screen.dart';
import '../../features/supplier/models/supplier.dart';
import '../../features/supplier/screens/add_supplier_screen.dart';
import '../../features/supplier/screens/supplier_details_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/notifications/screens/notification_settings_screen.dart';
import '../../features/contacts/screens/contacts_screen.dart';
import '../../features/expenses/screens/add_expense_screen.dart';
import '../../features/expenses/screens/expenses_list_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/operations/screens/operations_screen.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/sales/screens/sale_details_screen.dart';
import 'package:wanzo/features/expenses/screens/expense_detail_screen.dart';
import '../../features/security/screens/security_settings_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/restaurant/cubit/restaurant_orders_cubit.dart';
import '../../features/restaurant/repositories/restaurant_order_repository.dart';
import '../../features/restaurant/screens/restaurant_pos_screen.dart';
import '../../features/restaurant/screens/restaurant_orders_board_screen.dart';
import '../../features/restaurant/screens/restaurant_menu_config_screen.dart';
import '../../features/restaurant/screens/restaurant_dashboard_screen.dart';
import '../../features/restaurant/screens/restaurant_kitchen_screen.dart';
import '../modules/activity_mode.dart';
import '../services/business_context_service.dart';
import '../../features/atelier/cubit/atelier_orders_cubit.dart';
import '../../features/atelier/services/atelier_api_service.dart';
import '../../features/atelier/screens/atelier_orders_board_screen.dart';

/// Page SANS animation de transition : sur desktop, la navigation entre les
/// écrans principaux doit être INSTANTANÉE (pas de fondu/glissement). On
/// enveloppe le contenu dans un [NoTransitionPage] de go_router.
Page<dynamic> _noAnim(GoRouterState state, Widget child) =>
    NoTransitionPage<dynamic>(key: state.pageKey, child: child);

/// Configuration des routes de l\'application
class AppRouter {
  final AuthBloc authBloc;

  AppRouter({required this.authBloc});

  /// Cubit des commandes restaurant : instance unique partagée par le POS via
  /// un ShellRoute. Chargée à la première utilisation (mode restaurant).
  late final RestaurantOrdersCubit _restaurantOrdersCubit =
      RestaurantOrdersCubit(RestaurantOrderRepository())..load();

  /// Cubit des commandes atelier (persistées backend), partagé via ShellRoute.
  late final AtelierOrdersCubit _atelierOrdersCubit =
      AtelierOrdersCubit(AtelierApiService())..load();

  late final GoRouter router = GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (BuildContext context, GoRouterState state) {
      final authState = authBloc.state;
      final isAuthenticated = authState is AuthAuthenticated;
      final isAuthenticating = authState is AuthLoading;
      final isSyncPending = authState is AuthSyncPending;
      final isBusinessUnitRequired = authState is AuthBusinessUnitRequired;
      final isJoiningBU = authState is AuthJoinBusinessUnitInProgress;
      final isJoinBUFailure = authState is AuthJoinBusinessUnitFailure;
      final isProfileUpdate =
          authState is AuthProfileUpdateInProgress ||
          authState is AuthProfileUpdateSuccess;

      final onAuthScreens =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/onboarding' ||
          state.matchedLocation == '/auth0_info' ||
          state.matchedLocation == '/auth0_redirect';
      final onSplashScreen = state.matchedLocation == '/';
      final onSyncPending = state.matchedLocation == '/sync-pending';
      final onJoinBU = state.matchedLocation == '/join-business-unit';
      final onIntermediateScreens = onSyncPending || onJoinBU;

      // Ne pas rediriger pendant le chargement, les mises à jour de profil, ou sur splash avec état initial
      if (isAuthenticating ||
          isProfileUpdate ||
          isJoiningBU ||
          (onSplashScreen && authState is AuthInitial)) {
        return null;
      }

      // Sync Kafka en cours → rediriger vers l'écran d'attente
      if (isSyncPending && !onSyncPending) {
        return '/sync-pending';
      }
      if (isSyncPending && onSyncPending) {
        return null;
      }

      // BU requise → rediriger vers l'écran de saisie code BU
      if ((isBusinessUnitRequired || isJoinBUFailure) && !onJoinBU) {
        return '/join-business-unit';
      }
      if ((isBusinessUnitRequired || isJoinBUFailure) && onJoinBU) {
        return null;
      }

      // Si authentifié, rediriger vers dashboard depuis les écrans d'auth, splash, ou intermédiaires
      if (isAuthenticated &&
          (onAuthScreens || onSplashScreen || onIntermediateScreens)) {
        return '/dashboard';
      }

      // Si non authentifié et pas sur les écrans d'authentification ou de splash, rediriger vers auth0_info
      // AuthFailure sur splash → rediriger vers auth0_info
      if (authState is AuthFailure && onSplashScreen) {
        return '/auth0_info';
      }

      if (!isAuthenticated &&
          !isSyncPending &&
          !isBusinessUnitRequired &&
          !isJoinBUFailure &&
          !onAuthScreens &&
          !onSplashScreen) {
        return '/auth0_info';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),

      // ── Mode restaurant : POS 3 colonnes, cubit partagé ────────────────
      ShellRoute(
        builder: (context, state, child) => BlocProvider.value(
          value: _restaurantOrdersCubit,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/restaurant/orders',
            pageBuilder: (context, state) =>
                _noAnim(state, const RestaurantPosScreen()),
          ),
          // Vue Board (Kanban) des commandes — complémentaire à la caisse.
          GoRoute(
            path: '/restaurant/board',
            pageBuilder: (context, state) =>
                _noAnim(state, const RestaurantOrdersBoardScreen()),
          ),
          // Écran cuisine (KDS) — plein écran secondaire côté salle/cuisine.
          GoRoute(
            path: '/restaurant/kitchen',
            pageBuilder: (context, state) =>
                _noAnim(state, const RestaurantKitchenScreen()),
          ),
        ],
      ),

      // ── Mode atelier : board Kanban des commandes de confection ────────
      ShellRoute(
        builder: (context, state, child) => BlocProvider.value(
          value: _atelierOrdersCubit,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/atelier/board',
            pageBuilder: (context, state) =>
                _noAnim(state, const AtelierOrdersBoardScreen()),
          ),
        ],
      ),
      // Composition de la carte (mode restaurant) — pas besoin du cubit.
      GoRoute(
        path: '/restaurant/menu',
        pageBuilder: (context, state) =>
            _noAnim(state, const RestaurantMenuConfigScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth0_info',
        builder: (context, state) => Auth0InfoScreen(),
      ),
      GoRoute(
        path: '/auth0_redirect',
        builder: (context, state) => const Auth0RedirectScreen(),
      ),
      // Routes intermédiaires pour le flux de synchronisation et BU
      GoRoute(
        path: '/sync-pending',
        builder: (context, state) => const SyncPendingScreen(),
      ),
      GoRoute(
        path: '/join-business-unit',
        builder: (context, state) => const JoinBusinessUnitScreen(),
      ),
      // Routes legacy - redirigent vers auth0_info pour compatibilité
      // Note: forgot-password n'est plus nécessaire car géré par Auth0 Universal Login
      GoRoute(path: '/login', redirect: (_, __) => '/auth0_info'),
      GoRoute(path: '/signup', redirect: (_, __) => '/auth0_info'),

      // Routes principales de l'application
      GoRoute(
        path: '/dashboard',
        // Le tableau de bord dépend du métier : en mode restaurant on sert un
        // écran dédié (service/cuisine/plats), sinon le tableau de bord
        // boutique historique reste STRICTEMENT inchangé (aucun risque retail).
        pageBuilder: (context, state) {
          if (BusinessContextService().activityMode ==
              ActivityMode.restaurant) {
            return _noAnim(
              state,
              BlocProvider.value(
                value: _restaurantOrdersCubit,
                child: const RestaurantDashboardScreen(),
              ),
            );
          }
          return _noAnim(state, const DashboardScreen());
        },
      ),

      // Routes principales pour Ventes, Dépenses, Financement (Desktop)
      GoRoute(
        path: '/sales',
        name: 'sales_list',
        pageBuilder: (context, state) =>
            _noAnim(state, const SalesListScreen()),
        routes: [
          GoRoute(
            path: 'add',
            name: 'add_sale',
            pageBuilder: (context, state) =>
                _noAnim(state, const AddSaleScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/expenses',
        name: 'expenses_list',
        pageBuilder: (context, state) =>
            _noAnim(state, const ExpensesListScreen()),
        routes: [
          GoRoute(
            path: 'add',
            name: 'add_expense',
            pageBuilder: (context, state) =>
                _noAnim(state, const AddExpenseScreen()),
          ),
        ],
      ),

      // Route pour opérations (mobile - garde les onglets)
      GoRoute(
        path: '/inventory',
        pageBuilder: (context, state) =>
            _noAnim(state, const InventoryScreen()),
        routes: [
          GoRoute(
            path: 'add',
            pageBuilder: (context, state) =>
                _noAnim(state, const AddProductScreen()),
          ),
          GoRoute(
            path: 'edit/:productId',
            pageBuilder: (context, state) {
              final product = state.extra as Product?;
              return _noAnim(state, AddProductScreen(product: product));
            },
          ),
          GoRoute(
            path: 'product/:productId',
            pageBuilder: (context, state) {
              final product = state.extra as Product?;
              final productId = state.pathParameters['productId'] ?? '';
              return _noAnim(
                state,
                ProductDetailsScreen(
                  productId: productId,
                  product: product,
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/contacts',
        pageBuilder: (context, state) =>
            _noAnim(state, const ContactsScreen()),
      ),
      GoRoute(
        path: '/adha',
        pageBuilder: (context, state) => _noAnim(state, const AdhaScreen()),
      ),
      GoRoute(
        path: '/customers',
        builder: (context, state) => const SizedBox.shrink(),
        routes: [
          GoRoute(
            path: 'add',
            pageBuilder: (context, state) =>
                _noAnim(state, const AddCustomerScreen()),
          ),
          GoRoute(
            path: 'edit/:customerId',
            pageBuilder: (context, state) {
              final customer = state.extra as Customer?;
              return _noAnim(state, AddCustomerScreen(customer: customer));
            },
          ),
          GoRoute(
            path: 'detail/:customerId',
            pageBuilder: (context, state) {
              final customer = state.extra as Customer?;
              final customerId = state.pathParameters['customerId'] ?? '';
              return _noAnim(
                state,
                CustomerDetailsScreen(
                  customerId: customerId,
                  customer: customer,
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/suppliers',
        builder: (context, state) => const SizedBox.shrink(),
        routes: [
          GoRoute(
            path: 'add',
            pageBuilder: (context, state) =>
                _noAnim(state, const AddSupplierScreen()),
          ),
          GoRoute(
            path: 'edit/:supplierId',
            pageBuilder: (context, state) {
              final supplier = state.extra as Supplier?;
              return _noAnim(state, AddSupplierScreen(supplier: supplier));
            },
          ),
          GoRoute(
            path: 'detail/:supplierId',
            pageBuilder: (context, state) {
              final supplier = state.extra as Supplier?;
              final supplierId = state.pathParameters['supplierId'] ?? '';
              return _noAnim(
                state,
                SupplierDetailsScreen(
                  supplierId: supplierId,
                  supplier: supplier,
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            _noAnim(state, const SettingsScreen()),
        routes: [
          GoRoute(
            path: 'notifications',
            pageBuilder: (context, state) {
              final settings = state.extra as dynamic;
              return _noAnim(
                state,
                NotificationSettingsScreen(settings: settings),
              );
            },
          ),
          GoRoute(
            path: 'security',
            pageBuilder: (context, state) =>
                _noAnim(state, const SecuritySettingsScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) =>
            _noAnim(state, const NotificationsScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => _noAnim(state, const ProfileScreen()),
      ),
      GoRoute(
        path: '/operations',
        name: AppRoute.operations.name,
        pageBuilder: (context, state) =>
            _noAnim(state, const OperationsScreen()),
        routes: [
          GoRoute(
            path: 'sales/add',
            name: 'add_sale_from_operations',
            pageBuilder: (context, state) =>
                _noAnim(state, const AddSaleScreen()),
          ),
          GoRoute(
            path: 'expenses/add',
            name: 'add_expense_from_operations',
            pageBuilder: (context, state) =>
                _noAnim(state, const AddExpenseScreen()),
          ),
        ],
      ),

      // Routes de détail
      GoRoute(
        path: '/sale-detail/:id',
        name: AppRoute.saleDetail.name,
        pageBuilder: (context, state) {
          final sale = state.extra as Sale?;

          if (sale == null) {
            return _noAnim(
              state,
              Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: const Center(
                  child: Text('Sale data not provided or invalid.'),
                ),
              ),
            );
          }
          return _noAnim(state, SaleDetailsScreen(sale: sale));
        },
      ),
      GoRoute(
        path: '/expense-detail/:id',
        name: AppRoute.expenseDetail.name,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _noAnim(state, ExpenseDetailScreen(expenseId: id));
        },
      ),
      // Route pour les ventes par ID (redirection vers le détail)
      GoRoute(
        path: '/sales/:saleId',
        redirect:
            (context, state) =>
                '/sale-detail/${state.pathParameters['saleId']}',
      ),
    ],
  );
}

/// Classe permettant d'écouter les changements d'état d'authentification
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

enum AppRoute {
  // ...existing code...
  operations,
  saleDetail,
  expenseDetail,
  // ...existing code...
}

extension AppRouteExtension on AppRoute {
  String getPath() {
    switch (this) {
      // ...existing code...
      case AppRoute.operations:
        return '/operations';
      case AppRoute.saleDetail:
        return '/sale-detail'; // Path without parameter for general linking
      case AppRoute.expenseDetail:
        return '/expense-detail'; // Path without parameter for general linking
      // ...existing code...
    }
  }
}

// Helper method to get path with parameters
String saleDetailPath(String id) => '/sale-detail/$id';
String expenseDetailPath(String id) => '/expense-detail/$id';
