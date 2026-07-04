import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/daily_closing/close_day_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/daily_closing/get_daily_closing_summary_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/expense_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

// ==================== REPOSITORY PROVIDER ====================

final dailyClosingRepositoryProvider = Provider<DailyClosingRepository>((ref) {
  return DailyClosingRepositoryImpl(firestore: ref.watch(firestoreProvider));
});

// ==================== USE-CASE PROVIDERS ====================

final getDailyClosingSummaryUseCaseProvider =
    Provider<GetDailyClosingSummaryUseCase>((ref) {
  return GetDailyClosingSummaryUseCase(
    saleRepository: ref.watch(saleRepositoryProvider),
    expenseRepository: ref.watch(expenseRepositoryProvider),
  );
});

final closeDayUseCaseProvider = Provider<CloseDayUseCase>((ref) {
  return CloseDayUseCase(
    closingRepository: ref.watch(dailyClosingRepositoryProvider),
    saleRepository: ref.watch(saleRepositoryProvider),
    expenseRepository: ref.watch(expenseRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

// ==================== QUERIES ====================

/// Raw closing inputs (sales summary + itemized expenses) for [date].
///
/// For **today** the figures are sourced from the same live providers the rest
/// of the app uses — [todaysSalesSummaryProvider] (sales) and
/// [expensesByDateRangeProvider] (expenses) — so the End-of-Day numbers always
/// match the dashboard and refresh on the same triggers (checkout / void /
/// expense edits). For a past date (not reached by the current UI) it falls
/// back to the one-shot use case.
final dailyClosingDataProvider =
    FutureProvider.family<DailyClosingData, DateTime>((ref, date) async {
  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  final now = DateTime.now();
  final isToday = dayStart == DateTime(now.year, now.month, now.day);

  if (isToday) {
    final summary = await ref.watch(todaysSalesSummaryProvider.future);
    final expenses = await ref.watch(
      expensesByDateRangeProvider(
        ExpenseDateRangeParams(startDate: dayStart, endDate: dayEnd),
      ).future,
    );
    return DailyClosingData(
      businessDate: dayStart,
      summary: summary,
      expenses: expenses,
    );
  }

  // Past day — compute once via the use case (enforces viewEndOfDay).
  final actor = ref.watch(currentUserProvider).valueOrNull;
  if (actor == null) {
    throw const UnauthenticatedException();
  }
  final result = await ref
      .watch(getDailyClosingSummaryUseCaseProvider)
      .execute(actor: actor, date: date);
  if (!result.success) {
    throw AppExceptionWrapper(
      message: result.errorMessage ?? 'Failed to load closing summary',
      code: result.errorCode,
    );
  }
  return result.data!;
});

/// Full-day (no exclusions) draft for [date] — a thin derive over
/// [dailyClosingDataProvider] for consumers that only need the totals.
final dailyClosingDraftProvider =
    FutureProvider.family<DailyClosingDraft, DateTime>((ref, date) async {
  final data = await ref.watch(dailyClosingDataProvider(date).future);
  return data.draftExcluding(const {});
});

/// The saved closing for [date], or null if the day is still open.
final dailyClosingForDateProvider =
    FutureProvider.family<DailyClosingEntity?, DateTime>((ref, date) async {
  return ref.watch(dailyClosingRepositoryProvider).getClosing(date);
});

/// Stream of past closings, newest first.
final dailyClosingHistoryProvider =
    StreamProvider<List<DailyClosingEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(dailyClosingRepositoryProvider).watchClosings();
  });
});

// ==================== OPERATIONS ====================

/// Notifier wrapping the close-day mutation. Resolves the actor from
/// [currentUserProvider] and invalidates dependent providers on success.
class DailyClosingOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  DailyClosingOperationsNotifier(this._ref)
      : super(const AsyncValue.data(null));

  UserEntity _requireUser() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      throw const UnauthenticatedException();
    }
    return user;
  }

  Future<DailyClosingEntity?> closeDay({
    required DateTime date,
    required double openingFloat,
    required double countedCash,
    double plateNoDp = 0,
    double plateNoDelivery = 0,
    Set<String> excludedExpenseIds = const {},
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actor = _requireUser();
      final result = await _ref.read(closeDayUseCaseProvider).execute(
            actor: actor,
            date: date,
            openingFloat: openingFloat,
            countedCash: countedCash,
            plateNoDp: plateNoDp,
            plateNoDelivery: plateNoDelivery,
            excludedExpenseIds: excludedExpenseIds,
            notes: notes,
          );
      if (result.success) {
        state = const AsyncValue.data(null);
        _ref.invalidate(dailyClosingForDateProvider);
        _ref.invalidate(dailyClosingDataProvider);
        _ref.invalidate(dailyClosingDraftProvider);
        _ref.invalidate(dailyClosingHistoryProvider);
        _ref.invalidate(todaysSalesSummaryProvider);
        return result.data;
      }
      state = AsyncValue.error(
        result.errorMessage ?? 'Failed to close day',
        StackTrace.current,
      );
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final dailyClosingOperationsProvider = StateNotifierProvider<
    DailyClosingOperationsNotifier, AsyncValue<void>>((ref) {
  return DailyClosingOperationsNotifier(ref);
});
