import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';

/// One month/year bucket in the grouped expense history view.
class ExpenseMonthGroup {
  /// First day of the month at 00:00 — used as the group key and for
  /// formatting the section header (e.g. "May 2026").
  final DateTime monthStart;

  /// Expenses in this month, sorted most-recent first by [ExpenseEntity.date].
  final List<ExpenseEntity> items;

  const ExpenseMonthGroup({required this.monthStart, required this.items});
}

/// Groups [expenses] into month-of-year buckets, ordered most-recent month
/// first, with each bucket's items sorted most-recent first by
/// [ExpenseEntity.date]. Pure — no side effects, no mutation of the input
/// list. Mirrors the receiving history grouping pattern.
List<ExpenseMonthGroup> groupExpensesByMonthYear(
  List<ExpenseEntity> expenses,
) {
  DateTime keyFor(ExpenseEntity e) => DateTime(e.date.year, e.date.month);

  final buckets = <DateTime, List<ExpenseEntity>>{};
  for (final e in expenses) {
    buckets.putIfAbsent(keyFor(e), () => <ExpenseEntity>[]).add(e);
  }

  final orderedKeys = buckets.keys.toList()
    ..sort((a, b) => b.compareTo(a)); // most recent month first

  return [
    for (final key in orderedKeys)
      ExpenseMonthGroup(
        monthStart: key,
        items: buckets[key]!..sort((a, b) => b.date.compareTo(a.date)),
      ),
  ];
}
