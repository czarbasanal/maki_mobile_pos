import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Returns the top-selling products for the given date range.
///
/// Permission: [Permission.viewSalesReports]. Same daily-only restriction
/// as [GetSalesReportUseCase] — cashier / staff can only request today's
/// range.
class GetTopSellingUseCase {
  final SaleRepository _repository;
  final DateTime Function() _now;

  GetTopSellingUseCase({
    required SaleRepository repository,
    DateTime Function()? now,
  })  : _repository = repository,
        _now = now ?? DateTime.now;

  Future<UseCaseResult<List<ProductSalesData>>> execute({
    required UserEntity actor,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 10,
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
                "You can only view today's top-selling products. Switch the date range to today.",
            code: 'daily-only',
          );
        }
      }

      final results = await _repository.getTopSellingProducts(
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
      return UseCaseResult.successData(results);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(
          message: 'Failed to load top-selling products: $e');
    }
  }
}
