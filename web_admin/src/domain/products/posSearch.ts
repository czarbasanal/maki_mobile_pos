// POS product search + wedge-scanner resolution (mobile
// localProductSearchProvider / productByBarcodeProvider parity). A USB
// scanner types the code and sends Enter, so Enter-in-search resolves the
// raw text as a scan: barcode first, exact SKU fallback.
import type { Product } from '@/domain/entities';
import { normalizeBarcode, normalizeSku, normalizeSkuQuery } from './sku';

export function matchesPosQuery(product: Product, rawQuery: string): boolean {
  const q = rawQuery.trim().toLowerCase();
  if (!q) return false;
  const skuQ = normalizeSkuQuery(rawQuery.trim()).toLowerCase();
  return (
    product.name.toLowerCase().includes(q) ||
    product.sku.toLowerCase().includes(skuQ) ||
    (product.category ?? '').toLowerCase().includes(q) ||
    product.barcodes.some((b) => b.toLowerCase().includes(q))
  );
}

export function findByScannedCode(products: Product[], rawCode: string): Product | null {
  const code = normalizeBarcode(rawCode);
  if (!code) return null;
  const byBarcode = products.find((p) =>
    p.barcodes.some((b) => normalizeBarcode(b) === code),
  );
  if (byBarcode) return byBarcode;
  const sku = normalizeSku(normalizeSkuQuery(rawCode.trim()));
  return products.find((p) => normalizeSku(p.sku) === sku) ?? null;
}
