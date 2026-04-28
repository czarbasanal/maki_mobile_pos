import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Returns a [SalesSummary] for the given date range with profit + cost
/// fields populated. Admin-only — gated on [Permission.viewProfitReports].
///
/// `SalesSummary` is the same payload as the sales report; the separation
/// exists so the screen that needs profit data has to acquire admin
/// permission explicitly, rather than reading sales data and trusting the
/// UI to hide cost/profit fields. The data layer always includes those
/// fields, but only this use case authorizes admin to see them.
class GetProfitReportUseCase {
  final SaleRepository _repository;

  GetProfitReportUseCase({required SaleRepository repository})
      : _repository = repository;

  Future<UseCaseResult<SalesSummary>> execute({
    required UserEntity actor,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      assertPermission(actor, Permission.viewProfitReports);

      final summary = await _repository.getSalesSummary(
        startDate: startDate,
        endDate: endDate,
      );
      return UseCaseResult.successData(summary);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to load profit report: $e');
    }
  }
}
