/**
 * Pure planner for relink-duplicate-skus.mjs.
 *
 * Takes products that share a name+category but are not linked, and plans a
 * rewrite that turns each group into one base plus `<base>-N` variations.
 * The LOWEST SKU in a group is kept as the base — deterministic, and in an
 * auto-SKU catalog the lowest sequence is the first one entered.
 *
 * Does no I/O. The runner owns the Firestore writes and the SKU-claim moves.
 */

/** Word-order-insensitive name key + exact category — mirrors the app. */
export function productNameKey(name) {
  return String(name ?? '').toLowerCase().split(/\s+/).filter(Boolean).sort().join(' ');
}
export function productDuplicateKey(name, category) {
  return `${productNameKey(name)}|${String(category ?? '').trim().toLowerCase()}`;
}

/** True when every non-base member already points at a member of the group. */
export function isLinkedGroup(group) {
  const skus = new Set(group.map((p) => p.sku));
  const nonBase = group.filter((p) => p.baseSku != null);
  return nonBase.length > 0 && nonBase.every((p) => skus.has(p.baseSku));
}

/**
 * Groups sharing a duplicate key that are NOT already linked.
 * Groups of one, and already-linked groups, are left alone.
 */
export function unlinkedDuplicateGroups(products) {
  const byKey = new Map();
  for (const p of products) {
    const k = productDuplicateKey(p.name, p.category);
    if (!byKey.has(k)) byKey.set(k, []);
    byKey.get(k).push(p);
  }
  return [...byKey.values()].filter((g) => g.length > 1 && !isLinkedGroup(g));
}

/**
 * The rewrites for one group: the lowest SKU stays put as the base, every
 * other member becomes `<base>-N` with N counting from 1 in SKU order.
 *
 * Returns [] when the group already has a member whose SKU is not free —
 * the runner treats that as a skip rather than guessing.
 */
export function planGroupRewrite(group, skuIsTaken = () => false) {
  const sorted = [...group].sort((a, b) => String(a.sku).localeCompare(String(b.sku)));
  const base = sorted[0];
  const out = [];
  let n = 0;
  for (const p of sorted.slice(1)) {
    n += 1;
    let candidate = `${base.sku}-${n}`;
    // Never collide with a SKU that already exists elsewhere in the catalog.
    while (skuIsTaken(candidate)) {
      n += 1;
      candidate = `${base.sku}-${n}`;
    }
    out.push({
      id: p.id,
      name: p.name,
      fromSku: p.sku,
      toSku: candidate,
      baseSku: base.sku,
      variationNumber: n,
      cost: p.cost,
      price: p.price,
      quantity: p.quantity,
    });
  }
  return out;
}

/** Every rewrite across every unlinked duplicate group. */
export function planRelink(products) {
  const taken = new Set(products.map((p) => p.sku));
  const plan = [];
  for (const g of unlinkedDuplicateGroups(products)) {
    for (const r of planGroupRewrite(g, (s) => taken.has(s))) {
      taken.add(r.toSku);
      plan.push(r);
    }
  }
  return plan;
}
