# Web Admin — Bulk Product Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An admin CSV-import tool for products — upload → validate + decode cost + classify → per-row insert/update/skip preview → chunked batch write — plus the product write path it depends on (`create`/`update`/`bulkImport`).

**Architecture:** Client-side, like the dashboard and reports. Pure logic (parse → validate → classify) lives in small unit-tested modules; the page loads existing products/suppliers/cost-code, runs the transforms, and writes back via the repository. CSV is parsed by a small hand-rolled RFC-4180 parser added to the existing dependency-free `csv.ts` (no new npm dependency).

**Tech Stack:** Vite + React 18 + TS + Firebase Web SDK + React Query + Tailwind; Vitest (node env for logic). All commands run from `web_admin/`.

**Spec:** docs/superpowers/specs/2026-06-01-web-admin-bulk-product-import-design.md

**Conventions (carry from Specs 1–2):**
- Unit-tested modules + their transitive imports must use **relative imports** (`../entities`), NOT the `@/` alias — vitest does not resolve `@/`. Presentation-only code (hooks/pages/components, untested) uses `@/`.
- Run logic tests with `--environment=node` (jsdom cold-start is ~300s here).
- Typecheck with `npx tsc --noEmit -p tsconfig.json` (NOT `npm run typecheck`, which is broken). `npm run build` works.
- No jsdom component tests; verify UI via `tsc` + `build` + manual.

---

### Task 1: Add `createdByName` / `updatedByName` to the Product model

**Files:**
- Modify: `web_admin/src/domain/entities/Product.ts`
- Modify: `web_admin/src/data/converters/productConverter.ts`

Mirrors Flutter's `product_model` denormalized audit names so web-created products show a human name to non-admins. No unit test (trivial converter passthrough); verified by typecheck — and a downstream `classifyRows` test (Task 6) exercises the field via `toCreateInput`.

- [ ] **Step 1: Add the two fields to the entity** — in `web_admin/src/domain/entities/Product.ts`, add after `updatedBy: string | null;` (line 18):
```ts
  createdByName: string | null;
  updatedByName: string | null;
```

- [ ] **Step 2: Read them in the converter** — in `web_admin/src/data/converters/productConverter.ts` `fromFirestore`, add after the `updatedBy` line:
```ts
      createdByName: d.createdByName ?? null,
      updatedByName: d.updatedByName ?? null,
```

- [ ] **Step 3: Write them in the converter** — in the same file's `toFirestore`, add after `updatedBy: product.updatedBy,`:
```ts
      createdByName: product.createdByName,
      updatedByName: product.updatedByName,
```

- [ ] **Step 4: Typecheck** — `npx tsc --noEmit -p tsconfig.json`. Expected: no errors. (This widens `ProductCreateInput` to require the two fields; only the new importer code constructs that type, landing in later tasks — the repo `create` stub takes no args today, so nothing else breaks.)

- [ ] **Step 5: Commit**
```bash
git add src/domain/entities/Product.ts src/data/converters/productConverter.ts
git commit -m "feat(web-admin): add createdByName/updatedByName to Product (Flutter parity)"
```

---

### Task 2: `parseCsv` (RFC-4180)

**Files:**
- Modify: `web_admin/src/core/utils/csv.ts`
- Modify (test): `web_admin/src/core/utils/csv.test.ts`

- [ ] **Step 1: Write the failing tests** — append to `web_admin/src/core/utils/csv.test.ts`:
```ts
import { parseCsv } from './csv';

describe('parseCsv', () => {
  it('parses simple rows', () => {
    expect(parseCsv('a,b,c\n1,2,3')).toEqual([
      ['a', 'b', 'c'],
      ['1', '2', '3'],
    ]);
  });

  it('keeps commas inside quoted fields', () => {
    expect(parseCsv('name,note\n"Smith, J",ok')).toEqual([
      ['name', 'note'],
      ['Smith, J', 'ok'],
    ]);
  });

  it('keeps newlines inside quoted fields', () => {
    expect(parseCsv('a\n"x\ny"')).toEqual([['a'], ['x\ny']]);
  });

  it('unescapes doubled quotes', () => {
    expect(parseCsv('a\n"He said ""hi"""')).toEqual([['a'], ['He said "hi"']]);
  });

  it('handles CRLF and a trailing newline', () => {
    expect(parseCsv('a,b\r\n1,2\r\n')).toEqual([
      ['a', 'b'],
      ['1', '2'],
    ]);
  });

  it('strips a leading BOM', () => {
    expect(parseCsv('﻿a\n1')).toEqual([['a'], ['1']]);
  });

  it('returns [] for empty input', () => {
    expect(parseCsv('')).toEqual([]);
  });
});
```

- [ ] **Step 2: Run, expect FAIL** — `npx vitest run src/core/utils/csv.test.ts --environment=node`. Expected: `parseCsv` is not exported.

- [ ] **Step 3: Implement** — append to `web_admin/src/core/utils/csv.ts`:
```ts
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
```

- [ ] **Step 4: Run, expect PASS** — `npx vitest run src/core/utils/csv.test.ts --environment=node`.

- [ ] **Step 5: Commit**
```bash
git add src/core/utils/csv.ts src/core/utils/csv.test.ts
git commit -m "feat(web-admin): parseCsv (dependency-free RFC-4180 parser)"
```

---

### Task 3: `generateSku`

**Files:**
- Create: `web_admin/src/domain/products/sku.ts`
- Test: `web_admin/src/domain/products/sku.test.ts`

Port of Flutter `SkuGenerator.generateForName` (constants: prefix `SKU`, name-prefix length 10, name-random 6, fallback-random 8; Code128-safe alphabet).

