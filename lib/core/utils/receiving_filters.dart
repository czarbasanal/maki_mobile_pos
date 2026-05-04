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

/// Sum of [ReceivingEntity.totalCost] over a list. Trivial helper but
/// keeps the receiving-provider call sites readable.
double sumTotalCost(List<ReceivingEntity> receivings) {
  return receivings.fold<double>(0, (acc, r) => acc + r.totalCost);
}
