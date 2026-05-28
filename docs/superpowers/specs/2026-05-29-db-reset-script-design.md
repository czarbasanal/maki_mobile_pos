# Database Reset Script — Design

**Date:** 2026-05-29
**Status:** Approved (pending spec review)

## Problem

Need a script to reset the Firestore database to a clean operational state — clearing
transactional history — while preserving users and configuration so the app stays usable.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Reset scope | **Transactions only.** Wipe operational history; keep users, settings, catalog, and managed lists. |
| Runner | **Node Admin SDK** (`firebase-admin` `recursiveDelete`), using a service-account key. |
| Target | Single project `maki-mobile-pos` (no separate dev project) — so strong guards are mandatory. |
| Who runs it | The developer, manually. **Claude builds & tests it only (emulator); never runs it against the live project.** |

## What it wipes vs keeps

**WIPE (the only collections the script ever deletes):**
- `sales` (and its `items` subcollection)
- `drafts`
- `receivings`
- `expenses`
- `daily_closings`
- `void_requests`
- `user_logs`

**KEEP (never referenced for deletion):**
- `users`
- `settings` (`cost_code_mapping`, `general`, `sale_counters`)
- `products` (and its `price_history` subcollection)
- `suppliers`
- `product_categories`, `expense_categories`, `units`, `void_reasons`

**Safety invariant:** the script iterates a hardcoded `WIPE_COLLECTIONS` list only. It
**never** enumerates "all collections," so anything not explicitly listed (including
collections added in the future) is structurally safe from deletion.

## Architecture

A small Node package `tools/reset-db/`, mirroring `tools/firestore-rules-test/`
(mocha + Firestore emulator, Node 22). Three units:

- **`lib/config.js`** — pure constants + confirmation helpers; no Firebase.
- **`lib/reset.js`** — `resetDatabase(db, opts)`; takes a Firestore instance (so it runs
  against the emulator in tests and against prod from the CLI).
- **`reset.js`** — the guarded CLI entry that wires credentials, prompts, and printing.

## Components

### `lib/config.js`

```js
const WIPE_COLLECTIONS = [
  'sales', 'drafts', 'receivings', 'expenses',
  'daily_closings', 'void_requests', 'user_logs',
];

const KEEP_COLLECTIONS = [
  'users', 'settings', 'products', 'suppliers',
  'product_categories', 'expense_categories', 'units', 'void_reasons',
];

// The exact phrase the operator must type to confirm a real run.
function confirmationToken(projectId) { return projectId; }
function isConfirmed(input, projectId) {
  return typeof input === 'string' && input.trim() === confirmationToken(projectId);
}

module.exports = { WIPE_COLLECTIONS, KEEP_COLLECTIONS, confirmationToken, isConfirmed };
```

### `lib/reset.js`

```js
async function resetDatabase(db, { dryRun = false } = {}) {
  const results = [];
  for (const name of WIPE_COLLECTIONS) {
    const col = db.collection(name);
    if (dryRun) {
      const count = (await col.count().get()).data().count;
      results.push({ collection: name, count, deleted: false });
    } else {
      await db.recursiveDelete(col); // handles subcollections (sales/items)
      results.push({ collection: name, deleted: true });
    }
  }
  return results;
}
```

- `recursiveDelete` (firebase-admin ≥ v10) deletes each collection's docs and all nested
  subcollections — covers `sales/{id}/items`.
- Pure relative to a passed-in `db` — emulator in tests, prod from the CLI.

### `reset.js` (CLI entry)

Behavior:
1. Parse flags: `--dry-run` (count only, never deletes), `--yes` (skip the interactive
   prompt for automation).
2. **Require** `GOOGLE_APPLICATION_CREDENTIALS` to be set → else print setup instructions
   and exit non-zero.
3. `admin.initializeApp({ credential: admin.credential.applicationDefault() })`; resolve
   the project ID (`admin.app().options.projectId` / credential).
4. Print prominently: the **project ID**, the WIPE list, and the KEEP list.
5. If `--dry-run`: run `resetDatabase(db, {dryRun:true})`, print per-collection counts,
   exit. No deletion.
6. Else (real run): unless `--yes`, prompt on stdin: *"Type the project id `<id>` to
   confirm permanent deletion:"*. Validate with `isConfirmed`. On mismatch → abort, exit
   non-zero. On match (or `--yes`): run `resetDatabase`, print per-collection progress and
   a final summary.
7. Wrap in try/catch; non-zero exit on error.

### `package.json`

- `dependencies`: `firebase-admin` (^12 or current).
- `devDependencies`: `mocha`, `firebase-tools` (for `emulators:exec`). The emulator test
  uses `firebase-admin` connected to the emulator (no `@firebase/rules-unit-testing`
  needed — that package is for rules testing, this is an admin-path test).
- `scripts`:
  - `reset`: `node reset.js`
  - `reset:dry`: `node reset.js --dry-run`
  - `test`: `firebase emulators:exec --only firestore --project demo-maki-pos 'mocha --timeout 20000'`

### `.gitignore`

`node_modules/`, `*-debug.log`, and **service-account key files** (e.g.
`serviceAccount*.json`, `*.serviceaccount.json`) so a downloaded key never gets committed.

### `README.md`

- Bold warning: **permanently deletes operational data; cannot be undone**.
- Setup: install deps; obtain a service-account key (Firebase console → Project settings →
  Service accounts → Generate new private key); `export GOOGLE_APPLICATION_CREDENTIALS=...`.
- Usage: `npm run reset:dry` first; then `npm run reset` and type the project id.
- The WIPE/KEEP tables.

## Testing (mocha, emulator)

- **`test/config.test.js`** (pure, no Firebase):
  - `WIPE_COLLECTIONS` deep-equals the expected transactional set.
  - `WIPE_COLLECTIONS` and `KEEP_COLLECTIONS` are disjoint.
  - `users`, `settings`, `products` are **not** in `WIPE_COLLECTIONS`.
  - `isConfirmed('maki-mobile-pos', 'maki-mobile-pos')` is true; wrong/empty/whitespace
    inputs are false.
- **`test/reset.test.js`** (firebase-admin against the emulator via `FIRESTORE_EMULATOR_HOST`
  set by `emulators:exec`):
  - Seed: a `sales/{id}` with an `items/{id}` subdoc, plus docs in `drafts`, `expenses`,
    `user_logs` (wipe set) AND in `users`, `settings`, `products` (keep set).
  - Run `resetDatabase(db, {dryRun:false})`.
  - Assert: every WIPE collection is empty, the `sales/{id}/items` subdoc is gone, and
    every seeded KEEP collection still has its doc.
  - Second case: `dryRun:true` deletes nothing (counts only) — seed one doc, dry-run,
    assert it still exists and the reported count is 1.

## Out of scope

- Wiping/resetting `users`, `settings`, catalog (`products`/`suppliers`), or managed lists.
- Re-seeding defaults after reset (separate concern; managed-list seeding already exists
  in-app under Manage Lists).
- Auth user deletion (Firebase Auth accounts) — only the `users` Firestore collection is
  in scope, and it is **kept**.
- Running the script against the live project (operator's manual action).
- A scheduled/automated reset.
