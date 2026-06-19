# Web `Product.barcode` → `barcodes[]` Migration — Design

**Date:** 2026-06-19
**Surface:** React web admin (`web_admin/`). Mobile already uses `barcodes[]`.
**Status:** Design — approved, pending `writing-plans`.
**Depends on:** Barcode guard Slice C (web, singular) — DONE + deployed. This slice
generalizes that singular guard to the array.

## 1. Problem & intent

The web admin models a product's scan code as a **singular** `Product.barcode:
string | null`; mobile long ago migrated to a **`barcodes: string[]`** array
(multiple vendor/manufacturer codes per product). This slice brings the web to
parity: a product can hold zero, one, or many barcodes, each uniqueness-claimed
in `product_barcodes`, with a multi-barcode form UX.

### Decisions locked in brainstorming
- **Mobile-parity, no backfill.** Read `barcodes[] ∪ legacy barcode`; write
  `barcodes[]` + drop the legacy field; `array-contains` lookup with a legacy
  `==` fallback. No data script — every backfill run reports **0 barcodes in
  use** (no product has any barcode today), so there is nothing to convert; the
  read-union + lookup-fallback cover any future mobile-written legacy doc.
- **Form UX = chips + add-input** (mobile parity, adapted): removable chips, an
  "Add barcode" text field committing on Enter/button, duplicates-within-form
  rejected, pending input auto-committed on save. **No camera scan** on web
  (`mobile_scanner` is mobile-only) — manual keyboard entry.
- **Generalize the just-shipped singular guard to a set** — `create` claims
  every element; `update` diffs the set (claim added, free removed).
- **`normalizeBarcode(code) = code.trim()`** (case-sensitive) — unchanged from
  Slice C; stays byte-identical to the Dart side and the claim backfill.

## 2. Cross-surface contract (from mobile, for parity)

- Canonical Firestore field: **`barcodes`** (array of strings). Legacy singular
  **`barcode`** is read-only fallback, **deleted on write** (`deleteField()`).
- `fromMap` reads `barcodes[]` if present, else lifts the legacy singular
  `barcode`; trims and filters empties.
- Lookup: `where('barcodes', array-contains, code)` → legacy `where('barcode',
  '==', code)` → SKU fallback.
- Claim: `product_barcodes/{normalizeBarcode(code)}`, **one claim doc per
  element**, fields `{ barcode, productId, claimedBy, claimedAt }`. `create`
  claims all; `update` deletes removed + sets added.

## 3. Data model — entity + converter

**`src/domain/entities/Product.ts`:** replace `barcode: string | null` with
**`barcodes: string[]`**. (The legacy singular field exists only in old Firestore
docs; it is NOT a field on the entity.)

**`src/data/converters/productConverter.ts`:**
- `fromFirestore`: `barcodes: parseBarcodes(d)` — a pure helper reading
  `d.barcodes ?? []` **∪** the legacy `d.barcode`, normalize-trimming each,
  dropping empties, de-duping by normalized key (preserve first-seen order).
- `toFirestore`: write `barcodes: product.barcodes` **and** `barcode:
  deleteField()` (drops the legacy field; `ignoreUndefinedProperties` is off, so
  `deleteField()` is the correct removal). Import `deleteField` from
  `firebase/firestore`.

## 4. Pure helpers (`src/domain/products/barcodes.ts`, new)

- `parseBarcodes(raw: { barcodes?: unknown; barcode?: unknown }): string[]` —
  the read-union above. Tolerant of missing/non-array inputs.
- `diffBarcodeClaims(oldCodes: string[], nextCodes: string[]): { added:
  string[]; removed: string[] }` — compares by `normalizeBarcode` key; `added` =
  in next not old, `removed` = in old not next. Used by the update transaction.

Both are unit-tested (vitest) — they hold the tricky union/dedupe and diff logic.

## 5. Repository — claim the set

**`FirestoreProductRepository`:**
- `create`: compute `barcodeKeys = nextBarcodes.map(normalizeBarcode)` (dedupe);
  reject any non-`isClaimableBarcode` up front; in the existing transaction read
  the SKU claim **and every** barcode claim before any write; throw
  `DuplicateSkuError` / `DuplicateBarcodeError` on a pre-existing claim owned by
  another product; write the product + SKU claim + **one claim doc per barcode**.
- `updateProductWithClaims`: the `barcode` parameter becomes **`{ old: string[];
  next: string[] }`**. Compute `{ added, removed } = diffBarcodeClaims(old,
  next)`; reject any non-`isClaimableBarcode` added code; in the transaction read
  the SKU claim (if changed) + each **added** barcode claim before writes; on
  conflict throw the matching error; then update the product, move the SKU claim
  (unchanged logic), **delete each removed claim**, and **set each added claim**.
  Reads-before-writes preserved.
- `barcodeExists(code, excludeProductId?)`: unchanged (per-code claim read).
- `getByBarcode(code)`: `array-contains` on `barcodes` → legacy `==` on `barcode`
  fallback. (No live web caller today; kept correct for parity.)

## 6. Hook + form + detail

**`useProductMutations.ts`:**
- `CreateProductInput.barcode: string | null` → **`barcodes: string[]`**.
- `UpdateProductInput.oldBarcode` → **`oldBarcodes: string[]`**; pass
  `{ old: oldBarcodes, next: newBarcodes }` to `updateProductWithClaims`.
- Pre-checks loop the set: create → `for (code of barcodes)` barcodeExists guard;
  update → guard each **added** code only. Route update on `skuChanged ||
  barcodesChanged` (changed = `diffBarcodeClaims(old,next)` non-empty).

**`InventoryFormPage.tsx`:** zod `barcodes: z.array(z.string())`; managed array
state rendered as removable **chips** + an "Add barcode" input (commit on
Enter/button; reject a duplicate-within-form; auto-commit a pending input value
on submit). Map a thrown "barcode already exists" to the barcodes field. Pass
`oldBarcodes: target.barcodes` on update.

**`InventoryDetailPage.tsx`:** render the `barcodes` **list** (chips or comma
list) instead of a single value; show a muted "—" when empty.

## 7. Ripple (rename enforced by typecheck)

`barcode`→`barcodes` touches `productWrites.ts`, the receiving engine
(`applyReceivedItems.ts`, `planReceive.ts` — receiving-created products get
`barcodes: []`, was `barcode: null`), `filterProducts.ts`, and any reorder code
referencing the field. `tsc -b` enumerates every site; each is updated. Receiving
products carry no barcodes, so no claim is added there (unchanged behavior).

## 8. Testing & rollout

- **Unit (vitest):** `parseBarcodes` (union, legacy lift, dedupe, trim, empty/non-
  array tolerance) and `diffBarcodeClaims` (added/removed by normalized key,
  case-sensitivity, no-op). Existing `normalizeBarcode`/`isClaimableBarcode`
  tests stand.
- **Transaction paths:** verified by `tsc -b` + `npm run build` + manual smoke —
  the web has no Firestore-mock infra (same bar as the SKU/barcode guard slices).
- **Manual smoke (deferred per standing pref, but the would-be checks):** add two
  barcodes to a product (both claimed); create another product reusing one (2nd
  blocked on that code); remove a barcode (claim freed) then reuse it elsewhere
  (succeeds); SKU rename still relinks variations.
- **Rollout:** `cd web_admin && npm run build && firebase deploy --only hosting`.
  No `firestore.rules` change (the `product_barcodes` block already permits
  per-element claims). No data backfill.

## 9. Out of scope

- Product **image upload** (the separate "Inventory polish" slice 2).
- Any **mobile** change (already on `barcodes[]`).
- A `barcodes[]` **data backfill** (0 barcodes in use).
- Per-barcode metadata (label/type) — mobile's list is flat; web matches.

## 10. Risks

- **Entity rename ripple:** `barcode`→`barcodes` breaks every reader; mitigated
  by `tsc -b` enumerating all sites before the build passes.
- **Reworking just-shipped guard code:** `updateProductWithClaims`'s barcode
  param shape changes (single → set); the hook + form + receiving callers move
  together. Covered by typecheck.
- **No web repo tx tests:** the set-claim transaction is read-verified +
  manual-smoked, per precedent. The pure diff/union helpers (the error-prone
  parts) ARE unit-tested.
- **Legacy lookup fallback retained:** `getByBarcode` keeps the `==` fallback so
  an un-migrated mobile-written legacy doc still resolves; safe to drop only
  after a future uniform-`barcodes[]` state.
