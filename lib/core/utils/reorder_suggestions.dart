import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/sale_entity.dart';

/// Movement window and days-of-stock-to-cover for reorder suggestions.
/// A record so it carries value equality (used as a provider-family key).
typedef ReorderParams = ({int windowDays, int coverDays});

/// One suggested order line. Mirrors the web engine
/// (web_admin/src/domain/reorder/computeReorderSuggestions.ts).
class ReorderSuggestion extends Equatable {
  final ProductEntity product;
  final double velocityPerDay;
  final int targetStock;
  final int suggestedQty;

  const ReorderSuggestion({
    required this.product,
    required this.velocityPerDay,
    required this.targetStock,
    required this.suggestedQty,
  });

  String? get supplierName => product.supplierName;

  @override
  List<Object?> get props =>
      [product, velocityPerDay, targetStock, suggestedQty];
}

/// Sums quantity sold per productId across [sales] (pass completed sales only).
Map<String, int> unitsSoldByProduct(List<SaleEntity> sales) {
  final out = <String, int>{};
  for (final sale in sales) {
    for (final item in sale.items) {
      out[item.productId] = (out[item.productId] ?? 0) + item.quantity;
    }
  }
  return out;
}

/// Suggests an order quantity per active product purely from stock movement
/// and remaining stock:
///   velocity = unitsSold(window) / windowDays
///   target   = ceil(velocity × coverDays)
///   suggest  = max(0, target − currentStock)
/// Products with no recent sales (velocity 0) or enough stock are excluded.
/// Grouped/sorted by the product's supplier name (no-supplier last), qty desc.
List<ReorderSuggestion> computeReorderSuggestions(
  List<ProductEntity> products,
  Map<String, int> unitsSold,
  ReorderParams params,
) {
  final out = <ReorderSuggestion>[];

  for (final product in products) {
    if (!product.isActive) continue;
    final velocityPerDay = (unitsSold[product.id] ?? 0) / params.windowDays;
    final targetStock = (velocityPerDay * params.coverDays).ceil();
    final suggestedQty = math.max(0, targetStock - product.quantity);
    if (suggestedQty <= 0) continue;
    out.add(ReorderSuggestion(
      product: product,
      velocityPerDay: velocityPerDay,
      targetStock: targetStock,
      suggestedQty: suggestedQty,
    ));
  }

  out.sort((a, b) {
    final sa = a.supplierName ?? '\u{10FFFF}'; // nulls sort last
    final sb = b.supplierName ?? '\u{10FFFF}';
    if (sa != sb) return sa.compareTo(sb);
    return b.suggestedQty - a.suggestedQty;
  });
  return out;
}
