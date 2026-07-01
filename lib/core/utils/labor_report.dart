import 'package:maki_mobile_pos/domain/entities/sale_entity.dart';

/// Labor (service) revenue attributed to a single mechanic across a set of
/// sales. Labor has zero cost, so labor revenue == labor profit.
class LaborByMechanic {
  /// Mechanic id, or null when the service sale carried no mechanic.
  final String? mechanicId;

  /// Display name — falls back to "Unassigned" when [mechanicId] is null.
  final String mechanicName;

  /// Total labor fees credited to this mechanic.
  final double laborTotal;

  /// Number of service sales (jobs) this mechanic appears on.
  final int jobCount;

  const LaborByMechanic({
    required this.mechanicId,
    required this.mechanicName,
    required this.laborTotal,
    required this.jobCount,
  });
}

/// Aggregated labor report for a date range.
class LaborReportData {
  /// Total labor revenue across all service sales.
  final double totalLabor;

  /// Number of sales that carried any labor (service sales).
  final int serviceSaleCount;

  /// Per-mechanic breakdown, sorted by [LaborByMechanic.laborTotal] desc
  /// (ties broken by name, ascending).
  final List<LaborByMechanic> byMechanic;

  const LaborReportData({
    required this.totalLabor,
    required this.serviceSaleCount,
    required this.byMechanic,
  });

  factory LaborReportData.empty() => const LaborReportData(
        totalLabor: 0,
        serviceSaleCount: 0,
        byMechanic: [],
      );
}

const String _unassignedKey = '__unassigned__';
const String _unassignedName = 'Unassigned';

/// Builds a [LaborReportData] from [sales]. Voided sales and parts-only sales
/// (no labor) are excluded. Service sales with no mechanic are grouped under
/// an "Unassigned" bucket.
LaborReportData laborReportFromSales(List<SaleEntity> sales) {
  final buckets = <String, _Bucket>{};
  double totalLabor = 0;
  int serviceSaleCount = 0;

  for (final sale in sales) {
    if (sale.isVoided) continue;
    final labor = sale.laborRevenue;
    if (labor <= 0) continue;

    totalLabor += labor;
    serviceSaleCount++;

    final key = sale.mechanicId ?? _unassignedKey;
    final bucket = buckets.putIfAbsent(
      key,
      () => _Bucket(
        mechanicId: sale.mechanicId,
        mechanicName: sale.mechanicName ?? _unassignedName,
      ),
    );
    bucket.laborTotal += labor;
    bucket.jobCount++;
  }

  final byMechanic = buckets.values
      .map((b) => LaborByMechanic(
            mechanicId: b.mechanicId,
            mechanicName: b.mechanicName,
            laborTotal: b.laborTotal,
            jobCount: b.jobCount,
          ))
      .toList()
    ..sort((a, b) {
      final byTotal = b.laborTotal.compareTo(a.laborTotal);
      if (byTotal != 0) return byTotal;
      return a.mechanicName.toLowerCase().compareTo(b.mechanicName.toLowerCase());
    });

  return LaborReportData(
    totalLabor: totalLabor,
    serviceSaleCount: serviceSaleCount,
    byMechanic: byMechanic,
  );
}

class _Bucket {
  final String? mechanicId;
  final String mechanicName;
  double laborTotal = 0;
  int jobCount = 0;

  _Bucket({required this.mechanicId, required this.mechanicName});
}
