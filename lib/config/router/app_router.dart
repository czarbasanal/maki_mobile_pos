import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/config/router/route_guards.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

// Auth screens
import 'package:maki_mobile_pos/presentation/screens/auth/login_screen.dart';

// Main screens
import 'package:maki_mobile_pos/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:maki_mobile_pos/presentation/screens/pos/pos_screen.dart';
import 'package:maki_mobile_pos/presentation/screens/pos/checkout_screen.dart';

// Draft screens
import 'package:maki_mobile_pos/presentation/screens/drafts/drafts_list_screen.dart';
import 'package:maki_mobile_pos/presentation/screens/drafts/draft_edit_screen.dart';

// Inventory screens
import 'package:maki_mobile_pos/presentation/screens/inventory/inventory_screen.dart';
import 'package:maki_mobile_pos/presentation/screens/inventory/product_form_screen.dart';

// Receiving screens
import 'package:maki_mobile_pos/presentation/screens/receiving/receiving_screen.dart';
import 'package:maki_mobile_pos/presentation/screens/receiving/bulk_receiving_screen.dart';

// Supplier screens
import 'package:maki_mobile_pos/presentation/screens/suppliers/suppliers_screen.dart';
import 'package:maki_mobile_pos/presentation/screens/suppliers/supplier_form_screen.dart';

// Expense screens
import 'package:maki_mobile_pos/presentation/screens/expenses/expenses_screen.dart';
import 'package:maki_mobile_pos/presentation/screens/expenses/expense_form_screen.dart';

// Report screens
import 'package:maki_mobile_pos/presentation/screens/reports/sales_list_screen.dart';
import 'package:maki_mobile_pos/presentation/screens/reports/sales_report_screen.dart';
import 'package:maki_mobile_pos/presentation/screens/reports/profit_report_screen.dart';

// User management screens
import 'package:maki_mobile_pos/presentation/screens/users/users_screen.dart';
import 'package:maki_mobile_pos/presentation/screens/users/user_form_screen.dart';

// Settings screens
import 'package:maki_mobile_pos/presentation/screens/settings/settings_screen.dart';
import 'package:maki_mobile_pos/presentation/screens/settings/cost_code_settings_screen.dart';
import 'package:maki_mobile_pos/presentation/screens/settings/about_screen.dart';

// Logs screens
import 'package:maki_mobile_pos/presentation/screens/logs/activity_logs_screen.dart';

