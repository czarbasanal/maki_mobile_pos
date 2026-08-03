import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Most selling options one product may carry. Keeps the product doc small
/// and the picker sheet scrollable-free on a phone.
const int kMaxSellingOptions = 10;

/// Longest option label. Long enough for "By 6 (half box)".
const int kMaxSellingOptionLabel = 24;

/// Per-piece rate suffix for a product's [unit] — e.g. the "pc" in a
/// "₱110.00/pc" caption. `pcs` is special-cased down to `pc` because it's
/// the only plural default in the product data; every other unit (box,
/// set, pack, ...) is shown exactly as typed. Single source for this
/// mapping — every render site (POS picker, inventory editor, both
/// surfaces) calls this rather than hand-rolling the same conditional.
String sellingOptionRateSuffix(String unit) => unit == 'pcs' ? 'pc' : unit;

/// Validates a product's selling options. Returns `null` when the list is
/// valid, otherwise a message suitable for showing in the product form.
///
/// An empty list is valid — it means "no options", which is how every
/// product behaved before this feature.
String? validateSellingOptions(List<SellingOptionEntity> options) {
  if (options.isEmpty) return null;
  if (options.length > kMaxSellingOptions) {
    return 'At most $kMaxSellingOptions selling options per product.';
  }

  final seen = <String>{};
  for (final option in options) {
    final label = option.label.trim();
    if (label.isEmpty) return 'Every selling option needs a label.';
    if (label.length > kMaxSellingOptionLabel) {
      return 'Option labels are limited to $kMaxSellingOptionLabel characters.';
    }
    if (!seen.add(label.toLowerCase())) {
      return 'Option labels must be unique — "$label" is used twice.';
    }
    if (option.pieces < 1) {
      return '"$label" must cover at least 1 piece.';
    }
    if (option.price <= 0) {
      return '"$label" needs a price above zero.';
    }
  }
  return null;
}

/// Parses the Firestore `sellingOptions` array. Tolerant by design: a missing
/// field, a wrong type, or a malformed entry yields no option rather than an
/// exception, so one bad doc can never break the POS product list.
List<SellingOptionEntity> sellingOptionsFromList(dynamic raw) {
  if (raw is! List) return const [];
  final result = <SellingOptionEntity>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final id = item['id'] is String ? item['id'] as String : '';
    final label = item['label'] is String ? item['label'] as String : '';
    if (id.isEmpty || label.isEmpty) continue;
    result.add(SellingOptionEntity(
      id: id,
      label: label,
      pieces: item['pieces'] is num ? (item['pieces'] as num).toInt() : 1,
      price: item['price'] is num ? (item['price'] as num).toDouble() : 0.0,
    ));
  }
  return result;
}

/// Serializes selling options for the Firestore product doc.
List<Map<String, dynamic>> sellingOptionsToList(
  List<SellingOptionEntity> options,
) {
  return options
      .map((o) => <String, dynamic>{
            'id': o.id,
            'label': o.label,
            'pieces': o.pieces,
            'price': o.price,
          })
      .toList();
}

/// One price_history entry to write for a selling-option change.
class SellingOptionHistoryEvent {
  const SellingOptionHistoryEvent({
    required this.optionId,
    required this.optionLabel,
    required this.optionPieces,
    required this.price,
    required this.cost,
    required this.reason,
  });

  final String optionId;
  final String optionLabel;
  final int optionPieces;

  /// Price of the whole set.
  final double price;

  /// Cost of the whole set — pieces x unit cost — so the report's margin
  /// column compares like with like against [price].
  final double cost;

  final String reason;
}

/// One centavo. Matches the threshold priceHistoryReason-style comparisons
/// already use elsewhere (see `price_history_view.dart`), so a rounding
/// wobble never writes a history entry.
const double _historyEps = 0.01;

/// Diffs a product's selling options and returns the price_history entries to
/// write. Label-only renames produce nothing — a rename isn't a price event.
List<SellingOptionHistoryEvent> sellingOptionHistoryEvents(
  List<SellingOptionEntity> before,
  List<SellingOptionEntity> after,
  double unitCost,
) {
  final beforeById = {for (final o in before) o.id: o};
  final afterById = {for (final o in after) o.id: o};
  final events = <SellingOptionHistoryEvent>[];

  SellingOptionHistoryEvent event(SellingOptionEntity o, String reason) {
    return SellingOptionHistoryEvent(
      optionId: o.id,
      optionLabel: o.label,
      optionPieces: o.pieces,
      price: o.price,
      cost: o.pieces * unitCost,
      reason: reason,
    );
  }

  for (final o in after) {
    final prior = beforeById[o.id];
    if (prior == null) {
      events.add(event(o, 'Option added'));
      continue;
    }
    final piecesChanged = prior.pieces != o.pieces;
    final priceChanged = (prior.price - o.price).abs() > _historyEps;
    if (piecesChanged) {
      events.add(event(o, 'Option changed'));
    } else if (priceChanged) {
      events.add(event(o, 'Price update'));
    }
  }

  for (final o in before) {
    if (!afterById.containsKey(o.id)) events.add(event(o, 'Option removed'));
  }

  return events;
}
