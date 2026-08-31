import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/utils/business_day.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/daily_closing_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';

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
/// closing is saved — `closeDay` invalidates this provider directly on
/// success, rather than this watching a list provider as a proxy for it.
final unsettledBusinessDayProvider = FutureProvider<DateTime?>((ref) async {
  final today = ref.watch(businessDayProvider);
  final closingRepo = ref.watch(dailyClosingRepositoryProvider);
  final saleRepo = ref.watch(saleRepositoryProvider);
  final offset = ref.watch(shopOffsetProvider);
  final latest = await closingRepo.latestClosing();
  var start = latest == null
      ? today.subtract(const Duration(days: 14))
      : businessDateOf(latest.businessDate, offset)
          .add(const Duration(days: 1));
  final floor = today.subtract(const Duration(days: 14));
  if (start.isBefore(floor)) start = floor; // 14-day scan cap

  for (var d = start; d.isBefore(today); d = d.add(const Duration(days: 1))) {
    if (await closingRepo.getClosing(d) != null) continue; // gap already closed
    if (await saleRepo.hasCompletedSaleOn(d)) return d; // oldest unsettled
  }

  // Fallback (Fix 2b): the scan above can miss unsettled days it never
  // walked — a gap older than the 14-day cap, or a stale [latestClosing]
  // that pushed `start` too far forward. drawer_state/state is the same
  // doc the `drawerSettled()` rule reads server-side, so if IT says the
  // latest sale day is a past day that's never been closed, trust it even
  // though the scan came up empty.
  final drawerState = await closingRepo.getDrawerState();
  final lastSaleDay = drawerState.lastSaleDay ?? 0;
  final lastClosedDay = drawerState.lastClosedDay ?? 0;
  if (lastSaleDay > 0 &&
      lastSaleDay < businessDayIntOfWall(today) &&
      lastSaleDay > lastClosedDay) {
    return dateFromBusinessDayInt(lastSaleDay);
  }

  return null;
});