- [ ] **Step 1: Write the failing test** — create `web_admin/src/domain/products/sku.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { generateSku, slugifyForSku } from './sku';

// rand() => 0 makes the random suffix all 'A' (alphabet[0]).
const zero = () => 0;

describe('slugifyForSku', () => {
  it('uppercases and strips non-alphanumerics', () => {
    expect(slugifyForSku('Milk Chocolate 500g!')).toBe('MILKCHOCOLATE500G');
  });
});

describe('generateSku', () => {
  it('keeps the first letter, drops later vowels, caps at 10, adds a 6-char suffix', () => {
    expect(generateSku('Milk Chocolate 500g Box', zero)).toBe('MLKCHCLT50-AAAAAA');
  });

  it('keeps a leading vowel so short names stay recognisable', () => {
    expect(generateSku('Ice', zero)).toBe('IC-AAAAAA');
  });

  it('falls back to the SKU- prefix + 8-char suffix when the name has no usable chars', () => {
    expect(generateSku('!!!', zero)).toBe('SKU-AAAAAAAA');
  });
});
```

- [ ] **Step 2: Run, expect FAIL** — `npx vitest run src/domain/products/sku.test.ts --environment=node`. Expected: module not found.

- [ ] **Step 3: Implement** — create `web_admin/src/domain/products/sku.ts`:
```ts
// Port of lib/core/utils/sku_generator.dart `generateForName`. Ambiguous
// characters (0/O, 1/I/L) are excluded so SKUs stay scanner-friendly.
const SKU_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const SKU_PREFIX = 'SKU';
const SKU_RANDOM_LENGTH = 8;
const SKU_PREFIXED_RANDOM_LENGTH = 6;
const SKU_NAME_PREFIX_LENGTH = 10;

function randomString(length: number, rand: () => number): string {
  let out = '';
  for (let i = 0; i < length; i += 1) {
    out += SKU_CHARS[Math.floor(rand() * SKU_CHARS.length)];
  }
  return out;
}

export function slugifyForSku(name: string): string {
  return name.toUpperCase().replace(/[^A-Z0-9]/g, '');
}

/** `rand` is injectable so tests are deterministic. */
export function generateSku(name: string, rand: () => number = Math.random): string {
  const slug = slugifyForSku(name);
  if (slug.length === 0) {
    return `${SKU_PREFIX}-${randomString(SKU_RANDOM_LENGTH, rand)}`;
  }
  const first = slug[0];
  const rest = slug.slice(1).replace(/[AEIOU]/g, '');
  const base = first + rest;
  const prefix =
    base.length > SKU_NAME_PREFIX_LENGTH ? base.slice(0, SKU_NAME_PREFIX_LENGTH) : base;
  return `${prefix}-${randomString(SKU_PREFIXED_RANDOM_LENGTH, rand)}`;
}
```

- [ ] **Step 4: Run, expect PASS** — `npx vitest run src/domain/products/sku.test.ts --environment=node`.

- [ ] **Step 5: Commit**
```bash
git add src/domain/products/sku.ts src/domain/products/sku.test.ts
git commit -m "feat(web-admin): generateSku (port of SkuGenerator.generateForName)"
```

---

### Task 4: `generateSearchKeywords`

**Files:**
- Create: `web_admin/src/domain/products/searchKeywords.ts`
- Test: `web_admin/src/domain/products/searchKeywords.test.ts`

Port of Flutter `String.toSearchKeywords` + `_generateSearchKeywords` (prefix tokens of each word, length 1..10, lowercased, deduped across parts).

- [ ] **Step 1: Write the failing test** — create `web_admin/src/domain/products/searchKeywords.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { generateSearchKeywords, toSearchKeywords } from './searchKeywords';

describe('toSearchKeywords', () => {
  it('emits the length-1..n prefixes of each word, lowercased', () => {
    expect(toSearchKeywords('Hi World')).toEqual([
      'h', 'hi', 'w', 'wo', 'wor', 'worl', 'world',
    ]);
  });
});

describe('generateSearchKeywords', () => {
  it('unions prefixes across parts, skips null/empty, dedupes', () => {
    expect(generateSearchKeywords(['ab', null, 'ab cd', '']).sort()).toEqual(
      ['a', 'ab', 'c', 'cd'].sort(),
    );
  });
});
```

- [ ] **Step 2: Run, expect FAIL** — `npx vitest run src/domain/products/searchKeywords.test.ts --environment=node`.

- [ ] **Step 3: Implement** — create `web_admin/src/domain/products/searchKeywords.ts`:
```ts
// Port of lib/core/extensions/string_extensions.dart `toSearchKeywords` and
// product_model `_generateSearchKeywords`. Mobile search uses an
// arrayContainsAny query over this list, so web-created products must tokenize
// identically to be findable.
export function toSearchKeywords(value: string, minLength = 1, maxLength = 10): string[] {
  const out = new Set<string>();
  for (const word of value.toLowerCase().split(/\s+/)) {
    if (word.length === 0) continue;
    for (let i = minLength; i <= word.length && i <= maxLength; i += 1) {
      out.add(word.slice(0, i));
    }
  }
  return [...out];
}

export function generateSearchKeywords(parts: (string | null | undefined)[]): string[] {
  const out = new Set<string>();
  for (const part of parts) {
    if (!part) continue;
    for (const kw of toSearchKeywords(part)) out.add(kw);
  }
  return [...out];
}
```

- [ ] **Step 4: Run, expect PASS** — `npx vitest run src/domain/products/searchKeywords.test.ts --environment=node`.

- [ ] **Step 5: Commit**
```bash
git add src/domain/products/searchKeywords.ts src/domain/products/searchKeywords.test.ts
git commit -m "feat(web-admin): generateSearchKeywords (mobile-search parity)"
```

---

### Task 5: `parseImportRows`

**Files:**
- Create: `web_admin/src/domain/products/importRows.ts`
- Test: `web_admin/src/domain/products/importRows.test.ts`

Maps CSV headers (case-insensitive, aliases), validates required `name`/`price`/`code`, parses numbers (commas stripped), decodes cost via the active cipher (uppercasing the code first, since `decodeCostCode` is case-sensitive), applies defaults.

