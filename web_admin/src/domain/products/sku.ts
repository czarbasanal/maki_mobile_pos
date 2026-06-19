// Port of lib/core/utils/sku_generator.dart `generateForName`. Ambiguous
// characters (0/O, 1/I/L) are excluded so SKUs stay scanner-friendly.
const SKU_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const SKU_PREFIX = 'SKU';
const SKU_RANDOM_LENGTH = 8;
const SKU_PREFIXED_RANDOM_LENGTH = 6;
const SKU_NAME_PREFIX_LENGTH = 10;

function randomString(length: number, rand: () => number): string {
  let out = '';
  for (let i = 0; i < length; i += 1) {
    out += SKU_CHARS[Math.floor(rand() * SKU_CHARS.length)];
  }
  return out;
}

export function slugifyForSku(name: string): string {
  return name.toUpperCase().replace(/[^A-Z0-9]/g, '');
}

/** `rand` is injectable so tests are deterministic. */
export function generateSku(name: string, rand: () => number = Math.random): string {
  const slug = slugifyForSku(name);
  if (slug.length === 0) {
    return `${SKU_PREFIX}-${randomString(SKU_RANDOM_LENGTH, rand)}`;
  }
  const first = slug[0];
  const rest = slug.slice(1).replace(/[AEIOU]/g, '');
  const base = first + rest;
  const prefix =
    base.length > SKU_NAME_PREFIX_LENGTH ? base.slice(0, SKU_NAME_PREFIX_LENGTH) : base;
  return `${prefix}-${randomString(SKU_PREFIXED_RANDOM_LENGTH, rand)}`;
}

/**
 * Canonical key for product_skus claims. MUST stay byte-identical to
 * scripts/backfill-product-skus.mjs and mobile SkuGenerator.normalizeSku
 * (`trim().toUpperCase()`), or the guard and the backfilled claims key
 * differently and uniqueness silently breaks.
 */
export function normalizeSku(sku: string): string {
  return sku.trim().toUpperCase();
}

/**
 * Code128-safe SKU and a valid Firestore doc-id subset (non-empty, <= 50 chars,
 * letters/digits/hyphens only). Used to reject SKUs that can't key a claim doc.
 */
export function isValidSku(sku: string): boolean {
  return sku.length > 0 && sku.length <= 50 && /^[A-Za-z0-9-]+$/.test(sku);
}

/**
 * Canonical key for barcode-uniqueness claims
 * (`product_barcodes/{normalizeBarcode(code)}`). MUST stay byte-identical to
 * scripts/backfill-product-barcodes.mjs (`String(s).trim()`) and the Dart
 * SkuGenerator.normalizeBarcode — case-sensitive (barcodes are exact tokens).
 */
export function normalizeBarcode(code: string): string {
  return code.trim();
}

/**
 * Whether a (already-normalized, non-empty) barcode key can be a Firestore
 * doc-id, so it can be claimed. Empty keys mean "no barcode" (skip, not error).
 */
export function isClaimableBarcode(key: string): boolean {
  if (key.length === 0 || key.length > 1500) return false;
  if (key === '.' || key === '..') return false;
  if (key.includes('/')) return false;
  return !/^__.*__$/.test(key);
}
