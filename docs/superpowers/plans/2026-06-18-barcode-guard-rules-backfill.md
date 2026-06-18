# Barcode Guard — Slice A (rules + backfill) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lay the shared foundation for barcode-uniqueness — a `product_barcodes` claim collection (Firestore rules) + an idempotent backfill that claims every existing barcode — so Slices B (mobile) and C (web) can enforce uniqueness in transactions.

**Architecture:** Mirror the SKU guard's Slice A exactly: a `product_barcodes/{normalizeBarcode(code)}` claim doc per in-use barcode, rules identical to `product_skus`, and a one-off `firebase-admin` backfill script. No app code — enforcement is B/C. This is an operational slice (a rules deploy + a script run), verified by the deploy succeeding and the backfill report being clean, not by unit tests (matching SKU Slice A).

**Tech Stack:** Firestore security rules, Node + `firebase-admin` (ESM, ADC), `firebase` CLI.

## Global Constraints

- **`normalizeBarcode(code) = String(code ?? '').trim()`** — case-sensitive, exact. MUST be byte-identical when reimplemented in Dart (Slice B) and TS (Slice C).
- **One claim per distinct barcode; optional** (no barcode → no claim). A product's barcode set = its `barcodes` array ∪ a legacy singular `barcode`.
- **Doc-id safety:** a non-empty code that can't be a Firestore doc id (contains `/`, is `.`/`..`, matches `__.*__`, or > 1500 bytes) is reported **invalid** (not claimed); resolve before B/C.
- **Production-affecting:** an additive `product_barcodes` rules block + a write to the new `product_barcodes` collection. No `products`-rule change.
- **Rollout invariant:** the backfill is point-in-time — re-run it right before shipping Slice B and again with Slice C.

---

## Task 1: `product_barcodes` Firestore rules block

**Files:**
- Modify: `firestore.rules` (add a `product_barcodes` match block immediately after the `product_skus` block)

**Interfaces:**
- Produces: a live `product_barcodes` rules policy (read: valid+active; create: admin|staff+active; delete: admin+active; update: false).

- [ ] **Step 1: Add the rules block**

In `firestore.rules`, immediately after the closing `}` of the `match /product_skus/{sku} { … }` block, add:

```
    // Barcode uniqueness claim (Slice A). One product_barcodes/{normalizeBarcode(code)}
    // doc per in-use barcode; enforced in transactions by the product create / barcode
    // edit paths (slices B/C). Slice A only declares the rules + backfills; no client
    // enforces it yet. Policy MIRRORS product_skus.
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

- [ ] **Step 2: Deploy the rules (production)**

Run: `firebase deploy --only firestore:rules`
Expected: `✔ Deploy complete!` (compiles + releases). The `products` write paths are unchanged, so existing create/update still works.

- [ ] **Step 3: Commit**

```bash
git add firestore.rules
git commit -m "feat(rules): product_barcodes claim collection (barcode guard slice A)"
```

---

## Task 2: `backfill-product-barcodes.mjs` + run

**Files:**
- Create: `scripts/backfill-product-barcodes.mjs`

**Interfaces:**
- Consumes: the deployed `product_barcodes` collection (Task 1); existing `products` docs (`barcodes[]` and/or legacy `barcode`).
- Produces: a claim doc per distinct in-use barcode; a reconciliation report; exit 1 on any collision or invalid code.

- [ ] **Step 1: Write the backfill script**

Create `scripts/backfill-product-barcodes.mjs` (mirror of `backfill-product-skus.mjs`, adapted for optional, multi-valued, trim-only barcodes):

```js
// One-off, idempotent backfill for the BARCODE-uniqueness guard (Slice A).
// Claims a product_barcodes/{normalizeBarcode(code)} doc for every in-use barcode
// (a product's `barcodes` array ∪ a legacy singular `barcode`) so slices B/C can
// enforce uniqueness atomically. Barcodes are OPTIONAL (no barcode → no claim).
// Safe to re-run.
//
// Run:
//   cd scripts && npm install
//   gcloud auth application-default login        # OR export GOOGLE_APPLICATION_CREDENTIALS=<sa.json>
//   node backfill-product-barcodes.mjs
//
// Exit code 1 (and a printed report) if any barcodes collide on the normalized key
// (two products share a code) or a code can't be a Firestore doc id — resolve those
// manually (rename/clear one) and re-run until collisions == 0 and invalid == 0.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const PROJECT_ID = 'maki-mobile-pos';

// Keep IDENTICAL to the Dart/TS normalizeBarcode in slices B/C: trim only
// (case-sensitive — barcodes are exact scanned tokens).
function normalizeBarcode(s) {
  return String(s ?? '').trim();
}

// Firestore doc-id constraints: non-empty, no '/', not '.'/'..', not __.*__, <=1500 bytes.
function isValidDocId(id) {
  return (
    id.length > 0 &&
    Buffer.byteLength(id, 'utf8') <= 1500 &&
    !id.includes('/') &&
    id !== '.' &&
    id !== '..' &&
    !/^__.*__$/.test(id)
  );
}