- [ ] **Step 1: Write the failing test** — create `web_admin/src/domain/products/importRows.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { defaultCostCode } from '../entities';
import { parseImportRows } from './importRows';

// Default cipher: 1→N 2→B 5→F, so "NBF" decodes to 125.
const cipher = defaultCostCode;
const HEADER = ['name', 'category', 'code', 'price', 'qty', 'unit', 'reorder_level', 'supplier'];

function grid(...dataRows: string[][]) {
  return [HEADER, ...dataRows];
}

describe('parseImportRows', () => {
  it('decodes cost, parses numbers (commas stripped), applies defaults', () => {
    const { rows, headerError } = parseImportRows(
      grid(['Spark Plug', 'Engine', 'NBF', '1,250', '4', '', '2', 'Acme']),
      cipher,
    );
    expect(headerError).toBeNull();
    expect(rows[0]).toMatchObject({
      rowNumber: 1,
      name: 'Spark Plug',
      category: 'Engine',
      code: 'NBF',
      cost: 125,
      price: 1250,
      quantity: 4,
      reorderLevel: 2,
      unit: 'pcs', // blank -> default
      supplierName: 'Acme',
      errors: [],
    });
  });

  it('rejects the file when a required header is missing', () => {
    const r = parseImportRows([['name', 'price'], ['X', '5']], cipher);
    expect(r.rows).toEqual([]);
    expect(r.headerError).toContain('code');
  });

  it('errors a row with a blank name, bad price, or blank/undecodable code', () => {
    const { rows } = parseImportRows(
      grid(
        ['', 'c', 'NBF', '10', '', '', '', ''], // blank name
        ['A', 'c', 'NBF', 'abc', '', '', '', ''], // bad price
        ['B', 'c', '', '10', '', '', '', ''], // blank code
        ['C', 'c', 'NX', '10', '', '', '', ''], // undecodable code (X unknown)
      ),
      cipher,
    );
    expect(rows[0].errors[0]).toMatch(/name/i);
    expect(rows[1].errors[0]).toMatch(/price/i);
    expect(rows[2].errors[0]).toMatch(/cost code is required/i);
    expect(rows[3].errors[0]).toMatch(/cannot be decoded/i);
  });

  it('matches headers case-insensitively with aliases and skips blank lines', () => {
    const { rows } = parseImportRows(
      [
        ['Name', 'Code', 'Price', 'Quantity', 'ReorderLevel'],
        ['Widget', 'NBF', '50', '3', '1'],
        ['', '', '', '', ''], // blank -> skipped
      ],
      cipher,
    );
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ name: 'Widget', cost: 125, quantity: 3, reorderLevel: 1 });
  });

  it('lowercases code? no — uppercases it before decoding', () => {
    const { rows } = parseImportRows(grid(['A', '', 'nbf', '10', '', '', '', '']), cipher);
    expect(rows[0].code).toBe('NBF');
    expect(rows[0].cost).toBe(125);
  });
});
```

- [ ] **Step 2: Run, expect FAIL** — `npx vitest run src/domain/products/importRows.test.ts --environment=node`.

- [ ] **Step 3: Implement** — create `web_admin/src/domain/products/importRows.ts`:
```ts
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
```

- [ ] **Step 4: Run, expect PASS** — `npx vitest run src/domain/products/importRows.test.ts --environment=node`.

- [ ] **Step 5: Commit**
```bash
git add src/domain/products/importRows.ts src/domain/products/importRows.test.ts
git commit -m "feat(web-admin): parseImportRows (header map + validate + decode cost)"
```

---

### Task 6: `classifyRows` + `toCreateInput` / `toUpdateInput`

**Files:**
- Create: `web_admin/src/domain/products/classifyRows.ts`
- Test: `web_admin/src/domain/products/classifyRows.test.ts`

Classifies each parsed row (new / existing / error) by a `name|category` index, resolves supplier by name, sets the default action, and builds the repository inputs. Update inputs deliberately exclude `name` and `category` (both are the match key, identical by definition) so search keywords never drift.

- [ ] **Step 1: Write the failing test** — create `web_admin/src/domain/products/classifyRows.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import type { Product, Supplier } from '../entities';
import type { ParsedRow } from './importRows';
import { classifyRows, toCreateInput, toUpdateInput } from './classifyRows';

function parsed(over: Partial<ParsedRow> = {}): ParsedRow {
  return {
    rowNumber: 1,
    name: 'Spark Plug',
    category: 'Engine',
    code: 'NBF',
    cost: 125,
    price: 200,
    quantity: 5,
    reorderLevel: 1,
    unit: 'pcs',
    supplierName: 'Acme',
    errors: [],
    warnings: [],
    ...over,
  };
}

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: 'SP-1', name: 'Spark Plug', costCode: 'NBF', cost: 125, price: 200,
    quantity: 0, reorderLevel: 0, unit: 'pcs', supplierId: null, supplierName: null,
    isActive: true, createdAt: new Date(), updatedAt: null, createdBy: null, updatedBy: null,
    createdByName: null, updatedByName: null, searchKeywords: [], baseSku: null,
    variationNumber: null, barcode: null, category: 'Engine', imageUrl: null, notes: null,
    ...over,
  };
}

const supplier: Supplier = {
  id: 'sup1', name: 'Acme', address: null, contactPerson: null, contactNumber: null,
  alternativeNumber: null, email: null, transactionType: 'cash' as Supplier['transactionType'],
  isActive: true, notes: null, createdAt: new Date(), updatedAt: null, createdBy: null,
  updatedBy: null, productCount: 0, totalInventoryValue: 0,
};

const actor = { id: 'u1', name: 'Admin Jane' };

describe('classifyRows', () => {
  it('marks a name+category match as existing/update and resolves the supplier', () => {
    const [row] = classifyRows([parsed()], [product()], [supplier]);
    expect(row.status).toBe('existing');
    expect(row.matchedProductId).toBe('p1');
    expect(row.defaultAction).toBe('update');
    expect(row.supplierId).toBe('sup1');
    expect(row.supplierMatched).toBe(true);
  });

  it('marks an unmatched row as new/insert', () => {
    const [row] = classifyRows([parsed({ name: 'New Item' })], [product()], [supplier]);
    expect(row.status).toBe('new');
    expect(row.defaultAction).toBe('insert');
  });

  it('marks an error row as error/skip', () => {
    const [row] = classifyRows([parsed({ errors: ['Name is required.'] })], [], []);
    expect(row.status).toBe('error');
    expect(row.defaultAction).toBe('skip');
  });

  it('warns and keeps the name when the supplier is unknown', () => {
    const [row] = classifyRows([parsed({ supplierName: 'Ghost' })], [], []);
    expect(row.supplierId).toBeNull();
    expect(row.supplierMatched).toBe(false);
    expect(row.parsed.warnings.join(' ')).toMatch(/not found/i);
  });

  it('warns when multiple existing products share the name+category', () => {
    const [row] = classifyRows(
      [parsed()],
      [product({ id: 'p1' }), product({ id: 'p2' })],
      [],
    );
    expect(row.matchedProductId).toBe('p1');
    expect(row.parsed.warnings.join(' ')).toMatch(/match/i);
  });
});

describe('toCreateInput / toUpdateInput', () => {
  it('builds a full create input with generated sku + keywords + actor names', () => {
    const [row] = classifyRows([parsed({ name: 'New Item' })], [], [supplier]);
    const input = toCreateInput(row, actor);
    expect(input).toMatchObject({
      name: 'New Item', costCode: 'NBF', cost: 125, price: 200, quantity: 5,
      reorderLevel: 1, unit: 'pcs', supplierId: 'sup1', supplierName: 'Acme',
      isActive: true, createdBy: 'u1', updatedBy: 'u1',
      createdByName: 'Admin Jane', updatedByName: 'Admin Jane',
      baseSku: null, variationNumber: null, barcode: null, category: 'Engine',
    });
    expect(input.sku.length).toBeGreaterThan(0);
    expect(input.searchKeywords).toEqual(expect.arrayContaining(['new', 'item']));
  });

  it('builds an update input with value fields only (no name/category)', () => {
    const [row] = classifyRows([parsed()], [product()], [supplier]);
    const input = toUpdateInput(row, actor);
    expect(input).toMatchObject({
      costCode: 'NBF', cost: 125, price: 200, quantity: 5, reorderLevel: 1,
      unit: 'pcs', supplierId: 'sup1', supplierName: 'Acme',
      updatedBy: 'u1', updatedByName: 'Admin Jane',
    });
    expect('name' in input).toBe(false);
    expect('category' in input).toBe(false);
  });
});
```

