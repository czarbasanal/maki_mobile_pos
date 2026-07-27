/**
 * Pure planning logic for the re-SKU migration (old auto-generated SKUs ->
 * the coded scheme). No Firestore access here — see resku.mjs for the CLI
 * that reads/writes Firestore around these functions.
 */

// Mirrors lib/core/utils/sku_generator.dart EXACTLY:
//   generateForName(): `${prefix}-${6-char suffix}` where prefix is 1-10
//     chars of A-Z0-9 and the suffix alphabet excludes ambiguous chars
//     (no 0/O, 1/I/L).
//   generate(): `SKU-${8-char suffix}` (same suffix alphabet).
const OLD_AUTO_NAME_PATTERN = /^[A-Z0-9]{1,10}-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$/;
const OLD_AUTO_GENERIC_PATTERN = /^SKU-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$/;

/**
 * @param {string} sku
 * @returns {boolean} true if `sku` matches one of the two old auto-generated
 *   patterns (and therefore is a rename candidate). Manual part numbers and
 *   already-coded 8-digit skus (e.g. '00070153') never match.
 */
export function classifyOldAuto(sku) {
  const s = String(sku ?? '');
  return OLD_AUTO_NAME_PATTERN.test(s) || OLD_AUTO_GENERIC_PATTERN.test(s);
}

function composeAutoSku(categoryCode, sequence) {
  return `${categoryCode}${String(sequence).padStart(4, '0')}`;
}

function createdAtValue(createdAt) {
  return createdAt?.seconds ?? createdAt ?? 0;
}

/**
 * @param {object} args
 * @param {Array<{id: string, sku: string, category?: string|null, baseSku?: string|null, createdAt?: any}>} args.products
 * @param {Array<{name: string, code?: string}>} args.categories
 * @param {Record<string, number>} args.registry - category code -> nextSequence
 * @returns {{
 *   renames: Array<{id: string, oldSku: string, newSku: string, categoryCode: string}>,
 *   baseSkuFixes: Array<{id: string, oldBaseSku: string, newBaseSku: string}>,
 *   registryAfter: Record<string, number>,
 *   skipped: Array<{id: string, oldSku: string, reason: string}>,
 * }}
 */
export function planResku({ products, categories, registry = {} }) {
  const categoryByName = new Map();
  for (const cat of categories) {
    categoryByName.set(cat.name, cat);
  }

  // Bucket old-auto products by resolved category code; collect skips.
  const skipped = [];
  const byCode = new Map(); // code -> eligible products

  for (const product of products) {
    if (!classifyOldAuto(product.sku)) continue; // untouched: manual/coded

    const categoryName = product.category;
    if (!categoryName) {
      skipped.push({ id: product.id, oldSku: product.sku, reason: 'missing category' });
      continue;
    }
    const category = categoryByName.get(categoryName);
    if (!category) {
      skipped.push({
        id: product.id,
        oldSku: product.sku,
        reason: `category not found: ${categoryName}`,
      });
      continue;
    }
    if (!category.code) {
      skipped.push({
        id: product.id,
        oldSku: product.sku,
        reason: `uncoded category: ${categoryName}`,
      });
      continue;
    }

    if (!byCode.has(category.code)) byCode.set(category.code, []);
    byCode.get(category.code).push(product);
  }

  const renames = [];
  const registryAfter = { ...registry };

  for (const [code, group] of byCode) {
    group.sort((a, b) => {
      const aTime = createdAtValue(a.createdAt);
      const bTime = createdAtValue(b.createdAt);
      if (aTime !== bTime) return aTime - bTime;
      return a.id.localeCompare(b.id);
    });

    let sequence = registry[code] ?? 1;
    for (const product of group) {
      if (sequence > 9999) {
        throw new Error(`sequence overflow: category ${code} would exceed 9999`);
      }
      const newSku = composeAutoSku(code, sequence);
      renames.push({ id: product.id, oldSku: product.sku, newSku, categoryCode: code });
      sequence += 1;
    }
    registryAfter[code] = sequence;
  }

  // In-plan duplicate target check: a computed rename target must not
  // collide with (a) another rename target in this same plan, or (b) any
  // OTHER product's current sku (e.g. a manual/coded-looking sku that a
  // stale/lagging registry sequence happens to land on). Either would leave
  // two products claiming the same sku, so abort the whole plan rather than
  // silently applying it.
  const currentSkuOwner = new Map(products.map(p => [p.sku, p.id]));
  const seenTargets = new Set();
  for (const rename of renames) {
    if (seenTargets.has(rename.newSku)) {
      throw new Error(`duplicate target sku in plan: ${rename.newSku}`);
    }
    seenTargets.add(rename.newSku);

    const owner = currentSkuOwner.get(rename.newSku);
    if (owner && owner !== rename.id) {
      throw new Error(
        `duplicate target sku in plan: ${rename.newSku} would collide with existing product ${owner}`,
      );
    }
  }

  // Second pass: every product (renamed or not) whose baseSku equals an old
  // sku that got renamed gets its baseSku remapped too.
  const renameMap = new Map(renames.map(r => [r.oldSku, r.newSku]));
  const baseSkuFixes = [];
  for (const product of products) {
    const oldBaseSku = product.baseSku;
    if (oldBaseSku && renameMap.has(oldBaseSku)) {
      baseSkuFixes.push({
        id: product.id,
        oldBaseSku,
        newBaseSku: renameMap.get(oldBaseSku),
      });
    }
  }

  return { renames, baseSkuFixes, registryAfter, skipped };
}
