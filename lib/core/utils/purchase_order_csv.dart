import 'package:csv/csv.dart';
import 'package:maki_mobile_pos/core/extensions/datetime_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

const _converter = ListToCsvConverter(eol: '\n');

/// Order list to send to a supplier: items and quantities only — costs stay
/// private by design.
String buildPurchaseOrderCsv(PurchaseOrderEntity po) {
  final rows = <List<dynamic>>[
    ['Purchase Order', po.referenceNumber],
    ['Supplier', po.supplierName ?? 'No supplier'],
    ['Date', po.createdAt.toIsoDate()],
    [],
    ['SKU', 'Name', 'Qty', 'Unit'],
    for (final item in po.items) [item.sku, item.name, item.quantity, item.unit],
  ];
  return '${_converter.convert(rows)}\n';
}
