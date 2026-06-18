# Barcode Uniqueness Guard — Slice A (rules + backfill) — Design

**Date:** 2026-06-18
**Status:** Design — pending user review, then `writing-plans`.
**Surfaces:** Firestore rules + a Node backfill script. No app code (mobile/web
enforcement land in Slices B/C).

## 1. Problem & intent

Barcode uniqueness is enforced today by a **read-then-write `barcodeExists`
check** — a TOCTOU race (two products can claim the same barcode under
concurrency), and on mobile the check is explicitly *advisory*. This is the same
race the SKU guard closed for `sku`. We mirror that design for barcodes with a
deterministic keyed **claim** doc enforced in Firestore transactions.

This effort is **3 slices, like the SKU guard**:
- **A (this spec):** `product_barcodes` rules + backfill — the shared foundation.
- **B:** mobile claim guard (Dart transactions on create/update/delete).
- **C:** web claim guard (TS transactions).

Slice A declares the claim collection + rules and backfills a claim for every
existing barcode; **no client enforces it yet** (exactly like SKU Slice A).

### Decisions locked in brainstorming
- **Mirror the SKU-guard 3-slice shape, both surfaces.**
- **`normalizeBarcode(code) = code.trim()`** — case-sensitive, exact (barcodes
  are physical scanned tokens; mobile already matches them exactly).
- **One claim per distinct barcode**, **optional** (no barcode → no claim).
- **Claim kept on deactivate**; freed only by an admin rename (move) or a hard
  delete — matching the SKU guard.
- Production-affecting (additive `product_barcodes` collection + one rules
  block); confirmed.

## 2. Claim model

`product_barcodes/{normalizeBarcode(code)}` → `{ barcode, productId, claimedBy,
claimedAt }` (same shape as `product_skus`).

- **`normalizeBarcode(code) = String(code ?? '').trim()`** — the cross-surface
  contract Slices B (Dart) and C (TS) must reimplement **identically** (as
  `normalizeSku` is shared across surfaces).
- **Cardinality:** a product claims one doc per barcode it carries. Source of a
  product's barcode set:
  - mobile docs: the `barcodes` array **∪** a legacy singular `barcode` string;
  - web docs: the singular `barcode` string.
  The backfill reads the raw Firestore doc and unions both fields.
- **Optional:** empty/absent barcode → no claim (normal, not an error).
- **Doc-id safety:** a non-empty code that can't be a Firestore doc id (contains
  `/`, is `.`/`..`, matches `__.*__`, or > 1500 bytes) **cannot be claimed**;
  the backfill flags it as *invalid* (§4) so it's fixed before B/C. (Same
  reject-don't-encode stance as the SKU guard, which constrained SKUs to
  `[A-Za-z0-9-]`. Real shop barcodes are UPC/EAN digits, so this is rare.)

## 3. Firestore rules — mirror `product_skus`

Add a `product_barcodes` block alongside `product_skus` (firestore.rules), with
the **identical** policy:

```
match /product_barcodes/{barcode} {
  allow read:   if isValidUser() && isActiveUser();
  // Mirror the products create rule (admin OR staff) so a staff product create
  // doesn't half-commit (product written, claim denied).
  allow create: if (isAdmin() || hasRole('staff')) && isActiveUser();
  // Only an admin rename (frees old) or a hard delete frees a claim.
  allow delete: if isAdmin() && isActiveUser();
  // Claims are create/delete only — block update so a claim can't be repointed.
  allow update: if false;
}
```

Deploy: `firebase deploy --only firestore:rules`. No change to the `products`
rules.

## 4. Backfill — `scripts/backfill-product-barcodes.mjs`

A mirror of `scripts/backfill-product-skus.mjs` (firebase-admin ESM, ADC,
idempotent, `cd scripts && node backfill-product-barcodes.mjs`).

For each `products` doc, build its barcode set = `doc.barcodes` (array, if
present) **∪** `doc.barcode` (singular, if present); normalize each with
`normalizeBarcode`; dedupe within the product. For each (productId, key):
- key empty → skip (no barcode);
- key doc-id-unsafe → record **invalid**;
- claim `product_barcodes/{key}`: if it exists and `productId` matches → *already
  owned* (idempotent re-run); if it exists with a different `productId` →
  **collision**; else create the claim → *newly claimed*.

Prints a reconciliation report: `products · barcodes found · newly claimed ·
already owned · collisions · invalid`. **Exits 1** if any collision or invalid
code (resolve manually — rename/clear the offending barcode — and re-run until
clean), like the SKU backfill.

**Rollout invariant (carried to B/C):** the backfill is a point-in-time
snapshot. Re-run it right before shipping Slice B (mobile app build) and again
with Slice C (web deploy), since products created in between lack claims.

## 5. Testing & verification
- The backfill's `normalizeBarcode` + barcode-set union + collision/invalid
  classification are pure — unit-test them (Vitest in the script's package, or a
  small inline test), mirroring how the logic is verified. _(If the SKU backfill
  shipped without a unit test, match that: a careful dry-run report against prod
  is the verification.)_
- **Verification:** run the backfill against prod; confirm `collisions = 0,
  invalid = 0` and the claim count equals the distinct-barcode count.
- Deploy rules; confirm `firebase deploy --only firestore:rules` succeeds and the
  `products` write paths still work (no `products`-rule change).

## 6. Out of scope (this slice)
- **App enforcement** — the claim transactions on product create / barcode
  edit / delete (Slices B mobile, C web).
- The **web `barcodes[]` migration** (web stays singular `barcode`; it claims its
  one barcode).
- Barcode-claim freeing semantics beyond rename/delete; any `products` schema
  change.

## 7. Risks
- **Production write** to `product_barcodes` (additive) + a rules deploy. Mirrors
  the SKU Slice A, which shipped cleanly. No `products`-rule change.
- **Collisions** (two products already share a barcode) surface as a backfill
  failure to resolve manually — desirable (they're real data bugs the guard
  would otherwise block).
- **Cross-surface contract:** `normalizeBarcode` must be byte-identical in the
  script, Dart (B), and TS (C); call it out explicitly in B/C.
