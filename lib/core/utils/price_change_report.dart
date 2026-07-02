import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

/// A price-change entry with its ▲/▼ deltas vs the prior in-range change for
/// the same product.
class PriceChangeRow {
  final PriceChangeEntry entry;
  final double priceDelta;
  final double costDelta;
  final bool hasPrior;

  const PriceChangeRow({
    required this.entry,
    required this.priceDelta,
    required this.costDelta,
    required this.hasPrior,
  });
}

/// Groups [entries] by product, computes each change's delta against the prior
/// (older) in-range change for that product — the oldest change per product has
/// no prior (deltas 0) — then returns all rows newest-first by changedAt.
List<PriceChangeRow> priceChangeRowsInRange(List<PriceChangeEntry> entries) {
  final byProduct = <String, List<PriceChangeEntry>>{};
  for (final e in entries) {
    byProduct.putIfAbsent(e.productId, () => []).add(e);
  }

  final rows = <PriceChangeRow>[];
  for (final group in byProduct.values) {
    // Oldest -> newest so each entry can look back at the previous one.
    group.sort((a, b) => a.changedAt.compareTo(b.changedAt));
    PriceChangeEntry? prior;
    for (final e in group) {
      rows.add(PriceChangeRow(
        entry: e,
        priceDelta: prior == null ? 0 : e.price - prior.price,
        costDelta: prior == null ? 0 : e.cost - prior.cost,
        hasPrior: prior != null,
      ));
      prior = e;
    }
  }

  rows.sort((a, b) => b.entry.changedAt.compareTo(a.entry.changedAt));
  return rows;
}

/// Sort orders for the per-product price-change summary list.
enum PriceChangeSort { latest, cost, price, both }

/// A product's net price/cost movement over the report range: `prev` is the
/// value just before the range's first change (baseline), `curr` the newest
/// in-range value. [isNew] marks products whose history starts inside the
/// range (no baseline) — prev falls back to the oldest in-range entry.
class ProductPriceChangeSummary {
  final String productId;
  final double prevPrice;
  final double prevCost;
  final double currPrice;
  final double currCost;
  final int changeCount;
  final DateTime lastChangedAt;
  final bool isNew;

  const ProductPriceChangeSummary({
    required this.productId,
    required this.prevPrice,
    required this.prevCost,
    required this.currPrice,
    required this.currCost,
    required this.changeCount,
    required this.lastChangedAt,
    required this.isNew,
  });

  double get priceDiff => currPrice - prevPrice;
  double get costDiff => currCost - prevCost;
}

/// Groups in-range [entries] by product and summarizes each product's net
/// movement against its baseline (last change before the range; null when the
/// product has none). Newest [ProductPriceChangeSummary.lastChangedAt] first.
List<ProductPriceChangeSummary> priceChangeProductSummaries(
  List<PriceChangeEntry> entries,
  Map<String, PriceHistoryEntry?> baselines,
) {
  final byProduct = <String, List<PriceChangeEntry>>{};
  for (final e in entries) {
    byProduct.putIfAbsent(e.productId, () => []).add(e);
  }

  final summaries = <ProductPriceChangeSummary>[];
  byProduct.forEach((productId, group) {
    group.sort((a, b) => a.changedAt.compareTo(b.changedAt));
    final baseline = baselines[productId];
    final oldest = group.first;
    final newest = group.last;
    summaries.add(ProductPriceChangeSummary(
      productId: productId,
      prevPrice: baseline?.price ?? oldest.price,
      prevCost: baseline?.cost ?? oldest.cost,
      currPrice: newest.price,
      currCost: newest.cost,
      changeCount: group.length,
      lastChangedAt: newest.changedAt,
      isNew: baseline == null,
    ));
  });

  summaries.sort((a, b) => b.lastChangedAt.compareTo(a.lastChangedAt));
  return summaries;
}

/// Returns a new list sorted by [sort]; change-magnitude sorts are descending
/// with newest [ProductPriceChangeSummary.lastChangedAt] breaking ties.
List<ProductPriceChangeSummary> sortPriceChangeSummaries(
  List<ProductPriceChangeSummary> summaries,
  PriceChangeSort sort,
) {
  double magnitude(ProductPriceChangeSummary s) => switch (sort) {
        PriceChangeSort.cost => s.costDiff.abs(),
        PriceChangeSort.price => s.priceDiff.abs(),
        PriceChangeSort.both => s.costDiff.abs() + s.priceDiff.abs(),
        PriceChangeSort.latest => 0,
      };

  final sorted = List<ProductPriceChangeSummary>.of(summaries);
  sorted.sort((a, b) {
    if (sort != PriceChangeSort.latest) {
      final byMagnitude = magnitude(b).compareTo(magnitude(a));
      if (byMagnitude != 0) return byMagnitude;
    }
    return b.lastChangedAt.compareTo(a.lastChangedAt);
  });
  return sorted;
}
