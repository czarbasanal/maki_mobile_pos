import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/employee_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Adds an employee to the payroll registry. Permission: [Permission.manageHr].
/// Log string matches web's EmployeesPage verbatim.
class CreateEmployeeUseCase {
  final EmployeeRepository _repository;
  final ActivityLogger _logger;

  CreateEmployeeUseCase({
    required EmployeeRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<EmployeeEntity>> execute({
    required UserEntity actor,
    required EmployeeEntity employee,
  }) async {
    try {
      assertPermission(actor, Permission.manageHr);

      final created = await _repository.create(employee);

      await _logger.log(
        type: ActivityType.userManagement,
        action: 'Created employee: ${created.name}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: created.id,
        entityType: 'employee',
      );

      return UseCaseResult.successData(created);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to create employee: $e');
    }
  }
}
