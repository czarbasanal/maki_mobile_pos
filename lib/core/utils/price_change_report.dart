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
