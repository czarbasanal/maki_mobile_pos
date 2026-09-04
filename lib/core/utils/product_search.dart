import 'package:maki_mobile_pos/core/utils/sku_generator.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';

/// The one product-search predicate — every product search box on mobile
/// goes through this (inventory, POS, add-products sheets, bulk receiving),
/// and web_admin/src/domain/products/productSearch.ts mirrors it.
///
/// Semantics: the query is split on whitespace and EVERY token must appear
/// as a substring of the product's combined name / SKU / barcodes /
/// category — so word order and extra spaces never matter, and a token can
/// straddle fields ("0007 brake"). A concatenated query ("brakeshoe") falls
/// back to matching against the blob with spaces removed. A typed
/// dddd-dddd SKU is folded back to the stored 8-digit form per token.
bool matchesProductQuery(ProductEntity product, String rawQuery) {
  final tokens = rawQuery
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map(SkuGenerator.normalizeSkuQuery)
      .toList();
  if (tokens.isEmpty) return false;

  final blob = [
    product.name,
    product.sku,
    ...product.barcodes,
    if (product.category != null) product.category!,
  ].join(' ').toLowerCase();

  if (tokens.every(blob.contains)) return true;
  // "brakeshoe" should still find "BRAKE SHOE".
  return blob.replaceAll(RegExp(r'\s+'), '').contains(tokens.join());
}
