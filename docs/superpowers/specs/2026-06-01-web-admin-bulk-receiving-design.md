# Web Admin — Bulk Receiving — Design

> **Status:** approved design (brainstormed 2026-06-01). Replaces the just-shipped
> "Import Products" tool with a mobile-aligned **Bulk Receiving** flow.

## Context

Spec 3 shipped a web "Import Products" tool (`/inventory/import`) that did catalog create/update:
matched by name+category, decoded a cost code, and **overwrote** product quantity. That diverges from
how the Flutter app works — mobile has no standalone product import; its only batch path is **bulk
receiving** (`lib/.../receiving/batch_import_screen.dart` + `lib/core/utils/batch_import.dart` +
`lib/domain/usecases/receiving/receiving_import_resolver.dart` + `receiving_repository_impl.dart`),
which matches by **SKU**, **increments** stock, writes a `receivings` record, and spawns SKU
variations on cost mismatch.

This spec re-aligns the web with mobile: rename/replace the import tool with **Bulk Receiving** at
`/receiving/bulk`, and build the web receiving write-layer (currently phase-8 placeholders). The web
already has a faithful `Receiving`/`ReceivingItem` entity (`web_admin/src/domain/entities/Receiving.ts`)
and the `accessReceiving`/`receiveStock`/`bulkReceive` permissions; what's missing is the repository,
converter, product stock-write methods, and the UI.

## Goals

1. **Bulk Receiving** at `/receiving/bulk`: upload a mobile-format CSV → preview classification →
   commit, which writes a completed `receivings` record and applies stock.
2. **Mobile parity** in data + behavior: SKU matching, plain-cost CSV (encoded to a cost code on
   store), stock increments, `<sku>-N` variations on cost mismatch, price-history entries, and
   reference numbers identical to mobile, so web receivings appear in the mobile receiving history.
3. Build the reusable web **receiving write-layer** (repository + converter + product stock methods)
   that phase-8 receiving will also use.
4. **Remove** the "Import Products" page/route/nav and its import-only modules.

## Non-goals (out of scope)

- Manual (non-CSV) receiving entry form, receiving **drafts** list, and receiving **history**/detail
  views — these are the rest of phase-8 and are separate.
- Editing or **cancelling** a committed receiving; reversing stock.
- Two-phase draft→complete UX (we commit a completed receiving in one action — see Architecture).
- Barcode columns; the `barcode` (singular) vs Flutter `barcodes[]` reconciliation.

## Architecture

**Single-commit, client-orchestrated** (Approach A from brainstorming). The page loads existing
products (`productRepo.list()`), suppliers, and the active cost-code (`useCostCode()`), parses the
CSV, classifies rows against the loaded products, and on "Receive" performs the writes. Pure logic
(parse → classify → resolve) is isolated and unit-tested; the page is thin.

```
CSV file ─▶ parseCsv ─▶ parseReceivingRows(grid)            // mobile columns, validate
        ─▶ classifyReceivingRows(rows, products)            // by SKU: match / cost-mismatch / new
        ─▶ preview (summary chips + per-row badges)
        ─▶ commit: ReceivingRepository.bulkReceive(resolved, supplier, actor, cipher)
              → create new products (qty 0)
              → write completed `receivings` doc (RCV-YYYYMMDD-NNN)
              → per item: increment stock | create variation | price_history
```

Unlike mobile's draft→complete two-step, the CSV flow commits a **completed** receiving in one action.
Writes use chunked `writeBatch` (≤500 ops/batch) — atomic per chunk, an improvement over mobile's
sequential writes.

## CSV format (mobile-identical)

Columns `sku, name, category, unit, cost, price, quantity, reorder_level` — header required, first
column must be `sku` (case-insensitive); the rest are positional (matches `kBatchImportColumns`).

