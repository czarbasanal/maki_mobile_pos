import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';

// Temporary placeholder screen with navigation
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderScreen({
    required this.title,
    this.icon = Icons.construction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
              icon,
              size: 80,
              color: AppColors.primaryDark.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
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

/// Access denied screen shown when user lacks permission.
class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
        centerTitle: true,
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

/// Provider for the GoRouter instance.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Create a key to force router refresh on auth changes
  final authState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: RoutePaths.login,
    debugLogDiagnostics: true,

    // Global redirect for authentication and authorization
    redirect: (context, state) {
      final path = state.uri.path;
      final isPublicRoute = RouteGuards.isPublicRoute(path);

      // Get current user synchronously
      final user = authState.whenOrNull(data: (user) => user);
      final isLoading = authState.isLoading;

      // Don't redirect while loading
      if (isLoading) {
        return null;
      }

      final isLoggedIn = user != null;
      final isLoginRoute = path == RoutePaths.login;

      // If not logged in and trying to access protected route, go to login
      if (!isLoggedIn && !isPublicRoute) {
        return RoutePaths.login;
      }

      // If logged in and on login page, go to dashboard
      if (isLoggedIn && isLoginRoute) {
        return RoutePaths.dashboard;
      }

      // Check role-based access for protected routes
      if (isLoggedIn && !isPublicRoute && !RouteGuards.canAccess(path, user)) {
        // Return to dashboard if access denied
        return RoutePaths.dashboard;
      }

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
              child: const Text('Go to Dashboard'),
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
        builder: (context, state) => const _PlaceholderScreen(
          title: 'POS',
          icon: Icons.point_of_sale,
        ),
        routes: [
          GoRoute(
            path: 'checkout',
            name: RouteNames.checkout,
            builder: (context, state) => const _PlaceholderScreen(
              title: 'Checkout',
              icon: Icons.shopping_cart_checkout,
            ),
          ),
        ],
      ),

      // ==================== DRAFT ROUTES ====================
      GoRoute(
        path: RoutePaths.drafts,
        name: RouteNames.drafts,
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Drafts',
          icon: Icons.drafts,
        ),
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
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Inventory',
          icon: Icons.inventory,
        ),
        routes: [
          GoRoute(
            path: 'add',
            name: RouteNames.productAdd,
            builder: (context, state) => const _PlaceholderScreen(
              title: 'Add Product',
              icon: Icons.add_box,
            ),
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
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Receiving',
          icon: Icons.local_shipping,
        ),
        routes: [
          GoRoute(
            path: 'bulk',
            name: RouteNames.bulkReceiving,
            builder: (context, state) => const _PlaceholderScreen(
              title: 'Bulk Receiving',
              icon: Icons.inventory_2,
            ),
          ),
        ],
      ),

      // ==================== SUPPLIER ROUTES ====================
      GoRoute(
        path: RoutePaths.suppliers,
        name: RouteNames.suppliers,
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Suppliers',
          icon: Icons.people,
        ),
        routes: [
          GoRoute(
            path: 'add',
            name: RouteNames.supplierAdd,
            builder: (context, state) => const _PlaceholderScreen(
              title: 'Add Supplier',
              icon: Icons.person_add,
            ),
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
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Expenses',
          icon: Icons.receipt_long,
        ),
        routes: [
          GoRoute(
            path: 'add',
            name: RouteNames.expenseAdd,
            builder: (context, state) => const _PlaceholderScreen(
              title: 'Add Expense',
              icon: Icons.add_card,
            ),
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
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Reports',
          icon: Icons.bar_chart,
        ),
        routes: [
          GoRoute(
            path: 'sales',
            name: RouteNames.salesReport,
            builder: (context, state) => const _PlaceholderScreen(
              title: 'Sales Report',
              icon: Icons.show_chart,
            ),
          ),
          GoRoute(
            path: 'profit',
            name: RouteNames.profitReport,
            builder: (context, state) => const _PlaceholderScreen(
              title: 'Profit Report',
              icon: Icons.trending_up,
            ),
          ),
        ],
      ),

      // ==================== USER MANAGEMENT ROUTES ====================
      GoRoute(
        path: RoutePaths.users,
        name: RouteNames.users,
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Users',
          icon: Icons.manage_accounts,
        ),
        routes: [
          GoRoute(
            path: 'add',
            name: RouteNames.userAdd,
            builder: (context, state) => const _PlaceholderScreen(
              title: 'Add User',
              icon: Icons.person_add,
            ),
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
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Settings',
          icon: Icons.settings,
        ),
        routes: [
          GoRoute(
            path: 'cost-codes',
            name: RouteNames.costCodeSettings,
            builder: (context, state) => const _PlaceholderScreen(
              title: 'Cost Code Settings',
              icon: Icons.code,
            ),
          ),
        ],
      ),

      // ==================== LOGS ROUTES ====================
      GoRoute(
        path: RoutePaths.userLogs,
        name: RouteNames.userLogs,
        builder: (context, state) => const _PlaceholderScreen(
          title: 'User Logs',
          icon: Icons.history,
        ),
      ),

      // ==================== ACCESS DENIED ====================
      GoRoute(
        path: '/access-denied',
        builder: (context, state) => const _AccessDeniedScreen(),
      ),
    ],
  );
});
