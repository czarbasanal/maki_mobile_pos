# SKU-uniqueness guard Slice A — rules + backfill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add the `product_skus` guard collection's Firestore rules and an idempotent Node backfill script that claims a `product_skus/{trim().toUpperCase()}` doc for every existing product, so slices B/C can enforce SKU uniqueness atomically.

**Architecture:** Rules block mirrors the `products` create principals (admin|staff). A standalone `firebase-admin` ESM script reads every product, create-if-absent its normalized claim, reports legacy case/dup collisions (no overwrite), and prints a `products==claims, collisions==0` reconciliation. **No app code changes** — purely additive (rules + data).

**Tech Stack:** Firestore security rules, Node 22 ESM + `firebase-admin`. Spec: `docs/superpowers/specs/2026-06-01-sku-guard-rules-backfill-design.md`.

**Production-affecting steps (Task 3) require explicit confirmation:** deploying rules and writing to the production `product_skus` collection.

---

## Context verified

- `firebase.json` → `firestore.rules`, project `maki-mobile-pos`, db `(default)`, location `asia-southeast1`. Deploy: `firebase deploy --only firestore:rules`.
- `firestore.rules` helpers exist: `isAdmin()`, `hasRole(role)`, `isValidUser()`, `isActiveUser()`. `products` create rule (the one to mirror) = `(isAdmin() || hasRole('staff')) && isActiveUser()`.
- The `match /databases/{database}/documents {` body closes with `  }` then `}` at the file end (after the `void_requests` block which ends `allow delete: if false; \n    }`).
- No `scripts/` dir yet. Node v22 available. Backfill auth = application-default creds.

## File Structure

**Modify:** `firestore.rules` (add `product_skus` block).
**Create:** `scripts/backfill-product-skus.mjs`, `scripts/package.json`, `scripts/README.md`.

---

## Task 1: Add the `product_skus` rules block

**Files:**
- Modify: `firestore.rules` (insert before the `documents` block close)

- [ ] **Step 1: Insert the block**

In `firestore.rules`, find the end of the last collection block (the `void_requests`
block) and the two closing braces of the `documents`/`service` blocks:

```
      // Audit trail — no deletes.
      allow delete: if false;
    }
  }
}
```

Replace it with (insert the `product_skus` block before the `  }`):

```
      // Audit trail — no deletes.
      allow delete: if false;
    }

    // SKU-uniqueness guard: one claim doc per in-use SKU
    // (key = normalizeSku(sku) = sku.trim().toUpperCase()). Reserved atomically in a
    // transaction by the product create / SKU-rename paths (slices B/C). Slice A only
    // declares the rules + backfills claims; no client enforces it yet.
    match /product_skus/{sku} {
      // The claim transaction's tx.get must succeed for any creator; no secrets here.
      allow read:   if isValidUser() && isActiveUser();
      // MIRROR the products create rule (admin OR staff) — admin-only here would
      // half-commit every staff product create (product written, claim denied).
      allow create: if (isAdmin() || hasRole('staff')) && isActiveUser();
      // Only an admin rename (frees old) or a hard delete frees a claim.
      allow delete: if isAdmin() && isActiveUser();
      // Claims are create/delete only — block update so a claim can't be repointed.
      allow update: if false;
    }
  }
}
```

- [ ] **Step 2: Verify the rules file is syntactically well-formed**

Run: `cd /Users/czar/Desktop/MAKI_Mobile_POS/maki_mobile_pos && grep -c "match /product_skus" firestore.rules`
Expected: `1`. (Full validation happens at deploy time in Task 3; there is no offline
linter — the deploy compiles the rules.)

- [ ] **Step 3: Commit**

```bash
git add firestore.rules
git commit -m "feat(rules): product_skus SKU-uniqueness guard collection (read valid, create admin|staff, delete admin, no update)"
```

---

## Task 2: Backfill script + package

**Files:**
- Create: `scripts/package.json`, `scripts/backfill-product-skus.mjs`, `scripts/README.md`

- [ ] **Step 1: Create the package manifest**

Create `scripts/package.json`:

```json
{
  "name": "maki-scripts",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "description": "One-off operational scripts (run manually).",
  "dependencies": {
    "firebase-admin": "^13.0.0"
  }
}
```

- [ ] **Step 2: Create the backfill script**

Create `scripts/backfill-product-skus.mjs`:

```js
// One-off, idempotent backfill for the SKU-uniqueness guard (Slice A).
// Claims a product_skus/{normalizeSku(sku)} doc for every product so slices B/C can
// enforce uniqueness atomically. Safe to re-run.
//
// Run:
//   cd scripts && npm install
//   gcloud auth application-default login        # OR export GOOGLE_APPLICATION_CREDENTIALS=<sa.json>
//   node backfill-product-skus.mjs
//
// Exit code 1 (and a printed report) if any SKUs collide on the normalized key —
// resolve those manually (rename one product) and re-run until collisions == 0.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const PROJECT_ID = 'maki-mobile-pos';

// Keep IDENTICAL to the Dart/TS normalizeSku in slices B/C: trim + uppercase.
function normalizeSku(s) {
  return String(s ?? '').trim().toUpperCase();
}

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

async function main() {
  const products = await db.collection('products').get();
  let newlyClaimed = 0;
  let alreadyOwned = 0;
  const collisions = [];

  for (const doc of products.docs) {
    const sku = doc.get('sku');
    const key = normalizeSku(sku);
    if (!key) {
      collisions.push({ key: '(empty)', productId: doc.id, sku, reason: 'empty/invalid sku' });
      continue;
    }
    const claimRef = db.collection('product_skus').doc(key);
    const existing = await claimRef.get();
    if (existing.exists) {
      if (existing.get('productId') === doc.id) {
        alreadyOwned += 1; // idempotent re-run
      } else {
        collisions.push({
          key,
          claimedProductId: existing.get('productId'),
          conflictingProductId: doc.id,
          skus: [existing.get('sku'), sku],
        });
      }
      continue;
    }
    await claimRef.create({
      sku,
      productId: doc.id,
      claimedBy: 'backfill',
      claimedAt: FieldValue.serverTimestamp(),
    });
    newlyClaimed += 1;
  }

  const claimsSnap = await db.collection('product_skus').get();
  console.log('--- product_skus backfill reconciliation ---');
  console.log(`products      = ${products.size}`);
  console.log(`claims        = ${claimsSnap.size}`);
  console.log(`newly claimed = ${newlyClaimed}`);
  console.log(`already owned = ${alreadyOwned}`);
  console.log(`collisions    = ${collisions.length}`);

  if (collisions.length) {
    console.log('\n!!! COLLISIONS — resolve manually before slices B/C go strict:');
    for (const c of collisions) console.log('  ' + JSON.stringify(c));
    console.log('\nFix: rename one of each colliding pair (or fix the empty SKU), then re-run.');
    process.exitCode = 1;
    return;
  }
  if (claimsSnap.size !== products.size) {
    console.log(`\nWARNING: claims (${claimsSnap.size}) != products (${products.size}). Investigate before going strict.`);
    process.exitCode = 1;
    return;
  }
  console.log('\nOK: every product has a unique claim. Backfill complete.');
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
```

- [ ] **Step 3: Create the README**

Create `scripts/README.md`:

```markdown
# Operational scripts

One-off scripts run manually against the live project. Not part of the app build.

## backfill-product-skus.mjs

Backfills the `product_skus` SKU-uniqueness guard collection (one claim doc per product,
keyed by `sku.trim().toUpperCase()`). Idempotent — safe to re-run.

**Prereq:** the `product_skus` rules block is deployed (`firebase deploy --only
firestore:rules`). The script uses the **admin SDK** (bypasses rules) but the rules must
exist before slices B/C ship.

**Auth (application-default credentials):**
- `gcloud auth application-default login`  — OR —
- `export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json`

**Run:**
```
cd scripts
npm install
node backfill-product-skus.mjs
```

Exit code 0 + "Backfill complete" when every product owns a unique claim. Exit code 1 +
a collision report if two SKUs normalize to the same key — rename one product and re-run.
```

- [ ] **Step 4: Commit**

```bash
git add scripts/package.json scripts/backfill-product-skus.mjs scripts/README.md
git commit -m "feat(scripts): idempotent product_skus backfill (claim + collision audit)"
```

---

## Task 3: Roll out (PRODUCTION-AFFECTING — confirm each step with the human)

> These steps deploy rules and write to the live `product_skus` collection. Do them only
> with explicit human go-ahead, and report the output verbatim. Do NOT run them as part of
> an automated batch.

- [ ] **Step 1: Deploy the rules** *(confirm first)*

Run: `cd /Users/czar/Desktop/MAKI_Mobile_POS/maki_mobile_pos && firebase deploy --only firestore:rules`
Expected: `✔ Deploy complete!` and the compiler accepts the `product_skus` block. If the
compiler rejects it, fix the rules and redeploy before proceeding.

- [ ] **Step 2: Install script deps**

Run: `cd /Users/czar/Desktop/MAKI_Mobile_POS/maki_mobile_pos/scripts && npm install`
Expected: `firebase-admin` installed (a `scripts/node_modules` + `scripts/package-lock.json`).
Add `scripts/node_modules/` to `.gitignore` if not already ignored, and commit the
`package-lock.json`.

- [ ] **Step 3: Authenticate + run the backfill** *(needs application-default creds)*

If creds aren't set up, the human runs `gcloud auth application-default login` first
(suggest `! gcloud auth application-default login` in the session). Then:

Run: `cd /Users/czar/Desktop/MAKI_Mobile_POS/maki_mobile_pos/scripts && node backfill-product-skus.mjs`
Expected: the reconciliation summary. **Slice A is done only when it prints
`collisions = 0` and `claims == products` ("Backfill complete").**

- [ ] **Step 4: Resolve collisions if any, then re-run**

If the report lists collisions (legacy SKUs that normalize equal, e.g. `abc` + `ABC`, or
empty SKUs), surface them to the human, rename one product of each pair (via the live app
or console), and re-run Step 3 until `collisions = 0`.

- [ ] **Step 5: Spot-check**

In the Firebase console (or a quick admin-SDK read), confirm a few `product_skus/{KEY}`
docs exist with the right `sku`/`productId`. Record the final `products`/`claims` counts.

---

## Self-Review notes (author)

- **Spec coverage:** §2 rules → Task 1; §3 backfill script + audit + reconciliation → Task 2; §3/§4 the run + collision resolution + verification → Task 3; §1 guard model + normalize (`trim().toUpperCase()`) → embedded in both. §7 acceptance (rules deploy, `collisions=0 & claims==products`, spot-check, no regressions) → Task 3.
- **Out of scope (slices B/C):** any client claim/move/free, variation retry, the `skuExists` → guard-doc switch.
- **No app code changes** → existing `flutter test` / web `vitest` suites are untouched (nothing to run for Tasks 1–2; Task 3 is operational).
- **`normalizeSku` consistency:** the script's `s.trim().toUpperCase()` must match the Dart/TS ports added in slices B/C — noted in the script comment.
- **Production gates:** Task 3's rules deploy + backfill run are explicitly human-confirmed and reported verbatim (CLAUDE.md: confirm before deploying rules / touching shared collections).
