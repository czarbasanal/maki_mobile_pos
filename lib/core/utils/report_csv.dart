import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/core/utils/labor_report.dart';
import 'package:maki_mobile_pos/core/utils/mechanic_performance_report.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_report.dart';
import 'package:maki_mobile_pos/core/utils/price_change_report.dart';
import 'package:maki_mobile_pos/core/utils/sku_generator.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

const _converter = ListToCsvConverter(eol: '\n');
final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

/// One row per completed (non-voided) sale, plus a TOTAL row. [Labor] and
/// [Fees] break out service/labor and shop-fee revenue (separate tracks,
/// management's) without touching [Subtotal] (parts-only); together with
/// [Discount] they reconcile against [Total] (grand total, labor+fees
/// inclusive): Subtotal − Discount + Labor + Fees == Total.
String buildSalesReportCsv(List<SaleEntity> sales) {
  var subtotal = 0.0, discount = 0.0, labor = 0.0, fees = 0.0, total = 0.0;
  final rows = <List<dynamic>>[
    [
      'Sale #',
      'Date',
      'Cashier',
      'Subtotal',
      'Discount',
      'Labor',
      'Fees',
      'Total',
      'Payment',
    ],
  ];
  for (final s in sales.where((s) => !s.isVoided)) {
    subtotal += s.partsSubtotal;
    discount += s.totalDiscount;
    labor += s.laborSubtotal;
    fees += s.feesTotal;
    total += s.grandTotal;
    rows.add([
      s.saleNumber,
      _dateFmt.format(s.createdAt),
      s.cashierName,
      s.partsSubtotal.toStringAsFixed(2),
      s.totalDiscount.toStringAsFixed(2),
      s.laborSubtotal.toStringAsFixed(2),
      s.feesTotal.toStringAsFixed(2),
      s.grandTotal.toStringAsFixed(2),
      s.paymentMethod.displayName,
    ]);
  }
  rows.add([
    'TOTAL',
    '',
    '',
    subtotal.toStringAsFixed(2),
    discount.toStringAsFixed(2),
    labor.toStringAsFixed(2),
    fees.toStringAsFixed(2),
    total.toStringAsFixed(2),
    '',
  ]);
  return _converter.convert(rows);
}

/// Products ranked by profit desc, plus a TOTAL row.
String buildProfitReportCsv(List<ProductSalesData> products) {
  final ranked = [...products]
    ..sort((a, b) => b.totalProfit.compareTo(a.totalProfit));
  var qty = 0;
  var revenue = 0.0, cost = 0.0, profit = 0.0;
  final rows = <List<dynamic>>[
    ['Product', 'SKU', 'Qty Sold', 'Revenue', 'Cost', 'Profit', 'Margin %'],
  ];
  for (final p in ranked) {
    qty += p.quantitySold;
    revenue += p.totalRevenue;
    cost += p.totalCost;
    profit += p.totalProfit;
    rows.add([
      p.name,
      SkuGenerator.csvSku(p.sku),
      p.quantitySold,
      p.totalRevenue.toStringAsFixed(2),
      p.totalCost.toStringAsFixed(2),
      p.totalProfit.toStringAsFixed(2),
      p.profitMargin.toStringAsFixed(1),
    ]);
  }
  final margin = revenue > 0 ? (profit / revenue) * 100 : 0.0;
  rows.add([
    'TOTAL',
    '',
    qty,
    revenue.toStringAsFixed(2),
    cost.toStringAsFixed(2),
    profit.toStringAsFixed(2),
    margin.toStringAsFixed(1),
  ]);
  return _converter.convert(rows);
}

/// One row per mechanic, plus a TOTAL row (report totals).
String buildLaborReportCsv(LaborReportData report) {
  final rows = <List<dynamic>>[
    ['Mechanic', 'Jobs', 'Labor Total'],
  ];
  for (final m in report.byMechanic) {
    rows.add([m.mechanicName, m.jobCount, m.laborTotal.toStringAsFixed(2)]);
  }
  rows.add([
    'TOTAL',
    report.serviceSaleCount,
    report.totalLabor.toStringAsFixed(2),
  ]);
  return _converter.convert(rows);
}

/// One row per motorcycle model (jobs desc), plus a TOTAL row.
String buildMotorcycleModelReportCsv(MotorcycleModelReportData report) {
  final rows = <List<dynamic>>[
    ['Model', 'Jobs', 'Revenue', 'Labor'],
  ];
  for (final m in report.byModel) {
    rows.add([
      m.model,
      m.jobCount,
      m.totalRevenue.toStringAsFixed(2),
      m.laborTotal.toStringAsFixed(2),
    ]);
  }
  rows.add(['TOTAL', report.totalJobs, report.totalRevenue.toStringAsFixed(2), '']);
  return _converter.convert(rows);
}

/// One row per mechanic (total revenue desc), plus a TOTAL row.
String buildMechanicPerformanceReportCsv(MechanicPerformanceReportData report) {
  final rows = <List<dynamic>>[
    ['Mechanic', 'Jobs', 'Total Revenue', 'Labor'],
  ];
  for (final m in report.byMechanic) {
    rows.add([
      m.mechanicName,
      m.jobCount,
      m.totalRevenue.toStringAsFixed(2),
      m.laborTotal.toStringAsFixed(2),
    ]);
  }
  rows.add(
      ['TOTAL', report.jobCount, report.totalRevenue.toStringAsFixed(2), '']);
  return _converter.convert(rows);
}

String _signed(double v) => (v >= 0 ? '+' : '') + v.toStringAsFixed(2);

/// Extracts the SKU from a product label in the format "Name (SKU)".
/// Returns empty string if the label doesn't contain parentheses.
String _extractSkuFromLabel(String label) {
  final match = RegExp(r'\(([^)]+)\)$').firstMatch(label);
  return match?.group(1) ?? '';
}

/// Change log: one row per price/cost change, newest-first (as [rows] arrive).
/// [productLabelById] maps productId -> "Name (SKU)"; a missing product falls
/// back to the id. No TOTAL row (a change log has no meaningful column totals).
/// Option sits right after SKU: the selling option's label for an option row,
/// an empty string (not "Base" or a dash) for a base row.
String buildPriceChangeReportCsv(
  List<PriceChangeRow> rows,
  Map<String, String> productLabelById,
) {
  final fmt = DateFormat('yyyy-MM-dd HH:mm');
  final out = <List<dynamic>>[
    [
      'Date', 'Product', 'SKU', 'Option', 'New Price', 'Price Delta',
      'New Cost', 'Cost Delta', 'Reason', 'Changed By',
    ],
  ];
  for (final r in rows) {
    final e = r.entry;
    final label = productLabelById[e.productId] ?? e.productId;
    final extractedSku = _extractSkuFromLabel(label);
    final displayedSku = SkuGenerator.csvSku(extractedSku);
    out.add([
      fmt.format(e.changedAt),
      label,
      displayedSku,
      e.optionLabel ?? '',
      e.price.toStringAsFixed(2),
      r.hasPrior ? _signed(r.priceDelta) : '',
      e.cost.toStringAsFixed(2),
      r.hasPrior ? _signed(r.costDelta) : '',
      e.reason ?? '',
      e.changedBy,
    ]);
  }
  return _converter.convert(out);
}