- [ ] **Step 2: Run, expect FAIL** — `npx vitest run src/domain/products/classifyRows.test.ts --environment=node`.

- [ ] **Step 3: Implement** — create `web_admin/src/domain/products/classifyRows.ts`:
```ts
import type { Product, Supplier } from '../entities';
import type {
  ProductCreateInput,
  ProductUpdateInput,
} from '../repositories/ProductRepository';
import { generateSku } from './sku';
import { generateSearchKeywords } from './searchKeywords';
import type { ParsedRow } from './importRows';

export type RowStatus = 'new' | 'existing' | 'error';
export type RowAction = 'insert' | 'update' | 'skip';

export interface ClassifiedRow {
  parsed: ParsedRow;
  status: RowStatus;
  matchedProductId: string | null;
  supplierId: string | null;
  supplierMatched: boolean;
  defaultAction: RowAction;
}

function productKey(name: string, category: string | null): string {
  return `${name.trim().toLowerCase()}|${(category ?? '').trim().toLowerCase()}`;
}

export function classifyRows(
  parsed: ParsedRow[],
  existing: Product[],
  suppliers: Supplier[],
): ClassifiedRow[] {
  const productIndex = new Map<string, Product[]>();
  for (const p of existing) {
    const key = productKey(p.name, p.category);
    const list = productIndex.get(key);
    if (list) list.push(p);
    else productIndex.set(key, [p]);
  }
  const supplierIndex = new Map<string, Supplier>();
  for (const s of suppliers) supplierIndex.set(s.name.trim().toLowerCase(), s);

  return parsed.map((row): ClassifiedRow => {
    let supplierId: string | null = null;
    let supplierMatched = false;
    if (row.supplierName) {
      const s = supplierIndex.get(row.supplierName.trim().toLowerCase());
      if (s) {
        supplierId = s.id;
        supplierMatched = true;
      } else {
        row.warnings.push(`Supplier "${row.supplierName}" not found — keeping the name only.`);
      }
    }

    if (row.errors.length > 0) {
      return { parsed: row, status: 'error', matchedProductId: null, supplierId, supplierMatched, defaultAction: 'skip' };
    }

    const matches = productIndex.get(productKey(row.name, row.category)) ?? [];
    if (matches.length > 0) {
      if (matches.length > 1) {
        row.warnings.push(
          `${matches.length} existing products match this name + category; the first will be updated.`,
        );
      }
      return { parsed: row, status: 'existing', matchedProductId: matches[0].id, supplierId, supplierMatched, defaultAction: 'update' };
    }
    return { parsed: row, status: 'new', matchedProductId: null, supplierId, supplierMatched, defaultAction: 'insert' };
  });
}

export function toCreateInput(
  row: ClassifiedRow,
  actor: { id: string; name: string },
): ProductCreateInput {
  const sku = generateSku(row.parsed.name);
  return {
    sku,
    name: row.parsed.name,
    costCode: row.parsed.code,
    cost: row.parsed.cost,
    price: row.parsed.price,
    quantity: row.parsed.quantity,
    reorderLevel: row.parsed.reorderLevel,
    unit: row.parsed.unit,
    supplierId: row.supplierId,
    supplierName: row.parsed.supplierName,
    isActive: true,
    createdBy: actor.id,
    updatedBy: actor.id,
    createdByName: actor.name,
    updatedByName: actor.name,
    searchKeywords: generateSearchKeywords([sku, row.parsed.name, row.parsed.category]),
    baseSku: null,
    variationNumber: null,
    barcode: null,
    category: row.parsed.category,
    imageUrl: null,
    notes: null,
  };
}

export function toUpdateInput(
  row: ClassifiedRow,
  actor: { id: string; name: string },
): ProductUpdateInput {
  return {
    costCode: row.parsed.code,
    cost: row.parsed.cost,
    price: row.parsed.price,
    quantity: row.parsed.quantity,
    reorderLevel: row.parsed.reorderLevel,
    unit: row.parsed.unit,
    supplierId: row.supplierId,
    supplierName: row.parsed.supplierName,
    updatedBy: actor.id,
    updatedByName: actor.name,
  };
}
```

