import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Most selling options one product may carry. Keeps the product doc small
/// and the picker sheet scrollable-free on a phone.
const int kMaxSellingOptions = 10;

/// Longest option label. Long enough for "By 6 (half box)".
const int kMaxSellingOptionLabel = 24;

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
    final id = item['id'] as String? ?? '';
    final label = item['label'] as String? ?? '';
    if (id.isEmpty || label.isEmpty) continue;
    result.add(SellingOptionEntity(
      id: id,
      label: label,
      pieces: (item['pieces'] as num?)?.toInt() ?? 1,
      price: (item['price'] as num?)?.toDouble() ?? 0.0,
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
