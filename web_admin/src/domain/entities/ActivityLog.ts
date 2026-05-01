// Mirror of lib/domain/entities/activity_log_entity.dart. ActivityType values
// must match the Dart enum exactly — they're written by both apps to the same
// `user_logs` collection.

export const ActivityType = {
  login: 'login',
  logout: 'logout',
  saleCreated: 'sale_created',
  saleVoided: 'sale_voided',
  productCreated: 'product_created',
  productUpdated: 'product_updated',
  productDeleted: 'product_deleted',
  supplierCreated: 'supplier_created',
  supplierUpdated: 'supplier_updated',
  supplierDeleted: 'supplier_deleted',
  expenseCreated: 'expense_created',
  expenseUpdated: 'expense_updated',
  expenseDeleted: 'expense_deleted',
  userCreated: 'user_created',
  userUpdated: 'user_updated',
  userDeleted: 'user_deleted',
  receivingCreated: 'receiving_created',
  receivingCompleted: 'receiving_completed',
  pettyCashIn: 'petty_cash_in',
  pettyCashOut: 'petty_cash_out',
  pettyCashCutOff: 'petty_cash_cut_off',
  settingsUpdated: 'settings_updated',
  costCodeUpdated: 'cost_code_updated',
} as const;

export type ActivityType = (typeof ActivityType)[keyof typeof ActivityType];

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
