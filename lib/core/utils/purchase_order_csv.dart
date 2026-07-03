import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

/// Order list to send to a supplier: items and quantities only — costs stay
/// private by design.
String buildPurchaseOrderCsv(PurchaseOrderEntity po) {
  String esc(String v) =>
      v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
  String row(List<String> cells) => cells.map(esc).join(',');

  final d = po.createdAt;
  final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  final b = StringBuffer()
    ..writeln(row(['Purchase Order', po.referenceNumber]))
    ..writeln(row(['Supplier', po.supplierName ?? 'No supplier']))
    ..writeln(row(['Date', date]))
    ..writeln()
    ..writeln(row(['SKU', 'Name', 'Qty', 'Unit']));
  for (final item in po.items) {
    b.writeln(row([item.sku, item.name, '${item.quantity}', item.unit]));
  }
  return b.toString();
}
