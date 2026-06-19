import { normalizeBarcode } from './sku';

/**
 * A product's barcode set, read tolerantly from a Firestore doc: the canonical
 * `barcodes` array UNION a legacy singular `barcode`, each trimmed, empties
 * dropped, de-duped by normalized key (first-seen order preserved).
 */
export function parseBarcodes(raw: { barcodes?: unknown; barcode?: unknown }): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  const push = (v: unknown) => {
    if (typeof v !== 'string') return;
    const code = normalizeBarcode(v);
    if (code.length === 0 || seen.has(code)) return;
    seen.add(code);
    out.push(code);
  };
  if (Array.isArray(raw.barcodes)) for (const v of raw.barcodes) push(v);
  push(raw.barcode);
  return out;
}

/**
 * Claims to move when a product's barcode set changes, compared by normalized
 * key: `added` = in next not old, `removed` = in old not next. Returned values
 * are normalized keys (== the product_barcodes doc-ids).
 */
export function diffBarcodeClaims(
  oldCodes: string[],
  nextCodes: string[],
): { added: string[]; removed: string[] } {
  const oldKeys = new Set(oldCodes.map(normalizeBarcode).filter((k) => k.length > 0));
  const nextKeys = new Set(nextCodes.map(normalizeBarcode).filter((k) => k.length > 0));
  const added = [...nextKeys].filter((k) => !oldKeys.has(k));
  const removed = [...oldKeys].filter((k) => !nextKeys.has(k));
  return { added, removed };
}
