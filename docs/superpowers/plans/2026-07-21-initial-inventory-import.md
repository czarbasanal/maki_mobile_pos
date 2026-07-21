# Initial Inventory Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One-shot, verified import of the shop's 1,249-row master inventory CSV into the live `products` collection (plus categories, suppliers, and `product_skus` claims), honoring every invariant the Flutter/web apps maintain.

**Architecture:** A pure, unit-tested transform library (`scripts/import-inventory-lib.mjs`) turns CSV records into a write plan; a CLI (`scripts/import-inventory.mjs`) prints a dry-run report by default and performs idempotent, resumable Firestore writes under `--execute`. A wipe script (`scripts/wipe-db.mjs`) clears prod transaction/inventory data first (spec §11, user-confirmed keep-list). A separate verify script (`scripts/import-inventory-verify.mjs`) asserts post-import invariants against emulator or prod.

**Tech Stack:** Node ESM (`scripts/` package, `firebase-admin` ^13), built-in `node --test` runner, Firestore emulator for the dress rehearsal. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-07-21-initial-inventory-import-design.md` — the decisions there (corrections table, merges, variations, renames) are restated as code constants below; the spec is authoritative if a discrepancy is found.

## Global Constraints

- Work on branch `feat/initial-inventory-import` (already created; spec committed).
- All new files live in `scripts/`; run tests with `cd scripts && npm test`.
- **Dart/TS parity is non-negotiable** for: `normalizeSku` (= `trim().toUpperCase()`), SKU generation (alphabet `ABCDEFGHJKMNPQRSTUVWXYZ23456789`, name-prefix cap 10, suffix 6, fallback `SKU-` + 8), cost-code cipher (1→N 2→B 3→Q 4→M 5→F 6→Z 7→V 8→L 9→J 0→S, `SC`=00, `SCS`=000, ≤0→`S`), search keywords (lowercase, whitespace-split, per-word prefixes length 1..10, set semantics).
- Audit tag on every written doc: `createdBy`/`updatedBy` = `initial-inventory-import`; products additionally `createdByName`/`updatedByName` = `Initial Import`.
- The master CSV is copied into the repo (`scripts/data/master-inventory-2026-07-21.csv`) and never edited — all fixes are code constants.
- Writes to **prod** happen only in Task 10, behind TWO explicit user gates: one for the wipe, one for the import. Everything before that is tests, dry runs, and the emulator. NEVER run `wipe-db.mjs --execute` or `import-inventory.mjs --execute` against prod outside Task 10's gated steps.
- The app's category collection is **`product_categories`** (not `categories`); admin name-lists (`product_categories`, `units`, …) share the CategoryModel doc shape `{name, isActive, createdAt, updatedAt, createdBy, updatedBy}`.
- Units vocabulary (spec §12): CSV PC→`pcs`, SET→`set`, RULER→`ruler`, METER→`m`; the import creates missing `units` docs.
- Project ID: `maki-mobile-pos`. Auth: ADC (`gcloud auth application-default login`), already configured on this machine (read-only prod queries ran earlier this session).

---

### Task 0: Database wipe script (build + dry-run only — NO prod execute here)

**Files:**
- Create: `scripts/wipe-db.mjs`

**Interfaces:**
- Produces: standalone CLI. `node wipe-db.mjs` = dry run (per-collection counts + planned action, deletes nothing); `--execute` recursively deletes the DELETE list (subcollections included via `db.recursiveDelete`). Refuses to run if an unlisted collection exists (forces a human decision for anything new).
- The DELETE/KEEP lists are the user-confirmed spec §11 scope — copy verbatim.

- [ ] **Step 1: Write `scripts/wipe-db.mjs`**

```js
// Pre-import prod wipe — deletes transaction + inventory data, keeps users/defaults.
// Scope confirmed by user 2026-07-21 — see spec §11. NO backup was requested.
//
// Dry run:  node wipe-db.mjs           (prints per-collection plan, deletes nothing)
// Execute:  node wipe-db.mjs --execute
// Emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node wipe-db.mjs --execute
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID = 'maki-mobile-pos';
const DELETE = [
  'products', 'product_skus', 'product_categories', 'suppliers',
  'sales', 'receivings', 'drafts', 'purchase_orders',
  'expenses', 'daily_closings', 'user_logs', 'void_requests',
];
const KEEP = [
  'users', 'settings', 'units', 'expense_categories',
  'void_reasons', 'motorcycle_models', 'mechanics',
];

const execute = process.argv.includes('--execute');
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

const all = await db.listCollections();
console.log('--- wipe plan ---');
const unknown = [];
for (const col of all.sort((a, b) => a.id.localeCompare(b.id))) {
  const count = (await col.count().get()).data().count;
  const action = DELETE.includes(col.id) ? 'DELETE' : KEEP.includes(col.id) ? 'keep' : 'UNKNOWN';
  if (action === 'UNKNOWN') unknown.push(col.id);
  console.log(`${action.padEnd(8)} ${col.id.padEnd(22)} ${count}`);
}
if (unknown.length) {
  console.error(`\nUnknown collections not in DELETE or KEEP: ${unknown.join(', ')}`);
  console.error('Add each to one of the lists (with user sign-off) before running.');
  process.exit(1);
}
if (!execute) {
  console.log('\nDRY RUN — nothing deleted. Re-run with --execute to wipe.');
  process.exit(0);
}
for (const id of DELETE) {
  const ref = db.collection(id);
  const before = (await ref.count().get()).data().count;
  await db.recursiveDelete(ref); // subcollections too (sale items, price_history)
  console.log(`deleted ${id} (${before} docs)`);
}
console.log('\n--- post-wipe collections ---');
for (const col of await db.listCollections()) {
  const count = (await col.count().get()).data().count;
  console.log(`${col.id.padEnd(22)} ${count}`);
}
console.log('\nWipe complete.');
```

- [ ] **Step 2: Syntax check**

Run: `cd scripts && node --check wipe-db.mjs`
Expected: no output (OK)

- [ ] **Step 3: Dry run against prod (read-only)**

Run: `cd scripts && node wipe-db.mjs`
Expected: a table where every existing collection is labeled `DELETE` or `keep` (no `UNKNOWN`), e.g. `DELETE sales 43`, `keep users 3`, ending `DRY RUN — nothing deleted.` Do **NOT** pass `--execute` — the prod wipe happens only in Task 10.

- [ ] **Step 4: Commit**

```bash
git add scripts/wipe-db.mjs
git commit -m "feat(scripts): pre-import db wipe script (dry-run default)"
```

---

### Task 1: Package test wiring + CSV/number parsing

**Files:**
- Modify: `scripts/package.json`
- Create: `scripts/import-inventory-lib.mjs`
- Test: `scripts/import-inventory-lib.test.mjs`

**Interfaces:**
- Produces: `parseCsv(text) -> {header: string[], records: Array<Record<string,string>>}` (RFC-4180: quoted fields, `""` escapes, CRLF, BOM strip; all-empty lines dropped); `parseMoney(value) -> number|null` (strips `₱`, commas, spaces; `null` for empty/NaN); `parseQty(value) -> {qty: number, original: string|null}|null` (floor; `original` only when fractional; `null` for negative/unparsable).

- [ ] **Step 1: Add the test script to `scripts/package.json`**

```json
{
  "name": "maki-scripts",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "description": "One-off operational scripts (run manually).",
  "scripts": {
    "test": "node --test"
  },
  "dependencies": {
    "firebase-admin": "^13.0.0"
  }
}
```

- [ ] **Step 2: Write the failing tests**

Create `scripts/import-inventory-lib.test.mjs`:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { parseCsv, parseMoney, parseQty } from './import-inventory-lib.mjs';

test('parseCsv handles quoted fields containing commas and a BOM', () => {
  const text = '\uFEFF' + 'NAME,COST\n"TIRE, BIG","₱1,280.00"\nPLAIN,5\n';
  const { header, records } = parseCsv(text);
  assert.deepEqual(header, ['NAME', 'COST']);
  assert.equal(records.length, 2);
  assert.equal(records[0].NAME, 'TIRE, BIG');
  assert.equal(records[0].COST, '₱1,280.00');
});

test('parseCsv handles escaped quotes, CRLF, and no trailing newline', () => {
  const text = 'A,B\r\n"say ""hi""",x\r\nlast,row';
  const { records } = parseCsv(text);
  assert.equal(records.length, 2);
  assert.equal(records[0].A, 'say "hi"');
  assert.equal(records[1].B, 'row');
});

test('parseCsv drops all-empty lines and pads short rows', () => {
  const text = 'A,B,C\nx,y\n,,\n';
  const { records } = parseCsv(text);
  assert.equal(records.length, 1);
  assert.equal(records[0].C, '');
});

test('parseMoney strips peso signs and thousands separators', () => {
  assert.equal(parseMoney('₱55.00'), 55);
  assert.equal(parseMoney('₱1,280.00'), 1280);
  assert.equal(parseMoney('40'), 40);
  assert.equal(parseMoney('6U0'), null);
  assert.equal(parseMoney(''), null);
  assert.equal(parseMoney('  '), null);
});

test('parseQty floors decimals and reports the original', () => {
  assert.deepEqual(parseQty('4'), { qty: 4, original: null });
  assert.deepEqual(parseQty('27.5'), { qty: 27, original: '27.5' });
  assert.equal(parseQty('abc'), null);
  assert.equal(parseQty('-3'), null);
  assert.equal(parseQty(''), null);
});
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd scripts && npm test`
Expected: FAIL — `Cannot find module ... import-inventory-lib.mjs`

