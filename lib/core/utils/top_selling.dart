import 'package:maki_mobile_pos/domain/entities/sale_entity.dart';

/// One row in a top-selling ranking — the aggregated form of a single
/// product across one or more sales.
class TopSellingItem {
  final String productId;
  final String sku;
  final String name;
  final int quantitySold;
  final double totalRevenue;

  const TopSellingItem({
    required this.productId,
    required this.sku,
    required this.name,
    required this.quantitySold,
    required this.totalRevenue,
  });
}

/// Ranks products by units sold across the supplied [sales]. Voided sales
/// are excluded so canceled transactions don't pollute the leaderboard.
/// Ties on quantity are broken by total revenue (gross of any discount,
/// since the dashboard surface treats this as a popularity signal).
///
/// Returns the entire ranked list — callers (top-5, top-10, etc.) take
/// the prefix they need.
List<TopSellingItem> topSellingFromSales(List<SaleEntity> sales) {
  final agg = <String, _Bucket>{};
  for (final sale in sales) {
    if (sale.isVoided) continue;
    for (final item in sale.items) {
      final bucket = agg.putIfAbsent(
        item.productId,
        () => _Bucket(productId: item.productId, sku: item.sku, name: item.name),
      );
      bucket.quantity += item.quantity;
      bucket.revenue += item.grossAmount;
    }
  }

  final ranked = agg.values
      .map((b) => TopSellingItem(
            productId: b.productId,
            sku: b.sku,
            name: b.name,
            quantitySold: b.quantity,
            totalRevenue: b.revenue,
          ))
      .toList()
    ..sort((a, b) {
      final byQty = b.quantitySold.compareTo(a.quantitySold);
      if (byQty != 0) return byQty;
      return b.totalRevenue.compareTo(a.totalRevenue);
    });
  return ranked;
}

class _Bucket {
  final String productId;
  final String sku;
  final String name;
  int quantity = 0;
  double revenue = 0;

  _Bucket({required this.productId, required this.sku, required this.name});
}
