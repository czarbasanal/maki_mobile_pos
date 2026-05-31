import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

/// Firestore data model for end-of-day closings.
class DailyClosingModel {
  final String id;
  final DateTime businessDate;
  final double grossSales;
  final double netSales;
  final double totalDiscounts;
  final double cashSales;
  final double nonCashSales;
  final double gcashSales;
  final double mayaSales;
  final double totalExpenses;
  final double cashExpenses;
  final double salmonReceivable;
  final double laborRevenue;
  final double plateNoDp;
  final double plateNoDelivery;
  final double openingFloat;
  final double expectedCash;
  final double countedCash;
  final double variance;
  final int salesCount;
  final int voidedCount;
  final String? notes;
  final String closedBy;
  final String closedByName;
  final DateTime closedAt;

  const DailyClosingModel({
    required this.id,
    required this.businessDate,
    required this.grossSales,
    required this.netSales,
    required this.totalDiscounts,
    required this.cashSales,
    required this.nonCashSales,
    required this.gcashSales,
    required this.mayaSales,
    required this.totalExpenses,
    required this.cashExpenses,
    required this.salmonReceivable,
    this.laborRevenue = 0,
    this.plateNoDp = 0,
    this.plateNoDelivery = 0,
    required this.openingFloat,
    required this.expectedCash,
    required this.countedCash,
    required this.variance,
    required this.salesCount,
    required this.voidedCount,
    this.notes,
    required this.closedBy,
    required this.closedByName,
    required this.closedAt,
  });

  factory DailyClosingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyClosingModel.fromMap(data, doc.id);
  }

  factory DailyClosingModel.fromMap(Map<String, dynamic> map, String id) {
    double d(String k) => (map[k] as num?)?.toDouble() ?? 0.0;
    int i(String k) => (map[k] as num?)?.toInt() ?? 0;
    return DailyClosingModel(
      id: id,
      businessDate:
          (map['businessDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      grossSales: d('grossSales'),
      netSales: d('netSales'),
      totalDiscounts: d('totalDiscounts'),
      cashSales: d('cashSales'),
      nonCashSales: d('nonCashSales'),
      gcashSales: d('gcashSales'),
      mayaSales: d('mayaSales'),
      totalExpenses: d('totalExpenses'),
      cashExpenses: d('cashExpenses'),
      salmonReceivable: d('salmonReceivable'),
      laborRevenue: d('laborRevenue'),
      plateNoDp: d('plateNoDp'),
      plateNoDelivery: d('plateNoDelivery'),
      openingFloat: d('openingFloat'),
      expectedCash: d('expectedCash'),
      countedCash: d('countedCash'),
      variance: d('variance'),
      salesCount: i('salesCount'),
      voidedCount: i('voidedCount'),
      notes: map['notes'] as String?,
      closedBy: map['closedBy'] as String? ?? '',
      closedByName: map['closedByName'] as String? ?? '',
      closedAt: (map['closedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory DailyClosingModel.fromEntity(DailyClosingEntity e) {
    return DailyClosingModel(
      id: e.id,
      businessDate: e.businessDate,
      grossSales: e.grossSales,
      netSales: e.netSales,
      totalDiscounts: e.totalDiscounts,
      cashSales: e.cashSales,
      nonCashSales: e.nonCashSales,
      gcashSales: e.gcashSales,
      mayaSales: e.mayaSales,
      totalExpenses: e.totalExpenses,
      cashExpenses: e.cashExpenses,
      salmonReceivable: e.salmonReceivable,
      laborRevenue: e.laborRevenue,
      plateNoDp: e.plateNoDp,
      plateNoDelivery: e.plateNoDelivery,
      openingFloat: e.openingFloat,
      expectedCash: e.expectedCash,
      countedCash: e.countedCash,
      variance: e.variance,
      salesCount: e.salesCount,
      voidedCount: e.voidedCount,
      notes: e.notes,
      closedBy: e.closedBy,
      closedByName: e.closedByName,
      closedAt: e.closedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessDate': Timestamp.fromDate(businessDate),
      'grossSales': grossSales,
      'netSales': netSales,
      'totalDiscounts': totalDiscounts,
      'cashSales': cashSales,
      'nonCashSales': nonCashSales,
      'gcashSales': gcashSales,
      'mayaSales': mayaSales,
      'totalExpenses': totalExpenses,
      'cashExpenses': cashExpenses,
      'salmonReceivable': salmonReceivable,
      'laborRevenue': laborRevenue,
      'plateNoDp': plateNoDp,
      'plateNoDelivery': plateNoDelivery,
      'openingFloat': openingFloat,
      'expectedCash': expectedCash,
      'countedCash': countedCash,
      'variance': variance,
      'salesCount': salesCount,
      'voidedCount': voidedCount,
      'notes': notes,
      'closedBy': closedBy,
      'closedByName': closedByName,
      'closedAt': Timestamp.fromDate(closedAt),
    };
  }

  /// Same as [toMap] but stamps the close time with a server timestamp.
  Map<String, dynamic> toCreateMap() {
    final map = toMap();
    map['closedAt'] = FieldValue.serverTimestamp();
    return map;
  }

  DailyClosingEntity toEntity() {
    return DailyClosingEntity(
      id: id,
      businessDate: businessDate,
      grossSales: grossSales,
      netSales: netSales,
      totalDiscounts: totalDiscounts,
      cashSales: cashSales,
      nonCashSales: nonCashSales,
      gcashSales: gcashSales,
      mayaSales: mayaSales,
      totalExpenses: totalExpenses,
      cashExpenses: cashExpenses,
      salmonReceivable: salmonReceivable,
      laborRevenue: laborRevenue,
      plateNoDp: plateNoDp,
      plateNoDelivery: plateNoDelivery,
      openingFloat: openingFloat,
      expectedCash: expectedCash,
      countedCash: countedCash,
      variance: variance,
      salesCount: salesCount,
      voidedCount: voidedCount,
      notes: notes,
      closedBy: closedBy,
      closedByName: closedByName,
      closedAt: closedAt,
    );
  }
}
