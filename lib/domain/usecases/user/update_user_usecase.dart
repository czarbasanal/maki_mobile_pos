import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Updates an existing user. Handles plain field changes, role changes, and
/// active/inactive toggles in a single entry-point so all the cross-field
/// guards live in one place.
///
/// Permissions:
/// - [Permission.editUser] for any update
/// - [Permission.editUserPermissions] additionally required if the role is
///   changing
///
/// Business guards (independent of Firestore rules):
/// - You can't change your own role.
/// - You can't deactivate yourself.
/// - You can't demote or deactivate the last active admin.
/// - The target user must exist.
class UpdateUserUseCase {
  final UserRepository _repository;
  final ActivityLogger _logger;

  UpdateUserUseCase({
    required UserRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<UserEntity>> execute({
    required UserEntity actor,
    required UserEntity user,
  }) async {
    try {
      final original = await _repository.getUserById(user.id);
      if (original == null) {
        return const UseCaseResult.failure(
          message: 'User not found',
          code: 'not-found',
        );
      }

      final isRoleChange = original.role != user.role;
      final isActiveChange = original.isActive != user.isActive;
      final isDeactivating = original.isActive && !user.isActive;
      final isSelf = user.id == actor.id;

      // Permission tier:
      //   self-update with no role/isActive change → editOwnProfile (held by all roles)
      //   any other update → editUser (admin only)
      //   role change → additionally editUserPermissions
      if (isSelf && !isRoleChange && !isActiveChange) {
        assertPermission(actor, Permission.editOwnProfile);
      } else {
        assertPermission(actor, Permission.editUser);
      }
      if (isRoleChange) {
        assertPermission(actor, Permission.editUserPermissions);
      }

      if (user.id == actor.id && isRoleChange) {
        return const UseCaseResult.failure(
          message: 'You cannot change your own role',
          code: 'self-role-change',
        );
      }

      if (user.id == actor.id && isDeactivating) {
        return const UseCaseResult.failure(
          message: 'You cannot deactivate yourself',
          code: 'self-deactivate',
        );
      }

      // Last-admin guard. Trips when the change would remove the last active
      // admin from the system — either by demoting them or deactivating them.
      final wasActiveAdmin = original.role == UserRole.admin && original.isActive;
      final losingAdminStatus = wasActiveAdmin &&
          ((isRoleChange && user.role != UserRole.admin) || isDeactivating);
      if (losingAdminStatus) {
        final admins = await _repository.getUsersByRole(UserRole.admin);
        final activeAdminCount = admins.where((u) => u.isActive).length;
        if (activeAdminCount <= 1) {
          return const UseCaseResult.failure(
            message: 'Cannot demote or deactivate the last active admin',
            code: 'last-admin',
          );
        }
      }

      final updated = await _repository.updateUser(
        user: user,
        updatedBy: actor.id,
      );

      // Compose the change summary for the activity log.
      final changes = <String>[];
      if (original.displayName != updated.displayName) {
        changes.add('Name: ${updated.displayName}');
      }
      if (original.isActive != updated.isActive) {
        changes.add(updated.isActive ? 'Reactivated' : 'Deactivated');
      }
      await _logger.logUserUpdated(
        performedBy: actor,
        updatedUserId: updated.id,
        updatedUserName: updated.displayName,
        changes: changes.isEmpty ? null : changes.join(', '),
      );

      if (isRoleChange) {
        await _logger.logRoleChanged(
          performedBy: actor,
          targetUserId: updated.id,
          targetUserName: updated.displayName,
          oldRole: original.role.displayName,
          newRole: updated.role.displayName,
        );
      }

      return UseCaseResult.successData(updated);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to update user: $e');
    }
  }
}
