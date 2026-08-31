import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/utils/labor_report.dart';
import 'package:maki_mobile_pos/core/utils/mechanic_performance_report.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_report.dart';
import 'package:maki_mobile_pos/core/utils/top_selling.dart';
import 'package:maki_mobile_pos/core/utils/week_range.dart';
import 'package:maki_mobile_pos/data/repositories/sale_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/reports/get_profit_report_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/reports/get_sales_report_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/reports/get_top_selling_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the SaleRepository instance.
final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return SaleRepositoryImpl(
    firestore: ref.watch(firestoreProvider),
    offsetMinutes: () => ref.read(shopOffsetProvider),
  );
});

// ==================== SALE QUERIES ====================

/// Provides today's sales as a real-time stream. Watches
/// [businessDayProvider] (not a raw `DateTime.now()` snapshot) so a
/// midnight rollover re-subscribes to the new day's range instead of
/// leaving yesterday's stream open.
final todaysSalesProvider = StreamProvider<List<SaleEntity>>((ref) {
  final day = ref.watch(businessDayProvider);
  return authGatedStream(ref, (_) {
    return ref.watch(saleRepositoryProvider).watchSalesForDay(date: day);
  });
});

/// Provides today's completed sales only.
final todaysCompletedSalesProvider = StreamProvider<List<SaleEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref
        .watch(saleRepositoryProvider)
        .watchTodaysSales(status: SaleStatus.completed);
  });
});

/// Provides sales for a specific date.
final salesForDateProvider =
    FutureProvider.family<List<SaleEntity>, DateTime>((ref, date) async {
  final repository = ref.watch(saleRepositoryProvider);
  return repository.getSalesForDay(
      date: date, offsetMinutes: ref.watch(shopOffsetProvider));
});

/// Provides sales for a date range.
final salesByDateRangeProvider =
    FutureProvider.autoDispose.family<List<SaleEntity>, DateRangeParams>(
        (ref, params) async {
  final repository = ref.watch(saleRepositoryProvider);
  return repository.getSalesByDateRange(
    startDate: params.startDate,
    endDate: params.endDate,
    status: params.status,
    cashierId: params.cashierId,
  );
});

/// Labor (service) report for a date range, grouped by mechanic. Derived from
/// the raw sales in range (via [salesByDateRangeProvider]) so it needs no extra
/// Firestore round-trip. Labor exposes no cost, so this is gated at the same
/// level as the sales report (staff + admin) via the route guard.
final laborReportProvider =
    FutureProvider.autoDispose.family<LaborReportData, DateRangeParams>(
        (ref, params) async {
  final sales = await ref.watch(salesByDateRangeProvider(params).future);
  return laborReportFromSales(sales);
});

/// Motorcycle Models report for a date range (Job Orders). Derived from the raw
/// sales in range; admin-gated at the route layer.
final motorcycleModelReportProvider = FutureProvider.autoDispose
    .family<MotorcycleModelReportData, DateRangeParams>((ref, params) async {
  final sales = await ref.watch(salesByDateRangeProvider(params).future);
  return motorcycleModelReportFromSales(sales);
});

/// Top Mechanics report for a date range (Job Orders), ranked by total revenue.
final mechanicPerformanceReportProvider = FutureProvider.autoDispose
    .family<MechanicPerformanceReportData, DateRangeParams>((ref, params) async {
  final sales = await ref.watch(salesByDateRangeProvider(params).future);
  return mechanicPerformanceReportFromSales(sales);
});

/// Provides a single sale by ID.
///
/// autoDispose so opening a sale re-reads it. Without it the first result was
/// kept for the life of the ProviderContainer, so a sale corrected elsewhere —
/// another device, or a back-office fix — kept showing its old payment method
/// until the app was restarted. Matches the other read-model providers here.
final saleByIdProvider =
    FutureProvider.autoDispose.family<SaleEntity?, String>((ref, saleId) async {
  final repository = ref.watch(saleRepositoryProvider);
  return repository.getSaleById(saleId);
});

/// Provides recent sales with pagination.
final recentSalesProvider =
    FutureProvider.family<List<SaleEntity>, RecentSalesParams>(
        (ref, params) async {
  final repository = ref.watch(saleRepositoryProvider);
  return repository.getRecentSales(
    limit: params.limit,
    startAfterSaleId: params.startAfterSaleId,
    status: params.status,
  );
});

// ==================== REPORT USE-CASE PROVIDERS ====================

final getSalesReportUseCaseProvider = Provider<GetSalesReportUseCase>((ref) {
  return GetSalesReportUseCase(repository: ref.watch(saleRepositoryProvider));
});

final getProfitReportUseCaseProvider = Provider<GetProfitReportUseCase>((ref) {
  return GetProfitReportUseCase(repository: ref.watch(saleRepositoryProvider));
});

