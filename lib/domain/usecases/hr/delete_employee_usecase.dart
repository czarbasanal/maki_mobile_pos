import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/employee_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Hard-deletes a registry entry (the UI only offers this on inactive rows).
/// Past payslips keep their own frozen data. Permission: [Permission.manageHr].
class DeleteEmployeeUseCase {
  final EmployeeRepository _repository;
  final ActivityLogger _logger;

  DeleteEmployeeUseCase({
    required EmployeeRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<void>> execute({
    required UserEntity actor,
    required String employeeId,
    required String employeeName,
  }) async {
    try {
      assertPermission(actor, Permission.manageHr);

      await _repository.delete(employeeId);

      await _logger.log(
        type: ActivityType.userManagement,
        action: 'Deleted employee: $employeeName',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: employeeId,
        entityType: 'employee',
      );

      return const UseCaseResult.successVoid();
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to delete employee: $e');
    }
  }
}
