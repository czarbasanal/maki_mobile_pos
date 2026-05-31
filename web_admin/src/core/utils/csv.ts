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
