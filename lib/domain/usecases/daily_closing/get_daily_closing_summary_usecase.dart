import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Fetches the raw closing inputs ([DailyClosingData]: sales summary +
/// itemized expenses) for a business day. Callers derive drafts via
/// [DailyClosingData.draftExcluding].
///
/// Permission: [Permission.viewEndOfDay].
class GetDailyClosingSummaryUseCase {
  final SaleRepository _saleRepository;
  final ExpenseRepository _expenseRepository;

  GetDailyClosingSummaryUseCase({
    required SaleRepository saleRepository,
    required ExpenseRepository expenseRepository,
  })  : _saleRepository = saleRepository,
        _expenseRepository = expenseRepository;

  Future<UseCaseResult<DailyClosingData>> execute({
    required UserEntity actor,
    required DateTime date,
  }) async {
    try {
      assertPermission(actor, Permission.viewEndOfDay);

      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd =
          DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

      final summary = await _saleRepository.getSalesSummary(
        startDate: dayStart,
        endDate: dayEnd,
      );
      final expenses = await _expenseRepository.getExpenses(
        startDate: dayStart,
        endDate: dayEnd,
        limit: 1000,
      );

      return UseCaseResult.successData(DailyClosingData(
        businessDate: dayStart,
        summary: summary,
        expenses: expenses,
      ));
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(
          message: 'Failed to compute closing summary: $e');
    }
  }
}
