// Pure transform logic for the initial inventory import. No Firestore here —
// everything in this file is unit-testable with `npm test`.
//
// PARITY WARNING: normalizeSku / generateSku / encodeCostCode / toSearchKeywords
// are ports of the app's Dart (lib/core/utils/sku_generator.dart,
// lib/domain/entities/cost_code_entity.dart, string_extensions.dart) and the
// web TS (web_admin/src/domain/products/sku.ts). Keep byte-identical.

export const IMPORT_TAG = 'initial-inventory-import';
export const IMPORT_DISPLAY_NAME = 'Initial Import';

// ==================== CSV ====================

/** Minimal RFC-4180 parser: quotes, "" escapes, CRLF, BOM. */
export function parseCsv(text) {
  const src = text.startsWith('﻿') ? text.slice(1) : text;
  const rows = [];
  let field = '';
  let row = [];
  let inQuotes = false;
  for (let i = 0; i < src.length; i += 1) {
    const c = src[i];
    if (inQuotes) {
      if (c === '"') {
        if (src[i + 1] === '"') {
          field += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        field += c;
      }
    } else if (c === '"') {
      inQuotes = true;
    } else if (c === ',') {
      row.push(field);
      field = '';
    } else if (c === '\n') {
      row.push(field);
      field = '';
      rows.push(row);
      row = [];
    } else if (c !== '\r') {
      field += c;
    }
  }
  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  const [header, ...rest] = rows;
  const records = rest
    .filter((r) => r.some((cell) => cell.trim() !== ''))
    .map((r) => Object.fromEntries(header.map((h, idx) => [h, r[idx] ?? ''])));
  return { header, records };
}

// ==================== NUMBER PARSING ====================

export function parseMoney(value) {
  const cleaned = String(value ?? '').replace(/[₱,\s]/g, '');
  if (cleaned === '') return null;
  const n = Number(cleaned);
  return Number.isFinite(n) ? n : null;
}

export function parseQty(value) {
  const n = parseMoney(value);
  if (n === null || n < 0) return null;
  const qty = Math.floor(n);
  return { qty, original: qty === n ? null : String(value).trim() };
}
