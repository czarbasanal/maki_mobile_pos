import 'package:maki_mobile_pos/core/utils/sku_generator.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';

/// The one product-search predicate — every product search box on mobile
/// goes through this (inventory, POS, add-products sheets, bulk receiving),
/// and web_admin/src/domain/products/productSearch.ts mirrors it.
///
/// Semantics: the query is split on whitespace and EVERY token must appear
/// as a substring of the product's combined name / SKU / barcodes /
/// category — so word order and extra spaces never matter, and a token can
/// straddle words within a field ("0007 brake"). A concatenated query
/// ("brakeshoe") falls back to matching each field with ITS OWN spaces
/// removed — fields are joined with a \\u0000 sentinel precisely so no token
/// can match across a field seam (a "1534" bridging sku "…0153" and barcode
/// "4800…" must never hit). A dashed dddd-dddd token also matches as its
/// folded 8-digit SKU form, while the raw token still matches genuinely
/// dashed stored codes.
const String _sep = '\u0000';
final RegExp _whitespace = RegExp(r'\s+');

bool _tokenHits(String blob, String token) {
  if (blob.contains(token)) return true;
  final folded = SkuGenerator.normalizeSkuQuery(token);
  return folded != token && blob.contains(folded);
}

bool matchesProductQuery(ProductEntity product, String rawQuery) {
  final tokens = rawQuery
      .toLowerCase()
      .split(_whitespace)
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return false;

  final fields = [
    product.name,
    product.sku,
    ...product.barcodes,
    if (product.category != null) product.category!,
  ];
  final blob = fields.join(_sep).toLowerCase();
  if (tokens.every((t) => _tokenHits(blob, t))) return true;

  // "brakeshoe" should still find "BRAKE SHOE" — spaces collapse WITHIN a
  // field only; the sentinel keeps field boundaries unbridgeable.
  final collapsed = fields
      .map((f) => f.replaceAll(_whitespace, ''))
      .join(_sep)
      .toLowerCase();
  return _tokenHits(collapsed, tokens.join());
}
