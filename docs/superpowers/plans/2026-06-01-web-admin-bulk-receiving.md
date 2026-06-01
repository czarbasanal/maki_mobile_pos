# Web Admin — Bulk Receiving Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the web "Import Products" tool with a mobile-aligned **Bulk Receiving** flow at `/receiving/bulk` — upload a mobile-format CSV → preview SKU-based classification → commit a completed `receivings` record that increments stock, spawns `<sku>-N` variations on cost mismatch, and records price history.

**Architecture:** Client-orchestrated. The page loads products/suppliers/cost-code, parses + classifies the CSV, and on commit calls `ReceivingRepository.bulkReceive`, which creates new/variation products (`productRepo.create` + `recordPriceChange`) then writes the `receivings` doc + existing-stock increments in one `writeBatch`. Pure logic (parse/classify/variation-numbering) is isolated and unit-tested.

**Tech Stack:** Vite + React 18 + TS + Firebase Web SDK + React Query + Tailwind; Vitest (node env for logic). All commands run from `web_admin/`.

**Spec:** docs/superpowers/specs/2026-06-01-web-admin-bulk-receiving-design.md

**Conventions (carry from Specs 1–3):**
- Unit-tested modules + their transitive imports use **relative imports** (`../entities`), not `@/` (vitest doesn't resolve `@`). Presentation-only code uses `@/`.
- Logic tests: `--environment=node`. Typecheck: `npx tsc --noEmit -p tsconfig.json` (NOT `npm run typecheck`). `npm run build` works.
- No jsdom component tests; verify UI via `tsc` + `build` + manual.

**Deviations from the spec (YAGNI, behavior unchanged):**
- **No `receivingConverter`** — this feature only *writes* receivings (and shows the reference number); it never reads them back. The converter lands with the phase-8 receiving-history view.
- **No `createVariation` repo method** — a variation is created via `productRepo.create` with a client-computed `<base>-N` SKU + `baseSku`/`variationNumber` set, plus an explicit `recordPriceChange`. `adjustStock`/`setStock`/`listPriceHistory` stay phase-8 stubs (the receiving batch increments stock inline via `FieldValue.increment`).

---

### Task 1: Remove the Import Products surface

**Files:**
- Delete: `web_admin/src/presentation/features/import/ProductImportPage.tsx`, `ImportPreviewTable.tsx`, `useProductImport.ts`
- Delete: `web_admin/src/domain/products/importRows.ts`, `importRows.test.ts`, `classifyRows.ts`, `classifyRows.test.ts`
- Modify: `web_admin/src/presentation/router/routes.tsx`, `routePaths.ts`, `routeGuards.ts`, `components/common/Sidebar.tsx`
- Modify: `web_admin/src/domain/repositories/ProductRepository.ts`, `web_admin/src/data/repositories/FirestoreProductRepository.ts`

Receiving subsumes catalog import, so the import tool and the product `bulkImport` path are removed. `parseCsv`, `sku.ts`, `searchKeywords.ts`, `Product.createdByName/updatedByName`, and `FirestoreProductRepository.create` are KEPT (reused by receiving).

- [ ] **Step 1: Delete the import files**
```bash
cd web_admin
git rm src/presentation/features/import/ProductImportPage.tsx \
       src/presentation/features/import/ImportPreviewTable.tsx \
       src/presentation/features/import/useProductImport.ts \
       src/domain/products/importRows.ts src/domain/products/importRows.test.ts \
       src/domain/products/classifyRows.ts src/domain/products/classifyRows.test.ts
```

- [ ] **Step 2: Unwire the route** — in `web_admin/src/presentation/router/routes.tsx`, delete the import line `import { ProductImportPage } from '@/presentation/features/import/ProductImportPage';` and the route line `        { path: RoutePaths.productImport, element: <ProductImportPage /> },`.

- [ ] **Step 3: Drop the route path** — in `web_admin/src/presentation/router/routePaths.ts`, delete the line `  productImport: '/inventory/import',`.

- [ ] **Step 4: Drop the guard** — in `web_admin/src/presentation/router/routeGuards.ts`, delete the line `  [RoutePaths.productImport, Permission.importCsv],`.

- [ ] **Step 5: Drop the nav item + its icon** — in `web_admin/src/presentation/components/common/Sidebar.tsx`, delete the Stock-section line `      { label: 'Import Products', path: RoutePaths.productImport, icon: ArrowUpTrayIcon },` AND remove `  ArrowUpTrayIcon,` from the `@heroicons/react/24/outline` import block. (`noUnusedLocals` is on, so leaving the icon would fail typecheck. Task 11 re-adds it.)

- [ ] **Step 6: Remove `bulkImport` from the product repo interface** — in `web_admin/src/domain/repositories/ProductRepository.ts`, delete the `ProductImportOp` type, the `ProductImportResult` interface, and the `bulkImport(ops: ProductImportOp[], actorId: string): Promise<ProductImportResult>;` method line.

- [ ] **Step 7: Remove `bulkImport` from the impl** — in `web_admin/src/data/repositories/FirestoreProductRepository.ts`, delete the entire `async bulkImport(...) { ... }` method, and remove `ProductImportOp`, `ProductImportResult` from the `import type { ... } from '@/domain/repositories/ProductRepository';` block (leave `ProductCreateInput`, `ProductUpdateInput`). The `writeBatch` import becomes unused — remove `writeBatch,` from the `firebase/firestore` import.

- [ ] **Step 8: Verify** — `npx tsc --noEmit -p tsconfig.json` (no errors) and `npm run build` (succeeds). Run `npx vitest run --environment=node` — the suite should pass with the two removed product test files gone.

- [ ] **Step 9: Commit**
```bash
git add -A
git commit -m "refactor(web-admin): remove Import Products tool (superseded by bulk receiving)"
```

---

### Task 2: Variation numbering helpers

**Files:**
- Create: `web_admin/src/domain/receiving/variations.ts`
- Test: `web_admin/src/domain/receiving/variations.test.ts`

Ports of `SkuGenerator.removeVariationSuffix` / `getNextVariationNumber` / `generateVariation`.

- [ ] **Step 1: Write the failing test** — create `web_admin/src/domain/receiving/variations.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { nextVariationNumber, removeVariationSuffix, variationSku } from './variations';

describe('removeVariationSuffix', () => {
  it('strips a numeric -N suffix only', () => {
    expect(removeVariationSuffix('ABC123-2')).toBe('ABC123');
    expect(removeVariationSuffix('rs8-001')).toBe('rs8'); // numeric suffix stripped
    expect(removeVariationSuffix('ABC123')).toBe('ABC123');
  });
});

describe('variationSku', () => {
  it('appends -N verbatim', () => {
    expect(variationSku('ABC123', 1)).toBe('ABC123-1');
    expect(variationSku('rs8-001', 2)).toBe('rs8-001-2');
  });
});

describe('nextVariationNumber', () => {
  it('returns 1 when no variations exist', () => {
    expect(nextVariationNumber('ABC123', ['ABC123', 'XYZ'])).toBe(1);
  });

  it('returns max+1 over existing -N variations', () => {
    expect(nextVariationNumber('ABC123', ['ABC123', 'ABC123-1', 'ABC123-2'])).toBe(3);
  });

  it('ignores non-numeric suffixes', () => {
    expect(nextVariationNumber('ABC123', ['ABC123-blue', 'ABC123-1'])).toBe(2);
  });
});
```
- [ ] **Step 2: Run, expect FAIL** — `npx vitest run src/domain/receiving/variations.test.ts --environment=node`. Expected: module not found.

- [ ] **Step 3: Implement** — create `web_admin/src/domain/receiving/variations.ts`:
```ts
// Ports of lib/core/utils/sku_generator.dart variation helpers.
const SEP = '-';

/** Strips a trailing `-N` (numeric) suffix; leaves non-numeric suffixes alone. */
export function removeVariationSuffix(sku: string): string {
  const i = sku.lastIndexOf(SEP);
  if (i === -1) return sku;
  const suffix = sku.slice(i + 1);
  return /^\d+$/.test(suffix) ? sku.slice(0, i) : sku;
}

export function variationSku(baseSku: string, variationNumber: number): string {
  return `${baseSku}${SEP}${variationNumber}`;
}

/** Next free `<base>-N` given the existing SKUs (any case). */
export function nextVariationNumber(baseSku: string, existingSkus: string[]): number {
  const cleanBase = removeVariationSuffix(baseSku);
  const prefix = `${cleanBase}${SEP}`;
  let max = 0;
  for (const sku of existingSkus) {
    if (!sku.startsWith(prefix)) continue;
    const n = Number.parseInt(sku.slice(prefix.length), 10);
    if (Number.isInteger(n) && n > max) max = n;
  }
  return max + 1;
}
```

- [ ] **Step 4: Run, expect PASS** — `npx vitest run src/domain/receiving/variations.test.ts --environment=node`.

- [ ] **Step 5: Commit**
```bash
git add src/domain/receiving/variations.ts src/domain/receiving/variations.test.ts
git commit -m "feat(web-admin): variation SKU helpers (port of SkuGenerator)"
```

---

### Task 3: `parseReceivingRows`

**Files:**
- Create: `web_admin/src/domain/receiving/parseReceivingRows.ts`
- Test: `web_admin/src/domain/receiving/parseReceivingRows.test.ts`

Port of `lib/core/utils/batch_import.dart` `parseBatchImportCsv`. Positional columns; header's first cell must be `sku`.

- [ ] **Step 1: Write the failing test** — create `web_admin/src/domain/receiving/parseReceivingRows.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { parseReceivingRows } from './parseReceivingRows';

const HEADER = ['sku', 'name', 'category', 'unit', 'cost', 'price', 'quantity', 'reorder_level'];
const grid = (...rows: string[][]) => [HEADER, ...rows];

describe('parseReceivingRows', () => {
  it('parses a full row and applies defaults', () => {
    const { rows, headerError } = parseReceivingRows(
      grid(['SP-1', 'Spark Plug', 'Engine', '', '60', '100', '5', '2']),
    );
    expect(headerError).toBeNull();
    expect(rows[0]).toMatchObject({
      rowNumber: 2,
      sku: 'SP-1',
      name: 'Spark Plug',
      category: 'Engine',
      unit: 'pcs', // blank default
      cost: 60,
      price: 100,
      quantity: 5,
      reorderLevel: 2,
      autoGenerateSku: false,
      errors: [],
    });
  });

  it('rejects a file whose first header is not sku', () => {
    const r = parseReceivingRows([['name', 'sku'], ['x', 'y']]);
    expect(r.rows).toEqual([]);
    expect(r.headerError).toMatch(/sku/i);
  });

  it('flags GENERATE rows', () => {
    const { rows } = parseReceivingRows(grid(['generate', 'New', '', '', '10', '20', '3', '']));
    expect(rows[0].autoGenerateSku).toBe(true);
  });

  it('errors on missing name, bad cost/price, or non-positive quantity', () => {
    const { rows } = parseReceivingRows(
      grid(
        ['A', '', '', '', '1', '2', '3', ''],   // missing name
        ['B', 'b', '', '', 'x', '2', '3', ''],  // bad cost
        ['C', 'c', '', '', '1', '2', '0', ''],  // qty not > 0
      ),
    );
    expect(rows[0].errors[0]).toMatch(/name/i);
    expect(rows[1].errors[0]).toMatch(/cost/i);
    expect(rows[2].errors[0]).toMatch(/quantity/i);
  });

  it('skips wholly blank lines and strips commas in numbers', () => {
    const { rows } = parseReceivingRows(
      grid(['A', 'a', '', '', '1,250', '2,000', '4', ''], ['', '', '', '', '', '', '', '']),
    );
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ cost: 1250, price: 2000, quantity: 4 });
  });
});
```

- [ ] **Step 2: Run, expect FAIL** — `npx vitest run src/domain/receiving/parseReceivingRows.test.ts --environment=node`.

- [ ] **Step 3: Implement** — create `web_admin/src/domain/receiving/parseReceivingRows.ts`:
```ts
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
```

- [ ] **Step 4: Run, expect PASS** — `npx vitest run src/domain/receiving/parseReceivingRows.test.ts --environment=node`.

- [ ] **Step 5: Commit**
```bash
git add src/domain/receiving/parseReceivingRows.ts src/domain/receiving/parseReceivingRows.test.ts
git commit -m "feat(web-admin): parseReceivingRows (mobile batch-import format)"
```

---

### Task 4: `classifyReceivingRows`

**Files:**
- Create: `web_admin/src/domain/receiving/classifyReceivingRows.ts`
- Test: `web_admin/src/domain/receiving/classifyReceivingRows.test.ts`

Port of `classifyRows` — SKU index, ±0.01 cost tolerance.

- [ ] **Step 1: Write the failing test** — create `web_admin/src/domain/receiving/classifyReceivingRows.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import type { Product } from '../entities';
import type { ParsedReceivingRow } from './parseReceivingRows';
import { classifyReceivingRows } from './classifyReceivingRows';

function row(over: Partial<ParsedReceivingRow> = {}): ParsedReceivingRow {
  return {
    rowNumber: 2, sku: 'SP-1', name: 'Spark Plug', category: 'Engine', unit: 'pcs',
    cost: 60, price: 100, quantity: 5, reorderLevel: 0, autoGenerateSku: false,
    errors: [], warnings: [], ...over,
  };
}
function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: 'SP-1', name: 'Spark Plug', costCode: 'ZS', cost: 60, price: 100,
    quantity: 3, reorderLevel: 0, unit: 'pcs', supplierId: null, supplierName: null,
    isActive: true, createdAt: new Date(), updatedAt: null, createdBy: null, updatedBy: null,
    createdByName: null, updatedByName: null, searchKeywords: [], baseSku: null,
    variationNumber: null, barcode: null, category: 'Engine', imageUrl: null, notes: null,
    ...over,
  };
}

describe('classifyReceivingRows', () => {
  it('match when SKU found and cost within 0.01', () => {
    const [c] = classifyReceivingRows([row({ cost: 60.005 })], [product()]);
    expect(c.status).toBe('match');
    expect(c.existing?.id).toBe('p1');
  });

  it('mismatch when SKU found but cost differs', () => {
    const [c] = classifyReceivingRows([row({ cost: 75 })], [product()]);
    expect(c.status).toBe('mismatch');
    expect(c.existing?.id).toBe('p1');
  });

  it('new when SKU not found', () => {
    const [c] = classifyReceivingRows([row({ sku: 'NOPE' })], [product()]);
    expect(c.status).toBe('new');
    expect(c.existing).toBeNull();
  });

  it('new when GENERATE, even if the literal collides', () => {
    const [c] = classifyReceivingRows([row({ sku: 'GENERATE', autoGenerateSku: true })], [product({ sku: 'GENERATE' })]);
    expect(c.status).toBe('new');
  });

  it('error rows stay error', () => {
    const [c] = classifyReceivingRows([row({ errors: ['name is required.'] })], [product()]);
    expect(c.status).toBe('error');
  });
});
```

- [ ] **Step 2: Run, expect FAIL** — `npx vitest run src/domain/receiving/classifyReceivingRows.test.ts --environment=node`.

- [ ] **Step 3: Implement** — create `web_admin/src/domain/receiving/classifyReceivingRows.ts`:
```ts
import type { Product } from '../entities';
import type { ParsedReceivingRow } from './parseReceivingRows';

export type ReceivingRowStatus = 'new' | 'match' | 'mismatch' | 'error';

export interface ClassifiedReceivingRow {
  row: ParsedReceivingRow;
  status: ReceivingRowStatus;
  existing: Product | null;
}

const COST_TOLERANCE = 0.01;

export function classifyReceivingRows(
  rows: ParsedReceivingRow[],
  activeProducts: Product[],
): ClassifiedReceivingRow[] {
  const bySku = new Map<string, Product>();
  for (const p of activeProducts) bySku.set(p.sku.toLowerCase(), p);

  return rows.map((row): ClassifiedReceivingRow => {
    if (row.errors.length > 0) return { row, status: 'error', existing: null };
    if (row.autoGenerateSku) return { row, status: 'new', existing: null };
    const existing = bySku.get(row.sku.toLowerCase()) ?? null;
    if (!existing) return { row, status: 'new', existing: null };
    const costsEqual = Math.abs(existing.cost - row.cost) <= COST_TOLERANCE;
    return { row, status: costsEqual ? 'match' : 'mismatch', existing };
  });
}
```

- [ ] **Step 4: Run, expect PASS** — `npx vitest run src/domain/receiving/classifyReceivingRows.test.ts --environment=node`.

- [ ] **Step 5: Commit**
```bash
git add src/domain/receiving/classifyReceivingRows.ts src/domain/receiving/classifyReceivingRows.test.ts
git commit -m "feat(web-admin): classifyReceivingRows (SKU match / cost mismatch / new)"
```

---

### Task 5: Implement `recordPriceChange` on the product repo

**Files:**
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts`

- [ ] **Step 1: Implement** — in `web_admin/src/data/repositories/FirestoreProductRepository.ts`, replace the stub
```ts
  async recordPriceChange(): Promise<void> {
    throw new Error('ProductRepository.recordPriceChange not implemented yet (phase 7)');
  }
```
with:
```ts
  async recordPriceChange(
    productId: string,
    entry: Omit<PriceHistoryEntry, 'changedAt'>,
  ): Promise<void> {
    await addDoc(
      collection(this.db, FirestoreCollections.products, productId, Subcollections.priceHistory),
      {
        price: entry.price,
        cost: entry.cost,
        changedAt: serverTimestamp(),
        changedBy: entry.changedBy,
        reason: entry.reason,
      },
    );
  }
```
Add the needed imports: in the existing `import type { ... } from '@/domain/repositories/ProductRepository';` block add `PriceHistoryEntry`, and add `Subcollections` to the `import { FirestoreCollections } from '@/infrastructure/firebase/collections';` line → `import { FirestoreCollections, Subcollections } from '@/infrastructure/firebase/collections';`. (`addDoc`, `collection`, `serverTimestamp` are already imported.)

- [ ] **Step 2: Typecheck** — `npx tsc --noEmit -p tsconfig.json`. Expected: no errors.

- [ ] **Step 3: Commit**
```bash
git add src/data/repositories/FirestoreProductRepository.ts
git commit -m "feat(web-admin): implement recordPriceChange (price_history subcollection)"
```

---

### Task 6: `ReceivingRepository` interface

**Files:**
- Create: `web_admin/src/domain/repositories/ReceivingRepository.ts`

- [ ] **Step 1: Implement** — create `web_admin/src/domain/repositories/ReceivingRepository.ts`:
```ts
import type { CostCode } from '../entities';
import type { ClassifiedReceivingRow } from '../receiving/classifyReceivingRows';

export interface BulkReceiveInput {
  rows: ClassifiedReceivingRow[];
  /** All active products — used for variation numbering. */
  products: { sku: string }[];
  supplier: { id: string; name: string } | null;
  cipher: CostCode;
  actor: { id: string; name: string };
}

export interface ReceivingResult {
  referenceNumber: string;
  received: number; // line items committed
  newProducts: number;
  variations: number;
  failed: { row: number; message: string }[];
}

export interface ReceivingRepository {
  bulkReceive(input: BulkReceiveInput): Promise<ReceivingResult>;
}
```

- [ ] **Step 2: Typecheck** — `npx tsc --noEmit -p tsconfig.json`. Expected: no errors.

- [ ] **Step 3: Commit**
```bash
git add src/domain/repositories/ReceivingRepository.ts
git commit -m "feat(web-admin): ReceivingRepository contract (bulkReceive)"
```

---

### Task 7: `FirestoreReceivingRepository`

**Files:**
- Create: `web_admin/src/data/repositories/FirestoreReceivingRepository.ts`

Orchestrates the commit: create new/variation products (with price history), then a batched write of stock increments + the completed `receivings` doc. No unit test (Firestore); verified by typecheck + build + manual.

- [ ] **Step 1: Implement** — create `web_admin/src/data/repositories/FirestoreReceivingRepository.ts`:
```ts
import {
  collection,
  doc,
  getDocs,
  increment,
  query,
  serverTimestamp,
  Timestamp,
  where,
  writeBatch,
  type Firestore,
} from 'firebase/firestore';
import type { ProductRepository, ProductCreateInput } from '@/domain/repositories/ProductRepository';
import type {
  BulkReceiveInput,
  ReceivingRepository,
  ReceivingResult,
} from '@/domain/repositories/ReceivingRepository';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import { encodeCostCode } from '@/domain/entities';
import { generateSku } from '@/domain/products/sku';
import { generateSearchKeywords } from '@/domain/products/searchKeywords';
import { nextVariationNumber, variationSku } from '@/domain/receiving/variations';

interface BuiltItem {
  productId: string;
  sku: string;
  name: string;
  quantity: number;
  unit: string;
  unitCost: number;
  costCode: string;
  isNewVariation: boolean;
  newProductId: string | null;
}

export class FirestoreReceivingRepository implements ReceivingRepository {
  constructor(
    private readonly db: Firestore,
    private readonly products: ProductRepository,
  ) {}

  async bulkReceive(input: BulkReceiveInput): Promise<ReceivingResult> {
    const { rows, supplier, cipher, actor } = input;
    const referenceNumber = await this.generateReferenceNumber();

    const items: BuiltItem[] = [];
    const increments = new Map<string, number>(); // productId -> qty to add
    const failed: ReceivingResult['failed'] = [];
    const knownSkus = input.products.map((p) => p.sku);
    let newProducts = 0;
    let variations = 0;

    for (const c of rows) {
      if (c.status === 'error') continue;
      const r = c.row;
      try {
        if (c.status === 'match' && c.existing) {
          increments.set(c.existing.id, (increments.get(c.existing.id) ?? 0) + r.quantity);
          items.push({
            productId: c.existing.id, sku: c.existing.sku, name: c.existing.name,
            quantity: r.quantity, unit: c.existing.unit, unitCost: c.existing.cost,
            costCode: c.existing.costCode, isNewVariation: false, newProductId: null,
          });
        } else if (c.status === 'mismatch' && c.existing) {
          const base = c.existing.baseSku ?? c.existing.sku;
          const n = nextVariationNumber(base, knownSkus);
          const sku = variationSku(base, n);
          knownSkus.push(sku);
          const costCode = encodeCostCode(cipher, r.cost);
          const created = await this.products.create(
            this.productInput({
              sku, name: c.existing.name, cost: r.cost, costCode, price: c.existing.price,
              quantity: r.quantity, reorderLevel: c.existing.reorderLevel, unit: c.existing.unit,
              category: c.existing.category, supplierId: c.existing.supplierId,
              supplierName: c.existing.supplierName, baseSku: base, variationNumber: n, actor,
            }),
            actor.id,
          );
          await this.products.recordPriceChange(created.id, {
            price: c.existing.price, cost: r.cost, changedBy: actor.id, reason: 'receiving',
          });
          variations += 1;
          items.push({
            productId: c.existing.id, sku, name: c.existing.name, quantity: r.quantity,
            unit: c.existing.unit, unitCost: r.cost, costCode, isNewVariation: true,
            newProductId: created.id,
          });
        } else {
          // new
          const sku = r.autoGenerateSku ? generateSku(r.name) : r.sku;
          const costCode = encodeCostCode(cipher, r.cost);
          const created = await this.products.create(
            this.productInput({
              sku, name: r.name, cost: r.cost, costCode, price: r.price, quantity: r.quantity,
              reorderLevel: r.reorderLevel, unit: r.unit, category: r.category,
              supplierId: supplier?.id ?? null, supplierName: supplier?.name ?? null,
              baseSku: null, variationNumber: null, actor,
            }),
            actor.id,
          );
          await this.products.recordPriceChange(created.id, {
            price: r.price, cost: r.cost, changedBy: actor.id, reason: 'Initial price',
          });
          newProducts += 1;
          items.push({
            productId: created.id, sku: created.sku, name: r.name, quantity: r.quantity,
            unit: r.unit, unitCost: r.cost, costCode, isNewVariation: false, newProductId: null,
          });
        }
      } catch (e) {
        failed.push({ row: r.rowNumber, message: (e as Error).message });
      }
    }

    const batch = writeBatch(this.db);
    for (const [productId, delta] of increments) {
      batch.update(doc(this.db, FirestoreCollections.products, productId), {
        quantity: increment(delta),
        updatedBy: actor.id,
        updatedByName: actor.name,
        updatedAt: serverTimestamp(),
      });
    }
    const totalQuantity = items.reduce((n, it) => n + it.quantity, 0);
    const totalCost = items.reduce((n, it) => n + it.unitCost * it.quantity, 0);
    batch.set(doc(collection(this.db, FirestoreCollections.receivings)), {
      referenceNumber,
      supplierId: supplier?.id ?? null,
      supplierName: supplier?.name ?? null,
      items: items.map((it) => ({ ...it, notes: null })),
      totalCost,
      totalQuantity,
      status: 'completed',
      notes: null,
      createdBy: actor.id,
      createdByName: actor.name,
      completedBy: actor.id,
      createdAt: serverTimestamp(),
      completedAt: serverTimestamp(),
    });
    await batch.commit();

    return { referenceNumber, received: items.length, newProducts, variations, failed };
  }

  private productInput(p: {
    sku: string; name: string; cost: number; costCode: string; price: number; quantity: number;
    reorderLevel: number; unit: string; category: string | null; supplierId: string | null;
    supplierName: string | null; baseSku: string | null; variationNumber: number | null;
    actor: { id: string; name: string };
  }): ProductCreateInput {
    return {
      sku: p.sku, name: p.name, costCode: p.costCode, cost: p.cost, price: p.price,
      quantity: p.quantity, reorderLevel: p.reorderLevel, unit: p.unit,
      supplierId: p.supplierId, supplierName: p.supplierName, isActive: true,
      createdBy: p.actor.id, updatedBy: p.actor.id,
      createdByName: p.actor.name, updatedByName: p.actor.name,
      searchKeywords: generateSearchKeywords([p.sku, p.name, p.category]),
      baseSku: p.baseSku, variationNumber: p.variationNumber, barcode: null,
      category: p.category, imageUrl: null, notes: null,
    };
  }

  private async generateReferenceNumber(): Promise<string> {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
    const snap = await getDocs(
      query(
        collection(this.db, FirestoreCollections.receivings),
        where('createdAt', '>=', Timestamp.fromDate(start)),
        where('createdAt', '<', Timestamp.fromDate(end)),
      ),
    );
    const seq = snap.size + 1;
    const date = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(
      now.getDate(),
    ).padStart(2, '0')}`;
    return `RCV-${date}-${String(seq).padStart(3, '0')}`;
  }
}
```
NOTE: confirm `encodeCostCode` is exported from `@/domain/entities` (it is — re-exported via the entities barrel from `CostCode.ts`). The `reason` strings (`'receiving'`, `'Initial price'`) mirror mobile.

- [ ] **Step 2: Typecheck** — `npx tsc --noEmit -p tsconfig.json`. Expected: no errors.

- [ ] **Step 3: Commit**
```bash
git add src/data/repositories/FirestoreReceivingRepository.ts
git commit -m "feat(web-admin): FirestoreReceivingRepository.bulkReceive (receiving doc + stock + variations)"
```

---

### Task 8: Register `receivingRepo` in the DI container

**Files:**
- Modify: `web_admin/src/infrastructure/di/container.tsx`

- [ ] **Step 1: Wire it** — in `web_admin/src/infrastructure/di/container.tsx`:
  - Add imports after the `FirestoreSupplierRepository` import:
    ```ts
    import { FirestoreReceivingRepository } from '@/data/repositories/FirestoreReceivingRepository';
    import type { ReceivingRepository } from '@/domain/repositories/ReceivingRepository';
    ```
  - Add to the `Container` interface (after `supplierRepo`):
    ```ts
      receivingRepo: ReceivingRepository;
    ```
  - In `buildDefaultContainer()`, build it after `supplierRepo` (it depends on the product repo, so construct that first — it already is):
    ```ts
        supplierRepo: new FirestoreSupplierRepository(db),
        receivingRepo: new FirestoreReceivingRepository(db, new FirestoreProductRepository(db)),
    ```
  - Add the hook at the end of the file:
    ```ts
    export function useReceivingRepo(): ReceivingRepository {
      return useContainer().receivingRepo;
    }
    ```

- [ ] **Step 2: Typecheck** — `npx tsc --noEmit -p tsconfig.json`. Expected: no errors.

- [ ] **Step 3: Commit**
```bash
git add src/infrastructure/di/container.tsx
git commit -m "feat(web-admin): register receivingRepo + useReceivingRepo"
```

---

### Task 9: `useBulkReceiving` hook

**Files:**
- Create: `web_admin/src/presentation/features/receiving/useBulkReceiving.ts`

- [ ] **Step 1: Implement** — create `web_admin/src/presentation/features/receiving/useBulkReceiving.ts`:
```ts
import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  useProductRepo,
  useSupplierRepo,
  useReceivingRepo,
} from '@/infrastructure/di/container';
import { useCostCode } from '@/presentation/hooks/useCostCode';
import { useAuthStore } from '@/presentation/stores/authStore';
import { parseCsv } from '@/core/utils/csv';
import { parseReceivingRows } from '@/domain/receiving/parseReceivingRows';
import {
  classifyReceivingRows,
  type ClassifiedReceivingRow,
} from '@/domain/receiving/classifyReceivingRows';
import type { ReceivingResult } from '@/domain/repositories/ReceivingRepository';

interface ReceivingState {
  rows: ClassifiedReceivingRow[];
  headerError: string | null;
}

export function useBulkReceiving() {
  const productRepo = useProductRepo();
  const supplierRepo = useSupplierRepo();
  const receivingRepo = useReceivingRepo();
  const { data: costCode } = useCostCode();
  const user = useAuthStore((s) => s.user);

  const productsQuery = useQuery({ queryKey: ['products', 'all'], queryFn: () => productRepo.list() });
  const suppliersQuery = useQuery({ queryKey: ['suppliers', 'all'], queryFn: () => supplierRepo.list() });

  const [state, setState] = useState<ReceivingState | null>(null);
  const [supplierId, setSupplierId] = useState<string>('');
  const [parseError, setParseError] = useState<string | null>(null);
  const [result, setResult] = useState<ReceivingResult | null>(null);
  const [isReceiving, setIsReceiving] = useState(false);

  const ready = !!costCode && !!productsQuery.data && !!suppliersQuery.data;

  async function parseFile(file: File) {
    setParseError(null);
    setResult(null);
    if (!ready) {
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
      parsed = parseReceivingRows(parseCsv(text));
    } catch (e) {
      setParseError(`Could not parse the CSV: ${(e as Error).message}`);
      return;
    }
    if (parsed.headerError) {
      setState({ rows: [], headerError: parsed.headerError });
      return;
    }
    setState({ rows: classifyReceivingRows(parsed.rows, productsQuery.data!), headerError: null });
  }

  function reset() {
    setState(null);
    setParseError(null);
    setResult(null);
  }

  const summary = useMemo(() => {
    const rows = state?.rows ?? [];
    const count = (s: string) => rows.filter((r) => r.status === s).length;
    return {
      total: rows.length,
      match: count('match'),
      mismatch: count('mismatch'),
      new: count('new'),
      errors: count('error'),
      actionable: rows.filter((r) => r.status !== 'error').length,
    };
  }, [state]);

  async function runReceive() {
    if (!state || !user || !costCode || !productsQuery.data) return;
    const supplier = suppliersQuery.data?.find((s) => s.id === supplierId) ?? null;
    setIsReceiving(true);
    try {
      setResult(
        await receivingRepo.bulkReceive({
          rows: state.rows,
          products: productsQuery.data,
          supplier: supplier ? { id: supplier.id, name: supplier.name } : null,
          cipher: costCode,
          actor: { id: user.id, name: user.displayName },
        }),
      );
    } finally {
      setIsReceiving(false);
    }
  }

  return {
    isLoadingRefs: productsQuery.isLoading || suppliersQuery.isLoading || !costCode,
    loadError: (productsQuery.error ?? suppliersQuery.error ?? null) as Error | null,
    suppliers: suppliersQuery.data ?? [],
    supplierId,
    setSupplierId,
    state,
    parseError,
    summary,
    result,
    isReceiving,
    parseFile,
    reset,
    runReceive,
  };
}
```

- [ ] **Step 2: Typecheck** — `npx tsc --noEmit -p tsconfig.json`. Expected: no errors.

- [ ] **Step 3: Commit**
```bash
git add src/presentation/features/receiving/useBulkReceiving.ts
git commit -m "feat(web-admin): useBulkReceiving hook (parse -> classify -> bulkReceive)"
```

---

### Task 10: `ReceivingPreviewTable`

**Files:**
- Create: `web_admin/src/presentation/features/receiving/ReceivingPreviewTable.tsx`

- [ ] **Step 1: Implement** — create `web_admin/src/presentation/features/receiving/ReceivingPreviewTable.tsx`:
```tsx
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import type {
  ClassifiedReceivingRow,
  ReceivingRowStatus,
} from '@/domain/receiving/classifyReceivingRows';

const BADGE: Record<ReceivingRowStatus, { label: string; cls: string }> = {
  match: { label: 'Match', cls: 'bg-light-subtle text-light-text-secondary' },
  mismatch: { label: 'Variation', cls: 'bg-warning-light text-warning-dark' },
  new: { label: 'New', cls: 'bg-success-light text-success-dark' },
  error: { label: 'Error', cls: 'bg-error-light text-error-dark' },
};

export function ReceivingPreviewTable({ rows }: { rows: ClassifiedReceivingRow[] }) {
  return (
    <div className="overflow-x-auto rounded-lg border border-light-hairline bg-light-card">
      <table className="w-full text-bodySmall">
        <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
          <tr>
            <th className="px-tk-md py-tk-sm text-left font-medium">#</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">SKU</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Name</th>
            <th className="px-tk-md py-tk-sm text-right font-medium">Cost</th>
            <th className="px-tk-md py-tk-sm text-right font-medium">Price</th>
            <th className="px-tk-md py-tk-sm text-right font-medium">Qty</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Status</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-light-hairline">
          {rows.map((c) => {
            const r = c.row;
            const badge = BADGE[c.status];
            const note = r.errors[0] ?? r.warnings[0] ?? null;
            return (
              <tr key={r.rowNumber} className={cn(c.status === 'error' && 'bg-error-light/30')}>
                <td className="px-tk-md py-tk-sm tabular-nums text-light-text-hint">{r.rowNumber}</td>
                <td className="px-tk-md py-tk-sm tabular-nums">{r.autoGenerateSku ? '— (auto)' : r.sku}</td>
                <td className="px-tk-md py-tk-sm">
                  <div className="font-medium text-light-text">{r.name || '—'}</div>
                  {note ? (
                    <div className={cn('text-[12px]', c.status === 'error' ? 'text-error-dark' : 'text-light-text-hint')}>
                      {note}
                    </div>
                  ) : null}
                </td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(r.cost)}</td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(r.price)}</td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{r.quantity}</td>
                <td className="px-tk-md py-tk-sm">
                  <span className={cn('rounded-full px-tk-sm py-[1px] text-[11px] font-semibold', badge.cls)}>
                    {badge.label}
                  </span>
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

- [ ] **Step 2: Typecheck** — `npx tsc --noEmit -p tsconfig.json`. Expected: no errors.

- [ ] **Step 3: Commit**
```bash
git add src/presentation/features/receiving/ReceivingPreviewTable.tsx
git commit -m "feat(web-admin): ReceivingPreviewTable (Match/Variation/New/Error badges)"
```

---

### Task 11: `BulkReceivingPage` + route + nav

**Files:**
- Create: `web_admin/src/presentation/features/receiving/BulkReceivingPage.tsx`
- Modify: `web_admin/src/presentation/router/routes.tsx`, `routeGuards.ts`, `components/common/Sidebar.tsx`

- [ ] **Step 1: Implement the page** — create `web_admin/src/presentation/features/receiving/BulkReceivingPage.tsx`:
```tsx
import { useEffect, useRef, useState } from 'react';
import { ArrowUpTrayIcon } from '@heroicons/react/24/outline';
import { useBulkReceiving } from './useBulkReceiving';
import { ReceivingPreviewTable } from './ReceivingPreviewTable';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';

export function BulkReceivingPage() {
  const {
    isLoadingRefs, loadError, suppliers, supplierId, setSupplierId, state, parseError,
    summary, result, isReceiving, parseFile, reset, runReceive,
  } = useBulkReceiving();
  const fileRef = useRef<HTMLInputElement>(null);
  const [fileName, setFileName] = useState<string | null>(null);

  useEffect(() => {
    document.title = 'Bulk receiving · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Bulk receiving</h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Upload a CSV (sku, name, category, unit, cost, price, quantity, reorder_level). Existing SKUs
          get stock added; a different cost spawns a variation; new SKUs (or "GENERATE") are created.
        </p>
      </header>

      {loadError ? (
        <ErrorView title="Could not load reference data" message={loadError.message} />
      ) : (
        <>
          <div className="flex flex-wrap items-center gap-tk-md">
            <select
              className="rounded-md border border-light-border bg-light-card px-tk-md py-[8px] text-bodySmall text-light-text outline-none focus:border-light-text"
              value={supplierId}
              onChange={(e) => setSupplierId(e.target.value)}
            >
              <option value="">No supplier</option>
              {suppliers.map((s) => (
                <option key={s.id} value={s.id}>{s.name}</option>
              ))}
            </select>
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

          {parseError ? <ErrorView title="Receiving error" message={parseError} /> : null}
          {state?.headerError ? <ErrorView title="Wrong columns" message={state.headerError} /> : null}

          {result ? (
            <div className="rounded-md border border-light-hairline bg-light-card p-tk-lg text-bodySmall">
              <p className="font-semibold text-light-text">Received — {result.referenceNumber}</p>
              <p className="mt-tk-xs text-light-text-secondary">
                {result.received} line items · {result.newProducts} new · {result.variations} variations ·
                {' '}{result.failed.length} failed
              </p>
              {result.failed.length > 0 ? (
                <ul className="mt-tk-sm list-disc pl-tk-lg text-error-dark">
                  {result.failed.map((f) => <li key={f.row}>Row {f.row}: {f.message}</li>)}
                </ul>
              ) : null}
              <button
                type="button"
                onClick={() => { reset(); setFileName(null); }}
                className="mt-tk-md rounded-md border border-light-border px-tk-md py-[6px] text-light-text hover:bg-light-subtle"
              >
                Receive another file
              </button>
            </div>
          ) : state && !state.headerError ? (
            <>
              <div className="flex flex-wrap items-center justify-between gap-tk-md">
                <p className="text-bodySmall text-light-text-secondary">
                  {summary.total} rows · {summary.new} new · {summary.match} match · {summary.mismatch} variation
                  {summary.errors > 0 ? ` · ${summary.errors} error` : ''}
                </p>
                <button
                  type="button"
                  disabled={summary.actionable === 0 || isReceiving}
                  onClick={() => void runReceive()}
                  className="rounded-md bg-light-text px-tk-lg py-[8px] text-bodySmall font-semibold text-light-card hover:opacity-90 disabled:opacity-50"
                >
                  {isReceiving ? 'Receiving…' : `Receive ${summary.actionable} item${summary.actionable === 1 ? '' : 's'}`}
                </button>
              </div>
              <ReceivingPreviewTable rows={state.rows} />
            </>
          ) : isLoadingRefs ? (
            <div className="h-24"><LoadingView label="Loading products & suppliers…" /></div>
          ) : null}
        </>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Wire the route** — in `web_admin/src/presentation/router/routes.tsx`, add the import after the reports-page imports:
```ts
import { BulkReceivingPage } from '@/presentation/features/receiving/BulkReceivingPage';
```
and replace the placeholder route `        { path: RoutePaths.bulkReceiving, element: placeholder('Bulk receiving', 'phase 8') },` with:
```ts
        { path: RoutePaths.bulkReceiving, element: <BulkReceivingPage /> },
```

- [ ] **Step 3: Guard the route** — already done: `routeGuards.ts` already maps `[RoutePaths.bulkReceiving, Permission.bulkReceive],` in `protectedRoutes`. No change needed; just confirm it's present.

- [ ] **Step 4: Add the nav item + icon** — in `web_admin/src/presentation/components/common/Sidebar.tsx`, re-add `  ArrowUpTrayIcon,` to the `@heroicons/react/24/outline` import block (after `ArrowRightStartOnRectangleIcon,`), and in the **Stock** section's `items` array add after the Receiving entry (`{ label: 'Receiving', ... }`):
```ts
      { label: 'Bulk Receiving', path: RoutePaths.bulkReceiving, icon: ArrowUpTrayIcon },
```

- [ ] **Step 5: Verify** — `npx tsc --noEmit -p tsconfig.json` (no errors), then `npm run build` (succeeds).

- [ ] **Step 6: Commit**
```bash
git add src/presentation/features/receiving/BulkReceivingPage.tsx src/presentation/router/routes.tsx src/presentation/router/routeGuards.ts src/presentation/components/common/Sidebar.tsx
git commit -m "feat(web-admin): Bulk Receiving page + route + nav"
```

---

### Task 12: Final verification + memory note

**Files:** none (verification only)

- [ ] **Step 1: Full suite + typecheck + build**
```bash
cd web_admin
npx vitest run --environment=node
npx tsc --noEmit -p tsconfig.json
npm run build
```
Expected: all vitest suites pass (incl. the new `variations`/`parseReceivingRows`/`classifyReceivingRows` tests; the removed import tests are gone), typecheck clean, build emits `dist`.

- [ ] **Step 2: Manual deploy check (operator step)** — note in the PR/handoff: `firebase deploy --only hosting`, then on the live admin open **Stock → Bulk Receiving**. Pick a supplier, upload a mobile-format CSV (`sku, name, category, unit, cost, price, quantity, reorder_level`). Confirm the preview shows Match / Variation / New badges; click Receive; confirm the `RCV-…` reference + counts. Verify in the **mobile app's receiving history** that the receiving appears, that an existing product's stock went **up** by the received qty, that a cost-mismatch row created a `<sku>-N` variation, and that a `GENERATE` row created a product.

- [ ] **Step 3: Update the inventory-workflow memory (operator step)** — the receiving CSV differs from the old import format. Update `~/.claude/.../memory/feedback_inventory_transform_workflow.md` so the batch output matches the receiving columns (`sku, name, category, unit, cost, price, quantity, reorder_level` — a `sku` column, plain `cost` instead of the encoded `code`).

- [ ] **Step 4: No commit** — verification only.

---

## Notes for the executor
- Run all commands from `web_admin/`. Logic tests `--environment=node`; typecheck `npx tsc --noEmit -p tsconfig.json`; `npm run build`. `npm rebuild esbuild`/`npm ci` if a stale esbuild binary breaks the build.
- Tested modules (`variations`, `parseReceivingRows`, `classifyReceivingRows`) and their imports use **relative** imports — `@/` is unresolved by vitest.
- No new npm dependency, no Firestore rules change (admin-only app; `receivings` + `products` rules already allow admin writes; mobile already writes these collections).
- Writes are non-atomic across the sequential product creates (mirrors mobile); the stock increments + receiving doc are one atomic batch.
