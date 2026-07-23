import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/data/repositories/daily_closing_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/daily_closing_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Closes a business day: recomputes the figures, captures the manual float +
/// counted cash, persists the closing, and writes an activity log.
///
/// Permission: [Permission.closeDay]. Rejects with `already-closed` if a
/// closing already exists for that day (one closing per day).
class CloseDayUseCase {
  final DailyClosingRepository _closingRepository;
  final SaleRepository _saleRepository;
  final ExpenseRepository _expenseRepository;
  final ActivityLogger _logger;

  CloseDayUseCase({
    required DailyClosingRepository closingRepository,
    required SaleRepository saleRepository,
    required ExpenseRepository expenseRepository,
    required ActivityLogger logger,
  })  : _closingRepository = closingRepository,
        _saleRepository = saleRepository,
        _expenseRepository = expenseRepository,
        _logger = logger;

  Future<UseCaseResult<DailyClosingEntity>> execute({
    required UserEntity actor,
    required DateTime date,
    required double openingFloat,
    required double countedCash,
    List<double> plateNoDpAmounts = const [],
    List<double> plateNoDeliveryAmounts = const [],
    Set<String> excludedExpenseIds = const {},
    String? notes,
  }) async {
    try {
      assertPermission(actor, Permission.closeDay);

      final existing = await _closingRepository.getClosing(date);
      if (existing != null) {
        return const UseCaseResult.failure(
          message: 'This day has already been closed.',
          code: 'already-closed',
        );
      }

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

      // Excluded expenses stay recorded in the ledger — they're just not
      // deducted from the drawer in this closing.
      final includedExpenses = excludedExpenseIds.isEmpty
          ? expenses
          : expenses
              .where((e) => !excludedExpenseIds.contains(e.id))
              .toList();

      final draft = DailyClosingDraft.fromData(
        businessDate: dayStart,
        summary: summary,
        expenses: includedExpenses,
      );
      // Sums are computed ONCE here; the scalars remain the single source
      // for expected-cash math and back-compat reads.
      final plateNoDp =
          plateNoDpAmounts.fold(0.0, (total, amount) => total + amount);
      final plateNoDelivery =
          plateNoDeliveryAmounts.fold(0.0, (total, amount) => total + amount);
      final expectedCash = draft.expectedCashFor(
        openingFloat,
        plateNoDp: plateNoDp,
        plateNoDelivery: plateNoDelivery,
      );
      final variance = countedCash - expectedCash;
      final id = DailyClosingRepositoryImpl.docIdFor(dayStart);

      final entity = DailyClosingEntity(
        id: id,
        businessDate: dayStart,
        grossSales: draft.grossSales,
        netSales: draft.netSales,
        totalDiscounts: draft.totalDiscounts,
        cashSales: draft.cashSales,
        nonCashSales: draft.nonCashSales,
        gcashSales: draft.gcashSales,
        mayaSales: draft.mayaSales,
        totalExpenses: draft.totalExpenses,
        cashExpenses: draft.cashExpenses,
        salmonReceivable: draft.salmonReceivable,
        laborRevenue: draft.laborRevenue,
        plateNoDp: plateNoDp,
        plateNoDelivery: plateNoDelivery,
        plateNoDpAmounts: List.of(plateNoDpAmounts),
        plateNoDeliveryAmounts: List.of(plateNoDeliveryAmounts),
        openingFloat: openingFloat,
        expectedCash: expectedCash,
        countedCash: countedCash,
        variance: variance,
        salesCount: draft.salesCount,
        voidedCount: draft.voidedCount,
        excludedExpenseIds: excludedExpenseIds.toList()..sort(),
        notes: (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
        closedBy: actor.id,
        closedByName: actor.displayName,
        closedAt: DateTime.now(),
      );

      final saved = await _closingRepository.saveClosing(entity);

      await _logger.log(
        type: ActivityType.dayClosed,
        action: 'Closed business day $id',
        details:
            'Expected ₱${expectedCash.toStringAsFixed(2)}, counted ₱${countedCash.toStringAsFixed(2)} (variance ${variance >= 0 ? '+' : ''}${variance.toStringAsFixed(2)})',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: saved.id,
        entityType: 'daily_closing',
        metadata: {
          'expectedCash': expectedCash,
          'countedCash': countedCash,
          'variance': variance,
          'openingFloat': openingFloat,
        },
      );

      return UseCaseResult.successData(saved);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to close day: $e');
    }
  }
}
