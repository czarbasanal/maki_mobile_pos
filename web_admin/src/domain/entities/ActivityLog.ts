// Mirror of lib/domain/entities/activity_log_entity.dart. Values must match
// the Dart enum exactly — both apps write to the same `user_logs` collection.
//
// Fix-up note: phase 0's port invented strings (sale_created, etc.). The
// canonical values come from the Dart enum:
//   authentication / login / logout / sale / void_sale / refund / inventory
//   / stock_adjustment / receiving / user_management / user_created /
//   user_updated / user_deactivated / role_changed / security /
//   password_verified / password_failed / cost_viewed / settings /
//   cost_code_changed / expense / supplier / petty_cash / petty_cash_cutoff
//   / other

export const ActivityType = {
  authentication: 'authentication',
  login: 'login',
  logout: 'logout',
  sale: 'sale',
  voidSale: 'void_sale',
  refund: 'refund',
  inventory: 'inventory',
  stockAdjustment: 'stock_adjustment',
  receiving: 'receiving',
  userManagement: 'user_management',
  userCreated: 'user_created',
  userUpdated: 'user_updated',
  userDeactivated: 'user_deactivated',
  roleChanged: 'role_changed',
  security: 'security',
  passwordVerified: 'password_verified',
  passwordFailed: 'password_failed',
  costViewed: 'cost_viewed',
  settings: 'settings',
  costCodeChanged: 'cost_code_changed',
  expense: 'expense',
  supplier: 'supplier',
  pettyCash: 'petty_cash',
  pettyCashCutOff: 'petty_cash_cutoff',
  other: 'other',
} as const;

export type ActivityType = (typeof ActivityType)[keyof typeof ActivityType];

export const activityTypeDisplayName: Record<ActivityType, string> = {
  authentication: 'Authentication',
  login: 'Login',
  logout: 'Logout',
  sale: 'Sale',
  void_sale: 'Void Sale',
  refund: 'Refund',
  inventory: 'Inventory',
  stock_adjustment: 'Stock Adjustment',
  receiving: 'Receiving',
  user_management: 'User Management',
  user_created: 'User Created',
  user_updated: 'User Updated',
  user_deactivated: 'User Deactivated',
  role_changed: 'Role Changed',
  security: 'Security',
  password_verified: 'Password Verified',
  password_failed: 'Password Failed',
  cost_viewed: 'Cost Viewed',
  settings: 'Settings',
  cost_code_changed: 'Cost Code Changed',
  expense: 'Expense',
  supplier: 'Supplier',
  petty_cash: 'Petty Cash',
  petty_cash_cutoff: 'Petty Cash Cut-off',
  other: 'Other',
};

export function activityTypeFromString(value: string | null | undefined): ActivityType {
  if (!value) return ActivityType.other;
  const allValues = Object.values(ActivityType) as string[];
  return (allValues.includes(value) ? value : ActivityType.other) as ActivityType;
}

export function isSecurityActivity(t: ActivityType): boolean {
  return (
    t === ActivityType.security ||
    t === ActivityType.authentication ||
    t === ActivityType.userManagement ||
    t === ActivityType.passwordVerified ||
    t === ActivityType.passwordFailed
  );
}

export function isFinancialActivity(t: ActivityType): boolean {
  return t === ActivityType.sale || t === ActivityType.voidSale || t === ActivityType.refund;
}

export interface ActivityLog {
  id: string;
  type: ActivityType;
  action: string;
  details: string | null;
  userId: string;
  userName: string;
  userRole: string;
  entityId: string | null;
  entityType: string | null;
  metadata: Record<string, unknown> | null;
  deviceInfo: string | null;
  createdAt: Date;
}
