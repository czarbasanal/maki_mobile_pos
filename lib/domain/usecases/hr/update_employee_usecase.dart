import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/employee_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Edits a registry entry. Permission: [Permission.manageHr].
///
/// [activeChanged] marks an activate/deactivate flip so the log's details
/// column reads "Reactivated"/"Deactivated" — web parity; a plain edit
/// carries no details.
class UpdateEmployeeUseCase {
  final EmployeeRepository _repository;
  final ActivityLogger _logger;

  UpdateEmployeeUseCase({
    required EmployeeRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<void>> execute({
    required UserEntity actor,
    required EmployeeEntity employee,
    bool activeChanged = false,
  }) async {
    try {
      assertPermission(actor, Permission.manageHr);

      await _repository.update(employee);

      await _logger.log(
        type: ActivityType.userManagement,
        action: 'Updated employee: ${employee.name}',
        details: activeChanged
            ? (employee.isActive ? 'Reactivated' : 'Deactivated')
            : null,
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: employee.id,
        entityType: 'employee',
      );

      return const UseCaseResult.successVoid();
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to update employee: $e');
    }
  }
}