// ==================== ACCESS DENIED SCREEN ====================

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RoutePaths.dashboard);
            }
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 80,
              color: AppColors.error.withOpacity(0.7),
            ),
            const SizedBox(height: 24),
            Text(
              'Access Denied',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'You do not have permission to access this page.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go(RoutePaths.dashboard),
              icon: const Icon(Icons.home),
              label: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ROUTER PROVIDER ====================

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: RoutePaths.login,
    debugLogDiagnostics: true,

    // ==================== GLOBAL REDIRECT ====================
    redirect: (context, state) {
      final path = state.uri.path;
      final isPublicRoute = RouteGuards.isPublicRoute(path);

      final user = authState.whenOrNull(data: (user) => user);
      final isLoading = authState.isLoading;

      if (isLoading) return null;

      final isLoggedIn = user != null;
      final isLoginRoute = path == RoutePaths.login;

      if (!isLoggedIn && !isPublicRoute) {
        return RoutePaths.login;
      }

      if (isLoggedIn && isLoginRoute) {
        return RoutePaths.dashboard;
      }

      if (isLoggedIn && !isPublicRoute && !RouteGuards.canAccess(path, user)) {
        return RoutePaths.dashboard;
      }

      return null;
    },

    // ==================== ERROR HANDLING ====================
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RoutePaths.dashboard),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go(RoutePaths.dashboard),
              icon: const Icon(Icons.home),
              label: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    ),

    // ==================== ROUTE DEFINITIONS ====================
    routes: [
      // ==================== AUTH ROUTES ====================
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),

      // ==================== MAIN ROUTES ====================
      GoRoute(
        path: RoutePaths.dashboard,
        name: RouteNames.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),

      GoRoute(
        path: RoutePaths.pos,
        name: RouteNames.pos,
        builder: (context, state) => const POSScreen(),
        routes: [
          GoRoute(
            path: 'checkout',
            name: RouteNames.checkout,
            builder: (context, state) => const CheckoutScreen(),
          ),
        ],
      ),

      // ==================== DRAFT ROUTES ====================
      GoRoute(
        path: RoutePaths.drafts,
        name: RouteNames.drafts,
        builder: (context, state) => const DraftsListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            name: RouteNames.draftEdit,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return DraftEditScreen(draftId: id);
            },
          ),
        ],
      ),

      // ==================== INVENTORY ROUTES ====================
      GoRoute(
        path: RoutePaths.inventory,
        name: RouteNames.inventory,
        builder: (context, state) => const InventoryScreen(),
        routes: [
          GoRoute(
            path: 'add',
            name: RouteNames.productAdd,
            builder: (context, state) => const ProductFormScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            name: RouteNames.productEdit,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ProductFormScreen(productId: id);
            },
          ),
          GoRoute(
            path: ':id',
            name: RouteNames.productDetail,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ProductFormScreen(
                  productId: id); // Reuse form as detail view
            },
          ),
        ],
      ),

      // ==================== RECEIVING ROUTES ====================
      GoRoute(
        path: RoutePaths.receiving,
        name: RouteNames.receiving,
        builder: (context, state) => const ReceivingScreen(),
        routes: [
          GoRoute(
            path: 'bulk',
            name: RouteNames.bulkReceiving,
            builder: (context, state) => const BulkReceivingScreen(),
          ),
          GoRoute(
            path: 'bulk/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'];
              return BulkReceivingScreen(receivingId: id);
            },
          ),
        ],
      ),

      // ==================== SUPPLIER ROUTES ====================
      GoRoute(
        path: RoutePaths.suppliers,
        name: RouteNames.suppliers,
        builder: (context, state) => const SuppliersScreen(),
        routes: [
          GoRoute(
            path: 'add',
            name: RouteNames.supplierAdd,
            builder: (context, state) => const SupplierFormScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            name: RouteNames.supplierEdit,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return SupplierFormScreen(supplierId: id);
            },
          ),
        ],
      ),

      // ==================== EXPENSE ROUTES ====================
      GoRoute(
        path: RoutePaths.expenses,
        name: RouteNames.expenses,
        builder: (context, state) => const ExpensesScreen(),
        routes: [
          GoRoute(
            path: 'add',
            name: RouteNames.expenseAdd,
            builder: (context, state) => const ExpenseFormScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            name: RouteNames.expenseEdit,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ExpenseFormScreen(expenseId: id);
            },
          ),
        ],
      ),

      // ==================== REPORT ROUTES ====================
      GoRoute(
        path: RoutePaths.reports,
        name: RouteNames.reports,
        builder: (context, state) => const SalesListScreen(),
        routes: [
          GoRoute(
            path: 'sales',
            name: RouteNames.salesReport,
            builder: (context, state) => const SalesReportScreen(),
          ),
          GoRoute(
            path: 'profit',
            name: RouteNames.profitReport,
            builder: (context, state) => const ProfitReportScreen(),
          ),
        ],
      ),

      // ==================== USER MANAGEMENT ROUTES ====================
      GoRoute(
        path: RoutePaths.users,
        name: RouteNames.users,
        builder: (context, state) => const UsersScreen(),
        routes: [
          GoRoute(
            path: 'add',
            name: RouteNames.userAdd,
            builder: (context, state) => const UserFormScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            name: RouteNames.userEdit,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return UserFormScreen(userId: id);
            },
          ),
        ],
      ),

      // ==================== SETTINGS ROUTES ====================
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'cost-codes',
            name: RouteNames.costCodeSettings,
            builder: (context, state) => const CostCodeSettingsScreen(),
          ),
          GoRoute(
            path: 'about',
            builder: (context, state) => const AboutScreen(),
          ),
        ],
      ),

      // ==================== LOGS ROUTES ====================
      GoRoute(
        path: RoutePaths.userLogs,
        name: RouteNames.userLogs,
        builder: (context, state) => const ActivityLogsScreen(),
      ),

      // ==================== ACCESS DENIED ====================
      GoRoute(
        path: '/access-denied',
        builder: (context, state) => const _AccessDeniedScreen(),
      ),
    ],
  );
});
