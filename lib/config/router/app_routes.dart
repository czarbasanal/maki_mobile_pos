import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

// Auth screens (shared)
import 'package:maki_mobile_pos/presentation/shared/screens/auth/login_screen.dart';

// Mobile feature screens.
import 'package:maki_mobile_pos/presentation/mobile/screens/dashboard/dashboard_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/pos/pos_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/pos/checkout_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/drafts/drafts_list_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/drafts/draft_edit_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/inventory/inventory_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/inventory/product_form_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/receiving_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/bulk_receiving_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/suppliers/suppliers_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/suppliers/supplier_form_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/expenses/expenses_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/expenses/expense_form_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/petty_cash/petty_cash_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/petty_cash/petty_cash_form_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/sales_list_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/sales_report_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/profit_report_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/sales/sale_detail_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/users/users_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/users/user_form_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/settings_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/cost_code_settings_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/about_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/logs/activity_logs_screen.dart';

// Web feature screens (incrementally added; web falls back to mobile screens
// for routes that have not yet been redesigned for desktop).
import 'package:maki_mobile_pos/presentation/web/screens/dashboard/web_dashboard_screen.dart';

/// Which UI surface a route is being mounted into.
///
/// `featureRoutes(Surface.web)` returns web-redesigned screens where they
/// exist (currently: dashboard) and falls back to the mobile screen for
/// everything else. Mobile passes [Surface.mobile] and always gets the
/// mobile screens.
enum Surface { mobile, web }

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

Widget buildRouterErrorScreen(BuildContext context, GoRouterState state) {
  return Scaffold(
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
  );
}

/// Routes that live outside the web shell and the mobile bottom-nav (login,
/// access-denied). Both routers mount these at the root.
List<RouteBase> authRoutes() => [
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.accessDenied,
        name: RouteNames.accessDenied,
        builder: (context, state) => const _AccessDeniedScreen(),
      ),
    ];

/// Feature routes (everything post-login). The web router wraps these in a
/// ShellRoute that paints the sidebar + top bar; the mobile router mounts
/// them flat.
List<RouteBase> featureRoutes(Surface surface) => [
      GoRoute(
        path: RoutePaths.dashboard,
        name: RouteNames.dashboard,
        builder: (context, state) => switch (surface) {
          Surface.web => const WebDashboardScreen(),
          Surface.mobile => const DashboardScreen(),
        },
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
              return ProductFormScreen(productId: id);
            },
          ),
        ],
      ),
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
            name: RouteNames.bulkReceivingDetail,
            builder: (context, state) {
              final id = state.pathParameters['id'];
              return BulkReceivingScreen(receivingId: id);
            },
          ),
        ],
      ),
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
          GoRoute(
            path: 'sale/:id',
            name: RouteNames.saleDetail,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return SaleDetailScreen(saleId: id);
            },
          ),
        ],
      ),
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
            name: RouteNames.about,
            builder: (context, state) => const AboutScreen(),
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.userLogs,
        name: RouteNames.userLogs,
        builder: (context, state) => const ActivityLogsScreen(),
      ),
      GoRoute(
        path: RoutePaths.pettyCash,
        name: RouteNames.pettyCash,
        builder: (context, state) => const PettyCashScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: RouteNames.pettyCashNew,
            builder: (context, state) => const PettyCashFormScreen(),
          ),
        ],
      ),
    ];
