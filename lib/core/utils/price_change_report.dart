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

/// Groups by product AND selling option: a base per-piece price and an
/// option's set price (e.g. a By-6 pack) are different series and must never
/// be differenced against each other. A base entry has a null optionId, so
/// its key is stable and distinct from any option's.
String _groupKey(String productId, String? optionId) =>
    '$productId::${optionId ?? ''}';

/// Groups [entries] by (product, selling option), computes each change's delta
/// against the prior (older) in-range change in the same series — the oldest
/// change per group has no prior (deltas 0) — then returns all rows
/// newest-first by changedAt.
List<PriceChangeRow> priceChangeRowsInRange(List<PriceChangeEntry> entries) {
  final byProduct = <String, List<PriceChangeEntry>>{};
  for (final e in entries) {
    byProduct.putIfAbsent(_groupKey(e.productId, e.optionId), () => []).add(e);
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
/// in-range value. Without a baseline, prev falls back to the oldest in-range
/// entry. [isNew] marks products created inside the range (oldest entry is the
/// "Initial price" record). [hasPrev] is false when no prior value is known at
/// all (lone entry, no baseline) — deltas are meaningless then and the UI must
/// not render a "no change" comparison.
class ProductPriceChangeSummary {
  final String productId;
  final double prevPrice;
  final double prevCost;
  final double currPrice;
  final double currCost;
  final int changeCount;
  final DateTime lastChangedAt;
  final bool isNew;
  final bool hasPrev;

  const ProductPriceChangeSummary({
    required this.productId,
    required this.prevPrice,
    required this.prevCost,
    required this.currPrice,
    required this.currCost,
    required this.changeCount,
    required this.lastChangedAt,
    required this.isNew,
    required this.hasPrev,
  });

  double get priceDiff => currPrice - prevPrice;
  double get costDiff => currCost - prevCost;
}

/// The reason recorded on a product's creation-time price-history entry (see
/// ProductRepositoryImpl.createProduct).
const String _initialPriceReason = 'Initial price';

/// Groups in-range [entries] by (product, selling option) and summarizes each
/// group's net movement against its baseline (last change before the range,
/// for that same series; null when unknown). A product with multiple selling
/// options produces one summary per series — merging them would difference a
/// By-6 set price against a base per-piece price.
///
/// [baselines] is keyed by productId only (one baseline lookup per product,
/// regardless of how many series it has), so a baseline is only trusted for
/// the series it actually matches: its own optionId must equal the group's.
/// A baseline recorded against the base price must never seed an option
/// group's "prev", and vice versa — that mismatch is exactly the cross-series
/// contamination this function's grouping fix is about. When a baseline
/// doesn't match, the group falls back to "no baseline" (oldest in-range
/// entry as prev, hasPrev by entry count) exactly as if [baselines] had no
/// entry for it. Newest [ProductPriceChangeSummary.lastChangedAt] first.
List<ProductPriceChangeSummary> priceChangeProductSummaries(
  List<PriceChangeEntry> entries,
  Map<String, PriceHistoryEntry?> baselines,
) {
  final byProduct = <String, List<PriceChangeEntry>>{};
  for (final e in entries) {
    byProduct.putIfAbsent(_groupKey(e.productId, e.optionId), () => []).add(e);
  }

  final summaries = <ProductPriceChangeSummary>[];
  byProduct.forEach((groupKey, group) {
    group.sort((a, b) => a.changedAt.compareTo(b.changedAt));
    final oldest = group.first;
    final newest = group.last;
    final candidateBaseline = baselines[oldest.productId];
    final baseline = candidateBaseline?.optionId == oldest.optionId
        ? candidateBaseline
        : null;
    summaries.add(ProductPriceChangeSummary(
      productId: oldest.productId,
      prevPrice: baseline?.price ?? oldest.price,
      prevCost: baseline?.cost ?? oldest.cost,
      currPrice: newest.price,
      currCost: newest.cost,
      changeCount: group.length,
      lastChangedAt: newest.changedAt,
      isNew: baseline == null && oldest.reason == _initialPriceReason,
      hasPrev: baseline != null || group.length > 1,
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
  // Input is already newest-first (priceChangeProductSummaries' contract).
  if (sort == PriceChangeSort.latest) {
    return List<ProductPriceChangeSummary>.of(summaries);
  }

  double magnitude(ProductPriceChangeSummary s) => switch (sort) {
        PriceChangeSort.cost => s.costDiff.abs(),
        PriceChangeSort.price => s.priceDiff.abs(),
        PriceChangeSort.both => s.costDiff.abs() + s.priceDiff.abs(),
        PriceChangeSort.latest => 0,
      };

  final sorted = List<ProductPriceChangeSummary>.of(summaries);
  sorted.sort((a, b) {
    final byMagnitude = magnitude(b).compareTo(magnitude(a));
    if (byMagnitude != 0) return byMagnitude;
    return b.lastChangedAt.compareTo(a.lastChangedAt);
  });
  return sorted;
}
