import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';

/// Throws [PermissionDeniedException] if [user] does not hold [permission].
///
/// Use at the entry point of every state-changing use-case so business rules
/// fail loudly rather than silently writing to Firestore (which the rules
/// would reject anyway, but with a less actionable error).
void assertPermission(UserEntity user, Permission permission) {
  if (!user.hasPermission(permission)) {
    throw PermissionDeniedException(
      message:
          'User ${user.email} (${user.role.value}) lacks permission: ${permission.name}',
      requiredPermission: permission.name,
    );
  }
}

/// Throws if the user does not hold *any* of the listed permissions.
void assertAnyPermission(UserEntity user, List<Permission> permissions) {
  if (!permissions.any(user.hasPermission)) {
    throw PermissionDeniedException(
      message:
          'User ${user.email} (${user.role.value}) lacks any of: ${permissions.map((p) => p.name).join(', ')}',
    );
  }
}
