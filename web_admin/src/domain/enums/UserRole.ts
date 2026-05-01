// Mirror of lib/core/enums/user_role.dart. Stored in Firestore as the string
// value of `value`. cashier < staff < admin in privilege.

export const UserRole = {
  cashier: 'cashier',
  staff: 'staff',
  admin: 'admin',
} as const;

export type UserRole = (typeof UserRole)[keyof typeof UserRole];

export const userRoleDisplayName: Record<UserRole, string> = {
  cashier: 'Cashier',
  staff: 'Staff',
  admin: 'Admin',
};

const order: UserRole[] = [UserRole.cashier, UserRole.staff, UserRole.admin];

export function userRoleFromString(value: string | null | undefined): UserRole {
  if (value === UserRole.staff || value === UserRole.admin) return value;
  return UserRole.cashier;
}

export function hasPrivilegeOf(self: UserRole, other: UserRole): boolean {
  return order.indexOf(self) >= order.indexOf(other);
}
