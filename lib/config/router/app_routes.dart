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
import 'package:maki_mobile_pos/presentation/mobile/screens/inventory/price_history_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/receiving_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/bulk_receiving_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/receiving_history_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/receiving_drafts_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/batch_import_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/suppliers/suppliers_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/suppliers/supplier_form_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/expenses/expenses_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/expenses/expense_form_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/expenses/expense_history_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/sales_list_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/sales_report_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/reports_hub_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/profit_report_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/labor_report_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/price_change_report_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/top_selling_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/end_of_day_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/daily_closing_history_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/sales/sale_detail_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/sales/void_requests_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/users/users_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/users/user_form_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/settings_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/cost_code_settings_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/category_editor_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/category_settings_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/mechanic_editor_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/motorcycle_model_editor_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/category_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/about_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/logs/activity_logs_screen.dart';

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
              color: AppColors.error.withValues(alpha: 0.7),
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
List<RouteBase> featureRoutes() => [
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
            routes: [
              GoRoute(
                path: 'price-history',
                name: RouteNames.productPriceHistory,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return PriceHistoryScreen(productId: id);
                },
              ),
            ],
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
          GoRoute(
            path: 'history',
            name: RouteNames.receivingHistory,
            builder: (context, state) => const ReceivingHistoryScreen(),
          ),
          GoRoute(
            path: 'drafts',
            name: RouteNames.receivingDrafts,
            builder: (context, state) => const ReceivingDraftsScreen(),
          ),
          GoRoute(
            path: 'import',
            name: RouteNames.batchImport,
            builder: (context, state) => const BatchImportScreen(),
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
          GoRoute(
            path: 'history',
            name: RouteNames.expenseHistory,
            builder: (context, state) => ExpenseHistoryScreen(
              initialCategory: state.uri.queryParameters['category'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.reports,
        name: RouteNames.reports,
        builder: (context, state) => const ReportsHubScreen(),
        routes: [
          GoRoute(
            path: 'sales',
            name: RouteNames.salesReport,
            builder: (context, state) => const SalesReportScreen(),
          ),
          GoRoute(
            path: 'history',
            name: RouteNames.salesHistory,
            builder: (context, state) => const SalesListScreen(),
          ),
          GoRoute(
            path: 'profit',
            name: RouteNames.profitReport,
            builder: (context, state) => const ProfitReportScreen(),
          ),
          GoRoute(
            path: 'labor',
            name: RouteNames.laborReport,
            builder: (context, state) => const LaborReportScreen(),
          ),
          GoRoute(
            path: 'price-changes',
            name: RouteNames.priceChangeReport,
            builder: (context, state) => const PriceChangeReportScreen(),
          ),
          GoRoute(
            path: 'top-selling',
            name: RouteNames.topSelling,
            builder: (context, state) => const TopSellingScreen(),
          ),
          GoRoute(
            path: 'sale/:id',
            name: RouteNames.saleDetail,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return SaleDetailScreen(saleId: id);
            },
          ),
          GoRoute(
            path: 'end-of-day',
            name: RouteNames.endOfDay,
            builder: (context, state) => const EndOfDayScreen(),
            routes: [
              GoRoute(
                path: 'history',
                name: RouteNames.endOfDayHistory,
                builder: (context, state) =>
                    const DailyClosingHistoryScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.voidRequests,
        name: RouteNames.voidRequests,
        builder: (context, state) => const VoidRequestsScreen(),
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
            path: 'categories',
            name: RouteNames.categorySettings,
            builder: (context, state) => const CategorySettingsScreen(),
            routes: [
              GoRoute(
                path: ':kind',
                name: RouteNames.categoryEditor,
                builder: (context, state) {
                  final raw = state.pathParameters['kind'];
                  final kind = CategoryKind.values.firstWhere(
                    (k) => k.name == raw,
                    orElse: () => CategoryKind.product,
                  );
                  return CategoryEditorScreen(kind: kind);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'mechanics',
            name: RouteNames.mechanics,
            builder: (context, state) => const MechanicEditorScreen(),
          ),
          GoRoute(
            path: 'motorcycle-models',
            name: RouteNames.motorcycleModels,
            builder: (context, state) => const MotorcycleModelEditorScreen(),
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
    ];
