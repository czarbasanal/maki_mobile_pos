import 'package:maki_mobile_pos/domain/entities/sale_entity.dart';

/// Per-model row for the Motorcycle Models report.
class MotorcycleModelStat {
  final String model;
  final int jobCount;
  final double totalRevenue;
  final double laborTotal;
  const MotorcycleModelStat({
    required this.model,
    required this.jobCount,
    required this.totalRevenue,
    required this.laborTotal,
  });
}

/// Aggregated Motorcycle Models report for a date range.
class MotorcycleModelReportData {
  final int totalJobs;
  final double totalRevenue;

  /// Rows sorted by [MotorcycleModelStat.jobCount] desc, ties by model name asc.
  final List<MotorcycleModelStat> byModel;

  const MotorcycleModelReportData({
    required this.totalJobs,
    required this.totalRevenue,
    required this.byModel,
  });

  factory MotorcycleModelReportData.empty() =>
      const MotorcycleModelReportData(totalJobs: 0, totalRevenue: 0, byModel: []);
}

/// Groups billed-out Job Orders by motorcycle model. Voided sales and sales
/// with no model (walk-ins) are excluded.
MotorcycleModelReportData motorcycleModelReportFromSales(
    List<SaleEntity> sales) {
  final buckets = <String, _Bucket>{};
  int totalJobs = 0;
  double totalRevenue = 0;

  for (final s in sales) {
    if (s.isVoided) continue;
    final model = s.motorcycleModel?.trim() ?? '';
    if (model.isEmpty) continue;

    final b = buckets.putIfAbsent(model, () => _Bucket(model));
    b.jobCount++;
    b.totalRevenue += s.grandTotal;
    b.laborTotal += s.laborRevenue;
    totalJobs++;
    totalRevenue += s.grandTotal;
  }

  final byModel = buckets.values
      .map((b) => MotorcycleModelStat(
            model: b.model,
            jobCount: b.jobCount,
            totalRevenue: b.totalRevenue,
            laborTotal: b.laborTotal,
          ))
      .toList()
    ..sort((a, b) {
      final c = b.jobCount.compareTo(a.jobCount);
      return c != 0 ? c : a.model.toLowerCase().compareTo(b.model.toLowerCase());
    });

  return MotorcycleModelReportData(
      totalJobs: totalJobs, totalRevenue: totalRevenue, byModel: byModel);
}

class _Bucket {
  final String model;
  int jobCount = 0;
  double totalRevenue = 0;
  double laborTotal = 0;
  _Bucket(this.model);
}
