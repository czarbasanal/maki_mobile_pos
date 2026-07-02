import 'package:maki_mobile_pos/domain/entities/sale_entity.dart';

/// Per-mechanic row for the Top Mechanics report.
class MechanicPerformanceStat {
  final String? mechanicId;
  final String mechanicName;
  final int jobCount;
  final double totalRevenue;
  final double laborTotal;
  const MechanicPerformanceStat({
    required this.mechanicId,
    required this.mechanicName,
    required this.jobCount,
    required this.totalRevenue,
    required this.laborTotal,
  });
}

/// Aggregated Top Mechanics report for a date range.
class MechanicPerformanceReportData {
  final double totalRevenue;
  final int jobCount;

  /// Rows sorted by [MechanicPerformanceStat.totalRevenue] desc, ties by name asc.
  final List<MechanicPerformanceStat> byMechanic;

  const MechanicPerformanceReportData({
    required this.totalRevenue,
    required this.jobCount,
    required this.byMechanic,
  });

  factory MechanicPerformanceReportData.empty() =>
      const MechanicPerformanceReportData(
          totalRevenue: 0, jobCount: 0, byMechanic: []);
}

/// Per-mechanic totals over billed-out sales that carry a mechanic. Ranked by
/// total revenue (parts + labor). Voided and no-mechanic sales are excluded.
MechanicPerformanceReportData mechanicPerformanceReportFromSales(
    List<SaleEntity> sales) {
  final buckets = <String, _Bucket>{};
  double totalRevenue = 0;
  int jobCount = 0;

  for (final s in sales) {
    if (s.isVoided) continue;
    final id = s.mechanicId;
    if (id == null || id.isEmpty) continue;

    final b = buckets.putIfAbsent(
        id, () => _Bucket(id, s.mechanicName ?? '(unnamed)'));
    b.jobCount++;
    b.totalRevenue += s.grandTotal;
    b.laborTotal += s.laborRevenue;
    totalRevenue += s.grandTotal;
    jobCount++;
  }

  final byMechanic = buckets.values
      .map((b) => MechanicPerformanceStat(
            mechanicId: b.id,
            mechanicName: b.name,
            jobCount: b.jobCount,
            totalRevenue: b.totalRevenue,
            laborTotal: b.laborTotal,
          ))
      .toList()
    ..sort((a, b) {
      final c = b.totalRevenue.compareTo(a.totalRevenue);
      return c != 0
          ? c
          : a.mechanicName.toLowerCase().compareTo(b.mechanicName.toLowerCase());
    });

  return MechanicPerformanceReportData(
      totalRevenue: totalRevenue, jobCount: jobCount, byMechanic: byMechanic);
}

class _Bucket {
  final String id;
  final String name;
  int jobCount = 0;
  double totalRevenue = 0;
  double laborTotal = 0;
  _Bucket(this.id, this.name);
}
