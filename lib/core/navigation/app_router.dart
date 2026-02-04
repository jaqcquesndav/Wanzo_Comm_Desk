import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/auth0_redirect_screen.dart';
import '../../features/auth/screens/auth0_info_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/inventory/models/product.dart';
import '../../features/inventory/screens/add_product_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/inventory/screens/product_details_screen.dart';
import '../../features/sales/screens/add_sale_screen.dart';
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
import '../../features/expenses/screens/add_expense_screen.dart'; // Corrected import for AddExpenseScreen
import '../../features/financing/screens/add_financing_request_screen.dart';
import '../../features/financing/screens/financing_detail_screen.dart';
import '../../features/financing/models/financing_request.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/operations/screens/operations_screen.dart';
import 'package:wanzo/features/sales/models/sale.dart'; // Ensure Sale model is imported
import 'package:wanzo/features/sales/screens/sale_details_screen.dart';
import 'package:wanzo/features/expenses/screens/expense_detail_screen.dart';
import '../../features/security/screens/security_settings_screen.dart';

/// Configuration des routes de l\\\'application
class AppRouter {
  final AuthBloc authBloc;

  AppRouter({required this.authBloc});

  late final GoRouter router = GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (BuildContext context, GoRouterState state) {
      final authState = authBloc.state;
      final isAuthenticated = authState is AuthAuthenticated;
      final isAuthenticating = authState is AuthLoading;
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

      // Ne pas rediriger pendant le chargement, les mises à jour de profil, ou sur splash avec état initial
      if (isAuthenticating ||
          isProfileUpdate ||
          (onSplashScreen && authState is AuthInitial)) {
        return null;
      }

      // Si authentifié, rediriger vers dashboard depuis les écrans d'auth ou splash
      if (isAuthenticated && (onAuthScreens || onSplashScreen)) {
        return '/dashboard';
      }

      // Si non authentifié et pas sur les écrans d'authentification ou de splash, rediriger vers auth0_info
      if (!isAuthenticated && !onAuthScreens && !onSplashScreen) {
        return '/auth0_info';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth0_info',
        builder: (context, state) => const Auth0InfoScreen(),
      ),
      GoRoute(
        path: '/auth0_redirect',
        builder: (context, state) => const Auth0RedirectScreen(),
      ),
      GoRoute(
        path: '/login',
        redirect:
            (_, __) =>
                '/auth0_info', // Rediriger vers l'écran d'information Auth0
      ),
      GoRoute(
        path: '/signup',
        redirect:
            (_, __) =>
                '/auth0_info', // Rediriger vers l'écran d'information Auth0
      ),
      GoRoute(
        path: ForgotPasswordScreen.routeName,
        redirect:
            (_, __) =>
                '/auth0_info', // Rediriger vers l'écran d'information Auth0
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/financing/add',
        name: 'add_financing_direct',
        builder: (context, state) => const AddFinancingRequestScreen(),
      ),
      GoRoute(
        path: '/financing-detail/:id',
        name: 'financing_detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final financing = state.extra as FinancingRequest?;
          return FinancingDetailScreen(id: id, financing: financing);
        },
      ),

      // Old '/sales' route is removed as OperationsScreen is the main view.
      // Navigation to add/view sales and expenses will be handled by '/operations' sub-routes
      // or dedicated detail routes.
      GoRoute(
        path: '/inventory',
        builder: (context, state) => const InventoryScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) => const AddProductScreen(),
          ),
          GoRoute(
            path: 'edit/:productId',
            builder: (context, state) {
              final product = state.extra as Product?;
              return AddProductScreen(product: product);
            },
          ),
          GoRoute(
            path:
                'product/:productId', // Changed to avoid conflict with top-level ':productId' if any
            builder: (context, state) {
              final product = state.extra as Product?;
              final productId = state.pathParameters['productId'] ?? '';
              return ProductDetailsScreen(
                productId: productId,
                product: product,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactsScreen(),
      ),
      GoRoute(path: '/adha', builder: (context, state) => const AdhaScreen()),
      GoRoute(
        path: '/customers',
        builder: (context, state) => const SizedBox.shrink(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) => const AddCustomerScreen(),
          ),
          GoRoute(
            path: 'edit/:customerId',
            builder: (context, state) {
              final customer = state.extra as Customer?;
              return AddCustomerScreen(customer: customer);
            },
          ),
          GoRoute(
            path: 'detail/:customerId', // Changed to avoid conflict
            builder: (context, state) {
              final customer = state.extra as Customer?;
              final customerId = state.pathParameters['customerId'] ?? '';
              return CustomerDetailsScreen(
                customerId: customerId,
                customer: customer,
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
            builder: (context, state) => const AddSupplierScreen(),
          ),
          GoRoute(
            path: 'edit/:supplierId',
            builder: (context, state) {
              final supplier = state.extra as Supplier?;
              return AddSupplierScreen(supplier: supplier);
            },
          ),
          GoRoute(
            path: 'detail/:supplierId', // Changed to avoid conflict
            builder: (context, state) {
              final supplier = state.extra as Supplier?;
              final supplierId = state.pathParameters['supplierId'] ?? '';
              return SupplierDetailsScreen(
                supplierId: supplierId,
                supplier: supplier,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'notifications',
            builder: (context, state) {
              final settings = state.extra as dynamic;
              return NotificationSettingsScreen(settings: settings);
            },
          ),
          GoRoute(
            path: 'security',
            builder: (context, state) => const SecuritySettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      // AddExpenseScreen is now directly accessible via its route or as a sub-route of /operations
      // GoRoute(
      //   path: '/expenses/add', // This specific route can be kept if direct navigation is needed
      //   builder: (context, state) => const AddExpenseScreen(),
      // ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/operations',
        name: AppRoute.operations.name,
        builder: (context, state) => const OperationsScreen(),
        routes: [
          GoRoute(
            path: 'sales/add',
            name: 'add_sale_from_operations',
            builder: (context, state) => const AddSaleScreen(),
          ),
          GoRoute(
            path: 'expenses/add',
            name: 'add_expense_from_operations',
            builder: (context, state) => const AddExpenseScreen(),
          ),
          GoRoute(
            path: 'financing/add',
            name: 'add_financing_from_operations',
            builder: (context, state) => const AddFinancingRequestScreen(),
          ),
          // Detail screens are top-level routes accessed by ID
        ],
      ),
      GoRoute(
        path:
            '/sale-detail/:id', // The :id in path is now less directly used by builder
        name: AppRoute.saleDetail.name,
        builder: (context, state) {
          final sale = state.extra as Sale?;

          if (sale == null) {
            // Simplified error placeholder
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(
                child: Text('Sale data not provided or invalid.'),
              ),
            );
          }
          // Pass the Sale object to SaleDetailsScreen
          return SaleDetailsScreen(sale: sale);
        },
      ),
      GoRoute(
        path: '/expense-detail/:id',
        name: AppRoute.expenseDetail.name,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ExpenseDetailScreen(expenseId: id);
        },
      ),
      // Fallback for old /sales route, redirecting to /operations
      GoRoute(path: '/sales', redirect: (_, __) => '/operations'),
      GoRoute(path: '/sales/add', redirect: (_, __) => '/operations/sales/add'),
      GoRoute(
        path: '/sales/:saleId',
        redirect:
            (context, state) =>
                '/sale-detail/${state.pathParameters['saleId']}',
      ),
      GoRoute(
        path:
            '/expenses/add', // Kept for direct access if needed, or FAB in operations can use named route
        builder: (context, state) => const AddExpenseScreen(),
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