- [ ] **Step 4: Run, expect PASS** — `npx vitest run src/domain/products/classifyRows.test.ts --environment=node`.

- [ ] **Step 5: Commit**
```bash
git add src/domain/products/classifyRows.ts src/domain/products/classifyRows.test.ts
git commit -m "feat(web-admin): classifyRows + toCreateInput/toUpdateInput"
```

---

### Task 7: Add `bulkImport` to the ProductRepository interface

**Files:**
- Modify: `web_admin/src/domain/repositories/ProductRepository.ts`

- [ ] **Step 1: Add the types + method** — in `web_admin/src/domain/repositories/ProductRepository.ts`, add after the `ProductUpdateInput` interface (line 12):
```ts
export type ProductImportOp =
  | { kind: 'insert'; row: number; input: ProductCreateInput }
  | { kind: 'update'; row: number; id: string; input: ProductUpdateInput };

export interface ProductImportResult {
  inserted: number;
  updated: number;
  failed: { row: number; message: string }[];
}
```
and add this line inside the `ProductRepository` interface, right after the `update(...)` method:
```ts
  bulkImport(ops: ProductImportOp[], actorId: string): Promise<ProductImportResult>;
```

- [ ] **Step 2: Typecheck** — `npx tsc --noEmit -p tsconfig.json`. Expected: ONE error — `FirestoreProductRepository` no longer satisfies `ProductRepository` (missing `bulkImport`). That is fixed in Task 8; proceed.

- [ ] **Step 3: Commit**
```bash
git add src/domain/repositories/ProductRepository.ts
git commit -m "feat(web-admin): add ProductRepository.bulkImport contract"
```

---

### Task 8: Implement `create` / `update` / `bulkImport` in FirestoreProductRepository

**Files:**
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts`

Mirrors the suppliers `create()` pattern (`addDoc` + `serverTimestamp`). No unit test (Firestore); verified by typecheck + build + manual.

- [ ] **Step 1: Extend the firestore import** — replace the import block at the top of `web_admin/src/data/repositories/FirestoreProductRepository.ts` (lines 4–14) with:
```ts
import {
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  where,
  writeBatch,
  type Firestore,
} from 'firebase/firestore';
```

- [ ] **Step 2: Import the helpers + types** — add after the `productConverter` import (line 19):
```ts
import { generateSearchKeywords } from '@/domain/products/searchKeywords';
import type {
  ProductCreateInput,
  ProductImportOp,
  ProductImportResult,
  ProductUpdateInput,
} from '@/domain/repositories/ProductRepository';
```

- [ ] **Step 3: Replace the stubbed `create` and `update`** — find these two stub methods (leave the other phase-7 stubs `adjustStock`/`setStock`/`deactivate`/`recordPriceChange`/`listPriceHistory` untouched):
```ts
  async create(): Promise<Product> {
    throw new Error('ProductRepository.create not implemented yet (phase 7)');
  }
  async update(): Promise<void> {
    throw new Error('ProductRepository.update not implemented yet (phase 7)');
  }
```
and replace them with:
```ts
  async create(input: ProductCreateInput, actorId: string): Promise<Product> {
    const ref = await addDoc(
      collection(this.db, FirestoreCollections.products),
      this.createData(input, actorId),
    );
    const created = await this.getById(ref.id);
    if (!created) throw new Error('Failed to load the created product');
    return created;
  }

  async update(id: string, input: ProductUpdateInput, actorId: string): Promise<void> {
    await updateDoc(
      doc(this.db, FirestoreCollections.products, id),
      this.updateData(input, actorId),
    );
  }

  async bulkImport(ops: ProductImportOp[], actorId: string): Promise<ProductImportResult> {
    const result: ProductImportResult = { inserted: 0, updated: 0, failed: [] };
    const productsCol = collection(this.db, FirestoreCollections.products);
    for (let start = 0; start < ops.length; start += 500) {
      const chunk = ops.slice(start, start + 500);
      const batch = writeBatch(this.db);
      for (const op of chunk) {
        if (op.kind === 'insert') {
          batch.set(doc(productsCol), this.createData(op.input, actorId));
        } else {
          batch.update(
            doc(this.db, FirestoreCollections.products, op.id),
            this.updateData(op.input, actorId),
          );
        }
      }
      try {
        await batch.commit();
        for (const op of chunk) {
          if (op.kind === 'insert') result.inserted += 1;
          else result.updated += 1;
        }
      } catch (e) {
        for (const op of chunk) {
          result.failed.push({ row: op.row, message: (e as Error).message });
        }
      }
    }
    return result;
  }

  private createData(input: ProductCreateInput, actorId: string) {
    const searchKeywords =
      input.searchKeywords ??
      generateSearchKeywords([input.sku, input.name, input.category]);
    return {
      sku: input.sku,
      name: input.name,
      costCode: input.costCode,
      cost: input.cost,
      price: input.price,
      quantity: input.quantity,
      reorderLevel: input.reorderLevel,
      unit: input.unit,
      supplierId: input.supplierId,
      supplierName: input.supplierName,
      isActive: input.isActive,
      createdBy: actorId,
      updatedBy: actorId,
      createdByName: input.createdByName,
      // Mirror createdByName onto updatedByName at create, like Flutter.
      updatedByName: input.createdByName,
      searchKeywords,
      baseSku: input.baseSku,
      variationNumber: input.variationNumber,
      barcode: input.barcode,
      category: input.category,
      imageUrl: input.imageUrl,
      notes: input.notes,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };
  }

  private updateData(input: ProductUpdateInput, actorId: string) {
    const data: Record<string, unknown> = {
      updatedBy: actorId,
      updatedAt: serverTimestamp(),
    };
    const valueFields = [
      'sku', 'name', 'costCode', 'cost', 'price', 'quantity', 'reorderLevel',
      'unit', 'supplierId', 'supplierName', 'isActive', 'baseSku',
      'variationNumber', 'barcode', 'category', 'imageUrl', 'notes', 'updatedByName',
    ] as const;
    for (const key of valueFields) {
      if (input[key] !== undefined) data[key] = input[key];
    }
    // Keywords only need rebuilding if the name changes (import never does this;
    // a future inventory edit might).
    if (input.name !== undefined) {
      data.searchKeywords = generateSearchKeywords([
        input.sku ?? input.name,
        input.name,
        input.category ?? null,
      ]);
    }
    return data;
  }