- [ ] **Step 4: Implement in `scripts/import-inventory-lib.mjs`**

```js
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
  const src = text.startsWith('\uFEFF') ? text.slice(1) : text;
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd scripts && npm test`
Expected: PASS (all `parseCsv`/`parseMoney`/`parseQty` tests)

- [ ] **Step 6: Commit**

```bash
git add scripts/package.json scripts/import-inventory-lib.mjs scripts/import-inventory-lib.test.mjs
git commit -m "feat(scripts): CSV + money/qty parsing for inventory import"
```

---

### Task 2: Cost-code cipher encoder

**Files:**
- Modify: `scripts/import-inventory-lib.mjs`
- Test: `scripts/import-inventory-lib.test.mjs`

**Interfaces:**
- Produces: `encodeCostCode(cost: number) -> string` — port of `CostCodeEntity.encode` with the default mapping. NOTE: the Dart doc-comment example `10000 → "NSSSCS"` is stale/wrong; the **algorithm** (greedy left-to-right, triple-zero run first, then double, then single digit) is authoritative and yields `NSCSS`. All expectations below were verified against real CSV rows where possible.

- [ ] **Step 1: Write the failing tests** (append to `scripts/import-inventory-lib.test.mjs`)

```js
import { encodeCostCode } from './import-inventory-lib.mjs';

test('encodeCostCode matches real rows from the master CSV', () => {
  // Every pair below is a real (cost, CODE) row verified during data profiling.
  assert.equal(encodeCostCode(55), 'FF');
  assert.equal(encodeCostCode(285), 'BLF');
  assert.equal(encodeCostCode(80), 'LS');
  assert.equal(encodeCostCode(110), 'NNS');
  assert.equal(encodeCostCode(100), 'NSC');
  assert.equal(encodeCostCode(400), 'MSC');
  assert.equal(encodeCostCode(1204), 'NBSM');
  assert.equal(encodeCostCode(1688), 'NZLL');
  assert.equal(encodeCostCode(1750), 'NVFS');
  assert.equal(encodeCostCode(360), 'QZS');
});

test('encodeCostCode zero runs and edge cases (algorithm-derived)', () => {
  assert.equal(encodeCostCode(1000), 'NSCS'); // N + '000'→SCS
  assert.equal(encodeCostCode(10000), 'NSCSS'); // N + '000'→SCS + '0'→S
  assert.equal(encodeCostCode(0), 'S');
  assert.equal(encodeCostCode(680.75), 'ZLS'); // decimals truncated
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd scripts && npm test`
Expected: FAIL — `encodeCostCode` not exported

- [ ] **Step 3: Implement** (append to `scripts/import-inventory-lib.mjs`)

```js
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd scripts && npm test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/import-inventory-lib.mjs scripts/import-inventory-lib.test.mjs
git commit -m "feat(scripts): cost-code cipher encoder (Dart parity)"
```

---

### Task 3: SKU generation

**Files:**
- Modify: `scripts/import-inventory-lib.mjs`
- Test: `scripts/import-inventory-lib.test.mjs`

**Interfaces:**
- Produces: `slugifyForSku(name) -> string`; `generateSku(name, rand?) -> string` (`rand: () => number` injectable for determinism, defaults `Math.random`); `normalizeSku(sku) -> string`; `SKU_CHARS` constant.

- [ ] **Step 1: Write the failing tests** (append)

```js
import { generateSku, slugifyForSku, normalizeSku, SKU_CHARS } from './import-inventory-lib.mjs';

test('SKU alphabet excludes ambiguous chars', () => {
  assert.equal(SKU_CHARS, 'ABCDEFGHJKMNPQRSTUVWXYZ23456789');
});

test('generateSku matches the Dart generateForName contract', () => {
  const zeros = () => 0; // always picks 'A'
  // Dart doc example: 'Milk Chocolate 500g Box' -> prefix MLKCHCLT50
  assert.equal(generateSku('Milk Chocolate 500g Box', zeros), 'MLKCHCLT50-AAAAAA');
  // First char kept even if vowel; later vowels dropped.
  assert.equal(generateSku('Ice', zeros), 'IC-AAAAAA');
  // Empty slug falls back to SKU- + 8 random chars.
  assert.equal(generateSku('///', zeros), 'SKU-AAAAAAAA');
  // Real item name.
  assert.equal(
    generateSku('BELT BANDO SKYDRIVE SPORT 115I', zeros),
    'BLTBNDSKYD-AAAAAA',
  );
});

test('normalizeSku is trim + uppercase (claim-key parity)', () => {
  assert.equal(normalizeSku('  abC-12 '), 'ABC-12');
});

test('slugifyForSku strips non-alphanumerics', () => {
  assert.equal(slugifyForSku('W/ Stand (TMX)'), 'WSTANDTMX');
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd scripts && npm test`
Expected: FAIL — `generateSku` not exported

- [ ] **Step 3: Implement** (append)

```js
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd scripts && npm test`
Expected: PASS. (Sanity: `BELT BANDO SKYDRIVE SPORT 115I` → slug `BELTBANDOSKYDRIVESPORT115I`, first `B`, rest drops vowels → `LTBNDSKYDRVSPRT115`, base `BLTBNDSKYDRVSPRT115`, cap 10 → `BLTBNDSKYD`.)

- [ ] **Step 5: Commit**

```bash
git add scripts/import-inventory-lib.mjs scripts/import-inventory-lib.test.mjs
git commit -m "feat(scripts): SKU generator port for inventory import"
```

---

### Task 4: Search keywords

**Files:**
- Modify: `scripts/import-inventory-lib.mjs`
- Test: `scripts/import-inventory-lib.test.mjs`

**Interfaces:**
- Produces: `toSearchKeywords(str) -> string[]` (per-word prefixes, lengths 1..10, lowercase, set semantics); `productSearchKeywords({sku, name, category}) -> string[]` (union of sku+name+category keywords — NO barcodes, matching `ProductModel._generateSearchKeywords` with empty `barcodes`); `supplierSearchKeywords(name) -> string[]` (name only, matching `SupplierModel._generateSearchKeywords` with null contact/address).

