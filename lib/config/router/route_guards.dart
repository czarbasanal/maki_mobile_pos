import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/constants/constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Defines which roles can access which routes.
///
/// This is used by the router to determine if a user
/// should be allowed to navigate to a specific route.
abstract class RouteGuards {
  /// Routes that don't require authentication
  static const Set<String> publicRoutes = {
    '/login',
  };

  /// Routes accessible by all authenticated users
  static const Set<String> commonRoutes = {
    '/',
    '/pos',
    '/pos/checkout',
    '/drafts',
  };

  /// Routes that require specific permissions
  static const Map<String, Permission> protectedRoutes = {
    // Inventory
    '/inventory': Permission.viewInventory,
    '/inventory/add': Permission.addProduct,
    // Receiving
    '/receiving': Permission.accessReceiving,
    '/receiving/bulk': Permission.bulkReceive,
    '/receiving/history': Permission.viewReceivingHistory,
    '/receiving/drafts': Permission.accessReceiving,
    '/receiving/purchase-orders': Permission.accessReceiving,
    '/receiving/import': Permission.bulkReceive,
    // Suppliers
    '/suppliers': Permission.viewSuppliers,
    '/suppliers/add': Permission.addSupplier,
    // Expenses
    '/expenses': Permission.viewExpenses,
    '/expenses/add': Permission.addExpense,
    '/expenses/history': Permission.viewExpenses,
    // Reports
    '/reports': Permission.viewSalesReports,
    '/reports/sales': Permission.viewSalesReports,
    '/reports/profit': Permission.viewProfitReports,
    '/reports/labor': Permission.viewSalesReports,
    '/reports/job-orders': Permission.viewJobOrderReports,
    '/reports/history': Permission.viewSalesReports,
    '/reports/price-changes': Permission.viewProductCost,
    '/reports/top-selling': Permission.viewSalesReports,
    '/reports/end-of-day': Permission.viewEndOfDay,
    '/reports/end-of-day/history': Permission.viewEndOfDay,
    // Void approval queue (admin)
    '/void-requests': Permission.voidSale,
    // Users
    '/users': Permission.viewUsers,
    '/users/add': Permission.addUser,
    // Settings
    '/settings': Permission.viewSettings,
    '/settings/cost-codes': Permission.editCostCodeMapping,
    '/settings/categories': Permission.manageCategories,
    '/settings/mechanics': Permission.manageCategories,
    '/settings/motorcycle-models': Permission.manageCategories,
    // Logs
    '/logs': Permission.viewUserLogs,
  };

  /// Checks if a route is public (no auth required).
  static bool isPublicRoute(String path) {
    return publicRoutes.contains(path);
  }

  /// Checks if a route is a common route (any authenticated user).
  static bool isCommonRoute(String path) {
    // Check exact match
    if (commonRoutes.contains(path)) return true;

    // Check if it's a draft edit route (e.g., /drafts/123)
    if (path.startsWith('/drafts/')) return true;

    return false;
  }

  /// Checks if a user can access a specific route.
  ///
  /// Returns true if:
  /// - Route is public
  /// - Route is common and user is authenticated
  /// - User has the required permission for protected route
  static bool canAccess(String path, UserEntity? user) {
    // Public routes - anyone can access
    if (isPublicRoute(path)) {
      return true;
    }

    // No user - can't access protected routes
    if (user == null) {
      return false;
    }

    // Inactive user - can't access anything
    if (!user.isActive) {
      return false;
    }

    // Access-denied is reachable by any authenticated user — it's the
    // landing screen for permission failures.
    if (path == RoutePaths.accessDenied) {
      return true;
    }

    // Common routes - any authenticated user
    if (isCommonRoute(path)) {
      return true;
    }

    // Check protected routes
    final permission = _getRequiredPermission(path);
    if (permission != null) {
      return user.hasPermission(permission);
    }

    // Dynamic / nested routes (e.g. /inventory/edit/:id) — fail-safe deny.
    return _checkDynamicRoute(path, user);
  }

  /// Gets the required permission for a route.
  static Permission? _getRequiredPermission(String path) {
    // Exact match
    if (protectedRoutes.containsKey(path)) {
      return protectedRoutes[path];
    }

    return null;
  }

