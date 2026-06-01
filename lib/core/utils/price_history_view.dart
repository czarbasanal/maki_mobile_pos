import 'package:maki_mobile_pos/domain/repositories/product_repository.dart'
    show PriceHistoryEntry;

/// Which metric the dedicated price-history view is filtered to.
enum PriceMetric { all, price, cost }

/// A price-history entry paired with its change vs. the chronologically
/// previous (older) entry. For the oldest entry there is no prior, so the
/// deltas are 0 and [hasPrior] is false — it is the origin of every series.
class PriceHistoryRow {
  const PriceHistoryRow({
    required this.entry,
    required this.priceDelta,
    required this.costDelta,
    required this.hasPrior,
  });

  final PriceHistoryEntry entry;
  final double priceDelta;
  final double costDelta;
  final bool hasPrior;
}

/// Smallest change treated as a real move (guards against float noise).
const double _eps = 0.005;

/// Builds display rows from [entriesNewestFirst] (as returned by
/// `getPriceHistory`), filtered to [metric].
///
/// Deltas are computed against the chronologically previous entry — the NEXT
/// element in the newest-first list. The oldest entry has no prior, so its
/// deltas are 0 and it is always kept (origin point of every series). For
/// [PriceMetric.price] / [PriceMetric.cost], an entry is kept when it has no
/// prior OR that metric moved by more than [_eps].
List<PriceHistoryRow> buildPriceHistoryRows(
  List<PriceHistoryEntry> entriesNewestFirst,
  PriceMetric metric,
) {
  final rows = <PriceHistoryRow>[];
  for (var i = 0; i < entriesNewestFirst.length; i++) {
    final entry = entriesNewestFirst[i];
    final prior =
        i + 1 < entriesNewestFirst.length ? entriesNewestFirst[i + 1] : null;
    final hasPrior = prior != null;
    final priceDelta = hasPrior ? entry.price - prior.price : 0.0;
    final costDelta = hasPrior ? entry.cost - prior.cost : 0.0;

    final keep = switch (metric) {
      PriceMetric.all => true,
      PriceMetric.price => !hasPrior || priceDelta.abs() > _eps,
      PriceMetric.cost => !hasPrior || costDelta.abs() > _eps,
    };
    if (keep) {
      rows.add(PriceHistoryRow(
        entry: entry,
        priceDelta: priceDelta,
        costDelta: costDelta,
        hasPrior: hasPrior,
      ));
    }
  }
  return rows;
}

/// Returns the metric values in chronological order (oldest -> newest) for the
/// sparkline. Pass [forCost] true for the cost series, false for the price
/// series. Always reflects the full history regardless of the active filter.
List<double> sparklineSeries(
  List<PriceHistoryEntry> entriesNewestFirst, {
  required bool forCost,
}) {
  final values = [
    for (final e in entriesNewestFirst) forCost ? e.cost : e.price,
  ];
  return values.reversed.toList();
}

/// Maps a price-history [reason] (a `PriceChangeReason` constant) plus optional
/// [note] to a human label for the "Source" column.
String derivePriceHistorySource(String? reason, String? note) {
  switch (reason) {
    case 'Initial price':
      return 'Created';
    case 'Price update':
    case 'Cost update':
      return 'Manual edit';
    case 'Stock receiving':
      final rcv = _receivingId(note);
      return rcv == null ? 'Receiving' : 'Receiving ($rcv)';
    case null:
    case '':
      return 'Edit';
    default:
      return reason;
  }
}

/// Extracts an `RCV-YYYYMMDD-N` id from a free-text [note], if present.
String? _receivingId(String? note) {
  if (note == null) return null;
  final match = RegExp(r'RCV-\d{8}-\d+').firstMatch(note);
  return match?.group(0);
}
