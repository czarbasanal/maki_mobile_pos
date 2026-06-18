# Barcode Uniqueness Guard — Slice B (mobile) — Design

**Date:** 2026-06-18
**Surface:** Flutter mobile app (`lib/`). Web is Slice C.
**Status:** Design — pending user review, then `writing-plans`.
**Depends on:** Slice A (`product_barcodes` rules + backfill — DONE, deployed).

## 1. Problem & intent

Slice A created the `product_barcodes` claim collection + rules + backfill, but
**no client enforces it yet**. Mobile's barcode-uniqueness is still an *advisory*
`barcodeExists`-then-write check (TOCTOU race). Slice B makes mobile claim each
barcode in a Firestore transaction — exactly as Slice B of the SKU guard did for
`sku`, extended for barcodes being **optional** and **1:N** (a product carries a
`barcodes: List<String>`).

### Decisions locked in brainstorming
- **`normalizeBarcode(code) = code.trim()`** — case-sensitive (the cross-surface
  contract from Slice A; matches `backfill-product-barcodes.mjs`).
- **(a)** Cost **variations carry no barcodes** — `createVariation` clears them.
- **(b)** A product create is **all-or-nothing** across its SKU + every barcode
  (one transaction).
- **(c)** Claims are **kept on deactivate**; a barcode claim frees only when the
  barcode is removed from the product via an edit. Mobile has **no hard-delete**
  (only deactivate/reactivate), matching the SKU guard.

## 2. Helpers & types

- **`SkuGenerator.normalizeBarcode(String code) => code.trim();`** alongside
  `normalizeSku`. Plus a doc-id-safety predicate (a non-empty code is claimable
  only if it can be a Firestore doc id: no `/`, not `.`/`..`, not `__…__`,
  ≤ 1500 bytes). Empty/blank → no claim (optional barcode).
- **`DuplicateBarcodeException extends DuplicateEntryException`** (mirror
  `DuplicateSkuException`; `field: 'barcodes'`, `value: <code>`,
  `code: 'duplicate-barcode'`).
- **`_barcodesRef`** — `_firestore.collection(FirestoreCollections.productBarcodes)`
  (add the `productBarcodes = 'product_barcodes'` constant).

## 3. `createProduct` — claim all barcodes atomically

Replace the advisory barcode loop. Before the transaction, build the product's
**claimable barcode set**: `product.barcodes` → `normalizeBarcode` → drop empty →
dedupe; reject any non-empty code that fails the doc-id-safety check with a clear
`ValidationException` (mirrors the existing `isValidSku` reject).

Inside the existing SKU-claim `runTransaction` (reads-before-writes):
1. `tx.get` the SKU claim (existing) **and** `tx.get` each barcode claim.
2. If the SKU claim exists → `DuplicateSkuException`. If any barcode claim exists
   (and isn't this product) → `DuplicateBarcodeException(barcode: code)`.
3. `tx.set` the product, the SKU claim, **and** each barcode claim
   `{ barcode: code, productId: docRef.id, claimedBy, claimedAt }`.

Initial price history stays best-effort/unchanged.

## 4. `updateProduct` — diff the barcode set

Today the transaction runs only when `skuChanged`. Compute
`barcodesChanged = !setEquals(normalize(prior.barcodes), normalize(product.barcodes))`
and run the transaction when **`skuChanged || barcodesChanged`** (else the plain
`update` path, unchanged).

Pre-transaction (outside, since txns can't query): the existing variation-child
query (only when `skuChanged`). Compute `removed` and `added` barcode key sets
from prior vs new.

In the transaction (reads-before-writes):
- **Reads:** the new SKU claim (if `skuChanged`) + **each added** barcode claim.
  Conflict → `DuplicateSkuException` / `DuplicateBarcodeException`.
- **Writes:** `tx.update` the product; relink variation children + move the SKU
  claim (delete old / set new) if `skuChanged`; `tx.delete` each **removed**
  barcode claim (blind delete is valid after the reads); `tx.set` each **added**
  barcode claim.

Reject doc-id-unsafe **added** barcodes up front (as in create).

## 5. `createVariation` — carry no barcodes

`createVariation` copies the original via `copyWith` (which carries `barcodes`),
then calls `createProduct`. With claiming, that would self-collide on the base
product's barcodes. Fix: build the variation with **`barcodes: const []`** so it
claims none. (Semantically correct — a cost-variation is an internal product; the
manufacturer barcode belongs to the base item.) The `DuplicateSkuException`
retry loop is unchanged.

## 6. `barcodeExists` — read the claim

Replace the array-contains + legacy queries with a single claim read, mirroring
`skuExists`:
```
final snap = await _barcodesRef.doc(SkuGenerator.normalizeBarcode(barcode)).get();
if (!snap.exists) return false;
if (excludeProductId == null) return true;
return snap.data()?['productId'] != excludeProductId;
```
(`getProductByBarcode` is a *lookup* — keep its array-contains/legacy query; it
returns the product, not a uniqueness check.)

## 7. Lifecycle, testing, rollout

- **Deactivate/reactivate:** unchanged — claims kept. No hard-delete path.
- **Tests (`fake_cloud_firestore`), `flutter test`:**
  - create claims every barcode; a 2nd product with a shared barcode →
    `DuplicateBarcodeException`; the product+claims commit atomically.
  - edit: adding a barcode claims it (and blocks a dup); removing one frees it
    (reusable by another product); a no-op barcode set takes the plain path.
  - `createVariation` writes a product with empty `barcodes` and no barcode claim.
  - `barcodeExists` reads the claim (true when claimed, respects
    `excludeProductId`).
  - invalid barcode (`a/b`) on create/update → `ValidationException`.
  - `normalizeBarcode` is `trim()` (no uppercasing).
- **Rollout invariant:** re-run `scripts/backfill-product-barcodes.mjs` right
  before building/installing this app build (products created since Slice A
  ran lack claims). Ship = `flutter build apk --release` + manual install
  (agent builds; user installs — same as the SKU mobile slice).

## 8. Out of scope
- Web (Slice C). The web `barcode`→`barcodes[]` migration. Any `products`-schema
  or rules change (rules shipped in Slice A).

## 9. Risks
- **Transaction size / reads-before-writes:** a product with N barcodes adds N
  reads + N writes to the existing SKU/product transaction — far under Firestore's
  500-write limit for realistic barcode counts.
- **`createVariation` clearing barcodes** is a behavior change — but variations
  never *should* have carried the base's barcode; today no product has barcodes
  (backfill found 0), so there's no migration concern.
- **Cross-surface contract:** `normalizeBarcode` must equal the script's and
  (later) the web's `trim()` exactly.
