import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Returns a [SalesSummary] for the given date range.
///
/// Permission: [Permission.viewSalesReports].
///
/// If the actor holds [Permission.viewDailySalesOnly] (cashier / staff), the
/// requested range must be inside today (00:00 to 23:59:59.999 local). Wider
/// ranges are rejected with `daily-only`. The previous implementation
/// (`salesSummaryProvider` calling the repo directly) enforced this only in
/// the UI's date picker — anyone calling the provider programmatically bypassed
/// the restriction.
class GetSalesReportUseCase {
  final SaleRepository _repository;
  final DateTime Function() _now;

  GetSalesReportUseCase({
    required SaleRepository repository,
    DateTime Function()? now,
  })  : _repository = repository,
        _now = now ?? DateTime.now;

  Future<UseCaseResult<SalesSummary>> execute({
    required UserEntity actor,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      assertPermission(actor, Permission.viewSalesReports);

      if (actor.hasPermission(Permission.viewDailySalesOnly)) {
        final today = _now();
        final dayStart = DateTime(today.year, today.month, today.day);
        final dayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59,
            999);
        if (startDate.isBefore(dayStart) || endDate.isAfter(dayEnd)) {
          return const UseCaseResult.failure(
            message:
                "You can only view today's sales. Switch the date range to today.",
            code: 'daily-only',
          );
        }
      }

      final summary = await _repository.getSalesSummary(
        startDate: startDate,
        endDate: endDate,
      );
      return UseCaseResult.successData(summary);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to load sales report: $e');
    }
  }
}