| Column | Required | Rule |
|---|---|---|
| `sku` | **yes** | the product SKU, or the literal `GENERATE` (case-insensitive) to auto-create |
| `name` | **yes** | non-empty |
| `category` | no | blank → null |
| `unit` | no | blank → `pcs` |
| `cost` | **yes** | plain non-negative number (the *cost*, not a code); encoded to `costCode` on store |
| `price` | **yes** | non-negative number |
| `quantity` | **yes** | **positive** integer (you're receiving stock) |
| `reorder_level` | no | non-negative integer, blank → 0 |

**Difference from the old import format:** receiving needs a **`sku`** column and a **plain `cost`
number** (the old import used the encoded `code` and had no SKU). The `inventory_transform_workflow`
memory will be updated to the receiving format. Cost is encoded to a cost code via the active cipher
(`encodeCostCode`) before storing on products and receiving items — so cashiers still never see raw
cost. Required columns absent → the whole file is rejected.

## Classification (by SKU, ±0.01 cost tolerance)

Mirrors mobile `classifyRows`. Build a case-insensitive SKU index over the loaded active products:

- **NewProduct** — `sku` is `GENERATE`, or not found in the index. Will create a product (qty 0) then
  receive into it.
- **ExistingMatch** — SKU found and `|existing.cost − row.cost| ≤ 0.01`. Receiving adds the quantity.
- **CostMismatch** — SKU found but cost differs. Receiving spawns a variation `<baseSku>-N` at the new
  cost and receives into it; the original is untouched.

Rows that fail validation (missing required field, bad number, non-positive qty) are **errors**,
shown in the preview and excluded from the commit. Permission `addProduct` is asserted only when at
least one NewProduct row will commit.

## The receiving commit (write behavior)

`ReceivingRepository.bulkReceive(...)` performs, for the actionable rows:

1. **New products** — `productRepo.create` (or a batched set) a product: qty 0, `cost`,
   `costCode = encodeCostCode(cipher, cost)`, `reorderLevel`, `unit`, `category`, batch `supplier`,
   `searchKeywords`, generated SKU when `GENERATE`. Records an initial price-history entry.
2. **Receiving doc** — one `receivings` document, status `completed`, with `referenceNumber`
   (`RCV-YYYYMMDD-NNN`, sequence = today's receivings count + 1), `supplierId/Name`, `items[]`
   (`ReceivingItem`: productId, sku, name, quantity, unit, unitCost, costCode, isNewVariation,
   newProductId), `totalCost`, `totalQuantity`, `createdAt/completedAt = serverTimestamp()`,
   `createdBy/createdByName`, `completedBy`.
3. **Per item**:
   - ExistingMatch → increment product `quantity` (`FieldValue.increment`) + `updatedBy/At`.
   - CostMismatch → `createVariation(base, newCost)` (SKU `<baseSku>-N` via `getNextVariationNumber`
     computed from the loaded products), price-history entry (reason `receiving`), then stock onto the
     variation; tag the line `isNewVariation`/`newProductId`.
   - NewProduct → stock onto the just-created product.

Reference-number sequence needs one read (today's receivings) before the batch. Variation numbering is
derived client-side from the loaded product list (no extra reads). Writes are grouped into chunked
`writeBatch`es. `bulkReceive` returns `{ referenceNumber, received, newProducts, variations, failed[] }`.

## Components

**Reused from Spec 3 (kept):** `parseCsv` (`csv.ts`), `generateSku` (incl. variation base), `generateSearchKeywords`, `Product.createdByName/updatedByName`, `FirestoreProductRepository.create`, `encodeCostCode`/`decodeCostCode` (`CostCode.ts`), the `Receiving`/`ReceivingItem` entity.

**New / changed:**

| Unit | File | Responsibility |
|---|---|---|
| `parseReceivingRows` | `src/domain/receiving/parseReceivingRows.ts` | Mobile-format parse + validate → `ParsedReceivingRow[]` + `headerError`. Pure, tested. |
| `classifyReceivingRows` | `src/domain/receiving/classifyReceivingRows.ts` | SKU index + ±0.01 tolerance → `ClassifiedReceivingRow[]` (`new`/`match`/`mismatch`/`error`). Pure, tested. |
| variation helpers | `src/domain/receiving/variations.ts` | `nextVariationNumber(baseSku, existingSkus)`, `variationSku(base, n)` — ports of `SkuGenerator`. Pure, tested. |
| `referenceNumber` | inside `FirestoreReceivingRepository` | `RCV-YYYYMMDD-NNN` from a today-count query. |
| `ReceivingRepository` | `src/domain/repositories/ReceivingRepository.ts` | `bulkReceive(...)`, plus result/op types. |
| `FirestoreReceivingRepository` | `src/data/repositories/FirestoreReceivingRepository.ts` | The commit orchestration above (writeBatch). |
| `receivingConverter` | `src/data/converters/receivingConverter.ts` | `Receiving` ↔ Firestore (`receivings`). |
| Product stock methods | `src/data/repositories/FirestoreProductRepository.ts` | Implement `adjustStock` (increment), `recordPriceChange`, `listPriceHistory`; add `createVariation`. |
| `ProductRepository` | `src/domain/repositories/ProductRepository.ts` | Add `createVariation(...)`; drop the now-unused `bulkImport`. |
| DI container | `src/infrastructure/di/container.tsx` | Register `receivingRepo` + `useReceivingRepo()`. |
| `useBulkReceiving` | `src/presentation/features/receiving/useBulkReceiving.ts` | Loads refs; parse/classify; per-row actions; `runReceive()`. |
| `BulkReceivingPage` | `src/presentation/features/receiving/BulkReceivingPage.tsx` | Supplier picker + upload + preview + commit + result. |
| `ReceivingPreviewTable` | `src/presentation/features/receiving/ReceivingPreviewTable.tsx` | Per-row badges (Match / Variation / New / Error) + counts. |

**Removed:** `ProductImportPage`, `useProductImport`, `ImportPreviewTable`, `importRows.ts`,
`classifyRows.ts` (the name+category ones), the `/inventory/import` route + guard entry + "Import
Products" nav item, and `ProductRepository.bulkImport` + its impl.

## Routing, nav & permissions

- Route `RoutePaths.bulkReceiving` (`/receiving/bulk`, already defined) renders `BulkReceivingPage`
  (replaces the phase-8 placeholder).
- Sidebar **Stock** section: the existing "Receiving" item points at `/receiving` (still a
  placeholder); add/point a **"Bulk Receiving"** item at `/receiving/bulk`. Remove "Import Products".
- Route guard: `[RoutePaths.bulkReceiving, Permission.bulkReceive]`. The commit also asserts
  `addProduct` when new products are present (web is admin-only, so all pass; the assertion mirrors
  mobile and future-proofs role changes).

## Error handling

- Malformed/empty CSV or wrong header → inline message; nothing classified.
- Per-row validation errors → flagged in preview, excluded from commit.
- No actionable rows → commit button disabled.
- Reference-number read failure → surfaced; commit aborts before writes.
- Partial batch failure → `bulkReceive` reports failed rows by number; committed chunks remain (no
  rollback), consistent with mobile's non-atomic behavior but bounded per chunk.

## Testing (vitest, `--environment=node` for pure logic; relative imports in tested modules)

- `parseReceivingRows`: header check, required fields, number/qty validation, `GENERATE`, defaults.
- `classifyReceivingRows`: match (cost within tolerance), mismatch (variation forecast), new (missing
  SKU + `GENERATE`), error rows, case-insensitive SKU.
- `variations`: `nextVariationNumber` over existing SKUs, `variationSku` formatting.
- Repo (`FirestoreReceivingRepository`, product stock methods) + UI: `tsc --noEmit -p tsconfig.json`
  + `npm run build` + manual (no jsdom component tests, per Spec 2/3 convention).

## Rollout

Standard branch → implement (TDD per task) → `tsc` + `build` → `firebase deploy --only hosting`. No
Firestore rules change (admin-only app; existing `receivings` + `products` rules already allow admin
writes; mobile already writes these collections). No new npm dependency. Update the
`inventory_transform_workflow` memory to the receiving CSV format.

## Open questions

None — full mobile parity, mobile CSV format (sku + plain cost), SKU matching, variation-on-mismatch,
and full replacement of the import tool were all confirmed during brainstorming.
