// Port of lib/core/utils/sku_generator.dart `generateForName`, plus the
// Code128 auto-SKU helpers (composeAutoSku/matchesAutoPattern/sequenceOf/
// displaySku — mirrors lib/core/utils/sku_generator.dart's statics of the
// same name). Ambiguous characters (0/O, 1/I/L) are excluded so SKUs stay
// scanner-friendly. Keep this file, the Dart SkuGenerator, and
// scripts/backfill-*.mjs byte-identical for anything claim-key or
// pattern related.
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

/**
 * Composes an auto-generated SKU from a 4-digit category code and a
 * 1..9999 sequence. Format: code + zero-padded 4-digit sequence.
 * Example: composeAutoSku('0007', 153) => '00070153'.
 * Throws on a non-4-digit code or a sequence outside 1..9999 (mirrors the
 * Dart `SkuGenerator.composeAutoSku` asserts, which are non-strippable here).
 */
export function composeAutoSku(categoryCode: string, sequence: number): string {
  if (!/^\d{4}$/.test(categoryCode)) {
    throw new Error('categoryCode must be exactly 4 digits');
  }
  if (!Number.isInteger(sequence) || sequence < 1 || sequence > 9999) {
    throw new Error('sequence must be between 1 and 9999');
  }
  const paddedSequence = String(sequence).padStart(4, '0');
  return `${categoryCode}${paddedSequence}`;
}

/**
 * Whether `sku` matches the auto-generated pattern for `categoryCode`: exactly
 * 8 digits and starts with the (exactly-4-digit) category code. `categoryCode`
 * is validated at runtime — a malformed code (not exactly 4 digits) returns
 * false rather than throwing, since this is a guard callers use on arbitrary
 * input, not an invariant they control.
 */
export function matchesAutoPattern(sku: string, categoryCode: string): boolean {
  if (!/^\d{4}$/.test(categoryCode)) return false;
  if (sku.length !== 8) return false;
  if (!/^\d{8}$/.test(sku)) return false;
  return sku.startsWith(categoryCode);
}

/**
 * Extracts the sequence number (last 4 digits) from an auto-generated SKU.
 * Assumes `sku` already matches the auto pattern (see matchesAutoPattern).
 */
export function sequenceOf(sku: string): number {
  return Number.parseInt(sku.slice(4), 10);
}

/**
 * The SKU as it should be shown — verbatim.
 *
 * This used to split an 8-digit auto-SKU as 'XXXX-XXXX'. That was retired once
 * variation SKUs (`<base>-N`) became real stock: '0002-0194' sitting next to
 * '00020194-1' read as two unrelated codes rather than a part and its
 * variation. Every surface calls this rather than printing `sku` directly, so
 * the one seam survives for whatever the shop wants next.
 */
export function displaySku(sku: string): string {
  return sku;
}

/**
 * Turns a typed SKU back into its stored form — the inverse of displaySku for
 * search inputs.
 *
 * SKUs are shown as `0007-0153` everywhere, so that is what people type, but
 * searchKeywords is built from the stored `00070153`. Only the exact displayed
 * shape is rewritten: a manual SKU that genuinely owns a dash (`MLK-A3B7`) is
 * indexed verbatim and must pass through untouched.
 */
export function normalizeSkuQuery(query: string): string {
  return /^\d{4}-\d{4}$/.test(query) ? query.replace('-', '') : query;
}

/**
 * The SKU as it should appear in an exported CSV.
 *
 * Screens show the SKU verbatim, but a spreadsheet reads `00070153` as the
 * number 70153 and eats the leading zeros. Wrapping a digit-leading SKU as an
 * Excel/Sheets text formula keeps every character without reintroducing a
 * separator into the code itself.
 */
export function csvSku(sku: string): string {
  return /^\d/.test(sku) ? `="${sku}"` : sku;
}
