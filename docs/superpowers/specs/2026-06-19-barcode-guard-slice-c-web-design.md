# Barcode Uniqueness Guard — Slice C (web) — Design

**Date:** 2026-06-19
**Surface:** React web admin (`web_admin/`). Mobile is Slice B (done).
**Status:** Design — pending user review, then `writing-plans`.
**Depends on:** Slice A (`product_barcodes` rules + backfill — DONE, deployed).

## 1. Problem & intent

Slice A created the `product_barcodes` claim collection + rules; Slice B made
mobile enforce it. The web still uses a *read-then-write* `barcodeExists` check
(TOCTOU) and never claims a barcode. Slice C makes the web claim the (singular)
`Product.barcode` in Firestore transactions — mirroring the web SKU guard and
mobile Slice B.

### Decisions locked in brainstorming
- **`normalizeBarcode(code) = code.trim()`** — case-sensitive; byte-identical to
  `scripts/backfill-product-barcodes.mjs` and the Dart `normalizeBarcode`.
- **Web `barcode` stays singular** (0-or-1 claim); the `barcodes[]` migration
  remains deferred.
- **`buildProductWrites` stays SKU-only**; the barcode claim is added in
  `FirestoreProductRepository.create` directly. The receiving engine
  (`executeReceivePlan`) is untouched — receiving-created products carry no
  barcode, so there's nothing to claim there.
- **Generalize `updateProductWithSku` → `updateProductWithClaims`**, moving the
  SKU claim and/or the barcode claim, each only when that field changed.
- Claims are **kept on deactivate** (no claim release on soft-delete); a barcode
  claim frees only when the barcode is cleared/changed via an edit — matching the
  SKU guard.

## 2. Helpers & types

- **`src/domain/products/sku.ts`:** add
  `export function normalizeBarcode(code: string): string { return code.trim(); }`
  and `export function isClaimableBarcode(key: string): boolean` (non-empty,
  ≤ 1500 bytes, no `/`, not `.`/`..`, not `__…__`). Empty → no claim.
- **`src/data/errors.ts`:** add `DuplicateBarcodeError extends Error`
  (`name = 'DuplicateBarcodeError'`, default message `'A product with this
  barcode already exists'`).
- **`src/infrastructure/firebase/collections.ts`:** add
  `productBarcodes: 'product_barcodes'`.

## 3. `create` — claim the barcode in the transaction

`buildProductWrites` is unchanged (SKU claim only). In
`FirestoreProductRepository.create`:
1. Compute `barcodeKey = input.barcode ? normalizeBarcode(input.barcode) : ''`.
   If non-empty and `!isClaimableBarcode(barcodeKey)`, throw a clear `Error`
   ("Invalid barcode … cannot contain '/'."). The barcode claim ref is
   `doc(db, productBarcodes, barcodeKey)` (or none when empty).
2. In the existing `runTransaction`: read the SKU claim **and** (if present) the
   barcode claim before any write. Throw `DuplicateSkuError` /
   `DuplicateBarcodeError` on a pre-existing claim.
3. Write the product + SKU claim (as today) **and** (if present) the barcode
   claim `{ barcode: barcodeKey, productId, claimedBy, claimedAt }`.

## 4. `update` — generalize to move both claims

Rename `updateProductWithSku` → **`updateProductWithClaims`** with a signature
that carries both old/new SKU and old/new barcode:
```
updateProductWithClaims(
  id, input,
  { oldSku, newSku, skuChanged },
  { oldBarcode, newBarcode, barcodeChanged },
  actorId, actorName,
): Promise<void>
```
Outside the transaction (Firestore can't query inside): read variation children
(only when `skuChanged`). Inside `runTransaction` (reads-before-writes):
- **Reads:** the new SKU claim (if `skuChanged`) + the new barcode claim (if
  `barcodeChanged` and the new barcode is non-empty). Conflict (claim owned by
  another product) → `DuplicateSkuError` / `DuplicateBarcodeError`.
- **Writes:** `tx.update` the product (`updateData`); if `skuChanged`, relink
  children + delete old SKU claim + set new; if `barcodeChanged`, delete the old
  barcode claim (when the old was non-empty) + set the new (when the new is
  non-empty). Reject a doc-id-unsafe new barcode up front.

`useUpdateProduct` computes `barcodeChanged` (the form passes `oldBarcode`
alongside `oldSku`) and calls `updateProductWithClaims` when
`skuChanged || barcodeChanged`; otherwise the plain `update` (unchanged). It adds
a friendly `barcodeExists(newBarcode, id)` pre-check on change (the claim tx is
the real guard). `InventoryFormPage` passes `oldBarcode: target.barcode` in the
update payload; the existing SKU-rename confirm dialog is unchanged (barcode
changes need no confirm).

## 5. `barcodeExists` + create pre-check

`barcodeExists(barcode)` reads the claim:
```
const snap = await getDoc(doc(this.db, productBarcodes, normalizeBarcode(barcode)));
return snap.exists();
```
(`getByBarcode` keeps its `where('barcode','==',…)` *lookup* query — it returns
the product, not a uniqueness check.) `useCreateProduct` keeps its friendly
`barcodeExists` pre-check.

## 6. Testing & rollout
- **Unit-test `normalizeBarcode` + `isClaimableBarcode`** (vitest) in
  `src/domain/products/sku.test.ts` (trim, case-sensitivity, `/`/empty/`.`
  rejection).
- The repo transaction code is verified by **`npm run typecheck` + `npm run
  build` + manual** — the web has no Firestore-mock test infra (same as the web
  SKU slice C, which shipped that way).
- **Rollout:** re-run `scripts/backfill-product-barcodes.mjs` (claim any barcodes
  created since Slice A), then `cd web_admin && npm run build && firebase deploy
  --only hosting`. No `firestore.rules` change (shipped in Slice A).

## 7. Out of scope
- The web `barcode`→`barcodes[]` migration (still deferred).
- Touching `buildProductWrites` / the receiving engine.
- Any `products`-schema or rules change.

## 8. Risks
- **`updateProductWithClaims` signature change** ripples to `useUpdateProduct`
  and `InventoryFormPage` (must pass `oldBarcode`); covered by typecheck.
- **No web repo unit tests** for the transaction — manual smoke is essential:
  create two products with the same barcode (2nd blocked), edit a barcode onto a
  taken one (blocked), clear a barcode then reuse it on another product.
- **Cross-surface contract:** `normalizeBarcode` must equal the script's and
  Dart's `trim()` exactly.
