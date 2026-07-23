import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Permanently deletes a user's Firestore document.
///
/// Permissions: [Permission.deleteUser] (admin-only on this surface).
///
/// Business guards (independent of Firestore rules, which enforce the same):
/// - You cannot delete yourself.
/// - The target must exist.
/// - The target must already be DEACTIVATED (deactivate-first).
///
/// Historical records (sales, logs) keep their denormalized uid/name strings —
/// no cascade. The Firebase Auth credential is cleaned up separately with
/// scripts/delete-auth-user.mjs.
class DeleteUserUseCase {
  final UserRepository _repository;
  final ActivityLogger _logger;

  DeleteUserUseCase({
    required UserRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<void>> execute({
    required UserEntity actor,
    required String userId,
  }) async {
    try {
      assertPermission(actor, Permission.deleteUser);

      if (userId == actor.id) {
        return const UseCaseResult.failure(
          message: 'You cannot delete yourself',
          code: 'self-delete',
        );
      }

      final target = await _repository.getUserById(userId);
      if (target == null) {
        return const UseCaseResult.failure(
          message: 'User not found',
          code: 'not-found',
        );
      }

      if (target.isActive) {
        return const UseCaseResult.failure(
          message: 'Deactivate this user before deleting them',
          code: 'active-target',
        );
      }

      await _repository.deleteUser(userId);

      await _logger.log(
        type: ActivityType.userManagement,
        action: 'Deleted user: ${target.displayName}',
        details: target.email,
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: userId,
        entityType: 'user',
      );

      return const UseCaseResult.successVoid();
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to delete user: $e');
    }
  }
}
