import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Computes the live, unsaved [DailyClosingDraft] for a business day by
/// combining the sales summary with the day's expenses.
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

  Future<UseCaseResult<DailyClosingDraft>> execute({
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

      final draft = DailyClosingDraft.fromData(
        businessDate: dayStart,
        summary: summary,
        expenses: expenses,
      );
      return UseCaseResult.successData(draft);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(
          message: 'Failed to compute closing summary: $e');
    }
  }
}
