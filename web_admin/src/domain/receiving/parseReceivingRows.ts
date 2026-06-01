// Port of lib/core/utils/batch_import.dart parseBatchImportCsv. Positional
// columns: sku, name, category, unit, cost, price, quantity, reorder_level.

export const GENERATE_SKU = 'GENERATE';

export interface ParsedReceivingRow {
  rowNumber: number;
  sku: string;
  name: string;
  category: string | null;
  unit: string;
  cost: number;
  price: number;
  quantity: number;
  reorderLevel: number;
  autoGenerateSku: boolean;
  errors: string[];
  warnings: string[];
}

export interface ParseResult {
  rows: ParsedReceivingRow[];
  headerError: string | null;
}

function num(raw: string): number | null {
  const t = raw.trim().replace(/,/g, '');
  if (t === '') return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

export function parseReceivingRows(grid: string[][]): ParseResult {
  if (grid.length === 0) return { rows: [], headerError: 'The file is empty.' };
  const header = grid[0].map((c) => c.trim().toLowerCase());
  if (header[0] !== 'sku') {
    return { rows: [], headerError: 'Header row malformed — the first column must be "sku".' };
  }

  const dataRows = grid.slice(1).filter((r) => r.some((c) => c.trim() !== ''));
  const rows = dataRows.map((r, i): ParsedReceivingRow => {
    const cell = (idx: number) => (idx < r.length ? r[idx].trim() : '');
    const errors: string[] = [];

    const sku = cell(0);
    const name = cell(1);
    if (sku === '') errors.push('sku is required (or "GENERATE").');
    if (name === '') errors.push('name is required.');

    const costRaw = cell(4);
    const cost = num(costRaw);
    if (cost === null || cost < 0) errors.push(`cost must be a non-negative number (got "${costRaw}").`);

    const priceRaw = cell(5);
    const price = num(priceRaw);
    if (price === null || price < 0) errors.push(`price must be a non-negative number (got "${priceRaw}").`);

    const qtyRaw = cell(6);
    const qty = num(qtyRaw);
    if (qty === null || !Number.isInteger(qty) || qty <= 0) {
      errors.push(`quantity must be a positive whole number (got "${qtyRaw}").`);
    }

    const reorderRaw = cell(7);
    let reorderLevel = 0;
    if (reorderRaw !== '') {
      const ro = num(reorderRaw);
      if (ro === null || ro < 0 || !Number.isInteger(ro)) {
        errors.push(`reorder_level must be a non-negative whole number (got "${reorderRaw}").`);
      } else reorderLevel = ro;
    }

    return {
      rowNumber: i + 2, // header is line 1
      sku,
      name,
      category: cell(2) || null,
      unit: cell(3) || 'pcs',
      cost: cost ?? 0,
      price: price ?? 0,
      quantity: qty ?? 0,
      reorderLevel,
      autoGenerateSku: sku.toUpperCase() === GENERATE_SKU,
      errors,
      warnings: [],
    };
  });

  return { rows, headerError: null };
}
