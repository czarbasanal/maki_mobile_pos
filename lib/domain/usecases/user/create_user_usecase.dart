import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Creates a new user. Permission: [Permission.addUser].
///
/// The repository handles Firebase Auth account creation + Firestore document
/// in a single call. This use-case adds the permission gate and the audit
/// log entry that previously had to be written manually by every caller.
class CreateUserUseCase {
  final UserRepository _repository;
  final ActivityLogger _logger;

  CreateUserUseCase({
    required UserRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<UserEntity>> execute({
    required UserEntity actor,
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    try {
      assertPermission(actor, Permission.addUser);

      final created = await _repository.createUser(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
        createdBy: actor.id,
      );

      await _logger.logUserCreated(
        performedBy: actor,
        newUserId: created.id,
        newUserName: created.displayName,
        newUserRole: created.role.value,
      );

      return UseCaseResult.successData(created);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to create user: $e');
    }
  }
}
