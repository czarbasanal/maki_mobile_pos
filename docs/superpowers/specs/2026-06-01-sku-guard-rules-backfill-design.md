# SKU-uniqueness guard — Slice A (rules + backfill) — Design

**Date:** 2026-06-01
**Status:** Approved (brainstorm complete; grounded by the `sku-guard-understand` workflow — 22 SKU-write paths + synthesis)
**Context:** Foundation for closing the `skuExists` TOCTOU (two concurrent creates of the
same SKU can both pass the read-then-write check). Full effort = **3 slices**:
**A — rules + backfill (this)** → **B — mobile guard** (claim in `createProduct`, move in
the SKU-rename batch, variation retry) → **C — web guard** (mirror in
`FirestoreProductRepository`). A is the deploy-gated, prod-data foundation B and C depend on.

## 1. The guard model

A `product_skus/{normalizedSku}` **claim document** — one per in-use SKU. Uniqueness is
enforced by **Firestore doc-id collision inside a `runTransaction`** (slices B/C), since
client transactions cannot run queries. Slice A only creates the collection's **rules**
and **backfills** a claim for every existing product; no client enforcement yet.

- **Doc id:** `normalizeSku(sku)` where **`normalizeSku(s) = s.trim().toUpperCase()`**
  (case-insensitive — user decision; stricter than today's case-sensitive `where sku == X`).
- **Payload:** `{ sku: <verbatim, original-case>, productId, claimedBy, claimedAt }`.
- The product's own `sku` field is **never re-cased**; only the guard key is normalized.

## 2. firestore.rules (production-affecting — confirm before deploy)

Add a top-level block, mirroring the **`products`** create principals so a staff product
create can also write its claim (else the product would commit but the claim would be
denied — a half-commit). Helpers (`isAdmin`/`hasRole`/`isValidUser`/`isActiveUser`) already
exist.

```
match /product_skus/{sku} {
  // The claim transaction's tx.get must succeed for any creator; the doc holds no secrets.
  allow read:   if isValidUser() && isActiveUser();
  // MIRROR products create (firestore.rules: products allows staff) — admin-only here would
  // half-commit every staff product create.
  allow create: if (isAdmin() || hasRole('staff')) && isActiveUser();
  // Only an admin rename (frees old) or hard delete frees a claim.
  allow delete: if isAdmin() && isActiveUser();
  // Claims are create/delete only; blocking update prevents repointing one claim to another.
  allow update: if false;
}
```

Deploy **before** any client (slice B/C) ships, or the first guarded claim is denied in
prod. **Backward-compatible:** existing clients don't write claims and are unaffected.
(The backfill itself uses the **admin SDK**, which bypasses rules, so it doesn't depend on
this deploy — but the deploy must precede B/C.)

## 3. Backfill script (one-off, idempotent) + audit

`scripts/backfill-product-skus.mjs` — a standalone Node ESM script using **`firebase-admin`**
with application-default credentials (admin SDK bypasses security rules). It:

1. Reads **every** product doc (`products` collection).
2. For each, computes `key = normalizeSku(product.sku)`.
3. **Create-if-absent** `product_skus/{key} = { sku, productId, claimedBy: 'backfill', claimedAt }`
   (uses `create()` semantics — does **not** overwrite an existing claim).
4. **Audit / collision report:** when `product_skus/{key}` already exists for a *different*
   `productId` (two legacy products whose SKUs normalize equal — e.g. `abc` + `ABC`, or a
   genuine pre-existing duplicate), it **skips the write** and appends
   `{ key, claimedProductId, conflictingProductId, skus: [...] }` to a printed report for
   **manual resolution** (no automatic data change to live products).
5. Prints a **reconciliation summary**: `products=N, claims=M, collisions=K`. Backfill is
   "complete" only when `K == 0` and `M == N` (every product owns a claim). Re-running is
   safe (idempotent).

The script is **operational, run once** by the user. Credentials: either
`gcloud auth application-default login` or a service-account JSON via
`GOOGLE_APPLICATION_CREDENTIALS`. A minimal `scripts/package.json` declares the
`firebase-admin` dependency (`cd scripts && npm install && node backfill-product-skus.mjs`).
The `normalizeSku` helper is defined inline in the script (slices B/C add the identical
`trim().toUpperCase()` in Dart/TS).

## 4. Two-phase rollout (A enables Phase A; B/C ship the guard)

- **Phase A (after A):** rules deployed, backfill run, **audit clean** (`collisions == 0`,
  `claims == products`). Slices B/C then **claim on write inside a transaction** *while
  keeping* the existing `skuExists` pre-query as a backstop, because both old and new
  collisions are covered during transition.
- **Phase B (strict, in B/C):** once `claims == products` is verified, the advisory
  existence check becomes a **guard-doc `getDoc(product_skus/{normalizeSku(sku)})`**
  (naturally case-insensitive, one fast read) and the transaction is the sole enforcer.

Slice A's deliverable is: rules block + backfill script + a **verified, collision-free
backfill run**. It must NOT be considered done until the run reports `collisions == 0` and
`claims == products` (resolving any legacy case-collisions manually first).

## 5. Scope / non-goals

In:
- The `product_skus` rules block + deploy.
- The backfill script + its run + audit resolution.

Out (slices B/C):
- Any client claim/move/free logic (mobile `createProduct`/rename transaction; web
  `create`/`updateProductWithSku` transaction; variation retry).
- Changing the `skuExists` pre-query to guard-based (Phase B, in B/C).
- Freeing claims on hard delete (B/C — and deletes are admin-only + rare).

Decisions carried in (from brainstorm):
- **Case-insensitive** normalization (`trim().toUpperCase()`).
- **Deactivate keeps the SKU reserved** — only a rename or hard delete frees a claim
  (slices B/C); soft-delete does nothing to the claim.

## 6. Testing / verification

- The backfill is operational; verified by its **reconciliation output** (`claims ==
  products`, `collisions == 0`) and a spot-check that a few `product_skus/{KEY}` docs exist
  with the right `productId`.
- Rules: deploy succeeds; a quick check that an admin/staff can read the collection and a
  non-admin can't delete (rules-level; manual or emulator spot-check).
- No client/app code changes in Slice A → existing `flutter test` / web `vitest` suites are
  untouched and must stay green.

## 7. Acceptance criteria

1. `firestore.rules` has the `product_skus` block (read valid+active, create admin|staff,
   delete admin, update false); `firebase deploy --only firestore:rules` succeeds.
2. `scripts/backfill-product-skus.mjs` runs idempotently and prints `products=N, claims=N,
   collisions=0` (after any legacy case-collisions are manually resolved).
3. Spot-check: `product_skus/{NORMALIZED}` exists for sampled products with the correct
   `sku`/`productId`.
4. No existing test suite regresses (Slice A is additive — rules + a script + data).

## 8. Resolved decisions

- Guard = `product_skus/{normalizeSku(sku)}`, `normalizeSku = trim().toUpperCase()`.
- Rules mirror `products` create principals (admin **or staff**), delete admin-only, update
  forbidden.
- Backfill = **Node admin script** (not a web button), idempotent, with a **manual-resolution
  audit** for legacy case/dup collisions.
- Two-phase rollout; the `skuExists` pre-query stays as a backstop through B/C and becomes
  advisory (guard-doc read) at Phase B.
- Deactivate never frees a claim.