final getTopSellingUseCaseProvider = Provider<GetTopSellingUseCase>((ref) {
  return GetTopSellingUseCase(repository: ref.watch(saleRepositoryProvider));
});

/// Helper: read the current user or throw Unauthenticated. Reports must
/// always have an authenticated actor — a null user means the caller
/// reached this provider before/after sign-in transition.
UserEntity _requireActor(Ref ref) {
  final actor = ref.watch(currentUserProvider).valueOrNull;
  if (actor == null) {
    throw const UnauthenticatedException();
  }
  return actor;
}

// ==================== SALES SUMMARY ====================

/// Provides today's sales summary. Routes through [GetSalesReportUseCase] so
/// permission gating + the daily-only check are enforced at the domain layer
/// (not just by the UI date picker).
final todaysSalesSummaryProvider = FutureProvider<SalesSummary>((ref) async {
  final actor = _requireActor(ref);
  // businessDayProvider is a shop WALL midnight — calendar fields, not an
  // instant — so both bounds go back through the offset. Watching it (not a
  // raw DateTime.now() snapshot) is what makes a rollover re-run this query
  // for the new day.
  final businessDay = ref.watch(businessDayProvider);
  final offset = ref.watch(shopOffsetProvider);
  final dayStart = shopDayStartInstant(businessDay, offset);
  final dayEnd = shopDayEndInstant(businessDay, offset);

  final result = await ref.watch(getSalesReportUseCaseProvider).execute(
        actor: actor,
        startDate: dayStart,
        endDate: dayEnd,
      );
  if (!result.success) {
    throw AppExceptionWrapper(
        message: result.errorMessage ?? 'Failed to load summary',
        code: result.errorCode);
  }
  return result.data!;
});

/// Sales summary over the last 7 *completed* days (rolling window ending at
/// yesterday 23:59). Today is deliberately excluded: it is still in progress,
/// and dividing a partial day's takings by a whole-day count inflates the
/// Avg Daily figure. Rolling, not calendar-month scoped — the 1st reaches
/// back into the previous month instead of resetting to —.
/// How many completed days the Avg Daily card averages over. Thirty rather
/// than seven: a week is short enough that one unusually busy or dead day
/// visibly swings the figure, which made it read as noise rather than a
/// baseline.
const int kAvgDailyWindowDays = 30;

final rollingWindowSummaryProvider =
    FutureProvider<SalesSummary>((ref) async {
  final actor = _requireActor(ref);
  // Watch the clock (not a raw DateTime.now() snapshot) so a midnight
  // rollover slides the window forward a day.
  final today = ref.watch(businessDayProvider);
  final window =
      rollingDays(today, kAvgDailyWindowDays, ref.watch(shopOffsetProvider));

  final result = await ref.watch(getSalesReportUseCaseProvider).execute(
        actor: actor,
        startDate: window.start,
        endDate: window.end,
      );
  if (!result.success) {
    throw AppExceptionWrapper(
        message: result.errorMessage ?? 'Failed to load summary',
        code: result.errorCode);
  }
  return result.data!;
});

/// Average daily gross sales across the last [kAvgDailyWindowDays] completed
/// days.
///
/// Total from [rollingWindowSummaryProvider] divided by that same constant — a
/// quiet or closed day is a real ₱0 day and stays in the average. Numerator and
/// denominator cover the same span, and there is no month reset: the 1st
/// averages the previous thirty days like any other date. Stays `double?` so
/// the card's null-renders-— handling is untouched (loading/error still show —).
final avgDailySalesProvider = Provider<AsyncValue<double?>>((ref) {
  final summaryAsync = ref.watch(rollingWindowSummaryProvider);
  final today = ref.watch(businessDayProvider);
  final days =
      rollingDays(today, kAvgDailyWindowDays, ref.watch(shopOffsetProvider))
          .days;
  return summaryAsync.whenData<double?>(
    (summary) => avgDailyFromGross(summary.grossAmount, days),
  );
});

/// Top-selling products for today, ranked by units sold (ties broken by
/// total revenue). Derived from [todaysSalesProvider] so the leaderboard
/// updates in real time as new sales come through, with no extra
/// Firestore round-trip.
final topSellingTodayProvider =
    Provider<AsyncValue<List<TopSellingItem>>>((ref) {
  final salesAsync = ref.watch(todaysSalesProvider);
  return salesAsync.whenData(topSellingFromSales);
});

/// Provides sales summary for a date range.
final salesSummaryProvider =
    FutureProvider.family<SalesSummary, DateRangeParams>((ref, params) async {
  final actor = _requireActor(ref);
  final result = await ref.watch(getSalesReportUseCaseProvider).execute(
        actor: actor,
        startDate: params.startDate,
        endDate: params.endDate,
      );
  if (!result.success) {
    throw AppExceptionWrapper(
        message: result.errorMessage ?? 'Failed to load summary',
        code: result.errorCode);
  }
  return result.data!;
});