```

- [ ] **Step 4: Typecheck** — `npx tsc --noEmit -p tsconfig.json`. Expected: no errors (the Task 7 error is now resolved).

- [ ] **Step 5: Commit**
```bash
git add src/data/repositories/FirestoreProductRepository.ts
git commit -m "feat(web-admin): implement product create/update/bulkImport (writeBatch)"
```

---

### Task 9: `useProductImport` hook

**Files:**
- Create: `web_admin/src/presentation/features/import/useProductImport.ts`

Presentation-layer (not unit-tested) → `@/` imports are fine.

- [ ] **Step 1: Implement** — create `web_admin/src/presentation/features/import/useProductImport.ts`:
```ts
import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useProductRepo, useSupplierRepo } from '@/infrastructure/di/container';
import { useCostCode } from '@/presentation/hooks/useCostCode';
import { useAuthStore } from '@/presentation/stores/authStore';
import { parseCsv } from '@/core/utils/csv';
import { parseImportRows } from '@/domain/products/importRows';
import {
  classifyRows,
  toCreateInput,
  toUpdateInput,
  type ClassifiedRow,
  type RowAction,
} from '@/domain/products/classifyRows';
import type {
  ProductImportOp,
  ProductImportResult,
} from '@/domain/repositories/ProductRepository';

interface ImportState {
  rows: ClassifiedRow[];
  actions: Record<number, RowAction>;
  headerError: string | null;
}

export function useProductImport() {
  const productRepo = useProductRepo();
  const supplierRepo = useSupplierRepo();
  const { data: costCode } = useCostCode();
  const user = useAuthStore((s) => s.user);

  const productsQuery = useQuery({
    queryKey: ['products', 'all'],
    queryFn: () => productRepo.list(),
  });
  const suppliersQuery = useQuery({
    queryKey: ['suppliers', 'all'],
    queryFn: () => supplierRepo.list(),
  });

  const [state, setState] = useState<ImportState | null>(null);
  const [parseError, setParseError] = useState<string | null>(null);
  const [result, setResult] = useState<ProductImportResult | null>(null);
  const [isImporting, setIsImporting] = useState(false);

  const ready = !!costCode && !!productsQuery.data && !!suppliersQuery.data;

  async function parseFile(file: File) {
    setParseError(null);
    setResult(null);
    if (!ready || !costCode) {
      setParseError('Still loading reference data — try again in a moment.');
      return;
    }
    let text: string;
    try {
      text = await file.text();
    } catch {
      setParseError('Could not read the file.');
      return;
    }
    let parsed;
    try {
      parsed = parseImportRows(parseCsv(text), costCode);
    } catch (e) {
      setParseError(`Could not parse the CSV: ${(e as Error).message}`);
      return;
    }
    if (parsed.headerError) {
      setState({ rows: [], actions: {}, headerError: parsed.headerError });
      return;
    }
    const rows = classifyRows(parsed.rows, productsQuery.data!, suppliersQuery.data!);
    const actions: Record<number, RowAction> = {};
    for (const r of rows) actions[r.parsed.rowNumber] = r.defaultAction;
    setState({ rows, actions, headerError: null });
  }

  function setAction(rowNumber: number, action: RowAction) {
    setState((prev) =>
      prev ? { ...prev, actions: { ...prev.actions, [rowNumber]: action } } : prev,
    );
  }

  function reset() {
    setState(null);
    setParseError(null);
    setResult(null);
  }

  const summary = useMemo(() => {
    const rows = state?.rows ?? [];
    let insert = 0;
    let update = 0;
    let skip = 0;
    for (const r of rows) {
      const a = state?.actions[r.parsed.rowNumber] ?? r.defaultAction;
      if (a === 'insert') insert += 1;
      else if (a === 'update') update += 1;
      else skip += 1;
    }
    return {
      total: rows.length,
      insert,
      update,
      skip,
      errors: rows.filter((r) => r.status === 'error').length,
    };
  }, [state]);

  async function runImport() {
    if (!state || !user) return;
    const actor = { id: user.id, name: user.displayName };
    const ops: ProductImportOp[] = [];
    for (const r of state.rows) {
      const action = state.actions[r.parsed.rowNumber] ?? r.defaultAction;
      if (action === 'insert') {
        ops.push({ kind: 'insert', row: r.parsed.rowNumber, input: toCreateInput(r, actor) });
      } else if (action === 'update' && r.matchedProductId) {
        ops.push({
          kind: 'update',
          row: r.parsed.rowNumber,
          id: r.matchedProductId,
          input: toUpdateInput(r, actor),
        });
      }
    }
    setIsImporting(true);
    try {
      setResult(await productRepo.bulkImport(ops, actor.id));
    } finally {
      setIsImporting(false);
    }
  }

  return {
    isLoadingRefs: productsQuery.isLoading || suppliersQuery.isLoading || !costCode,
    loadError: (productsQuery.error ?? suppliersQuery.error ?? null) as Error | null,
    state,
    parseError,
    summary,
    result,
    isImporting,
    parseFile,
    setAction,
    runImport,
    reset,
  };
}
```

- [ ] **Step 2: Typecheck** — `npx tsc --noEmit -p tsconfig.json`. Expected: no errors.

- [ ] **Step 3: Commit**
```bash
git add src/presentation/features/import/useProductImport.ts
git commit -m "feat(web-admin): useProductImport hook (parse -> classify -> bulkImport)"
```

---

### Task 10: `ImportPreviewTable`

**Files:**
- Create: `web_admin/src/presentation/features/import/ImportPreviewTable.tsx`

- [ ] **Step 1: Implement** — create `web_admin/src/presentation/features/import/ImportPreviewTable.tsx`:
```tsx
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import type { ClassifiedRow, RowAction } from '@/domain/products/classifyRows';