- [ ] **Step 1: Write the failing tests** (append)

```js
import { toSearchKeywords, productSearchKeywords, supplierSearchKeywords } from './import-inventory-lib.mjs';

test('toSearchKeywords matches the Dart doc example', () => {
  assert.deepEqual(
    [...toSearchKeywords('Hello World')].sort(),
    ['h', 'he', 'hel', 'hell', 'hello', 'w', 'wo', 'wor', 'worl', 'world'].sort(),
  );
});

test('toSearchKeywords caps prefixes at 10 chars', () => {
  const kw = toSearchKeywords('ADJUSTABLE1234');
  assert.ok(kw.includes('adjustable')); // length 10
  assert.ok(!kw.includes('adjustable1')); // length 11 — capped
});

test('productSearchKeywords unions sku, name, category', () => {
  const kw = productSearchKeywords({ sku: 'MS-AB', name: 'OIL X', category: 'LUBE&FLUIDS' });
  for (const expected of ['ms-ab', 'oil', 'x', 'lube&fluid', 'm', 'o', 'l']) {
    assert.ok(kw.includes(expected), `missing ${expected}`);
  }
  assert.equal(new Set(kw).size, kw.length, 'no duplicates');
});

test('supplierSearchKeywords is name-only prefixes', () => {
  assert.deepEqual([...supplierSearchKeywords('KS')].sort(), ['k', 'ks'].sort());
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd scripts && npm test`
Expected: FAIL — `toSearchKeywords` not exported

- [ ] **Step 3: Implement** (append)

```js
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd scripts && npm test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/import-inventory-lib.mjs scripts/import-inventory-lib.test.mjs
git commit -m "feat(scripts): search-keyword generation (app parity)"
```

---

### Task 5: Corrections constants, name matching, and the transform

**Files:**
- Modify: `scripts/import-inventory-lib.mjs`
- Test: `scripts/import-inventory-lib.test.mjs`

**Interfaces:**
- Produces:
  - `nameKey(name) -> string` — uppercase sorted-word-set key (`'ASK BRAKE SHOE XRM'` ≡ `'BRAKE SHOE ASK XRM'`).
  - `COST_CORRECTIONS`, `NAME_CORRECTIONS`, `CATEGORY_NORMALIZE`, `MERGE_CATEGORY_OVERRIDES`, `UNIT_MAP` constants (values below are user-verified — copy exactly).
  - `transform(records) -> {standalone: Item[], pairs: {base: Item, variation: Item}[], categories: string[], units: string[], report}` where `Item = {name, category, costCode, cost, price, quantity, reorderLevel, unit, supplierCode: string|null, notes: string|null}` (no sku/keywords yet — those are generated at write time). `unit` is the MAPPED app-vocabulary value (`pcs`/`set`/`ruler`/`m`); `units` is the sorted distinct list of mapped units used.
  - `report` fields: `recordsTotal, skippedNoName, errors[], cipherMismatches[], costCorrectionsApplied[], nameCorrectionsApplied[], categoryNormalized, decimalQtyRounded[], mergedDoubles[], mergedBatches[], variationPairs[], supplierLinks[], expected: {products, standaloneOrBase, variations, categories, inventoryValue, retailValue}`.
- Dedup dispatch rules (from the spec): group rows by `nameKey`; group of 2 with **different costCode** → variation pair (first row = base); **same costCode + same qty** → double-listing, keep first row once (category override map applies); **same costCode + different qty** → same-cost batches, sum qty, price = max (TOP GASKET → qty 15, ₱150); group > 2 → error.

- [ ] **Step 1: Write the failing tests** (append)

```js
import {
  nameKey, transform, COST_CORRECTIONS, NAME_CORRECTIONS,
} from './import-inventory-lib.mjs';

test('nameKey ignores word order', () => {
  assert.equal(nameKey('ASK BRAKE SHOE XRM'), nameKey('BRAKE SHOE  ASK XRM'));
  assert.notEqual(nameKey('OIL FILTER SUZUKI'), nameKey('OIL FILTER YAMAHA'));
});

const REC = (over = {}) => ({
  NAME: 'WIDGET A', CATEGORY: 'ENGINE', CODE: 'FF', 'UNIT COST': '₱55.00',
  'SELLING PRICE': '₱100.00', QTY: '2', UNIT: 'PC', REORDER_LEVEL: '0',
  SUPPLIER: 'NA', ...over,
});

test('transform: plain row becomes a standalone item', () => {
  const { standalone, pairs, report } = transform([REC()]);
  assert.equal(standalone.length, 1);
  assert.equal(pairs.length, 0);
  assert.deepEqual(standalone[0], {
    name: 'WIDGET A', category: 'ENGINE', costCode: 'FF', cost: 55, price: 100,
    quantity: 2, reorderLevel: 0, unit: 'pcs', supplierCode: null, notes: null,
  });
  assert.equal(report.cipherMismatches.length, 0);
  assert.equal(report.expected.products, 1);
  assert.equal(report.expected.inventoryValue, 110);
});

test('transform: skips nameless (totals) rows', () => {
  const { standalone, report } = transform([REC({ NAME: '  ' })]);
  assert.equal(standalone.length, 0);
  assert.equal(report.skippedNoName, 1);
});

test('transform: different costCode pair becomes base + variation', () => {
  const { standalone, pairs } = transform([
    REC({ QTY: '1' }),
    REC({ CODE: 'ZS', 'UNIT COST': '₱60.00', QTY: '3' }),
  ]);
  assert.equal(standalone.length, 0);
  assert.equal(pairs.length, 1);
  assert.equal(pairs[0].base.cost, 55);
  assert.equal(pairs[0].variation.cost, 60);
  assert.equal(pairs[0].variation.quantity, 3);
});

test('transform: same code + same qty merges without summing', () => {
  const { standalone, report } = transform([
    REC({ NAME: 'SIGNAL LIGHT LENS W100 WHT', CATEGORY: 'LENS', QTY: '20' }),
    REC({ NAME: 'SIGNAL LIGHT LENS W100 WHT', CATEGORY: 'ACCESSORIES', QTY: '20' }),
  ]);
  assert.equal(standalone.length, 1);
  assert.equal(standalone[0].quantity, 20);
  assert.equal(standalone[0].category, 'ACCESSORIES'); // MERGE_CATEGORY_OVERRIDES
  assert.equal(report.mergedDoubles.length, 1);
});

test('transform: same code + different qty sums and takes max price', () => {
  const { standalone, report } = transform([
    REC({ NAME: 'TOP GASKET AMCO W125', CODE: 'QF', 'UNIT COST': '35', QTY: '10', 'SELLING PRICE': '120' }),
    REC({ NAME: 'TOP GASKET AMCO W125', CODE: 'QF', 'UNIT COST': '35', QTY: '5', 'SELLING PRICE': '150' }),
  ]);
  assert.equal(standalone.length, 1);
  assert.equal(standalone[0].quantity, 15);
  assert.equal(standalone[0].price, 150);
  assert.equal(report.mergedBatches.length, 1);
});

test('transform: applies cost and name corrections', () => {
  const { standalone } = transform([
    REC({ NAME: 'HEADLIGHT RS100', CATEGORY: 'LIGHTS', CODE: 'BQX', 'UNIT COST': '23X', 'SELLING PRICE': '₱480.00' }),
  ]);
  assert.equal(standalone[0].name, 'HEADLIGHT RS100 BLK');
  assert.equal(standalone[0].cost, 230);
  assert.equal(standalone[0].costCode, 'BQS');
});

test('transform: normalizes CHAIN & SPROCKET and floors decimal qty with note', () => {
  const { standalone, report } = transform([
    REC({ NAME: 'FUEL HOSE BLK', CATEGORY: 'CHAIN & SPROCKET', QTY: '27.5', UNIT: 'RULER', CODE: 'Q', 'UNIT COST': '3' }),
  ]);
  assert.equal(standalone[0].category, 'CHAIN&SPROCKET');
  assert.equal(standalone[0].quantity, 27);
  assert.equal(standalone[0].notes, 'Imported qty rounded down from 27.5');
  assert.equal(report.categoryNormalized, 1);
  assert.equal(report.decimalQtyRounded.length, 1);
});

test('transform: maps CSV units to app vocabulary, keeps unknowns verbatim', () => {
  const mapped = transform([
    REC({ NAME: 'A1' }), // PC
    REC({ NAME: 'A2', UNIT: 'SET' }),
    REC({ NAME: 'A3', UNIT: 'RULER' }),
    REC({ NAME: 'A4', UNIT: 'METER' }),
    REC({ NAME: 'A5', UNIT: 'DOZEN' }),
  ]);
  assert.deepEqual(mapped.standalone.map((i) => i.unit), ['pcs', 'set', 'ruler', 'm', 'DOZEN']);
  assert.deepEqual(mapped.units, ['DOZEN', 'm', 'pcs', 'ruler', 'set']);
  assert.equal(mapped.report.unmappedUnits.length, 1);
});

test('transform: unparsable cost is a blocking error, >2 group is an error', () => {
  const bad = transform([REC({ 'UNIT COST': 'URX' })]);
  assert.equal(bad.report.errors.length, 1);
  const triple = transform([REC(), REC(), REC()]);
  assert.equal(triple.report.errors.length, 1);
});

test('corrections tables carry the user-verified values', () => {
  assert.deepEqual(COST_CORRECTIONS['CARBURETOR SUNTAL CT150BOXER'], { costCode: 'ZLS', cost: 680 });
  assert.deepEqual(COST_CORRECTIONS['TAIL LIGHT COVER XRM110 BLK'], { costCode: 'MS', cost: 40 });
  assert.equal(Object.keys(COST_CORRECTIONS).length, 8);
  assert.equal(NAME_CORRECTIONS['HEADLIGHT RS100'], 'HEADLIGHT RS100 BLK');
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd scripts && npm test`
Expected: FAIL — `nameKey`/`transform` not exported