  /// Checks access for dynamic routes (with parameters).
  static bool _checkDynamicRoute(String path, UserEntity user) {
    // Inventory edit routes - staff needs editProductLimited, admin needs editProduct
    if (path.startsWith('/inventory/edit/')) {
      return user.hasPermission(Permission.editProduct) ||
          user.hasPermission(Permission.editProductLimited);
    }

    // Price-history view lives under /inventory/<id>/price-history — it exposes
    // cost, so it is admin-only via viewProductCost (defense in depth; the UI
    // tile is also gated). Must precede the generic /inventory/<id> branch.
    if (RegExp(r'^/inventory/[^/]+/price-history$').hasMatch(path)) {
      return user.hasPermission(Permission.viewProductCost);
    }

    // Inventory detail routes (view) - anyone with viewInventory
    if (RegExp(r'^/inventory/[^/]+$').hasMatch(path)) {
      return user.hasPermission(Permission.viewInventory);
    }

    // Supplier edit routes
    if (path.startsWith('/suppliers/edit/')) {
      return user.hasPermission(Permission.editSupplier);
    }

    // Expense edit routes - only admin can edit
    if (path.startsWith('/expenses/edit/')) {
      return user.hasPermission(Permission.editExpense);
    }

    // Report sale detail routes - anyone with viewSalesReports
    if (path.startsWith('/reports/sale/')) {
      return user.hasPermission(Permission.viewSalesReports);
    }

    // User edit routes
    if (path.startsWith('/users/edit/')) {
      return user.hasPermission(Permission.editUser);
    }

    // Bulk receiving detail (resume a saved bulk draft) — same gate as
    // /receiving/bulk.
    if (path.startsWith('/receiving/bulk/')) {
      return user.hasPermission(Permission.bulkReceive);
    }

    // Purchase orders — new + detail live under the list path; same gate as
    // /receiving/purchase-orders (staff + admin).
    if (path.startsWith('/receiving/purchase-orders/')) {
      return user.hasPermission(Permission.accessReceiving);
    }

    // About screen lives under /settings/about — anyone with viewSettings.
    if (path == RoutePaths.about) {
      return user.hasPermission(Permission.viewSettings);
    }

    // Per-kind editors live under /settings/categories/<kind> — same gate as
    // the hub.
    if (path.startsWith('${RoutePaths.categorySettings}/')) {
      return user.hasPermission(Permission.manageCategories);
    }

    // Fail-safe: deny everything not explicitly allowlisted above. Any new
    // dynamic route must be added here, otherwise we'd leak access.
    return false;
  }

  /// Gets the redirect path when access is denied.
  static String getRedirectPath(UserEntity? user, String attemptedPath) {
    // Not authenticated - go to login
    if (user == null) {
      return '/login';
    }

    // Authenticated but no access - go to dashboard
    return '/';
  }

  /// Gets available menu items for a user role.
  ///
  /// Updated role permissions:
  /// - Cashier: POS, Drafts, Inventory (view), Reports (daily), Expenses (add), Settings (profile)
  /// - Staff: POS, Drafts, Inventory (edit no price), Receiving, Reports (daily), Expenses (add), Settings (profile)
  /// - Admin: Everything
  static List<MenuItem> getMenuItems(UserRole role) {
    final items = <MenuItem>[];

    // POS - available to all
    items.add(const MenuItem(
      title: 'POS',
      icon: Icons.point_of_sale,
      path: '/pos',
    ));

    // Drafts - available to all
    items.add(const MenuItem(
      title: 'Job Orders',
      icon: Icons.drafts,
      path: '/drafts',
    ));

    // Inventory - all roles can view
    if (RolePermissions.hasPermission(role, Permission.viewInventory)) {
      items.add(const MenuItem(
        title: 'Inventory',
        icon: Icons.inventory,
        path: '/inventory',
      ));
    }

    // Receiving - staff and admin
    if (RolePermissions.hasPermission(role, Permission.accessReceiving)) {
      items.add(const MenuItem(
        title: 'Receiving',
        icon: Icons.local_shipping,
        path: '/receiving',
      ));
    }

    // Suppliers - admin only
    if (RolePermissions.hasPermission(role, Permission.viewSuppliers)) {
      items.add(const MenuItem(
        title: 'Suppliers',
        icon: Icons.people,
        path: '/suppliers',
      ));
    }

    // Expenses - all roles can view/add
    if (RolePermissions.hasPermission(role, Permission.viewExpenses)) {
      items.add(const MenuItem(
        title: 'Expenses',
        icon: Icons.receipt_long,
        path: '/expenses',
      ));
    }

    // Reports - all roles (daily for cashier/staff, full for admin)
    if (RolePermissions.hasPermission(role, Permission.viewSalesReports)) {
      items.add(const MenuItem(
        title: 'Reports',
        icon: Icons.bar_chart,
        path: '/reports',
      ));
    }

    // Users - admin only
    if (RolePermissions.hasPermission(role, Permission.viewUsers)) {
      items.add(const MenuItem(
        title: 'Users',
        icon: Icons.manage_accounts,
        path: '/users',
      ));
    }

    // Settings - all roles (profile for cashier/staff, full for admin)
    if (RolePermissions.hasPermission(role, Permission.viewSettings)) {
      items.add(const MenuItem(
        title: 'Settings',
        icon: Icons.settings,
        path: '/settings',
      ));
    }

    // Logs - admin only
    if (RolePermissions.hasPermission(role, Permission.viewUserLogs)) {
      items.add(const MenuItem(
        title: 'Activity Logs',
        icon: Icons.history,
        path: '/logs',
      ));
    }

    return items;
  }
}

/// Represents a menu item in the dashboard.
class MenuItem {
  final String title;
  final IconData icon;
  final String path;
  final String? badge;

  const MenuItem({
    required this.title,
    required this.icon,
    required this.path,
    this.badge,
  });
}
