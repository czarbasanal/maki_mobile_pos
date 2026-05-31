# Web Admin — Bulk Product Import — Design

> **Status:** approved design (brainstormed 2026-06-01). Spec 3 of the web-admin effort
> (Foundation ✓ → Sales monitoring + Reports ✓ → **Bulk product import**).

## Context

The React admin (`web_admin/`, served at root `/`, admin-only) has shipped Foundation (data-model
alignment) and Spec 2 (sales monitoring + reports). The remaining web-admin goal is **bulk product
import**. Today the product *write path* does not exist in the React app:
`FirestoreProductRepository.create()` / `update()` are phase-7 stubs that throw, and there is no batch
write method. The read side (`list`, `getBySku`, `skuExists`, `search`, etc.) is implemented.

The shop's inventory is prepared as category batches in Google Sheets and exported to CSV. Each row
carries 8 columns: **name, category, code, price, qty, unit, reorder_level, supplier** — where `code`
is the **cost-code** (the shop's cipher that encodes cost as letters to hide it from cashiers), and
SKU is auto-generated (not a column). This spec builds an admin tool that ingests that CSV.

## Goals

1. An admin **CSV upload → validate → preview → import** tool for products (`/inventory/import`).
2. Per-row review in a preview table: **insert / update / skip** each row before writing.
3. Decode the `code` column to a numeric cost via the active cost-code cipher.
4. Resolve the `supplier` name to a supplier record where possible; keep the typed name otherwise.
5. Implement the product write path (`create`, `update`, plus a batched `bulkImport`) — the dependency
   that makes import (and later phase-7 inventory editing) possible.

## Non-goals (out of scope)

- **Inventory browse/edit** (phase 7) — this tool only *imports*; it does not list or edit products.
- **Barcode import** and reconciling React's single `barcode` with Flutter's `barcodes[]` list.
- Image upload, undo/rollback of an import, scheduled/automated imports.
- A column-mapping UI — headers are auto-mapped from the fixed export format (see below).
- A new CSV-parsing dependency — a small, tested RFC-4180 parser is added to the existing
  dependency-free `csv.ts` instead.

## Architecture

**Client-side**, consistent with the dashboard and Spec 2. The page loads existing products
(`productRepo.list()`), suppliers (`supplierRepo.list()`), and the active cost-code
(`useCostCode()`), then runs pure transforms and writes back via the repository. Pure logic
(parse → validate → classify) is isolated and unit-tested; the page is a thin shell.

```
CSV file ─▶ parseCsv(text): string[][]
        ─▶ parseImportRows(rows, costCode): ParsedRow[]      // map headers, validate, decode cost
        ─▶ classifyRows(parsed, existing, suppliers): ClassifiedRow[]   // new/existing/error + supplier
        ─▶ preview table (per-row action) ─▶ bulkImport(ops, actor): ImportResult
```

## Field mapping

The `Product` entity has 23 fields. Only the 8 CSV columns are user-supplied; the rest are generated
or system-set. **A row is importable only if `name` and `price` are valid; everything else defaults.**

### From the CSV

| Product field | CSV column | Required? | Rule / default |
|---|---|---|---|
| `name` | `name` | **Required** | non-empty; row is an error if blank |
| `price` | `price` | **Required** | parsed number ≥ 0 (commas stripped: `1,250` → 1250) |
| `costCode` | `code` | Optional | stored verbatim (encoded letters) |
| `cost` | *derived from* `code` | derived | `decodeCostCode(cipher, code)` where `cipher` is the active `CostCode`; blank `code` → 0 + **warning**; present but undecodable → **error** |
| `category` | `category` | Optional | `null` if blank |
| `quantity` | `qty` / `quantity` | Optional | parsed number ≥ 0, default `0` |
| `reorderLevel` | `reorder_level` / `reorderLevel` | Optional | parsed number ≥ 0, default `0` |
| `unit` | `unit` | Optional | default `'pcs'` |
| `supplierName` | `supplier` | Optional | `null` if blank |
| `supplierId` | *derived from* `supplier` | derived | match supplier by name (case-insensitive) → id; no match → `null` (name kept, flagged) |

Header matching is **case-insensitive** and accepts the aliases shown (`qty`/`quantity`,
`reorder_level`/`reorderLevel`). Required CSV columns are `name` and `price`; if either header is
absent the whole file is rejected with a clear message. Unknown extra columns are ignored.

### Generated / system-set (never from the CSV)

| Field | Value |
|---|---|
| `sku` | auto-generated — TS port of `SkuGenerator.generateForName(name)`: uppercase-slug (strip non-alphanumeric) → keep first char, drop subsequent vowels → cap at the name-prefix length → `-` + random suffix from the Code128-safe alphabet (`ABCDEFGHJKMNPQRSTUVWXYZ23456789`). Empty slug → `SKU-` + random. |
| `searchKeywords` | TS port of `_generateSearchKeywords()` + `String.toSearchKeywords()`: lowercase sku, name, and category; for each whitespace-split word emit its prefixes length 1..min(word, 10); dedupe. So mobile `arrayContainsAny` search finds web-created products. |
| `isActive` | `true` |
| `createdBy` / `updatedBy` | signed-in admin's uid |
| `createdByName` / `updatedByName` | signed-in admin's display name (see model change) |
| `createdAt` / `updatedAt` | Firestore `serverTimestamp()` |
| `baseSku`, `variationNumber`, `barcode`, `imageUrl`, `notes` | `null` (import creates base products, no variations/barcodes/images) |

## Model change (fidelity)

React `Product` is missing `createdByName` / `updatedByName`, but every Flutter-created product writes
them (`product_model.toCreateMap` denormalizes the actor's display name so non-admin viewers see a
human audit name). To keep web-created products consistent with mobile ones:

- Add `createdByName: string | null` and `updatedByName: string | null` to `Product`
  (`web_admin/src/domain/entities/Product.ts`).
- Read them in `productConverter.fromFirestore` (default `null`) and write them in `toFirestore`.
- They become part of `ProductCreateInput` (which is `Omit<Product,'id'|'createdAt'|'updatedAt'|'searchKeywords'>`),
  so the importer supplies `createdByName` = the admin's display name; `create()` mirrors it to
  `updatedByName` at create time, matching Flutter.

The `barcode` (singular) vs Flutter `barcodes[]` mismatch is left as-is — no barcode column is imported,
and reconciling it is broader than this spec.

## Building blocks (new / changed)

| Unit | File | Responsibility |
|---|---|---|
| `parseCsv` | `src/core/utils/csv.ts` (extend) | `parseCsv(text: string): string[][]` — RFC-4180: quoted fields, commas/newlines inside quotes, `""` escape, CRLF/LF, trailing newline, leading BOM stripped. Pure, unit-tested. No dependency (symmetric with the existing `salesToCsv`). |
| `generateSku` | `src/domain/products/sku.ts` | `generateSku(name: string, rand?: () => number): string` — port of `generateForName`. `rand` injectable for deterministic tests. |
| `generateSearchKeywords` | `src/domain/products/searchKeywords.ts` | `generateSearchKeywords(parts: string[]): string[]` — port of `toSearchKeywords` over sku+name+category. Pure, unit-tested. |
| `parseImportRows` | `src/domain/products/importRows.ts` | `parseImportRows(rows: string[][], costCode: CostCode): { rows: ParsedRow[]; headerError: string \| null }`. Maps headers (aliases, case-insensitive), validates required `name`/`price`, parses numbers, decodes `cost` from `code`, applies defaults, collects per-row `errors[]`/`warnings[]`. `ParsedRow` carries the raw + resolved values. |
| `classifyRows` | `src/domain/products/classifyRows.ts` | `classifyRows(parsed, existing: Product[], suppliers: Supplier[]): ClassifiedRow[]`. Status `new \| existing \| error` (match existing by `name\|category` lowercased index; ambiguous multi-match → warning, first wins). Resolves `supplierId`/`supplierName` (name index; no match → name kept + `supplierMatched=false`). Sets `defaultAction` (new→insert, existing→update, error→skip) and `matchedProductId`. Pure, unit-tested. |
| `toCreateInput` / `toUpdateInput` | `src/domain/products/importRows.ts` | Build a full `ProductCreateInput` (insert) / `ProductUpdateInput` (update: cost, costCode, price, quantity, reorderLevel, unit, category, supplierId, supplierName — **not** name) from a `ClassifiedRow` + actor. Pure. |
| `FirestoreProductRepository.create` | `src/data/repositories/FirestoreProductRepository.ts` | Implement the stub: generate `searchKeywords` (if absent), write `createdBy`/`updatedBy`, `createdByName`/`updatedByName`, `createdAt`/`updatedAt = serverTimestamp()`, `isActive`; `addDoc` via converter + serverTimestamp overrides; returns the created `Product`. |
| `FirestoreProductRepository.update` | same file | Implement the stub: `updateDoc` with the changed fields, regenerate `searchKeywords` when name/category/sku change, set `updatedBy`/`updatedByName`/`updatedAt`. |
| `FirestoreProductRepository.bulkImport` | same file | `bulkImport(ops: ImportOp[], actorId): Promise<ImportResult>` — `ImportOp = {kind:'insert', input} \| {kind:'update', id, input}`. The `input`s already carry `createdBy`/`createdByName` (and `updatedByName`) from `toCreateInput`/`toUpdateInput`; `actorId` is the authoritative actor for write fields + logging. Chunked `writeBatch` (≤ 500 ops/batch). Returns `{ inserted, updated, failed: {row, message}[] }`. Best-effort: a failed chunk records its rows but does not abort the rest. (Initial price-history write is skipped here — not needed for bulk seed.) |
| `useProductImport` | `src/presentation/features/import/useProductImport.ts` | Hook orchestrating: load products/suppliers/costCode; expose `parseFile(file)`, the classified rows + summary, per-row action setters, and `runImport()` → `bulkImport`. Uses React-Query for the loads and a mutation for the write. |

## Pages, routing & nav

- Route `RoutePaths.productImport = '/inventory/import'`, wired in `routes.tsx` (admin shell) and the
  route guard (admin-only, like the rest of the app).
- A **"Import Products"** item under the **Stock** sidebar section (`Sidebar.tsx`), icon
  `ArrowUpTrayIcon`.
- `ProductImportPage` (`src/presentation/features/import/ProductImportPage.tsx`):
  1. **Upload** — file `<input accept=".csv">` (+ drag-drop target). On select → `parseFile`.
  2. **Summary banner** — *N new · M update · K error* counts; header-error / empty-file message.
  3. **Preview** — `ImportPreviewTable` (`ImportPreviewTable.tsx`): columns row#, name, category,
     ₱cost (+ `code`), price, qty, unit, reorder, supplier (matched badge / "new"), status badge
     (New / Existing / Error), and a per-row action `<select>` (Insert / Update / Skip). Error rows
     are locked to Skip with the reason shown; warning rows show a subtle note (e.g. blank code,
     unmatched supplier, ambiguous match).
  4. **Import** — button "Import N products" (disabled when 0 actionable). Runs `runImport()`; on
     completion shows a result summary (inserted / updated / failed-by-row) and lets the user clear
     and import another file.
  - States via `LoadingView` / `ErrorView` / `EmptyState`, matching Spec 2.

## Error handling

- Malformed CSV (`parseCsv` throws) → inline error message, nothing classified.
- Missing required column (`name` or `price`) → file rejected with the missing-column list.
- Empty file / header-only → "No rows found" message.
- Per-row validation (blank name, unparseable price/qty, undecodable cost) → row flagged **error**,
  locked to Skip, reason shown; it is never written.
- Blank `code`, unmatched supplier, ambiguous name match → **warning** (still importable).
- Partial write failure → `bulkImport` reports failed rows by number; successful rows remain written
  (no rollback). The result summary surfaces failures.

## Testing (vitest, `--environment=node` for pure logic)

Unit-tested (node env, fast — and note that tested modules must use **relative imports**, since the
`@` alias is not resolved by vitest):

- `parseCsv`: simple rows, quoted fields with commas, quoted newlines, `""` escapes, CRLF, trailing
  newline, BOM, ragged rows.
- `generateSku`: slug + vowel-drop + length cap + injected-random suffix; empty-name fallback.
- `generateSearchKeywords`: prefix tokens, dedupe, multi-word, lowercase.
- `parseImportRows`: header aliasing, missing required column, required-field errors, number parsing
  (commas), cost decode (valid / blank-warning / undecodable-error), unit/qty/reorder defaults.
- `classifyRows`: new vs existing (name|category), ambiguous match, supplier match / no-match,
  default actions, error→skip; `toCreateInput`/`toUpdateInput` field selection.

Verified via `npx tsc --noEmit -p tsconfig.json` + `npm run build` + manual (no jsdom component tests,
consistent with Spec 2): repo writes (`create`/`update`/`bulkImport`) and the page.

## Rollout

Standard branch → implement (TDD per task) → `npx tsc --noEmit -p tsconfig.json` → `npm run build` →
`firebase deploy --only hosting`. No data migration. No Firestore rules change (admin-only app; the
existing `products` create/update rules already permit admin writes). One internal model extension
(`createdByName`/`updatedByName`); no new npm dependency.

## Open questions

None — input method (CSV upload), cost-code decode, per-row insert/update/skip preview, supplier
match-by-name-keep-name, and `name`+`price` as the only required columns were all confirmed during
brainstorming.
