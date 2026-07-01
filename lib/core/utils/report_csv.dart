import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/core/utils/labor_report.dart';
import 'package:maki_mobile_pos/core/utils/price_change_report.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

const _converter = ListToCsvConverter(eol: '\n');
final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

/// One row per completed (non-voided) sale, plus a TOTAL row.
String buildSalesReportCsv(List<SaleEntity> sales) {
  var subtotal = 0.0, discount = 0.0, total = 0.0;
  final rows = <List<dynamic>>[
    ['Sale #', 'Date', 'Cashier', 'Subtotal', 'Discount', 'Total', 'Payment'],
  ];
  for (final s in sales.where((s) => !s.isVoided)) {
    subtotal += s.partsSubtotal;
    discount += s.totalDiscount;
    total += s.grandTotal;
    rows.add([
      s.saleNumber,
      _dateFmt.format(s.createdAt),
      s.cashierName,
      s.partsSubtotal.toStringAsFixed(2),
      s.totalDiscount.toStringAsFixed(2),
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
      p.sku,
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

String _signed(double v) => (v >= 0 ? '+' : '') + v.toStringAsFixed(2);

/// Change log: one row per price/cost change, newest-first (as [rows] arrive).
/// [productLabelById] maps productId -> "Name (SKU)"; a missing product falls
/// back to the id. No TOTAL row (a change log has no meaningful column totals).
String buildPriceChangeReportCsv(
  List<PriceChangeRow> rows,
  Map<String, String> productLabelById,
) {
  final fmt = DateFormat('yyyy-MM-dd HH:mm');
  final out = <List<dynamic>>[
    [
      'Date', 'Product', 'SKU', 'New Price', 'Price Delta', 'New Cost',
      'Cost Delta', 'Reason', 'Changed By',
    ],
  ];
  for (final r in rows) {
    final e = r.entry;
    out.add([
      fmt.format(e.changedAt),
      productLabelById[e.productId] ?? e.productId,
      '',
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
