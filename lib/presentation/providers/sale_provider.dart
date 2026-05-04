import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/utils/top_selling.dart';
import 'package:maki_mobile_pos/core/utils/week_range.dart';
import 'package:maki_mobile_pos/data/repositories/sale_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/reports/get_profit_report_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/reports/get_sales_report_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/reports/get_top_selling_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the SaleRepository instance.
final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return SaleRepositoryImpl();
});

// ==================== SALE QUERIES ====================

/// Provides today's sales as a real-time stream.
final todaysSalesProvider = StreamProvider<List<SaleEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(saleRepositoryProvider).watchTodaysSales();
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
  return repository.getSalesForDay(date: date);
});

/// Provides sales for a date range.
final salesByDateRangeProvider =
    FutureProvider.family<List<SaleEntity>, DateRangeParams>(
        (ref, params) async {
  final repository = ref.watch(saleRepositoryProvider);
  return repository.getSalesByDateRange(
    startDate: params.startDate,
    endDate: params.endDate,
    status: params.status,
    cashierId: params.cashierId,
  );
});

/// Provides a single sale by ID.
final saleByIdProvider =
    FutureProvider.family<SaleEntity?, String>((ref, saleId) async {
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
  final today = DateTime.now();
  final dayStart = DateTime(today.year, today.month, today.day);
  final dayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

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

/// Sales summary for the current week-to-date (Monday → now). Drives the
/// dashboard's Avg Daily Sales card; the SalesSummary itself is reused for
/// any other week-scoped totals.
final weekToDateSummaryProvider = FutureProvider<SalesSummary>((ref) async {
  final actor = _requireActor(ref);
  final w = weekToDate(DateTime.now());

  final result = await ref.watch(getSalesReportUseCaseProvider).execute(
        actor: actor,
        startDate: w.start,
        endDate: w.end,
      );
  if (!result.success) {
    throw AppExceptionWrapper(
        message: result.errorMessage ?? 'Failed to load summary',
        code: result.errorCode);
  }
  return result.data!;
});

/// Average daily gross sales for the current week so far.
///
/// Derived from [weekToDateSummaryProvider] — gross amount divided by the
/// number of days elapsed in the current Monday→Sunday week. Recomputes
/// daily as the day count advances.
final avgDailySalesProvider = Provider<AsyncValue<double>>((ref) {
  final summaryAsync = ref.watch(weekToDateSummaryProvider);
  final daysElapsed = weekToDate(DateTime.now()).daysElapsed;
  return summaryAsync.whenData(
    (summary) => avgDailyFromGross(summary.grossAmount, daysElapsed),
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
