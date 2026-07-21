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

// ==================== COST-CODE CIPHER ====================
// Port of lib/domain/entities/cost_code_entity.dart `encode` with the
// default mapping (CostCodeModel.defaultMapping — matches prod).

export const DIGIT_TO_LETTER = {
  1: 'N', 2: 'B', 3: 'Q', 4: 'M', 5: 'F',
  6: 'Z', 7: 'V', 8: 'L', 9: 'J', 0: 'S',
};
const DOUBLE_ZERO = 'SC';
const TRIPLE_ZERO = 'SCS';

export function encodeCostCode(cost) {
  const whole = Math.trunc(cost);
  if (whole <= 0) return DIGIT_TO_LETTER[0];
  const s = String(whole);
  let out = '';
  let i = 0;
  while (i < s.length) {
    const remaining = s.length - i;
    if (remaining >= 3 && s[i] === '0' && s[i + 1] === '0' && s[i + 2] === '0') {
      out += TRIPLE_ZERO;
      i += 3;
      continue;
    }
    if (remaining >= 2 && s[i] === '0' && s[i + 1] === '0') {
      out += DOUBLE_ZERO;
      i += 2;
      continue;
    }
    out += DIGIT_TO_LETTER[s[i]];
    i += 1;
  }
  return out;
}

// ==================== SKU GENERATION ====================
// Port of lib/core/utils/sku_generator.dart generateForName / the identical
// web port web_admin/src/domain/products/sku.ts.

export const SKU_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const SKU_PREFIX = 'SKU';
const SKU_RANDOM_LENGTH = 8;
const SKU_PREFIXED_RANDOM_LENGTH = 6;
const SKU_NAME_PREFIX_LENGTH = 10;

function randomString(length, rand) {
  let out = '';
  for (let i = 0; i < length; i += 1) {
    out += SKU_CHARS[Math.floor(rand() * SKU_CHARS.length)];
  }
  return out;
}

export function slugifyForSku(name) {
  return name.toUpperCase().replace(/[^A-Z0-9]/g, '');
}

export function generateSku(name, rand = Math.random) {
  const slug = slugifyForSku(name ?? '');
  if (slug.length === 0) return `${SKU_PREFIX}-${randomString(SKU_RANDOM_LENGTH, rand)}`;
  const first = slug[0];
  const rest = slug.slice(1).replace(/[AEIOU]/g, '');
  const base = first + rest;
  const prefix = base.length > SKU_NAME_PREFIX_LENGTH
    ? base.slice(0, SKU_NAME_PREFIX_LENGTH)
    : base;
  return `${prefix}-${randomString(SKU_PREFIXED_RANDOM_LENGTH, rand)}`;
}

/** MUST stay byte-identical to backfill-product-skus.mjs / Dart / web. */
export function normalizeSku(sku) {
  return String(sku ?? '').trim().toUpperCase();
}

// ==================== SEARCH KEYWORDS ====================
// Port of lib/core/extensions/string_extensions.dart toSearchKeywords and
// ProductModel._generateSearchKeywords / SupplierModel._generateSearchKeywords.

export function toSearchKeywords(str, { minLength = 1, maxLength = 10 } = {}) {
  const keywords = new Set();
  for (const word of String(str).toLowerCase().split(/\s+/)) {
    if (!word) continue;
    for (let i = minLength; i <= word.length && i <= maxLength; i += 1) {
      keywords.add(word.slice(0, i));
    }
  }
  return [...keywords];
}

export function productSearchKeywords({ sku, name, category }) {
  const keywords = new Set([
    ...toSearchKeywords(sku),
    ...toSearchKeywords(name),
    ...(category ? toSearchKeywords(category) : []),
  ]);
  return [...keywords];
}

export function supplierSearchKeywords(name) {
  return toSearchKeywords(name);
}
