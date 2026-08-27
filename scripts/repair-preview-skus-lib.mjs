/**
 * Pure planners for repair-preview-skus.mjs.
 *
 * Background: a product created through receiving (or the New Product page)
 * with an auto-generated SKU is written with a PEEKED preview code, and the
 * real one is only allocated inside the transaction that claims it. Until the
 * fix in web_admin (`withAllocatedSku` + the plan-item write-back), two things
 * kept the stale preview:
 *   1. `products/{id}.searchKeywords`, derived from the SKU — so the product
 *      could not be found by typing the SKU actually printed on it.
 *   2. `receivings/{id}.items[].sku` — so receiving history showed a SKU
 *      belonging to some other product, identical across every new line that
 *      peeked the same sequence.
 * These planners find and repair both. They do no I/O.
 */

/** Port of `toSearchKeywords` (lib/core/extensions/string_extensions.dart and
 *  web_admin/src/domain/products/searchKeywords.ts) — both cap at 10. */
export function toSearchKeywords(value, minLength = 1, maxLength = 10) {
  const out = new Set();
  for (const word of String(value ?? '').toLowerCase().split(/\s+/)) {
    if (word.length === 0) continue;
    for (let i = minLength; i <= word.length && i <= maxLength; i += 1) {
      out.add(word.slice(0, i));
    }
  }
  return [...out];
}

/**
 * The keyword set a product SHOULD carry: the union of what mobile's
 * `_generateSearchKeywords` and web's `generateSearchKeywords` derive — sku,
 * name, barcodes, category. Rebuilding the whole set (rather than adding the
 * missing sku tokens) is what drops the stale preview's tokens; taking the
 * union of both generators is what stops the repair from wiping the barcode
 * tokens that only mobile writes.
 */
export function expectedKeywords(product) {
  const out = new Set();
  const parts = [product.sku, product.name, ...(product.barcodes ?? []), product.category];
  for (const part of parts) {
    if (!part) continue;
    for (const kw of toSearchKeywords(part)) out.add(kw);
  }
  return [...out];
}

/**
 * Returns `{ id, sku, keywords, dropped }` for a product whose keywords no
 * longer match its SKU, or null when nothing needs changing. Only a product
 * MISSING one of its own sku tokens is treated as broken — an extra token by
 * itself is harmless (a renamed product keeps its old name's tokens, and that
 * costs nothing but a wider search hit).
 */
export function planKeywordRepair(product) {
  const have = new Set(product.searchKeywords ?? []);
  const skuTokens = toSearchKeywords(product.sku);
  if (skuTokens.length === 0) return null;
  if (skuTokens.every((t) => have.has(t))) return null;

  const keywords = expectedKeywords(product);
  const keep = new Set(keywords);
  return {
    id: product.id,
    sku: product.sku,
    keywords,
    dropped: [...have].filter((t) => !keep.has(t)),
  };
}

/**
 * Returns the line-level SKU corrections for one receiving: each item whose
 * recorded sku disagrees with the product it points at. A line links to the
 * product it created through `newProductId` (variations keep `productId` on
 * the product they vary), so that takes precedence. Lines with no link, or
 * whose product has since been deleted, are left alone — there is nothing
 * authoritative to copy from.
 */
export function planReceivingItemFixes(receiving, productsById) {
  const fixes = [];
  (receiving.items ?? []).forEach((item, index) => {
    const productId = item.newProductId ?? item.productId;
    if (!productId) return;
    const product = productsById.get(productId);
    if (!product) return;
    if (product.sku === item.sku) return;
    fixes.push({ index, from: item.sku, to: product.sku, name: item.name });
  });
  return fixes;
}

/** Groups a receiving's lines by sku so the report can name the exact symptom
 *  the user sees in history: two different products sharing one code. */
export function duplicateSkusIn(receiving) {
  const counts = new Map();
  for (const item of receiving.items ?? []) {
    const key = item.sku ?? '';
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return [...counts.entries()]
    .filter(([, n]) => n > 1)
    .map(([sku, count]) => ({ sku, count }));
}
