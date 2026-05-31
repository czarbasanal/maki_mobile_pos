import { decodeCostCode, type CostCode } from '../entities';

export interface ParsedRow {
  rowNumber: number; // 1-based, excludes the header
  name: string;
  category: string | null;
  code: string; // uppercased raw cost code
  cost: number; // decoded; 0 when the code is in error
  price: number;
  quantity: number;
  reorderLevel: number;
  unit: string;
  supplierName: string | null;
  errors: string[];
  warnings: string[];
}

export interface ParseResult {
  rows: ParsedRow[];
  headerError: string | null;
}

const COLUMN_ALIASES: Record<string, string[]> = {
  name: ['name'],
  category: ['category'],
  code: ['code', 'costcode'],
  price: ['price'],
  qty: ['qty', 'quantity'],
  unit: ['unit'],
  reorder: ['reorderlevel', 'reorder', 'reorderpoint'],
  supplier: ['supplier', 'suppliername'],
};
const REQUIRED_COLUMNS = ['name', 'price', 'code'] as const;

function norm(header: string): string {
  return header.toLowerCase().replace(/[^a-z0-9]/g, '');
}

function parseNumber(raw: string): number | null {
  const t = raw.trim().replace(/,/g, '');
  if (t === '') return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

export function parseImportRows(rows: string[][], cipher: CostCode): ParseResult {
  if (rows.length === 0) return { rows: [], headerError: 'The file is empty.' };

  const header = rows[0].map(norm);
  const indexOf: Record<string, number> = {};
  for (const [key, aliases] of Object.entries(COLUMN_ALIASES)) {
    indexOf[key] = header.findIndex((h) => aliases.includes(h));
  }
  const missing = REQUIRED_COLUMNS.filter((k) => indexOf[k] < 0);
  if (missing.length > 0) {
    return { rows: [], headerError: `Missing required column(s): ${missing.join(', ')}.` };
  }

  const cell = (r: string[], key: string): string => {
    const idx = indexOf[key];
    return idx >= 0 && idx < r.length ? r[idx].trim() : '';
  };

  const dataRows = rows.slice(1).filter((r) => r.some((c) => c.trim() !== ''));

  const parsed = dataRows.map((r, i): ParsedRow => {
    const errors: string[] = [];
    const warnings: string[] = [];

    const name = cell(r, 'name');
    if (name === '') errors.push('Name is required.');

    const priceRaw = cell(r, 'price');
    const priceNum = parseNumber(priceRaw);
    if (priceRaw === '') errors.push('Price is required.');
    else if (priceNum === null) errors.push(`Price "${priceRaw}" is not a number.`);
    else if (priceNum < 0) errors.push('Price cannot be negative.');

    const code = cell(r, 'code').toUpperCase();
    let cost = 0;
    if (code === '') {
      errors.push('Cost code is required.');
    } else {
      const decoded = decodeCostCode(cipher, code);
      if (decoded === null) errors.push(`Cost code "${code}" cannot be decoded.`);
      else cost = decoded;
    }

    const qtyRaw = cell(r, 'qty');
    let quantity = 0;
    if (qtyRaw !== '') {
      const q = parseNumber(qtyRaw);
      if (q === null || q < 0) errors.push(`Quantity "${qtyRaw}" is not a valid number.`);
      else quantity = q;
    }

    const reorderRaw = cell(r, 'reorder');
    let reorderLevel = 0;
    if (reorderRaw !== '') {
      const ro = parseNumber(reorderRaw);
      if (ro === null || ro < 0) errors.push(`Reorder level "${reorderRaw}" is not a valid number.`);
      else reorderLevel = ro;
    }

    return {
      rowNumber: i + 1,
      name,
      category: cell(r, 'category') || null,
      code,
      cost,
      price: priceNum ?? 0,
      quantity,
      reorderLevel,
      unit: cell(r, 'unit') || 'pcs',
      supplierName: cell(r, 'supplier') || null,
      errors,
      warnings,
    };
  });

  return { rows: parsed, headerError: null };
}