- [ ] **Step 3: Implement** (append)

```js
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd scripts && npm test`
Expected: PASS (all transform tests)

- [ ] **Step 5: Commit**

```bash
git add scripts/import-inventory-lib.mjs scripts/import-inventory-lib.test.mjs
git commit -m "feat(scripts): inventory transform with corrections, merges, variations"
```

---

### Task 6: Real-CSV golden test

**Files:**
- Create: `scripts/data/master-inventory-2026-07-21.csv` (copy of the master CSV)
- Test: `scripts/import-inventory-golden.test.mjs`

**Interfaces:**
- Consumes: `parseCsv`, `transform` from Task 5.
- The expected numbers below were established during data profiling; a mismatch means the transform (or the CSV copy) regressed — investigate, don't adjust the numbers to fit.

- [ ] **Step 1: Copy the CSV into the repo**

```bash
mkdir -p scripts/data
cp '/Users/czar/Downloads/MAKI_Master_Inventory - ALL ITEMS_latest (1).csv' scripts/data/master-inventory-2026-07-21.csv
```

- [ ] **Step 2: Write the failing golden test**

Create `scripts/import-inventory-golden.test.mjs`:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { parseCsv, transform } from './import-inventory-lib.mjs';

const CSV = fileURLToPath(new URL('./data/master-inventory-2026-07-21.csv', import.meta.url));

test('golden: full master CSV transforms to the approved shape', () => {
  const { records } = parseCsv(readFileSync(CSV, 'utf8'));
  const { standalone, pairs, categories, units, report } = transform(records);

  assert.equal(report.recordsTotal, 1250); // 1249 items + totals row
  assert.equal(report.skippedNoName, 1); // the totals row
  assert.equal(report.errors.length, 0);
  assert.equal(report.cipherMismatches.length, 0); // corrections make it 8/8 clean
  assert.equal(report.costCorrectionsApplied.length, 8);
  assert.deepEqual(report.nameCorrectionsApplied, ['HEADLIGHT RS100 -> HEADLIGHT RS100 BLK']);
  assert.equal(report.categoryNormalized, 23); // CHAIN & SPROCKET rows
  assert.equal(report.decimalQtyRounded.length, 4);
  assert.equal(report.mergedDoubles.length, 8);
  assert.equal(report.mergedBatches.length, 1); // TOP GASKET
  assert.equal(report.variationPairs.length, 12);
  assert.equal(report.supplierLinks.length, 5); // HD, HMJ, HNG, KS×2
  assert.equal(report.unmappedUnits.length, 0);
  assert.deepEqual(units, ['m', 'pcs', 'ruler', 'set']);

  assert.equal(standalone.length, 1216); // 1207 singles + 9 merges
  assert.equal(pairs.length, 12);
  assert.equal(report.expected.products, 1240);
  assert.equal(categories.length, 24);
  assert.ok(!categories.includes('LENS'), 'LENS folded into ACCESSORIES');
  assert.ok(!categories.includes('CHAIN & SPROCKET'), 'spaced form normalized');

  // Spot values (user-verified decisions).
  const byName = new Map(standalone.map((i) => [i.name, i]));
  const gasket = byName.get('TOP GASKET AMCO W125');
  assert.deepEqual(
    { qty: gasket.quantity, price: gasket.price, code: gasket.costCode },
    { qty: 15, price: 150, code: 'QF' },
  );
  const carb = byName.get('CARBURETOR SUNTAL CT150BOXER');
  assert.deepEqual({ cost: carb.cost, code: carb.costCode }, { cost: 680, code: 'ZLS' });
  assert.ok(byName.has('HEADLIGHT RS100 BLK'));
  assert.ok(!byName.has('HEADLIGHT RS100'));
  const hose = byName.get('FUEL HOSE BLK');
  assert.equal(hose.quantity, 27);
  assert.equal(hose.unit, 'ruler');
  assert.match(hose.notes, /rounded down from 27\.5/);
  const oilFilter = byName.get('OIL FILTER BAJAJ/CT100');
  assert.deepEqual({ qty: oilFilter.quantity, cat: oilFilter.category }, { qty: 16, cat: 'LUBE&FLUIDS' });
});
```

- [ ] **Step 3: Run the test**

Run: `cd scripts && npm test`
Expected: PASS. If any count differs, STOP and reconcile against the spec — do not edit expectations to match output without understanding why.

- [ ] **Step 4: Commit**

```bash
git add scripts/data/master-inventory-2026-07-21.csv scripts/import-inventory-golden.test.mjs
git commit -m "test(scripts): golden transform test over the real master CSV"
```

---

### Task 7: CLI dry run

**Files:**
- Create: `scripts/import-inventory.mjs`

**Interfaces:**
- Consumes: everything exported by the lib (Tasks 1–5).
- Produces (for Task 8 to extend): `main()` flow with `--execute` flag parsed; dry run prints the report + skip preview and exits 0; blocking transform errors exit 1; missing CSV arg exits 2. Existing-product skip preview loads prod read-only via ADC; if credentials are unavailable the dry run still works, printing a warning instead of the skip list.

- [ ] **Step 1: Implement the CLI (dry-run portion)**

Create `scripts/import-inventory.mjs`:

```js
// Initial inventory import — see docs/superpowers/specs/2026-07-21-initial-inventory-import-design.md
//
// Dry run (default):  node import-inventory.mjs data/master-inventory-2026-07-21.csv
// Execute:            node import-inventory.mjs data/master-inventory-2026-07-21.csv --execute
// Emulator:           FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node import-inventory.mjs ... --execute
//
// Auth: gcloud auth application-default login   (not needed for emulator)
import { readFileSync } from 'node:fs';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import {
  parseCsv, transform, generateSku, normalizeSku, nameKey,
  productSearchKeywords, supplierSearchKeywords,
  IMPORT_TAG, IMPORT_DISPLAY_NAME,
} from './import-inventory-lib.mjs';

