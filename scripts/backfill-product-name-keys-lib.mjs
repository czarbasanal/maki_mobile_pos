/**
 * Pure planners for backfill-product-name-keys.mjs.
 *
 * Third copy of the name-key helper by necessity: scripts are standalone Node
 * ESM and cannot import web_admin's TypeScript or the Flutter source. The test
 * shares its vector table with both other implementations so the three cannot
 * drift apart silently.
 */

/** Lowercased, whitespace-collapsed, token-sorted form of `name`. */
export function productNameKey(name) {
  return String(name ?? '')
    .toLowerCase()
    .split(/\s+/)
    .filter((t) => t.length > 0)
    .sort()
    .join(' ');
}

/** Name key plus an exact category match. */
export function productDuplicateKey(name, category) {
  return `${productNameKey(name)}|${String(category ?? '').trim().toLowerCase()}`;
}

/**
 * Products whose stored `nameKey` is missing or no longer matches their name
 * and category. Returning only the stale ones makes a re-run a no-op.
 */
export function planNameKeyBackfill(products) {
  const out = [];
  for (const p of products) {
    const nameKey = productDuplicateKey(p.name, p.category);
    if (p.nameKey !== nameKey) out.push({ id: p.id, nameKey, name: p.name });
  }
  return out;
}

/**
 * Products that already share a duplicate key, largest group first. This is a
 * report only — merging existing duplicates is deliberately out of scope.
 */
export function duplicateGroups(products) {
  const byKey = new Map();
  for (const p of products) {
    const key = productDuplicateKey(p.name, p.category);
    if (!byKey.has(key)) byKey.set(key, []);
    byKey.get(key).push(p);
  }
  return [...byKey.entries()]
    .filter(([, members]) => members.length > 1)
    .map(([key, members]) => ({ key, members }))
    .sort((a, b) => b.members.length - a.members.length);
}
