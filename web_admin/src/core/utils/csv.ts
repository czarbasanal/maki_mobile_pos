// Dependency-free CSV: build the string, then download via Blob + anchor.

import {
  type Sale,
  saleGrandTotal,
  saleLaborSubtotal,
  salePartsSubtotal,
  saleTotalDiscount,
} from '../../domain/entities';

const SALE_HEADERS = [
  'saleNumber',
  'date',
  'items',
  'paymentMethod',
  'grossSales',
  'discount',
  'labor',
  'total',
  'cashier',
  'mechanic',
] as const;

/** Quotes a CSV cell when it contains a comma, quote, or newline (RFC 4180). */
function cell(value: string | number): string {
  const s = String(value ?? '');
  if (/[",\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

export function salesToCsv(sales: Sale[]): string {
  const rows = sales.map((s) =>
    [
      cell(s.saleNumber),
      cell(s.createdAt.toISOString()),
      cell(s.items.reduce((n, it) => n + it.quantity, 0)),
      cell(s.paymentMethod),
      cell(salePartsSubtotal(s)),
      cell(saleTotalDiscount(s)),
      cell(saleLaborSubtotal(s)),
      cell(saleGrandTotal(s)),
      cell(s.cashierName),
      cell(s.mechanicName ?? ''),
    ].join(','),
  );
  return [SALE_HEADERS.join(','), ...rows].join('\n');
}

export function downloadCsv(filename: string, content: string): void {
  const blob = new Blob([content], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

/**
 * Minimal RFC-4180 CSV parser. Handles quoted fields (commas/newlines inside
 * quotes), `""` escapes, CRLF or LF line endings, a leading BOM, and a trailing
 * newline. Returns a grid of raw string cells (no trimming, no header handling).
 */
export function parseCsv(text: string): string[][] {
  const s = text.charCodeAt(0) === 0xfeff ? text.slice(1) : text;
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let inQuotes = false;
  let i = 0;

  while (i < s.length) {
    const c = s[i];
    if (inQuotes) {
      if (c === '"') {
        if (s[i + 1] === '"') {
          field += '"';
          i += 2;
          continue;
        }
        inQuotes = false;
        i += 1;
        continue;
      }
      field += c;
      i += 1;
      continue;
    }
    if (c === '"') {
      inQuotes = true;
      i += 1;
    } else if (c === ',') {
      row.push(field);
      field = '';
      i += 1;
    } else if (c === '\r') {
      i += 1;
    } else if (c === '\n') {
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
      i += 1;
    } else {
      field += c;
      i += 1;
    }
  }
  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  return rows;
}
