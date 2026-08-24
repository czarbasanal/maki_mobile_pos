import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/payslip_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Deletes a payslip (frozen snapshots can be removed, never edited).
/// Permission: [Permission.manageHr]. Log string matches web verbatim.
class DeletePayslipUseCase {
  final PayslipRepository _repository;
  final ActivityLogger _logger;

  DeletePayslipUseCase({
    required PayslipRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<void>> execute({
    required UserEntity actor,
    required String payslipId,
    required String employeeName,
  }) async {
    try {
      assertPermission(actor, Permission.manageHr);

      await _repository.delete(payslipId);

      await _logger.log(
        type: ActivityType.userManagement,
        action: 'Deleted payslip: $employeeName',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: payslipId,
        entityType: 'payslip',
      );

      return const UseCaseResult.successVoid();
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to delete payslip: $e');
    }
  }
}
