/// Word-order-insensitive product name key, for duplicate detection.
///
/// The catalog is full of terse part names whose word order drifts between
/// entries — "CHAIN GLOBAL 428-120L" and "GLOBAL CHAIN 428-120L" are the same
/// part. Sorting the tokens makes both collapse to one key.
///
/// Punctuation stays INSIDE tokens on purpose: `90/90-14` and `90/90-17` are
/// different tyre sizes, and `428-120l` is a chain length. Stripping it would
/// merge genuinely different products.
///
/// MIRRORED in web_admin/src/domain/products/nameKey.ts — keep in lock-step.
library;

/// Lowercased, whitespace-collapsed, token-sorted form of [name].
String productNameKey(String name) {
  final tokens = name
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList()
    ..sort();
  return tokens.join(' ');
}

/// The key two products must share to be considered the same item: the
/// name key plus an exact category match. A null/absent category is an
/// empty segment so it can never read as the literal word "null".
String productDuplicateKey(String name, String? category) =>
    '${productNameKey(name)}|${(category ?? '').trim().toLowerCase()}';
