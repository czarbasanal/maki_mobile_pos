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

/// Live, unsaved closing figures for [date]. Drives the review screen.
final dailyClosingDraftProvider =
    FutureProvider.family<DailyClosingDraft, DateTime>((ref, date) async {
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
            notes: notes,
          );
      if (result.success) {
        state = const AsyncValue.data(null);
        _ref.invalidate(dailyClosingForDateProvider);
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
