import 'package:maki_mobile_pos/core/utils/week_range.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';

/// Returns the subset of [receivings] that are completed and whose
/// effective timestamp (completedAt, falling back to createdAt) lands
/// at-or-after the start of the current month relative to [now]. Pure —
/// callers pass `DateTime.now()`. Used by the receiving dashboard's
/// month-to-date count and peso-total cards.
List<ReceivingEntity> monthToDateCompleted(
  List<ReceivingEntity> receivings,
  DateTime now,
) {
  final monthStart = DateTime(now.year, now.month);
  return receivings.where((r) {
    if (r.status != ReceivingStatus.completed) return false;
    final ts = r.completedAt ?? r.createdAt;
    return !ts.isBefore(monthStart);
  }).toList();
}

/// Returns receivings created in the current Monday-anchored week
/// relative to [now]. All statuses are included — in-progress drafts
/// belong on the "recent" list alongside completed ones. Pure — callers
/// pass `DateTime.now()`.
List<ReceivingEntity> receivingsInCurrentWeek(
  List<ReceivingEntity> receivings,
  DateTime now,
) {
  final week = weekToDate(now);
  return receivings.where((r) => !r.createdAt.isBefore(week.start)).toList();
}

/// Sum of [ReceivingEntity.totalCost] over a list. Trivial helper but
/// keeps the receiving-provider call sites readable.
double sumTotalCost(List<ReceivingEntity> receivings) {
  return receivings.fold<double>(0, (acc, r) => acc + r.totalCost);
}

/// One month/year bucket in the grouped history view.
class ReceivingMonthGroup {
  /// First day of the month at 00:00 — used as the group key and for
  /// formatting the section header (e.g. "May 2026").
  final DateTime monthStart;

  /// Receivings in this month, sorted most-recent first by their
  /// effective timestamp.
  final List<ReceivingEntity> items;

  const ReceivingMonthGroup({required this.monthStart, required this.items});
}

/// Groups [receivings] into month-of-year buckets, ordered most-recent
/// month first, with each bucket's items sorted most-recent first by
/// `completedAt ?? createdAt`. Pure — no side effects, no mutation of
/// the input list. Used by the receiving history screen.
List<ReceivingMonthGroup> groupByMonthYear(
  List<ReceivingEntity> receivings,
) {
  DateTime keyFor(ReceivingEntity r) {
    final ts = r.completedAt ?? r.createdAt;
    return DateTime(ts.year, ts.month);
  }

  final buckets = <DateTime, List<ReceivingEntity>>{};
  for (final r in receivings) {
    buckets.putIfAbsent(keyFor(r), () => <ReceivingEntity>[]).add(r);
  }

  final orderedKeys = buckets.keys.toList()
    ..sort((a, b) => b.compareTo(a)); // most recent month first

  return [
    for (final key in orderedKeys)
      ReceivingMonthGroup(
        monthStart: key,
        items: buckets[key]!
          ..sort((a, b) {
            final at = a.completedAt ?? a.createdAt;
            final bt = b.completedAt ?? b.createdAt;
            return bt.compareTo(at);
          }),
      ),
  ];
}
