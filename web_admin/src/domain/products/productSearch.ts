// The one product-search predicate — every product search box on web goes
// through this (inventory filter, POS, receiving suggestions, price-history
// picker), and lib/core/utils/product_search.dart mirrors it on mobile.
//
// Semantics: the query is split on whitespace and EVERY token must appear as
// a substring of the product's combined name / SKU / barcodes / category —
// so word order and extra spaces never matter, and a token can straddle
// fields ("0007 brake"). A concatenated query ("brakeshoe") falls back to
// matching each field with ITS OWN spaces removed — fields are joined with a
// \u0000 sentinel precisely so no token can match across a field seam (a
// "1534" bridging sku "…0153" and barcode "4800…" must never hit).
// A dashed dddd-dddd token also matches as its folded 8-digit SKU form,
// while the raw token still matches genuinely dashed stored codes.
import { normalizeSkuQuery } from './sku';

export interface SearchableProduct {
  name: string;
  sku: string;
  category?: string | null;
  barcodes?: string[];
}

const SEP = '\u0000';

function tokenHits(blob: string, token: string): boolean {
  if (blob.includes(token)) return true;
  const folded = normalizeSkuQuery(token);
  return folded !== token && blob.includes(folded);
}

export function matchesProductQuery(product: SearchableProduct, rawQuery: string): boolean {
  const tokens = rawQuery.toLowerCase().split(/\s+/).filter((t) => t.length > 0);
  if (tokens.length === 0) return false;
  const fields = [product.name, product.sku, ...(product.barcodes ?? []), product.category ?? ''];
  const blob = fields.join(SEP).toLowerCase();
  if (tokens.every((t) => tokenHits(blob, t))) return true;
  // "brakeshoe" should still find "BRAKE SHOE" — spaces collapse WITHIN a
  // field only; the sentinel keeps field boundaries unbridgeable.
  const collapsed = fields.map((f) => f.replace(/\s+/g, '')).join(SEP).toLowerCase();
  return tokenHits(collapsed, tokens.join(''));
}
