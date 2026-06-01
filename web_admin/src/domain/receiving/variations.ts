// Ports of lib/core/utils/sku_generator.dart variation helpers.
const SEP = '-';

/** Strips a trailing `-N` (numeric) suffix; leaves non-numeric suffixes alone. */
export function removeVariationSuffix(sku: string): string {
  const i = sku.lastIndexOf(SEP);
  if (i === -1) return sku;
  const suffix = sku.slice(i + 1);
  return /^\d+$/.test(suffix) ? sku.slice(0, i) : sku;
}

export function variationSku(baseSku: string, variationNumber: number): string {
  return `${baseSku}${SEP}${variationNumber}`;
}

/** Next free `<base>-N` given the existing SKUs (any case). */
export function nextVariationNumber(baseSku: string, existingSkus: string[]): number {
  const cleanBase = removeVariationSuffix(baseSku);
  const prefix = `${cleanBase}${SEP}`;
  let max = 0;
  for (const sku of existingSkus) {
    if (!sku.startsWith(prefix)) continue;
    const n = Number.parseInt(sku.slice(prefix.length), 10);
    if (Number.isInteger(n) && n > max) max = n;
  }
  return max + 1;
}
