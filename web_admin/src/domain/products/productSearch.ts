// The one product-search predicate — every product search box on web goes
// through this (inventory filter, POS, receiving suggestions, price-history
// picker), and lib/core/utils/product_search.dart mirrors it on mobile.
//
// Semantics: the query is split on whitespace and EVERY token must appear as
// a substring of the product's combined name / SKU / barcodes / category —
// so word order and extra spaces never matter, and a token can straddle
// fields ("0007 brake"). A concatenated query ("brakeshoe") falls back to
// matching against the blob with spaces removed.
export interface SearchableProduct {
  name: string;
  sku: string;
  category?: string | null;
  barcodes?: string[];
}

export function matchesProductQuery(product: SearchableProduct, rawQuery: string): boolean {
  const tokens = rawQuery.toLowerCase().split(/\s+/).filter((t) => t.length > 0);
  if (tokens.length === 0) return false;
  const blob = [product.name, product.sku, ...(product.barcodes ?? []), product.category ?? '']
    .join(' ')
    .toLowerCase();
  if (tokens.every((t) => blob.includes(t))) return true;
  // "brakeshoe" should still find "BRAKE SHOE".
  return blob.replace(/\s+/g, '').includes(tokens.join(''));
}