/// Provides admin-only profit report (same payload, gated separately).
final profitReportProvider =
    FutureProvider.family<SalesSummary, DateRangeParams>((ref, params) async {
  final actor = _requireActor(ref);
  final result = await ref.watch(getProfitReportUseCaseProvider).execute(
        actor: actor,
        startDate: params.startDate,
        endDate: params.endDate,
      );
  if (!result.success) {
    throw AppExceptionWrapper(
        message: result.errorMessage ?? 'Failed to load profit report',
        code: result.errorCode);
  }
  return result.data!;
});

/// Provides top selling products for a date range.
final topSellingProductsProvider =
    FutureProvider.family<List<ProductSalesData>, TopSellingParams>(
        (ref, params) async {
  final actor = _requireActor(ref);
  final result = await ref.watch(getTopSellingUseCaseProvider).execute(
        actor: actor,
        startDate: params.startDate,
        endDate: params.endDate,
        limit: params.limit,
      );
  if (!result.success) {
    throw AppExceptionWrapper(
        message: result.errorMessage ?? 'Failed to load top selling',
        code: result.errorCode);
  }
  return result.data!;
});

/// Wraps a [UseCaseResult.failure] as an exception so AsyncValue.error
/// surfaces the message + code. Used by the report providers above.
class AppExceptionWrapper extends AppException {
  const AppExceptionWrapper({required super.message, super.code});
}

// ==================== SALE OPERATIONS ====================

/// Notifier for sale operations (create, void, etc.)
class SaleOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final SaleRepository _repository;
  final Ref _ref;

  SaleOperationsNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  /// Creates a new sale.
  Future<SaleEntity?> createSale(SaleEntity sale) async {
    state = const AsyncValue.loading();
    try {
      final created = await _repository.createSale(sale);
      state = const AsyncValue.data(null);

      // Invalidate related providers to refresh data
      _ref.invalidate(todaysSalesProvider);
      _ref.invalidate(todaysSalesSummaryProvider);

      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Voids a sale.
  Future<SaleEntity?> voidSale({
    required String saleId,
    required String voidedBy,
    required String voidedByName,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final voided = await _repository.voidSale(
        saleId: saleId,
        voidedBy: voidedBy,
        voidedByName: voidedByName,
        reason: reason,
      );
      state = const AsyncValue.data(null);

      // Invalidate related providers
      _ref.invalidate(todaysSalesProvider);
      _ref.invalidate(todaysSalesSummaryProvider);
      _ref.invalidate(saleByIdProvider(saleId));

      return voided;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Updates sale notes.
  Future<SaleEntity?> updateSaleNotes({
    required String saleId,
    required String notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _repository.updateSaleNotes(
        saleId: saleId,
        notes: notes,
      );
      state = const AsyncValue.data(null);
      _ref.invalidate(saleByIdProvider(saleId));
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Generates a new sale number.
  Future<String?> generateSaleNumber(DateTime date) async {
    try {
      return await _repository.generateSaleNumber(date);
    } catch (e) {
      return null;
    }
  }
}

/// Provider for sale operations.
final saleOperationsProvider =
    StateNotifierProvider<SaleOperationsNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(saleRepositoryProvider);
  return SaleOperationsNotifier(repository, ref);
});

// ==================== PARAMETER CLASSES ====================

/// Parameters for date range queries.
class DateRangeParams {
  final DateTime startDate;
  final DateTime endDate;
  final SaleStatus? status;
  final String? cashierId;

  const DateRangeParams({
    required this.startDate,
    required this.endDate,
    this.status,
    this.cashierId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DateRangeParams &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.status == status &&
        other.cashierId == cashierId;
  }

  @override
  int get hashCode =>
      startDate.hashCode ^
      endDate.hashCode ^
      status.hashCode ^
      cashierId.hashCode;
}

/// Parameters for recent sales queries.
class RecentSalesParams {
  final int limit;
  final String? startAfterSaleId;
  final SaleStatus? status;

  const RecentSalesParams({
    this.limit = 20,
    this.startAfterSaleId,
    this.status,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecentSalesParams &&
        other.limit == limit &&
        other.startAfterSaleId == startAfterSaleId &&
        other.status == status;
  }

  @override
  int get hashCode =>
      limit.hashCode ^ startAfterSaleId.hashCode ^ status.hashCode;
}

/// Parameters for top selling products queries.
class TopSellingParams {
  final DateTime startDate;
  final DateTime endDate;
  final int limit;

  const TopSellingParams({
    required this.startDate,
    required this.endDate,
    this.limit = 10,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TopSellingParams &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.limit == limit;
  }

  @override
  int get hashCode => startDate.hashCode ^ endDate.hashCode ^ limit.hashCode;
}
