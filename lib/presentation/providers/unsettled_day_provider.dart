import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/daily_closing_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';

/// Detects the OLDEST business day that has completed sales but was never
/// closed — the day a rollover banner/blocker should point the user at.
///
/// Scans forward from the day after the latest closing (or 14 days back
/// from "today" if nothing has ever been closed — capped there either way)
/// up to (but not including) "today". A day is:
/// - **settled** if it already has a closing — skipped, keep scanning;
/// - **unsettled** if it has no closing AND at least one completed sale —
///   returned immediately (oldest wins);
/// - **skipped** if it has no closing and no sales — nothing to settle.
///
/// Re-runs whenever the business day flips ([businessDayProvider]) or a
/// closing is saved/invalidated ([dailyClosingHistoryProvider] — the same
/// invalidation `closeDay` already fires on success).
final unsettledBusinessDayProvider = FutureProvider<DateTime?>((ref) async {
  final today = ref.watch(businessDayProvider);
  final closingRepo = ref.watch(dailyClosingRepositoryProvider);
  final saleRepo = ref.watch(saleRepositoryProvider);
  // Re-run when a close lands (same invalidation closeDay already fires).
  ref.watch(dailyClosingHistoryProvider);

  final latest = await closingRepo.latestClosing();
  var start = latest == null
      ? today.subtract(const Duration(days: 14))
      : latest.businessDate.add(const Duration(days: 1));
  final floor = today.subtract(const Duration(days: 14));
  if (start.isBefore(floor)) start = floor; // 14-day scan cap

  for (var d = start; d.isBefore(today); d = d.add(const Duration(days: 1))) {
    if (await closingRepo.getClosing(d) != null) continue; // gap already closed
    if (await saleRepo.hasCompletedSaleOn(d)) return d; // oldest unsettled
  }
  return null;
});
