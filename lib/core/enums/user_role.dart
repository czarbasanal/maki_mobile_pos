/// Defines the three user roles in the POS system.
///
/// Role hierarchy (least to most privileged):
/// [cashier] < [staff] < [admin]
enum UserRole {
  /// Can only access POS functionality
  cashier('cashier', 'Cashier'),

  /// Can access POS, Receiving, and Inventory (without cost visibility)
  staff('staff', 'Staff'),

  /// Full system access including user management and cost visibility
  admin('admin', 'Admin');

  const UserRole(this.value, this.displayName);

  /// The value stored in Firestore
  final String value;

  /// Human-readable name for UI display
  final String displayName;

  /// Creates a [UserRole] from a Firestore string value.
  /// Returns [cashier] as default if value is invalid.
  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.cashier,
    );
  }

  /// Checks if this role has equal or higher privilege than [other].
  bool hasPrivilegeOf(UserRole other) {
    return index >= other.index;
  }

  /// Checks if this role is exactly [admin].
  bool get isAdmin => this == UserRole.admin;

  /// Checks if this role is exactly [staff].
  bool get isStaff => this == UserRole.staff;

  /// Checks if this role is exactly [cashier].
  bool get isCashier => this == UserRole.cashier;
}
