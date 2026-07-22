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

// ==================== CORRECTIONS (user-verified 2026-07-21) ====================
// See docs/superpowers/specs/2026-07-21-initial-inventory-import-design.md §Decisions.
// Keyed by the EXACT trimmed NAME as it appears in the CSV (before renames).

export const COST_CORRECTIONS = {
  'CARBURETOR SUNTAL CT150BOXER': { costCode: 'ZLS', cost: 680 },
  'FOOTREST ASSY W/ STAND CSL TMX': { costCode: 'BFS', cost: 250 },
  'FRONT FENDER SMASH115 MATTE BLK': { costCode: 'MFS', cost: 450 },
  'HEADLIGHT RS100': { costCode: 'BQS', cost: 230 },
  'PISTON KIT M.DIALLO SMASH110': { costCode: 'NZS', cost: 160 },
  'PISTON KIT M.DIALLO SMASH115': { costCode: 'NZS', cost: 160 },
  'SPROCKET RR CNKY NIKOYO CT100 45T': { costCode: 'NZF', cost: 165 },
  'TAIL LIGHT COVER XRM110 BLK': { costCode: 'MS', cost: 40 },
};

export const NAME_CORRECTIONS = {
  'HEADLIGHT RS100': 'HEADLIGHT RS100 BLK',
};

export const CATEGORY_NORMALIZE = {
  'CHAIN & SPROCKET': 'CHAIN&SPROCKET',
};

// For merged double-listings the FIRST row's category wins unless overridden here.
export const MERGE_CATEGORY_OVERRIDES = {
  'SIGNAL LIGHT LENS W100 WHT': 'ACCESSORIES',
  'SIGNAL LIGHT LENS XRM ORG': 'ACCESSORIES',
};

// CSV unit -> the app's admin-managed `units` vocabulary (spec §12).
export const UNIT_MAP = { PC: 'pcs', SET: 'set', RULER: 'ruler', METER: 'm' };

// ==================== NAME MATCHING ====================

/** Word-order-insensitive key: 'ASK BRAKE SHOE XRM' ≡ 'BRAKE SHOE ASK XRM'. */
export function nameKey(name) {
  return String(name).trim().toUpperCase().split(/\s+/).filter(Boolean).sort().join(' ');
}

// ==================== TRANSFORM ====================

export function transform(records) {
  const report = {
    recordsTotal: records.length,
    skippedNoName: 0,
    errors: [],
    cipherMismatches: [],
    costCorrectionsApplied: [],
    nameCorrectionsApplied: [],
    categoryNormalized: 0,
    decimalQtyRounded: [],
    mergedDoubles: [],
    mergedBatches: [],
    variationPairs: [],
    supplierLinks: [],
    unmappedUnits: [],
  };

  const items = [];
  for (const [idx, rec] of records.entries()) {
    const line = idx + 2; // line 1 is the header
    const rawName = (rec.NAME ?? '').trim();
    if (!rawName) {
      report.skippedNoName += 1;
      continue;
    }
    const correction = COST_CORRECTIONS[rawName] ?? null;
    if (correction) report.costCorrectionsApplied.push(rawName);
    const rename = NAME_CORRECTIONS[rawName] ?? null;
    if (rename) report.nameCorrectionsApplied.push(`${rawName} -> ${rename}`);
    const name = rename ?? rawName;

    let category = (rec.CATEGORY ?? '').trim();
    if (CATEGORY_NORMALIZE[category]) {
      category = CATEGORY_NORMALIZE[category];
      report.categoryNormalized += 1;
    }

    const cost = correction ? correction.cost : parseMoney(rec['UNIT COST']);
    const costCode = correction ? correction.costCode : (rec.CODE ?? '').trim();
    const price = parseMoney(rec['SELLING PRICE']);
    const parsedQty = parseQty(rec.QTY);
    if (cost === null || price === null || parsedQty === null || !category) {
      report.errors.push({ line, name, reason: 'unparsable cost/price/qty or missing category' });
      continue;
    }
    if (parsedQty.original) {
      report.decimalQtyRounded.push(`${name}: ${parsedQty.original} -> ${parsedQty.qty}`);
    }
    if (encodeCostCode(cost) !== costCode) {
      report.cipherMismatches.push({ line, name, cost, costCode, expected: encodeCostCode(cost) });
    }
    const supplierRaw = (rec.SUPPLIER ?? '').trim();
    const rawUnit = (rec.UNIT ?? '').trim() || 'PC';
    const unit = UNIT_MAP[rawUnit] ?? rawUnit;
    if (!UNIT_MAP[rawUnit]) report.unmappedUnits.push(`${name}: ${rawUnit}`);
    items.push({
      name,
      category,
      costCode,
      cost,
      price,
      quantity: parsedQty.qty,
      reorderLevel: Number.parseInt(rec.REORDER_LEVEL, 10) || 0,
      unit,
      supplierCode: supplierRaw && supplierRaw !== 'NA' ? supplierRaw : null,
      notes: parsedQty.original ? `Imported qty rounded down from ${parsedQty.original}` : null,
    });
  }

  // Group by word-set name key and dispatch per the spec's dedup rules.
  const groups = new Map();
  for (const item of items) {
    const key = nameKey(item.name);
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(item);
  }

  const standalone = [];
  const pairs = [];
  for (const group of groups.values()) {
    if (group.length === 1) {
      standalone.push(group[0]);
      continue;
    }
    if (group.length > 2) {
      report.errors.push({ name: group[0].name, reason: `${group.length} rows share this name — resolve manually` });
      continue;
    }
    const [a, b] = group; // CSV order preserved by Map insertion order
    if (a.costCode !== b.costCode) {
      report.variationPairs.push(`${a.name} (${a.costCode} qty ${a.quantity} / ${b.costCode} qty ${b.quantity})`);
      pairs.push({ base: a, variation: b });
    } else if (a.quantity === b.quantity) {
      const merged = { ...a, category: MERGE_CATEGORY_OVERRIDES[a.name] ?? a.category };
      report.mergedDoubles.push(`${a.name} (qty kept ${a.quantity}, category ${merged.category})`);
      standalone.push(merged);
    } else {
      const merged = {
        ...a,
        quantity: a.quantity + b.quantity,
        price: Math.max(a.price, b.price),
        category: MERGE_CATEGORY_OVERRIDES[a.name] ?? a.category,
      };
      report.mergedBatches.push(`${a.name} (qty ${a.quantity}+${b.quantity}=${merged.quantity}, price ${merged.price})`);
      standalone.push(merged);
    }
  }

  const all = [...standalone, ...pairs.flatMap((p) => [p.base, p.variation])];
  for (const item of all) {
    if (item.supplierCode) report.supplierLinks.push(`${item.name} -> ${item.supplierCode}`);
  }
  const categories = [...new Set(all.map((i) => i.category))].sort();
  const units = [...new Set(all.map((i) => i.unit))].sort();
  report.expected = {
    products: all.length,
    standaloneOrBase: standalone.length + pairs.length,
    variations: pairs.length,
    categories: categories.length,
    inventoryValue: all.reduce((s, i) => s + i.cost * i.quantity, 0),
    retailValue: all.reduce((s, i) => s + i.price * i.quantity, 0),
  };
  return { standalone, pairs, categories, units, report };
}
