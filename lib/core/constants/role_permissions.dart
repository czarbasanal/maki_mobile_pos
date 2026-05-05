import 'package:maki_mobile_pos/core/enums/user_role.dart';

/// Defines all permission types in the system.
enum Permission {
  // POS Permissions
  accessPos,
  processSale,
  applyDiscount,
  voidSale,

  // Draft Permissions
  saveDraft,
  viewDrafts,
  editDraft,
  deleteDraft,

  // Inventory Permissions
  viewInventory,
  viewProductCost, // Requires password confirmation
  addProduct,
  editProduct, // Full edit including price (admin only)
  editProductLimited, // Edit without price field (staff only)
  deleteProduct,

  // Receiving Permissions
  accessReceiving,
  receiveStock,
  bulkReceive,
  importCsv,
  viewReceivingHistory,

  // Supplier Permissions
  viewSuppliers,
  addSupplier,
  editSupplier,
  deleteSupplier,

  // Expense Permissions
  viewExpenses,
  addExpense,
  editExpense,
  deleteExpense,

  // Cash Management
  managePettyCash,
  performCutOff,

  // Reports Permissions
  viewSalesReports,
  viewProfitReports, // Shows cost-based profit data
  viewDailySalesOnly, // Can only view today's sales (cashier & staff)

  // User Management Permissions
  viewUsers,
  addUser,
  editUser,
  deleteUser,
  editUserPermissions,

  // Settings Permissions
  viewSettings,
  editOwnProfile, // Edit own display name and password
  editCostCodeMapping,
  manageCategories, // Manage product/expense category lists

  // Logs
  viewUserLogs,
}

/// Maps user roles to their allowed permissions.
///
/// This is the SINGLE SOURCE OF TRUTH for role-based access control.
/// Any permission check in the app should reference this class.
abstract class RolePermissions {
  // ==================== CASHIER PERMISSIONS ====================
  // POS + view-only inventory + today's sales report + add expenses + own profile
  static const Set<Permission> _cashierPermissions = {
    // POS
    Permission.accessPos,
    Permission.processSale,
    Permission.applyDiscount,
    // Note: voidSale is NOT included (admin only)
    // Drafts
    Permission.saveDraft,
    Permission.viewDrafts,
    Permission.editDraft,
    Permission.deleteDraft,
    // Inventory (view only, no cost, no edit)
    Permission.viewInventory,
    // Reports (daily only)
    Permission.viewSalesReports,
    Permission.viewDailySalesOnly,
    // Expenses (add only)
    Permission.viewExpenses,
    Permission.addExpense,
    // Settings (own profile only)
    Permission.viewSettings,
    Permission.editOwnProfile,
  };

  // ==================== STAFF PERMISSIONS ====================
  // POS + edit inventory (no price) + today's sales + add expenses
  // + receiving & history + own profile
  static const Set<Permission> _staffPermissions = {
    // POS
    Permission.accessPos,
    Permission.processSale,
    Permission.applyDiscount,
    // Note: voidSale is NOT included (admin only)
    // Drafts
    Permission.saveDraft,
    Permission.viewDrafts,
    Permission.editDraft,
    Permission.deleteDraft,
    // Inventory (edit without price, no cost visibility)
    Permission.viewInventory,
    Permission.editProductLimited,
    // Note: viewProductCost is NOT included
    // Note: addProduct is NOT included (admin only)
    // Note: deleteProduct is NOT included (admin only)
    // Receiving (full access + history)
    Permission.accessReceiving,
    Permission.receiveStock,
    Permission.bulkReceive,
    Permission.viewReceivingHistory,
    // Reports (daily only)
    Permission.viewSalesReports,
    Permission.viewDailySalesOnly,
    // Expenses (add only)
    Permission.viewExpenses,
    Permission.addExpense,
    // Settings (own profile only)
    Permission.viewSettings,
    Permission.editOwnProfile,
  };

