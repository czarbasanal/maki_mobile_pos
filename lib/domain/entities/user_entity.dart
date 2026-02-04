import 'package:equatable/equatable.dart';
import 'package:maki_mobile_pos/core/constants/constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';

/// Represents a user in the POS system.
///
/// This is a domain entity - it contains only business logic
/// and has no knowledge of data sources or serialization.
class UserEntity extends Equatable {
  /// Unique identifier (Firebase Auth UID)
  final String id;

  /// User's email address (used for login)
  final String email;

  /// User's display name
  final String displayName;

  /// User's role determining permissions
  final UserRole role;

  /// Whether the user account is active
  final bool isActive;

  /// Optional phone number
  final String? phoneNumber;

  /// URL to user's profile photo
  final String? photoUrl;

  /// Timestamp when user was created
  final DateTime createdAt;

  /// Timestamp when user was last updated
  final DateTime? updatedAt;

  /// ID of user who created this account (for audit)
  final String? createdBy;

  /// ID of user who last updated this account (for audit)
  final String? updatedBy;

  /// Timestamp of last login
  final DateTime? lastLoginAt;

  const UserEntity({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    this.phoneNumber,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.lastLoginAt,
  });

  // ==================== PERMISSION HELPERS ====================

  /// Checks if this user has a specific permission.
  bool hasPermission(Permission permission) {
    if (!isActive) return false;
    return RolePermissions.hasPermission(role, permission);
  }

  /// Checks if this user can access a specific feature.
  bool canAccess(String feature) {
    if (!isActive) return false;
    return RolePermissions.canAccess(role, feature);
  }

  /// Checks if this user is an admin.
  bool get isAdmin => role == UserRole.admin;

  /// Checks if this user is staff.
  bool get isStaff => role == UserRole.staff;

  /// Checks if this user is a cashier.
  bool get isCashier => role == UserRole.cashier;

  /// Checks if this user is staff or admin.
  bool get isStaffOrAdmin => isStaff || isAdmin;

  /// Gets the display name for the role.
  String get roleDisplayName => role.displayName;

  // ==================== COPY WITH ====================

  /// Creates a copy of this user with the given fields replaced.
  UserEntity copyWith({
    String? id,
    String? email,
    String? displayName,
    UserRole? role,
    bool? isActive,
    String? phoneNumber,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    DateTime? lastLoginAt,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  // ==================== EQUATABLE ====================

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        role,
        isActive,
        phoneNumber,
        photoUrl,
        createdAt,
        updatedAt,
        createdBy,
        updatedBy,
        lastLoginAt,
      ];

  @override
  String toString() {
    return 'UserEntity(id: $id, email: $email, displayName: $displayName, role: ${role.value}, isActive: $isActive)';
  }
}