const STATUS_BADGE: Record<ClassifiedRow['status'], string> = {
  new: 'bg-success-light text-success-dark',
  existing: 'bg-light-subtle text-light-text-secondary',
  error: 'bg-error-light text-error-dark',
};

export function ImportPreviewTable({
  rows,
  actions,
  onAction,
}: {
  rows: ClassifiedRow[];
  actions: Record<number, RowAction>;
  onAction: (rowNumber: number, action: RowAction) => void;
}) {
  return (
    <div className="overflow-x-auto rounded-lg border border-light-hairline bg-light-card">
      <table className="w-full text-bodySmall">
        <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
          <tr>
            <th className="px-tk-md py-tk-sm text-left font-medium">#</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Name</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Category</th>
            <th className="px-tk-md py-tk-sm text-right font-medium">Cost</th>
            <th className="px-tk-md py-tk-sm text-right font-medium">Price</th>
            <th className="px-tk-md py-tk-sm text-right font-medium">Qty</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Unit</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Supplier</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Status</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Action</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-light-hairline">
          {rows.map((r) => {
            const p = r.parsed;
            const note = p.errors[0] ?? p.warnings[0] ?? null;
            return (
              <tr key={p.rowNumber} className={cn(r.status === 'error' && 'bg-error-light/30')}>
                <td className="px-tk-md py-tk-sm tabular-nums text-light-text-hint">{p.rowNumber}</td>
                <td className="px-tk-md py-tk-sm">
                  <div className="font-medium text-light-text">{p.name || '—'}</div>
                  {note ? (
                    <div
                      className={cn(
                        'text-[12px]',
                        r.status === 'error' ? 'text-error-dark' : 'text-light-text-hint',
                      )}
                    >
                      {note}
                    </div>
                  ) : null}
                </td>
                <td className="px-tk-md py-tk-sm text-light-text-secondary">{p.category ?? '—'}</td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">
                  {formatMoney(p.cost)}
                  <span className="ml-tk-xs text-[11px] text-light-text-hint">{p.code}</span>
                </td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(p.price)}</td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{p.quantity}</td>
                <td className="px-tk-md py-tk-sm text-light-text-secondary">{p.unit}</td>
                <td className="px-tk-md py-tk-sm text-light-text-secondary">
                  {p.supplierName ?? '—'}
                  {p.supplierName && !r.supplierMatched ? (
                    <span className="ml-tk-xs text-[11px] text-warning-dark">new</span>
                  ) : null}
                </td>
                <td className="px-tk-md py-tk-sm">
                  <span
                    className={cn(
                      'rounded-full px-tk-sm py-[1px] text-[11px] font-semibold capitalize',
                      STATUS_BADGE[r.status],
                    )}
                  >
                    {r.status}
                  </span>
                </td>
                <td className="px-tk-md py-tk-sm">
                  <select
                    className="rounded-md border border-light-border bg-light-card px-tk-sm py-[4px] text-bodySmall text-light-text outline-none focus:border-light-text disabled:opacity-50"
                    value={actions[p.rowNumber] ?? r.defaultAction}
                    disabled={r.status === 'error'}
                    onChange={(e) => onAction(p.rowNumber, e.target.value as RowAction)}
                  >
                    {r.status !== 'error' && r.status === 'new' ? (
                      <option value="insert">Insert</option>
                    ) : null}
                    {r.status === 'existing' ? <option value="update">Update</option> : null}
                    {r.status === 'existing' ? <option value="insert">Insert as new</option> : null}
                    <option value="skip">Skip</option>
                  </select>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
```

- [ ] **Step 2: Typecheck** — `npx tsc --noEmit -p tsconfig.json`. Expected: no errors. (If `bg-error-light/30` opacity isn't enabled, drop `/30`. `success-light`/`success-dark`/`warning-dark` tokens exist per `tailwind.config.ts`.)

- [ ] **Step 3: Commit**
```bash
git add src/presentation/features/import/ImportPreviewTable.tsx
git commit -m "feat(web-admin): ImportPreviewTable (per-row status + action)"
```

---

### Task 11: `ProductImportPage` + routing + nav

**Files:**
- Create: `web_admin/src/presentation/features/import/ProductImportPage.tsx`
- Modify: `web_admin/src/presentation/router/routePaths.ts`
- Modify: `web_admin/src/presentation/router/routes.tsx`
- Modify: `web_admin/src/presentation/router/routeGuards.ts`
- Modify: `web_admin/src/presentation/components/common/Sidebar.tsx`

- [ ] **Step 1: Implement the page** — create `web_admin/src/presentation/features/import/ProductImportPage.tsx`:
```tsx
import { useEffect, useRef, useState } from 'react';
import { ArrowUpTrayIcon } from '@heroicons/react/24/outline';
import { useProductImport } from './useProductImport';
import { ImportPreviewTable } from './ImportPreviewTable';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';

export function ProductImportPage() {
  const {
    isLoadingRefs,
    loadError,
    state,
    parseError,
    summary,
    result,
    isImporting,
    parseFile,
    setAction,
    runImport,
    reset,
  } = useProductImport();
  const fileRef = useRef<HTMLInputElement>(null);
  const [fileName, setFileName] = useState<string | null>(null);

  useEffect(() => {
    document.title = 'Import products · MAKI POS Admin';
  }, []);

  const actionable = summary.insert + summary.update;

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          Import products
        </h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Upload a CSV (name, category, code, price, qty, unit, reorder_level, supplier). SKU is
          generated; cost is decoded from the code.
        </p>
      </header>

      {loadError ? (
        <ErrorView title="Could not load reference data" message={loadError.message} />
      ) : (
        <>
          <div className="flex flex-wrap items-center gap-tk-md">
            <button
              type="button"
              disabled={isLoadingRefs}
              onClick={() => fileRef.current?.click()}
              className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-[8px] text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-50"
            >
              <ArrowUpTrayIcon className="h-4 w-4" />
              Choose CSV
            </button>
            {fileName ? <span className="text-bodySmall text-light-text-secondary">{fileName}</span> : null}
            {isLoadingRefs ? <span className="text-bodySmall text-light-text-hint">Loading…</span> : null}
            <input
              ref={fileRef}
              type="file"
              accept=".csv,text/csv"
              className="hidden"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) {
                  setFileName(f.name);
                  void parseFile(f);
                }
                e.target.value = '';
              }}
            />
          </div>

          {parseError ? <ErrorView title="Import error" message={parseError} /> : null}

          {state?.headerError ? (
            <ErrorView title="Wrong columns" message={state.headerError} />
          ) : null}

          {result ? (
            <div className="rounded-md border border-light-hairline bg-light-card p-tk-lg text-bodySmall">
              <p className="font-semibold text-light-text">Import complete</p>
              <p className="mt-tk-xs text-light-text-secondary">
                Inserted {result.inserted} · Updated {result.updated} · Failed {result.failed.length}
              </p>
              {result.failed.length > 0 ? (
                <ul className="mt-tk-sm list-disc pl-tk-lg text-error-dark">
                  {result.failed.map((f) => (
                    <li key={f.row}>Row {f.row}: {f.message}</li>
                  ))}
                </ul>
              ) : null}
              <button
                type="button"
                onClick={() => {
                  reset();
                  setFileName(null);
                }}
                className="mt-tk-md rounded-md border border-light-border px-tk-md py-[6px] text-light-text hover:bg-light-subtle"
              >
                Import another file
              </button>
            </div>
          ) : state && !state.headerError ? (
            <>
              <div className="flex flex-wrap items-center justify-between gap-tk-md">
                <p className="text-bodySmall text-light-text-secondary">
                  {summary.total} rows · {summary.insert} insert · {summary.update} update ·{' '}
                  {summary.skip} skip
                  {summary.errors > 0 ? ` · ${summary.errors} error` : ''}
                </p>
                <button
                  type="button"
                  disabled={actionable === 0 || isImporting}
                  onClick={() => void runImport()}
                  className="rounded-md bg-light-text px-tk-lg py-[8px] text-bodySmall font-semibold text-light-card hover:opacity-90 disabled:opacity-50"
                >
                  {isImporting ? 'Importing…' : `Import ${actionable} product${actionable === 1 ? '' : 's'}`}
                </button>
              </div>
              <ImportPreviewTable rows={state.rows} actions={state.actions} onAction={setAction} />
            </>
          ) : isLoadingRefs ? (
            <div className="h-24">
              <LoadingView label="Loading products & suppliers…" />
            </div>
          ) : null}
        </>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Add the route path** — in `web_admin/src/presentation/router/routePaths.ts`, add inside the inventory group (right after the `productDetail: '/inventory/:id',` line):
```ts
  productImport: '/inventory/import',
```

- [ ] **Step 3: Wire the route** — in `web_admin/src/presentation/router/routes.tsx`, add the import after the reports-page imports:
```ts
import { ProductImportPage } from '@/presentation/features/import/ProductImportPage';
```
and add this route inside the `AdminShell` children (next to the inventory routes):
```ts
        { path: RoutePaths.productImport, element: <ProductImportPage /> },
```

- [ ] **Step 4: Guard the route** — in `web_admin/src/presentation/router/routeGuards.ts`, add to the `protectedRoutes` map (after the `productAdd` entry):
```ts
  [RoutePaths.productImport, Permission.importCsv],
```

- [ ] **Step 5: Add the sidebar item** — in `web_admin/src/presentation/components/common/Sidebar.tsx`, add `ArrowUpTrayIcon` to the `@heroicons/react/24/outline` import block, then add this item to the **Stock** section's `items` array (after the Inventory entry):
```ts
      { label: 'Import Products', path: RoutePaths.productImport, icon: ArrowUpTrayIcon },
```

- [ ] **Step 6: Verify** — `npx tsc --noEmit -p tsconfig.json` (no errors), then `npm run build` (succeeds).

- [ ] **Step 7: Commit**
```bash
git add src/presentation/features/import/ProductImportPage.tsx src/presentation/router/routePaths.ts src/presentation/router/routes.tsx src/presentation/router/routeGuards.ts src/presentation/components/common/Sidebar.tsx
git commit -m "feat(web-admin): Product import page + route + nav"
```

---

### Task 12: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Full suite + typecheck + build**
```bash
cd web_admin
npx vitest run --environment=node
npx tsc --noEmit -p tsconfig.json
npm run build
```
Expected: all vitest suites pass (incl. the new `csv`/`sku`/`searchKeywords`/`importRows`/`classifyRows` tests), typecheck clean, build emits `web_admin/dist`.

- [ ] **Step 2: Manual deploy check (operator step)** — note in the PR/handoff: `firebase deploy --only hosting`, then on the live admin open **Stock → Import Products**. Export a category batch from Google Sheets to CSV and upload it. Confirm: the preview shows decoded ₱ cost next to the code, new vs existing classification, supplier "new" flags, error rows locked to Skip; flip an action; click Import; confirm the inserted/updated counts and that a spot-checked product appears in the mobile app's product search (validates `searchKeywords`). Re-upload the same file → rows now classify as **existing**.

- [ ] **Step 3: No commit** — verification only.

---

## Notes for the executor
- Run all commands from `web_admin/`. Logic tests use `--environment=node`; typecheck with `npx tsc --noEmit -p tsconfig.json`; `npm run build` works. `npm rebuild esbuild` / `npm ci` if a stale esbuild binary breaks `vite build`.
- Tested modules (`csv`, `sku`, `searchKeywords`, `importRows`, `classifyRows`) and anything they import use **relative imports** — `@/` is unresolved by vitest.
- No new npm dependency, no Firestore rules change (admin-only app; `products` create/update rules already allow admin), no data migration.
- Tailwind tokens used: `success-light`/`success-dark`/`error-light`/`error-dark`/`warning-dark`/`light-subtle`/`light-border`/`light-hairline` all exist in `tailwind.config.ts`. If an opacity modifier (`/30`) isn't enabled, drop it.
