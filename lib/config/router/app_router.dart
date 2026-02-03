import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';

// Temporary placeholder screens - will be replaced in later steps
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title Screen')),
    );
  }
}

/// Provider for the GoRouter instance.
///
/// Using a provider allows the router to react to auth state changes
/// and enables dependency injection for testing.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // Initial route
    initialLocation: RoutePaths.login,

    // Enable debug logging in development
    debugLogDiagnostics: true,

    // Global redirect for authentication
    // TODO: Implement auth check in Phase 2
    redirect: (context, state) {
      // Will be implemented with auth provider
      return null;
    },

    // Error handling
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
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
            ElevatedButton(
              onPressed: () => context.go(RoutePaths.dashboard),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),

    // Route definitions
    routes: [
      // ==================== AUTH ROUTES ====================
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (context, state) => const _PlaceholderScreen(title: 'Login'),
      ),

      // ==================== MAIN ROUTES ====================
      GoRoute(
        path: RoutePaths.dashboard,
        name: RouteNames.dashboard,
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Dashboard'),
      ),

      GoRoute(
        path: RoutePaths.pos,
        name: RouteNames.pos,
        builder: (context, state) => const _PlaceholderScreen(title: 'POS'),
        routes: [
          GoRoute(
            path: 'checkout',
            name: RouteNames.checkout,
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Checkout'),
          ),
        ],
      ),

      // ==================== DRAFT ROUTES ====================
      GoRoute(
        path: RoutePaths.drafts,
        name: RouteNames.drafts,
        builder: (context, state) => const _PlaceholderScreen(title: 'Drafts'),
        routes: [
          GoRoute(
            path: ':id',
            name: RouteNames.draftEdit,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return _PlaceholderScreen(title: 'Edit Draft: $id');
            },
          ),
        ],
      ),

      // ==================== INVENTORY ROUTES ====================
      GoRoute(
        path: RoutePaths.inventory,
        name: RouteNames.inventory,
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Inventory'),
        routes: [
          GoRoute(
            path: 'add',
            name: RouteNames.productAdd,
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Add Product'),
          ),
          GoRoute(
            path: 'edit/:id',
            name: RouteNames.productEdit,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return _PlaceholderScreen(title: 'Edit Product: $id');
            },
          ),
          GoRoute(
            path: ':id',
            name: RouteNames.productDetail,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return _PlaceholderScreen(title: 'Product: $id');
            },
          ),
        ],
      ),

      // ==================== RECEIVING ROUTES ====================
      GoRoute(
        path: RoutePaths.receiving,
        name: RouteNames.receiving,
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Receiving'),
        routes: [
          GoRoute(
            path: 'bulk',
            name: RouteNames.bulkReceiving,
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Bulk Receiving'),
          ),
        ],
      ),

      // ==================== SUPPLIER ROUTES ====================
      GoRoute(
        path: RoutePaths.suppliers,
        name: RouteNames.suppliers,
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Suppliers'),
        routes: [
          GoRoute(
            path: 'add',
            name: RouteNames.supplierAdd,
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Add Supplier'),
          ),
          GoRoute(
            path: 'edit/:id',
            name: RouteNames.supplierEdit,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return _PlaceholderScreen(title: 'Edit Supplier: $id');
            },
          ),
        ],
      ),

      // ==================== EXPENSE ROUTES ====================
      GoRoute(
        path: RoutePaths.expenses,
        name: RouteNames.expenses,
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Expenses'),
        routes: [
          GoRoute(
            path: 'add',
            name: RouteNames.expenseAdd,
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Add Expense'),
          ),
          GoRoute(
            path: 'edit/:id',
            name: RouteNames.expenseEdit,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return _PlaceholderScreen(title: 'Edit Expense: $id');
            },
          ),
        ],
      ),

      // ==================== REPORT ROUTES ====================
      GoRoute(
        path: RoutePaths.reports,
        name: RouteNames.reports,
        builder: (context, state) => const _PlaceholderScreen(title: 'Reports'),
        routes: [
          GoRoute(
            path: 'sales',
            name: RouteNames.salesReport,
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Sales Report'),
          ),
          GoRoute(
            path: 'profit',
            name: RouteNames.profitReport,
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Profit Report'),
          ),
        ],
      ),

      // ==================== USER MANAGEMENT ROUTES ====================
      GoRoute(
        path: RoutePaths.users,
        name: RouteNames.users,
        builder: (context, state) => const _PlaceholderScreen(title: 'Users'),
        routes: [
          GoRoute(
            path: 'add',
            name: RouteNames.userAdd,
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Add User'),
          ),
          GoRoute(
            path: 'edit/:id',
            name: RouteNames.userEdit,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return _PlaceholderScreen(title: 'Edit User: $id');
            },
          ),
        ],
      ),

      // ==================== SETTINGS ROUTES ====================
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Settings'),
        routes: [
          GoRoute(
            path: 'cost-codes',
            name: RouteNames.costCodeSettings,
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Cost Code Settings'),
          ),
        ],
      ),

      // ==================== LOGS ROUTES ====================
      GoRoute(
        path: RoutePaths.userLogs,
        name: RouteNames.userLogs,
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'User Logs'),
      ),
    ],
  );
});
