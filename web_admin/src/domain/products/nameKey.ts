// Word-order-insensitive product name key, for duplicate detection.
//
// The catalog is full of terse part names whose word order drifts between
// entries — "CHAIN GLOBAL 428-120L" and "GLOBAL CHAIN 428-120L" are the same
// part. Sorting the tokens makes both collapse to one key.
//
// Punctuation stays INSIDE tokens on purpose: 90/90-14 and 90/90-17 are
// different tyre sizes, and 428-120l is a chain length. Stripping it would
// merge genuinely different products.
//
// MIRRORED in lib/core/utils/product_name_key.dart — keep in lock-step.

/** Lowercased, whitespace-collapsed, token-sorted form of `name`. */
export function productNameKey(name: string): string {
  return name
    .toLowerCase()
    .split(/\s+/)
    .filter((t) => t.length > 0)
    .sort()
    .join(' ');
}

/**
 * The key two products must share to be considered the same item: the name
 * key plus an exact category match. A null/absent category is an empty
 * segment so it can never read as the literal string "null".
 */
export function productDuplicateKey(name: string, category: string | null): string {
  return `${productNameKey(name)}|${(category ?? '').trim().toLowerCase()}`;
}