const PROJECT_ID = 'maki-mobile-pos';

const args = process.argv.slice(2);
const execute = args.includes('--execute');
const csvPath = args.find((a) => !a.startsWith('--'));
if (!csvPath) {
  console.error('Usage: node import-inventory.mjs <csv-path> [--execute]');
  process.exit(2);
}

function section(title) {
  console.log(`\n=== ${title} ===`);
}

function printList(title, list) {
  section(`${title} (${list.length})`);
  for (const entry of list) {
    console.log(`  ${typeof entry === 'string' ? entry : JSON.stringify(entry)}`);
  }
}

const { records } = parseCsv(readFileSync(csvPath, 'utf8'));
const result = transform(records);
const { report } = result;

section('TRANSFORM REPORT');
console.log(`records read          = ${report.recordsTotal}`);
console.log(`skipped (no name)     = ${report.skippedNoName}`);
console.log(`category normalized   = ${report.categoryNormalized}`);
console.log(`expected products     = ${report.expected.products} (${report.expected.standaloneOrBase} base/standalone + ${report.expected.variations} variations)`);
console.log(`expected categories   = ${report.expected.categories}`);
console.log(`inventory value       = ₱${report.expected.inventoryValue.toLocaleString()}`);
console.log(`retail value          = ₱${report.expected.retailValue.toLocaleString()}`);
printList('COST CORRECTIONS APPLIED', report.costCorrectionsApplied);
printList('NAME CORRECTIONS APPLIED', report.nameCorrectionsApplied);
printList('MERGED DOUBLE-LISTINGS (qty kept once)', report.mergedDoubles);
printList('MERGED SAME-COST BATCHES (qty summed)', report.mergedBatches);
printList('VARIATION PAIRS', report.variationPairs);
printList('DECIMAL QTY ROUNDED DOWN', report.decimalQtyRounded);
printList('SUPPLIER LINKS', report.supplierLinks);
printList('CIPHER MISMATCHES (expect none)', report.cipherMismatches);
printList('BLOCKING ERRORS', report.errors);