// A product's barcode set: the `barcodes` array ∪ a legacy singular `barcode`,
// normalized and de-duped by key.
function barcodeKeys(doc) {
  const raw = [];
  const arr = doc.get('barcodes');
  if (Array.isArray(arr)) raw.push(...arr);
  const legacy = doc.get('barcode');
  if (legacy != null) raw.push(legacy);
  const keys = new Set();
  for (const r of raw) {
    const key = normalizeBarcode(r);
    if (key) keys.add(key);
  }
  return [...keys];
}

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

async function main() {
  const products = await db.collection('products').get();
  let barcodesFound = 0;
  let newlyClaimed = 0;
  let alreadyOwned = 0;
  const collisions = [];
  const invalid = [];

  for (const doc of products.docs) {
    for (const key of barcodeKeys(doc)) {
      barcodesFound += 1;
      if (!isValidDocId(key)) {
        invalid.push({ key, productId: doc.id });
        continue;
      }
      const claimRef = db.collection('product_barcodes').doc(key);
      const existing = await claimRef.get();
      if (existing.exists) {
        if (existing.get('productId') === doc.id) {
          alreadyOwned += 1; // idempotent re-run
        } else {
          collisions.push({
            key,
            claimedProductId: existing.get('productId'),
            conflictingProductId: doc.id,
          });
        }
        continue;
      }
      await claimRef.create({
        barcode: key,
        productId: doc.id,
        claimedBy: 'backfill',
        claimedAt: FieldValue.serverTimestamp(),
      });
      newlyClaimed += 1;
    }
  }

  const claimsSnap = await db.collection('product_barcodes').get();
  console.log('--- product_barcodes backfill reconciliation ---');
  console.log(`products       = ${products.size}`);
  console.log(`barcodes found = ${barcodesFound}`);
  console.log(`claims         = ${claimsSnap.size}`);
  console.log(`newly claimed  = ${newlyClaimed}`);
  console.log(`already owned  = ${alreadyOwned}`);
  console.log(`collisions     = ${collisions.length}`);
  console.log(`invalid        = ${invalid.length}`);

  if (collisions.length || invalid.length) {
    if (collisions.length) {
      console.log('\n!!! COLLISIONS — two products share a barcode; resolve before B/C:');
      for (const c of collisions) console.log('  ' + JSON.stringify(c));
    }
    if (invalid.length) {
      console.log('\n!!! INVALID barcodes (cannot be a doc id) — fix/clear before B/C:');
      for (const i of invalid) console.log('  ' + JSON.stringify(i));
    }
    console.log('\nFix the offending products, then re-run.');
    process.exitCode = 1;
    return;
  }
  console.log('\nOK: every in-use barcode has a unique claim. Backfill complete.');
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
```

- [ ] **Step 2: Run the backfill (production)**

Run: `cd scripts && node backfill-product-barcodes.mjs`
Expected: a reconciliation report ending with `OK: every in-use barcode has a unique claim. Backfill complete.` and `collisions = 0`, `invalid = 0`. (ADC is already configured locally.)

- [ ] **Step 3: If collisions/invalid (exit 1) — resolve, don't force**

If the report lists collisions (two products with the same barcode) or invalid codes (e.g. containing `/`), fix the offending products (clear/rename the barcode in the app) and re-run until both are 0. Do **not** proceed to Slices B/C until clean. (No code change in this step.)

- [ ] **Step 4: Commit the script**

```bash
git add scripts/backfill-product-barcodes.mjs
git commit -m "feat(scripts): product_barcodes backfill (barcode guard slice A)"
```

---

## Self-review notes (author)

- **Spec coverage:** §2 claim model + normalize + doc-id safety → Task 2 (`normalizeBarcode`, `isValidDocId`, `barcodeKeys`); §3 rules → Task 1; §4 backfill (sources `barcodes[]` ∪ legacy `barcode`, reports collisions+invalid, idempotent, exit 1) → Task 2; §5 verification = deploy + clean report → Task 1 Step 2 + Task 2 Step 2. Covered.
- **Type/contract consistency:** `normalizeBarcode = trim()` matches the spec's cross-surface contract verbatim; the claim doc shape `{ barcode, productId, claimedBy, claimedAt }` matches `product_skus`. Rules policy is identical to `product_skus`.
- **Operational, not TDD:** no unit tests (matches SKU Slice A — the pure helpers are trivial; verification is the prod report). If a `scripts/` test runner is later added, `normalizeBarcode`/`isValidDocId`/`barcodeKeys` are the units to cover.
- **Order:** deploy rules (Task 1) before/independent of the backfill (Task 2 runs via admin SDK, which bypasses rules either way); both must be clean before Slices B/C.