  // ==================== ADMIN PERMISSIONS ====================
  // Full access to everything - explicitly listed for const compatibility
  static const Set<Permission> _adminPermissions = {
    // POS
    Permission.accessPos,
    Permission.processSale,
    Permission.applyDiscount,
    Permission.voidSale,
    // Drafts
    Permission.saveDraft,
    Permission.viewDrafts,
    Permission.editDraft,
    Permission.deleteDraft,
    // Inventory
    Permission.viewInventory,
    Permission.viewProductCost,
    Permission.addProduct,
    Permission.editProduct,
    Permission.editProductLimited,
    Permission.deleteProduct,
    // Receiving
    Permission.accessReceiving,
    Permission.receiveStock,
    Permission.bulkReceive,
    Permission.importCsv,
    Permission.viewReceivingHistory,
    // Suppliers
    Permission.viewSuppliers,
    Permission.addSupplier,
    Permission.editSupplier,
    Permission.deleteSupplier,
    // Expenses
    Permission.viewExpenses,
    Permission.addExpense,
    Permission.editExpense,
    Permission.deleteExpense,
    // Cash Management
    Permission.managePettyCash,
    Permission.performCutOff,
    // Reports (full access, no daily restriction)
    Permission.viewSalesReports,
    Permission.viewProfitReports,
    // User Management
    Permission.viewUsers,
    Permission.addUser,
    Permission.editUser,
    Permission.deleteUser,
    Permission.editUserPermissions,
    // Settings (full)
    Permission.viewSettings,
    Permission.editOwnProfile,
    Permission.editCostCodeMapping,
    Permission.manageCategories,
    // Logs
    Permission.viewUserLogs,
  };

  /// Checks if a role has a specific permission.
  static bool hasPermission(UserRole role, Permission permission) {
    return getPermissions(role).contains(permission);
  }

  /// Gets all permissions for a role.
  static Set<Permission> getPermissions(UserRole role) {
    switch (role) {
      case UserRole.cashier:
        return _cashierPermissions;
      case UserRole.staff:
        return _staffPermissions;
      case UserRole.admin:
        return _adminPermissions;
    }
  }

  /// Checks if a role can access a specific route/feature.
  static bool canAccess(UserRole role, String feature) {
    switch (feature) {
      case 'pos':
        return hasPermission(role, Permission.accessPos);
      case 'inventory':
        return hasPermission(role, Permission.viewInventory);
      case 'receiving':
        return hasPermission(role, Permission.accessReceiving);
      case 'suppliers':
        return hasPermission(role, Permission.viewSuppliers);
      case 'expenses':
        return hasPermission(role, Permission.viewExpenses);
      case 'reports':
        return hasPermission(role, Permission.viewSalesReports);
      case 'users':
        return hasPermission(role, Permission.viewUsers);
      case 'settings':
        return hasPermission(role, Permission.viewSettings);
      case 'logs':
        return hasPermission(role, Permission.viewUserLogs);
      default:
        return false;
    }
  }

  /// Permissions that require password confirmation before use.
  static const Set<Permission> passwordProtectedPermissions = {
    Permission.viewProductCost,
    Permission.voidSale,
    Permission.editCostCodeMapping,
  };

  /// Checks if a permission requires password confirmation.
  static bool requiresPassword(Permission permission) {
    return passwordProtectedPermissions.contains(permission);
  }

  /// Checks if a role is restricted to daily reports only.
  static bool isDailyReportsOnly(UserRole role) {
    return hasPermission(role, Permission.viewDailySalesOnly);
  }

  /// Checks if a role can edit product fields (limited = no price).
  static bool canEditProductLimited(UserRole role) {
    return hasPermission(role, Permission.editProductLimited) &&
        !hasPermission(role, Permission.editProduct);
  }

  /// Checks if a role can do full product edits (including price).
  static bool canEditProductFull(UserRole role) {
    return hasPermission(role, Permission.editProduct);
  }
}
