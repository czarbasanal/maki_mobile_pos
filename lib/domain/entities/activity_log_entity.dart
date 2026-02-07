import 'package:equatable/equatable.dart';

/// Represents an activity log entry for audit trail.
///
/// Tracks sensitive operations like:
/// - Void sales
/// - Cost visibility toggles
/// - User management actions
/// - Password verifications
/// - Settings changes
class ActivityLogEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// Type of activity
  final ActivityType type;

  /// Brief description of the action
  final String action;

  /// Detailed description (optional)
  final String? details;

  /// User who performed the action
  final String userId;

  /// User's display name
  final String userName;

  /// User's role at time of action
  final String userRole;

  /// Related entity ID (e.g., sale ID, product ID)
  final String? entityId;

  /// Related entity type (e.g., 'sale', 'product', 'user')
  final String? entityType;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  /// IP address or device info (optional)
  final String? deviceInfo;

  /// When the action occurred
  final DateTime createdAt;

  const ActivityLogEntity({
    required this.id,
    required this.type,
    required this.action,
    this.details,
    required this.userId,
    required this.userName,
    required this.userRole,
    this.entityId,
    this.entityType,
    this.metadata,
    this.deviceInfo,
    required this.createdAt,
  });

  /// Whether this is a security-related action
  bool get isSecurityRelated =>
      type == ActivityType.security ||
      type == ActivityType.authentication ||
      type == ActivityType.userManagement;

  /// Whether this is a financial action
  bool get isFinancialAction =>
      type == ActivityType.sale ||
      type == ActivityType.voidSale ||
      type == ActivityType.refund;

  ActivityLogEntity copyWith({
    String? id,
    ActivityType? type,
    String? action,
    String? details,
    String? userId,
    String? userName,
    String? userRole,
    String? entityId,
    String? entityType,
    Map<String, dynamic>? metadata,
    String? deviceInfo,
    DateTime? createdAt,
    bool clearDetails = false,
    bool clearEntityId = false,
    bool clearEntityType = false,
    bool clearMetadata = false,
    bool clearDeviceInfo = false,
  }) {
    return ActivityLogEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      action: action ?? this.action,
      details: clearDetails ? null : (details ?? this.details),
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      entityId: clearEntityId ? null : (entityId ?? this.entityId),
      entityType: clearEntityType ? null : (entityType ?? this.entityType),
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
      deviceInfo: clearDeviceInfo ? null : (deviceInfo ?? this.deviceInfo),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        action,
        details,
        userId,
        userName,
        userRole,
        entityId,
        entityType,
        metadata,
        deviceInfo,
        createdAt,
      ];
}

/// Types of activities that can be logged.
enum ActivityType {
  // Authentication
  authentication('authentication', 'Authentication', '🔐'),
  login('login', 'Login', '🔑'),
  logout('logout', 'Logout', '🚪'),

  // Sales
  sale('sale', 'Sale', '💰'),
  voidSale('void_sale', 'Void Sale', '❌'),
  refund('refund', 'Refund', '↩️'),

  // Inventory
  inventory('inventory', 'Inventory', '📦'),
  stockAdjustment('stock_adjustment', 'Stock Adjustment', '📊'),
  receiving('receiving', 'Receiving', '📥'),

  // User Management
  userManagement('user_management', 'User Management', '👥'),
  userCreated('user_created', 'User Created', '➕'),
  userUpdated('user_updated', 'User Updated', '✏️'),
  userDeactivated('user_deactivated', 'User Deactivated', '🚫'),
  roleChanged('role_changed', 'Role Changed', '🔄'),

  // Security
  security('security', 'Security', '🛡️'),
  passwordVerified('password_verified', 'Password Verified', '✅'),
  passwordFailed('password_failed', 'Password Failed', '⚠️'),
  costViewed('cost_viewed', 'Cost Viewed', '👁️'),

  // Settings
  settings('settings', 'Settings', '⚙️'),
  costCodeChanged('cost_code_changed', 'Cost Code Changed', '🔢'),

  // General
  other('other', 'Other', '📝');

  final String value;
  final String displayName;
  final String emoji;

  const ActivityType(this.value, this.displayName, this.emoji);

  /// Creates from string value.
  static ActivityType fromString(String? value) {
    if (value == null || value.isEmpty) return ActivityType.other;
    return ActivityType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => ActivityType.other,
    );
  }

  /// Whether this is a security-related activity type.
  bool get isSecurityRelated =>
      this == ActivityType.security ||
      this == ActivityType.authentication ||
      this == ActivityType.userManagement ||
      this == ActivityType.passwordVerified ||
      this == ActivityType.passwordFailed;

  /// Whether this is a financial action.
  bool get isFinancialAction =>
      this == ActivityType.sale ||
      this == ActivityType.voidSale ||
      this == ActivityType.refund;
}