if (report.errors.length > 0) {
  console.error('\nBlocking errors above — fix the data or the transform before importing.');
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

/** Map nameKey -> [{id, sku, name, baseSku}] for every existing product. */
async function loadExistingProducts() {
  const snap = await db.collection('products').get();
  const byKey = new Map();
  for (const doc of snap.docs) {
    const key = nameKey(doc.get('name') ?? '');
    if (!byKey.has(key)) byKey.set(key, []);
    byKey.get(key).push({
      id: doc.id,
      sku: doc.get('sku'),
      name: doc.get('name'),
      baseSku: doc.get('baseSku') ?? null,
    });
  }
  return { byKey, count: snap.size };
}

/** Resolve skips/resume against existing docs. Returns the concrete write list. */
function planWrites(existingByKey) {
  const skips = [];
  const singles = []; // {item, baseSku: null, variationNumber: null}
  const pairJobs = []; // {writeBase: Item|null, variation: Item, baseSkuFixed: string|null}
  for (const item of result.standalone) {
    const existing = existingByKey.get(nameKey(item.name));
    if (existing) {
      skips.push(`${item.name} (exists as '${existing[0].name}', id ${existing[0].id})`);
      continue;
    }
    singles.push(item);
  }
  for (const { base, variation } of result.pairs) {
    const existing = existingByKey.get(nameKey(base.name)) ?? [];
    if (existing.length >= 2) {
      skips.push(`${base.name} (pair — both docs already exist)`);
    } else if (existing.length === 1) {
      if (existing[0].baseSku) {
        skips.push(`${base.name} (pair — lone existing doc is itself a variation; resolve manually)`);
      } else {
        skips.push(`${base.name} (base exists — will write variation only)`);
        pairJobs.push({ writeBase: null, variation, baseSkuFixed: existing[0].sku });
      }
    } else {
      pairJobs.push({ writeBase: base, variation, baseSkuFixed: null });
    }
  }
  return { skips, singles, pairJobs };
}

let existing;
try {
  existing = await loadExistingProducts();
} catch (err) {
  if (execute) throw err;
  console.log(`\n(existing-product check skipped — could not reach Firestore: ${err.message})`);
  console.log('\nDRY RUN — nothing written. Re-run with --execute to import.');
  process.exit(0);
}

const plan = planWrites(existing.byKey);
printList('SKIPPED — NAME ALREADY IN SYSTEM', plan.skips);
const totalToWrite = plan.singles.length
  + plan.pairJobs.reduce((s, j) => s + (j.writeBase ? 2 : 1), 0);
section('WRITE PLAN');
console.log(`existing products     = ${existing.count}`);
console.log(`products to write     = ${totalToWrite}`);

if (!execute) {
  console.log('\nDRY RUN — nothing written. Re-run with --execute to import.');
  process.exit(0);
}

await runImport(db, plan, result.categories, result.units);
```

(`runImport` is added in Task 8 — until then, add a temporary last line `async function runImport() { throw new Error('not implemented — Task 8'); }`.)

- [ ] **Step 2: Verify the dry run against prod (read-only)**

Run: `cd scripts && node import-inventory.mjs data/master-inventory-2026-07-21.csv`
Expected output (key lines):
- `records read = 1250`, `skipped (no name) = 1`
- `expected products = 1240 (1228 base/standalone + 12 variations)`
- `expected categories = 24`
- `CIPHER MISMATCHES (expect none) (0)`, `BLOCKING ERRORS (0)`
- If prod has NOT been wiped yet when this runs: `SKIPPED — NAME ALREADY IN SYSTEM` contains `BRAKE SHOE ASK XRM (exists as 'ASK BRAKE SHOE XRM' ...)` and `products to write = 1239`. (Post-wipe in Task 10 the same command shows 0 skips / 1240.)
- ends with `DRY RUN — nothing written.`

- [ ] **Step 3: Run the unit tests to confirm nothing broke**

Run: `cd scripts && npm test`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add scripts/import-inventory.mjs
git commit -m "feat(scripts): inventory import CLI — dry-run report + skip preview"
```

---

### Task 8: Firestore writer (`--execute`)

**Files:**
- Modify: `scripts/import-inventory.mjs` (replace the Task-7 `runImport` stub)

**Interfaces:**
- Consumes: `plan = {skips, singles, pairJobs}`, `result.categories`, lib exports.
- Behavior contract:
  - Category docs go in **`product_categories`** (the app's real collection — there is no `categories` collection): `{name, isActive: true, createdAt/updatedAt: serverTimestamp, createdBy/updatedBy: IMPORT_TAG}` — mirror of `CategoryModel.toMap(forCreate:)`. Only names not already present (exact trim match).
  - Unit docs: same shape, collection `units`, for every mapped unit in `result.units` not already present (`set` and `ruler` are the expected creations; `pcs`/`m` exist).
  - Supplier docs: full `SupplierModel.toMap(forCreate:)` shape — `{name, address: null, contactPerson: null, contactNumber: null, alternativeNumber: null, email: null, transactionType: 'na', isActive: true, notes: null, productCount: 0, totalInventoryValue: 0, searchKeywords: supplierSearchKeywords(name), createdAt/updatedAt: serverTimestamp, createdBy/updatedBy: IMPORT_TAG}`. Only codes needed by write-list items and not already present (case-insensitive name match).
  - Product + claim written **atomically** (one `WriteBatch` per product: `batch.create(claimRef)` + `batch.create(docRef)`), claim keyed `product_skus/{normalizeSku(sku)}` with `{sku, productId, claimedBy: IMPORT_TAG, claimedAt: serverTimestamp}`. On `ALREADY_EXISTS` (claim collision) regenerate the SKU and retry (max 5).
  - Product doc mirrors `ProductModel.toMap(forCreate:)` — exact field list in the code below (includes `imageUrl: null`, `barcodes: []`, mirrored `createdByName`/`updatedByName`).
  - Variations written after their base, `baseSku` = the base's actual SKU, `variationNumber: 1`.
  - Supplier aggregates incremented once at the end (`FieldValue.increment`).
  - Reconciliation: orphan import-tagged claims (from a crashed run) deleted + reported; then assert `claims count === products count` and `written === planned`; exit 1 on mismatch.

- [ ] **Step 1: Replace the stub with the real `runImport`**

```js
async function runImport(db, plan, categories, unitsUsed) {
  section('EXECUTE');

  // Shared helper: admin name-lists (product_categories, units) use the
  // CategoryModel doc shape.
  async function ensureNameList(collection, names) {
    const snap = await db.collection(collection).get();
    const existingNames = new Set(snap.docs.map((d) => (d.get('name') ?? '').trim()));
    let created = 0;
    for (const name of names) {
      if (existingNames.has(name)) continue;
      await db.collection(collection).add({
        name,
        isActive: true,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        createdBy: IMPORT_TAG,
        updatedBy: IMPORT_TAG,
      });
      created += 1;
    }
    return created;
  }

  // ---- Categories + units ----
  const catsCreated = await ensureNameList('product_categories', categories);
  console.log(`categories created    = ${catsCreated}`);
  const unitsCreated = await ensureNameList('units', unitsUsed);
  console.log(`units created         = ${unitsCreated}`);

  // ---- Suppliers ----
  const writeItems = [
    ...plan.singles.map((item) => ({ item, kind: 'single' })),
    ...plan.pairJobs.flatMap((job) => [
      ...(job.writeBase ? [{ item: job.writeBase, kind: 'base', job }] : []),
      { item: job.variation, kind: 'variation', job },
    ]),
  ];
  const neededCodes = new Set(
    writeItems.map(({ item }) => item.supplierCode).filter(Boolean),
  );
  const supSnap = await db.collection('suppliers').get();
  const suppliers = new Map(
    supSnap.docs.map((d) => [(d.get('name') ?? '').trim().toUpperCase(), { id: d.id, name: d.get('name') }]),
  );
  let supsCreated = 0;
  for (const code of neededCodes) {
    if (suppliers.has(code.toUpperCase())) continue;
    const ref = await db.collection('suppliers').add({
      name: code,
      address: null,
      contactPerson: null,
      contactNumber: null,
      alternativeNumber: null,
      email: null,
      transactionType: 'na',
      isActive: true,
      notes: null,
      productCount: 0,
      totalInventoryValue: 0,
      searchKeywords: supplierSearchKeywords(code),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      createdBy: IMPORT_TAG,
      updatedBy: IMPORT_TAG,
    });
    suppliers.set(code.toUpperCase(), { id: ref.id, name: code });
    supsCreated += 1;
  }
  console.log(`suppliers created     = ${supsCreated}`);

  // ---- Products (+ claims, atomically per product) ----
  const aggregates = new Map(); // supplierKey -> {count, value}

  async function writeProduct(item, { baseSku, variationNumber }) {
    const docRef = db.collection('products').doc();
    const supplier = item.supplierCode ? suppliers.get(item.supplierCode.toUpperCase()) : null;
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const sku = generateSku(item.name);
      const claimRef = db.collection('product_skus').doc(normalizeSku(sku));
      const batch = db.batch();
      batch.create(claimRef, {
        sku,
        productId: docRef.id,
        claimedBy: IMPORT_TAG,
        claimedAt: FieldValue.serverTimestamp(),
      });
      batch.create(docRef, {
        sku,
        name: item.name,
        costCode: item.costCode,
        cost: item.cost,
        price: item.price,
        quantity: item.quantity,
        reorderLevel: item.reorderLevel,
        unit: item.unit,
        supplierId: supplier?.id ?? null,
        supplierName: supplier?.name ?? null,
        isActive: true,
        searchKeywords: productSearchKeywords({ sku, name: item.name, category: item.category }),
        baseSku,
        variationNumber,
        barcodes: [],
        category: item.category,
        imageUrl: null,
        notes: item.notes,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        createdBy: IMPORT_TAG,
        updatedBy: IMPORT_TAG,
        createdByName: IMPORT_DISPLAY_NAME,
        updatedByName: IMPORT_DISPLAY_NAME,
      });
      try {
        await batch.commit();
        if (supplier) {
          const key = item.supplierCode.toUpperCase();
          const agg = aggregates.get(key) ?? { count: 0, value: 0 };
          agg.count += 1;
          agg.value += item.cost * item.quantity;
          aggregates.set(key, agg);
        }
        return sku;
      } catch (err) {
        if (err.code === 6 || err.code === 'already-exists') continue; // claim collision → new suffix
        throw err;
      }
    }
    throw new Error(`Could not claim a unique SKU for ${item.name} after 5 attempts`);
  }

  let written = 0;
  const progress = () => {
    written += 1;
    if (written % 100 === 0) console.log(`  ...${written} products written`);
  };
  for (const item of plan.singles) {
    await writeProduct(item, { baseSku: null, variationNumber: null });
    progress();
  }
  for (const job of plan.pairJobs) {
    let baseSku = job.baseSkuFixed;
    if (job.writeBase) {
      baseSku = await writeProduct(job.writeBase, { baseSku: null, variationNumber: null });
      progress();
    }
    await writeProduct(job.variation, { baseSku, variationNumber: 1 });
    progress();
  }
  console.log(`products written      = ${written}`);

  // ---- Supplier aggregates ----
  for (const [key, agg] of aggregates) {
    const supplier = suppliers.get(key);
    await db.collection('suppliers').doc(supplier.id).update({
      productCount: FieldValue.increment(agg.count),
      totalInventoryValue: FieldValue.increment(agg.value),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: IMPORT_TAG,
    });
  }
  console.log(`supplier aggregates   = ${aggregates.size} updated`);

  // ---- Reconciliation ----
  section('RECONCILIATION');
  // Orphan claims: import-tagged claims whose product doc is missing (crashed run).
  const importClaims = await db.collection('product_skus')
    .where('claimedBy', '==', IMPORT_TAG).get();
  let orphans = 0;
  for (const claim of importClaims.docs) {
    const productRef = db.collection('products').doc(claim.get('productId'));
    if (!(await productRef.get()).exists) {
      console.log(`  deleting orphan claim ${claim.id} (product ${claim.get('productId')} missing)`);
      await claim.ref.delete();
      orphans += 1;
    }
  }
  if (orphans) console.log(`orphan claims removed = ${orphans}`);

  const productsCount = (await db.collection('products').count().get()).data().count;
  const claimsCount = (await db.collection('product_skus').count().get()).data().count;
  console.log(`products in db        = ${productsCount}`);
  console.log(`claims in db          = ${claimsCount}`);
  const expectedTotal = existing.count + written;
  let ok = true;
  if (claimsCount !== productsCount) {
    console.error(`MISMATCH: claims (${claimsCount}) != products (${productsCount})`);
    ok = false;
  }
  if (productsCount !== expectedTotal) {
    console.error(`MISMATCH: products (${productsCount}) != existing ${existing.count} + written ${written}`);
    ok = false;
  }
  if (!ok) process.exit(1);
  console.log('\nOK — import reconciled cleanly.');
}
```

- [ ] **Step 2: Run lints available: node syntax check + unit tests**

Run: `cd scripts && node --check import-inventory.mjs && npm test`
Expected: syntax OK, tests PASS (writer is exercised in Task 9, not unit-tested — it is Firestore I/O glue around the tested lib).

- [ ] **Step 3: Verify dry run still behaves identically**

Run: `cd scripts && node import-inventory.mjs data/master-inventory-2026-07-21.csv`
Expected: same report as Task 7 Step 2, still ends `DRY RUN — nothing written.`

- [ ] **Step 4: Commit**

```bash
git add scripts/import-inventory.mjs
git commit -m "feat(scripts): idempotent Firestore writer for inventory import"
```

---

### Task 9: Verify script + emulator dress rehearsal (wipe + import)

**Files:**
- Create: `scripts/import-inventory-verify.mjs`

**Interfaces:**
- Consumes: written Firestore state (emulator or prod). Standalone script:
  `[FIRESTORE_EMULATOR_HOST=...] node import-inventory-verify.mjs` — runs invariant + spot checks, exits 0/1.

- [ ] **Step 1: Write the verify script**

Create `scripts/import-inventory-verify.mjs`:

```js
// Post-import invariant checks. Run against the emulator after the dress
// rehearsal and against prod after the real import.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault(), projectId: 'maki-mobile-pos' });
const db = getFirestore();

let failures = 0;
function check(label, cond, detail = '') {
  if (cond) {
    console.log(`  PASS  ${label}`);
  } else {
    failures += 1;
    console.error(`  FAIL  ${label} ${detail}`);
  }
}

async function byName(name) {
  const snap = await db.collection('products').where('name', '==', name).get();
  return snap.docs;
}

console.log('--- counts ---');
const products = (await db.collection('products').count().get()).data().count;
const claims = (await db.collection('product_skus').count().get()).data().count;
console.log(`products=${products} claims=${claims}`);
check('claims == products', claims === products, `(${claims} vs ${products})`);

console.log('--- variation pair: BELT BANDO SKYDRIVE SPORT 115I ---');
const belts = await byName('BELT BANDO SKYDRIVE SPORT 115I');
check('two docs', belts.length === 2, `(${belts.length})`);
if (belts.length === 2) {
  const base = belts.find((d) => d.get('baseSku') == null);
  const variation = belts.find((d) => d.get('baseSku') != null);
  check('base + variation roles', Boolean(base && variation));
  if (base && variation) {
    check('variation.baseSku == base.sku', variation.get('baseSku') === base.get('sku'));
    check('variationNumber == 1', variation.get('variationNumber') === 1);
    const costs = new Set(belts.map((d) => d.get('cost')));
    check('costs are {550, 570}', costs.has(550) && costs.has(570));
  }
}

console.log('--- corrected cost: CARBURETOR SUNTAL CT150BOXER ---');
const [carb] = await byName('CARBURETOR SUNTAL CT150BOXER');
check('exists', Boolean(carb));
if (carb) {
  check('cost 680 / code ZLS', carb.get('cost') === 680 && carb.get('costCode') === 'ZLS');
}

console.log('--- merged batch: TOP GASKET AMCO W125 ---');
const gaskets = await byName('TOP GASKET AMCO W125');
check('single doc', gaskets.length === 1, `(${gaskets.length})`);
if (gaskets.length === 1) {
  check('qty 15 / price 150 / code QF',
    gaskets[0].get('quantity') === 15 && gaskets[0].get('price') === 150 && gaskets[0].get('costCode') === 'QF');
}

console.log('--- rename: HEADLIGHT RS100 BLK ---');
check('renamed doc exists', (await byName('HEADLIGHT RS100 BLK')).length === 1);
check('old name absent', (await byName('HEADLIGHT RS100')).length === 0);

console.log('--- supplier link: HORN PIAA SNAIL DUAL ---');
const [horn] = await byName('HORN PIAA SNAIL DUAL');
check('exists', Boolean(horn));
if (horn) {
  check('supplier HD linked', horn.get('supplierId') != null && horn.get('supplierName') === 'HD');
}

console.log('--- decimal qty: FUEL HOSE BLK ---');
const [hose] = await byName('FUEL HOSE BLK');
check('exists', Boolean(hose));
if (hose) {
  check('qty 27 + note + unit ruler',
    hose.get('quantity') === 27 && /27\.5/.test(hose.get('notes') ?? '') && hose.get('unit') === 'ruler');
}

console.log('--- merged double-listing: OIL FILTER BAJAJ/CT100 ---');
const filters = await byName('OIL FILTER BAJAJ/CT100');
check('single doc, qty 16, LUBE&FLUIDS',
  filters.length === 1 && filters[0].get('quantity') === 16 && filters[0].get('category') === 'LUBE&FLUIDS');

console.log('--- units vocabulary ---');
const unitNames = (await db.collection('units').get()).docs.map((d) => d.get('name'));
check('set + ruler unit docs exist', unitNames.includes('set') && unitNames.includes('ruler'));

console.log('--- searchKeywords sanity ---');
if (carb) {
  const kw = carb.get('searchKeywords') ?? [];
  check('keywords include name prefixes', kw.includes('carburetor') && kw.includes('c'));
  // Keywords cap at 10 chars per word, so only the first-10 prefix of the SKU
  // is guaranteed present — never the full SKU.
  check('keywords include sku prefix', kw.includes((carb.get('sku') ?? '').toLowerCase().slice(0, 10)));
}

console.log(failures === 0 ? '\nALL CHECKS PASSED' : `\n${failures} CHECK(S) FAILED`);
process.exit(failures === 0 ? 0 : 1);
```

- [ ] **Step 2: Start the Firestore emulator** (separate terminal or background)

Run: `firebase emulators:start --only firestore --project maki-mobile-pos`
Expected: `All emulators ready!` with firestore on `127.0.0.1:8080`.

- [ ] **Step 3: Seed wipe-rehearsal data (keeps AND deletes, with subcollections)**

Run (from `scripts/`):

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node -e "
import('firebase-admin/app').then(async ({ initializeApp }) => {
  const { getFirestore } = await import('firebase-admin/firestore');
  initializeApp({ projectId: 'maki-mobile-pos' });
  const db = getFirestore();
  // keeps
  await db.collection('users').doc('u1').create({ name: 'Test User', role: 'admin' });
  await db.collection('settings').doc('sale_counters').create({ '20260721': 3 });
  await db.collection('units').add({ name: 'pcs', isActive: true });
  await db.collection('units').add({ name: 'm', isActive: true });
  // deletes (with subcollections)
  const sale = db.collection('sales').doc();
  await sale.create({ total: 100 });
  await sale.collection('items').doc().create({ qty: 1 });
  const prod = db.collection('products').doc();
  await prod.create({ sku: 'junk-1', name: 'JUNK PRODUCT' });
  await prod.collection('price_history').doc().create({ price: 1 });
  await db.collection('product_skus').doc('JUNK-1').create({ sku: 'junk-1', productId: prod.id, claimedBy: 'seed' });
  await db.collection('suppliers').add({ name: 'HD' });
  console.log('seeded');
});"
```

Expected: `seeded`

- [ ] **Step 4: Wipe rehearsal — dry run, execute, verify keeps survive**

Run: `cd scripts && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node wipe-db.mjs`
Expected: table labels `sales`/`products`/`product_skus`/`suppliers` as `DELETE` and `users`/`settings`/`units` as `keep`, no `UNKNOWN`, ends `DRY RUN — nothing deleted.`

Run: `cd scripts && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node wipe-db.mjs --execute`
Expected: `deleted` lines for the seeded delete-collections; post-wipe table lists ONLY `users` (1), `settings` (1), `units` (2). Sale items and price_history subcollections are gone with their parents.

- [ ] **Step 5: Seed the skip-machinery test product (post-wipe)**

Run (from `scripts/`):

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node -e "
import('firebase-admin/app').then(async ({ initializeApp }) => {
  const { getFirestore } = await import('firebase-admin/firestore');
  initializeApp({ projectId: 'maki-mobile-pos' });
  const db = getFirestore();
  const ref = db.collection('products').doc();
  await ref.create({ sku: 'ask-001', name: 'ASK BRAKE SHOE XRM', quantity: 15, baseSku: null });
  await db.collection('product_skus').doc('ASK-001').create({ sku: 'ask-001', productId: ref.id, claimedBy: 'seed' });
  console.log('seeded');
});"
```

Expected: `seeded`. (Prod post-wipe has zero products — this seed exists purely to prove the word-order skip/resume machinery works end-to-end.)

- [ ] **Step 6: Import rehearsal — dry run, then execute**

Run: `cd scripts && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node import-inventory.mjs data/master-inventory-2026-07-21.csv`
Expected: skip list shows `BRAKE SHOE ASK XRM (exists as 'ASK BRAKE SHOE XRM' ...)`, `products to write = 1239`.

Run: `cd scripts && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node import-inventory.mjs data/master-inventory-2026-07-21.csv --execute`
Expected: `categories created = 24`, `units created = 2` (set, ruler — pcs/m were seeded), `suppliers created = 4` (incl. HD, wiped in Step 4), `products written = 1239`, `products in db = 1240`, `claims in db = 1240`, `OK — import reconciled cleanly.`

- [ ] **Step 7: Run the verify script against the emulator**

Run: `cd scripts && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node import-inventory-verify.mjs`
Expected: `ALL CHECKS PASSED`

- [ ] **Step 8: Idempotency — re-run execute, expect zero new writes**

Run: `cd scripts && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node import-inventory.mjs data/master-inventory-2026-07-21.csv --execute`
Expected: every import name now skips (`products to write = 0`), `products written = 0`, counts unchanged (1240/1240), `OK — import reconciled cleanly.`

- [ ] **Step 9: Stop the emulator, commit**

```bash
git add scripts/import-inventory-verify.mjs
git commit -m "feat(scripts): post-import verify script; emulator rehearsal passed"
```

---

### Task 10: README + prod wipe + prod import (TWO USER GATES)

**Files:**
- Modify: `scripts/README.md`

- [ ] **Step 1: Document the script in `scripts/README.md`** (append)

```markdown
## wipe-db.mjs + import-inventory.mjs (one-shot, 2026-07-21)

Fresh-start sequence: `wipe-db.mjs` deletes transaction + inventory data (keeps users,
settings, units, expense_categories, void_reasons, motorcycle_models, mechanics), then
`import-inventory.mjs` loads the master inventory CSV
(`data/master-inventory-2026-07-21.csv`) into `products` + `product_skus` claims +
`product_categories` + `units` + `suppliers`. Spec:
`docs/superpowers/specs/2026-07-21-initial-inventory-import-design.md`.

- Wipe dry run:      `node wipe-db.mjs` (add `--execute` to delete — DESTRUCTIVE)
- Import dry run:    `node import-inventory.mjs data/master-inventory-2026-07-21.csv`
- Import:            add `--execute`
- Verify afterwards: `node import-inventory-verify.mjs`
- Emulator rehearsal: prefix commands with `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080`

Import is idempotent & resumable: existing product names (word-order-insensitive) are
skipped, the SKU claim + product doc are written atomically, and orphan import claims
are cleaned on reconcile. Everything written is tagged
`createdBy: 'initial-inventory-import'`.
```

- [ ] **Step 2: Full test suite one last time**

Run: `cd scripts && npm test`
Expected: PASS (all files)

- [ ] **Step 3: Commit**

```bash
git add scripts/README.md
git commit -m "docs(scripts): document import-inventory usage"
```

- [ ] **Step 4: Prod WIPE dry run — present to the user**

Run: `cd scripts && node wipe-db.mjs`
Show the user the full table (expected: `DELETE sales 43`, `DELETE products 6`, … `keep users 3`, `keep settings 2`, no `UNKNOWN`).

- [ ] **Step 5: 🛑 GATE 1 — wait for the user's explicit "go" on the WIPE.**

Do NOT run `wipe-db.mjs --execute` against prod without the user confirming Step 4's table. Destructive and irreversible (user declined a backup).

- [ ] **Step 6: Prod wipe execute (only after Gate 1)**

Run: `cd scripts && node wipe-db.mjs --execute`
Expected: `deleted <collection> (<n> docs)` for all 12 delete-collections; post-wipe table shows only the 7 keep-collections; `Wipe complete.`

- [ ] **Step 7: Prod IMPORT dry run — present to the user**

Run: `cd scripts && node import-inventory.mjs data/master-inventory-2026-07-21.csv`
Show the user the full report (expected post-wipe: `SKIPPED — NAME ALREADY IN SYSTEM (0)`, `products to write = 1240`, 0 errors, 0 cipher mismatches).

- [ ] **Step 8: 🛑 GATE 2 — wait for the user's explicit "go" on the IMPORT.**

- [ ] **Step 9: Prod import execute + verify (only after Gate 2)**

Run: `cd scripts && node import-inventory.mjs data/master-inventory-2026-07-21.csv --execute`
Expected: `categories created = 24`, `units created = 2`, `suppliers created = 4`, `products written = 1240`, `products in db = 1240`, `claims in db = 1240`, `OK — import reconciled cleanly.`

Run: `cd scripts && node import-inventory-verify.mjs`
Expected: `ALL CHECKS PASSED`

- [ ] **Step 10: User smoke test**

Ask the user to open the web admin (https://maki-mobile-pos.web.app) inventory list and spot-check: search works (`belt bando` shows 2 rows), a corrected item shows cost ₱680, TOP GASKET shows qty 15 @ ₱150, categories filter shows the 24 new categories, a mobile product form's unit dropdown includes `set` and `ruler`. Remind the user: BRAKE SHOE ASK XRM imported at qty 9 — physically verify that one item.

- [ ] **Step 11: Final commit + finishing-a-development-branch**

Any fixes discovered during prod verification get committed; then use the superpowers:finishing-a-development-branch skill (merge `feat/initial-inventory-import` to `main`, push per user preference).

---

## Self-Review Notes

- **Spec coverage:** wipe scope §11 (Task 0 + Task 9 rehearsal + Task 10 gates), corrections table (Task 5 constants + tests), merges/variations (Task 5), unit mapping §12 (Task 5 + Task 8 units-ensure + verify), SKU/claims/keywords parity (Tasks 3–4 + writer), `product_categories`/suppliers (Task 8), idempotency/resume (Tasks 8–9 incl. crashed-run orphan cleanup and partial-pair resume), two prod gates (Task 10), emulator rehearsal of wipe AND import (Task 9), golden numbers (Task 6). Receivings/barcodes/rules/Storage explicitly out of scope — no task touches them.
- **Numbers:** 1250 records = 1249 items + totals; 21 dup names = 12 variation pairs + 9 merges; products 1240 = 1216 standalone + 12×2 pairs. Prod post-wipe: 0 skips → 1240 written, 1240 total. Emulator rehearsal keeps a seeded skip product → 1239 written, 1240 total there.
- **Emulator/prod parity:** wipe removes HD in both → `suppliers created = 4` everywhere; `units created = 2` (set, ruler) in both (emulator seeds pcs + m).
