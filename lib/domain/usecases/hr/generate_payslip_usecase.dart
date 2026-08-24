import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/payslip_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Writes the frozen payslip snapshot and returns the new doc id.
/// Permission: [Permission.manageHr]. Log string matches web's PayrollPage
/// verbatim (en-dash period range in details).
class GeneratePayslipUseCase {
  final PayslipRepository _repository;
  final ActivityLogger _logger;

  GeneratePayslipUseCase({
    required PayslipRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<String>> execute({
    required UserEntity actor,
    required PayslipEntity payslip,
  }) async {
    try {
      assertPermission(actor, Permission.manageHr);

      final id = await _repository.create(payslip);

      await _logger.log(
        type: ActivityType.userManagement,
        action: 'Generated payslip: ${payslip.employeeName}',
        details: '${payslip.periodStart} – ${payslip.periodEnd}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: id,
        entityType: 'payslip',
      );

      return UseCaseResult.successData(id);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to generate payslip: $e');
    }
  }
}
