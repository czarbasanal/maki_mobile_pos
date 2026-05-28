# Database Reset Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A guarded Node Admin-SDK script that wipes the transactional Firestore collections (sales+items, drafts, receivings, expenses, daily_closings, void_requests, user_logs) while never touching users, settings, catalog, or managed lists.

**Architecture:** A new `tools/reset-db/` Node package (mirroring `tools/firestore-rules-test/`): a pure config/confirmation module, a `resetDatabase(db)` core using `firebase-admin` `recursiveDelete`, and a guarded CLI entry. The script only ever iterates a hardcoded WIPE list, so kept data is structurally safe. Tested with mocha — pure unit tests + a Firestore-emulator integration test.

**Tech Stack:** Node 22, `firebase-admin`, `firebase-tools` (emulator), mocha.

**Spec:** `docs/superpowers/specs/2026-05-29-db-reset-script-design.md`

### Conventions
- All paths are relative to the repo root; the package lives at `tools/reset-db/`.
- Run npm/node/mocha commands **from inside `tools/reset-db/`** (`cd tools/reset-db`).
- `firebase`/`mocha` resolve from `node_modules/.bin` inside npm scripts; for ad-hoc use, prefix `npx`.

---

## Task 1: Scaffold the package + pure config module

**Files:**
- Create: `tools/reset-db/package.json`
- Create: `tools/reset-db/.gitignore`
- Create: `tools/reset-db/firebase.json`
- Create: `tools/reset-db/firestore.rules.boot`
- Create: `tools/reset-db/lib/config.js`
- Test: `tools/reset-db/test/config.test.js`

- [ ] **Step 1: Create `package.json`**

`tools/reset-db/package.json`:

```json
{
  "name": "maki-reset-db",
  "version": "0.1.0",
  "private": true,
  "description": "Guarded Firestore reset — wipes transactional collections, keeps users + config.",
  "scripts": {
    "reset": "node reset.js",
    "reset:dry": "node reset.js --dry-run",
    "test:config": "mocha test/config.test.js --timeout 5000",
    "test": "firebase emulators:exec --only firestore --project demo-maki-pos 'mocha --timeout 20000'"
  },
  "dependencies": {
    "firebase-admin": "^12.7.0"
  },
  "devDependencies": {
    "firebase-tools": "^14.6.0",
    "mocha": "^11.0.1"
  }
}
```

- [ ] **Step 2: Create `.gitignore`**

`tools/reset-db/.gitignore`:

```gitignore
node_modules/
*-debug.log
firebase-debug.log
firestore-debug.log
.firebase/
# Never commit a service-account key
serviceAccount*.json
*serviceaccount*.json
*.serviceaccount.json
```

- [ ] **Step 3: Create the emulator config files**

`tools/reset-db/firebase.json`:

```json
{
  "emulators": {
    "firestore": { "port": 8080 },
    "ui": { "enabled": false }
  },
  "firestore": { "rules": "firestore.rules.boot" }
}
```

`tools/reset-db/firestore.rules.boot` (admin bypasses rules; this just satisfies the emulator's rules reference):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} { allow read, write: if true; }
  }
}
```

- [ ] **Step 4: Install dependencies**

Run: `cd tools/reset-db && npm install`
Expected: `node_modules/` populated; `firebase-admin`, `firebase-tools`, `mocha` resolve.

- [ ] **Step 5: Write the failing config test**

`tools/reset-db/test/config.test.js`:

```js
const assert = require('assert');
const {
  WIPE_COLLECTIONS,
  KEEP_COLLECTIONS,
  isConfirmed,
} = require('../lib/config');

describe('reset-db config', () => {
  it('WIPE_COLLECTIONS is exactly the transactional set', () => {
    assert.deepStrictEqual(WIPE_COLLECTIONS, [
      'sales',
      'drafts',
      'receivings',
      'expenses',
      'daily_closings',
      'void_requests',
      'user_logs',
    ]);
  });

  it('WIPE and KEEP are disjoint', () => {
    const overlap = WIPE_COLLECTIONS.filter((c) => KEEP_COLLECTIONS.includes(c));
    assert.deepStrictEqual(overlap, []);
  });

  it('never wipes users, settings, or products', () => {
    for (const safe of ['users', 'settings', 'products']) {
      assert.ok(!WIPE_COLLECTIONS.includes(safe), `${safe} must not be wiped`);
      assert.ok(KEEP_COLLECTIONS.includes(safe), `${safe} must be kept`);
    }
  });

  it('isConfirmed accepts only the exact project id (trimmed)', () => {
    assert.strictEqual(isConfirmed('maki-mobile-pos', 'maki-mobile-pos'), true);
    assert.strictEqual(isConfirmed('  maki-mobile-pos  ', 'maki-mobile-pos'), true);
    assert.strictEqual(isConfirmed('maki', 'maki-mobile-pos'), false);
    assert.strictEqual(isConfirmed('', 'maki-mobile-pos'), false);
    assert.strictEqual(isConfirmed(undefined, 'maki-mobile-pos'), false);
  });
});
```

- [ ] **Step 6: Run the test to verify it fails**

Run: `cd tools/reset-db && npm run test:config`
Expected: FAIL — `Cannot find module '../lib/config'`.

- [ ] **Step 7: Create `lib/config.js`**

`tools/reset-db/lib/config.js`:

```js
'use strict';

/**
 * The ONLY collections this tool ever deletes. The script never enumerates
 * "all collections", so anything absent here (now or in the future) is safe.
 */
const WIPE_COLLECTIONS = [
  'sales', // includes the `items` subcollection (recursiveDelete)
  'drafts',
  'receivings',
  'expenses',
  'daily_closings',
  'void_requests',
  'user_logs',
];

/** Documented for clarity + guard tests. Never referenced for deletion. */
const KEEP_COLLECTIONS = [
  'users',
  'settings',
  'products', // includes the `price_history` subcollection
  'suppliers',
  'product_categories',
  'expense_categories',
  'units',
  'void_reasons',
];

/** The exact phrase the operator must type to confirm a real run. */
function confirmationToken(projectId) {
  return projectId;
}

function isConfirmed(input, projectId) {
  return typeof input === 'string' && input.trim() === confirmationToken(projectId);
}

module.exports = { WIPE_COLLECTIONS, KEEP_COLLECTIONS, confirmationToken, isConfirmed };
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `cd tools/reset-db && npm run test:config`
Expected: PASS (4 tests).

- [ ] **Step 9: Commit**

```bash
git add tools/reset-db/package.json tools/reset-db/.gitignore tools/reset-db/firebase.json tools/reset-db/firestore.rules.boot tools/reset-db/lib/config.js tools/reset-db/test/config.test.js
git commit -m "chore(reset-db): scaffold package + pure config module"
```

---

## Task 2: `resetDatabase` core + emulator integration test

**Files:**
- Create: `tools/reset-db/lib/reset.js`
- Test: `tools/reset-db/test/reset.test.js`

- [ ] **Step 1: Write the failing emulator test**

`tools/reset-db/test/reset.test.js`:

```js
const assert = require('assert');
const admin = require('firebase-admin');
const { resetDatabase } = require('../lib/reset');

// Under `firebase emulators:exec`, FIRESTORE_EMULATOR_HOST is set, so the
// Admin SDK talks to the emulator. No credential needed for the emulator.
admin.initializeApp({ projectId: 'demo-maki-pos' });
const db = admin.firestore();

async function count(path) {
  const snap = await db.collection(path).count().get();
  return snap.data().count;
}

describe('resetDatabase (emulator)', () => {
  it('dry run reports counts and deletes nothing', async () => {
    await db.collection('drafts').doc('dry1').set({ x: 1 });

    const results = await resetDatabase(db, { dryRun: true });

    assert.strictEqual(await count('drafts'), 1, 'dry run must not delete');
    const drafts = results.find((r) => r.collection === 'drafts');
    assert.strictEqual(drafts.deleted, false);
    assert.ok(drafts.count >= 1);
  });

  it('wipes transactional collections + subcollections, keeps the rest', async () => {
    // Wipe set (incl. a sales/{id}/items subdoc)
    await db.collection('sales').doc('s1').set({ total: 100 });
    await db.collection('sales').doc('s1').collection('items').doc('i1').set({ qty: 2 });
    await db.collection('drafts').doc('d1').set({ x: 1 });
    await db.collection('expenses').doc('e1').set({ amount: 5 });
    await db.collection('user_logs').doc('l1').set({ action: 'Login' });
    // Keep set
    await db.collection('users').doc('u1').set({ name: 'Admin' });
    await db.collection('settings').doc('general').set({ k: 'v' });
    await db.collection('products').doc('p1').set({ sku: 'SKU1' });

    await resetDatabase(db, { dryRun: false });

    // Wipe set is empty, including the subcollection.
    for (const c of [
      'sales', 'drafts', 'receivings', 'expenses',
      'daily_closings', 'void_requests', 'user_logs',
    ]) {
      assert.strictEqual(await count(c), 0, `${c} should be empty`);
    }
    const itemsSnap = await db
      .collection('sales').doc('s1').collection('items').count().get();
    assert.strictEqual(itemsSnap.data().count, 0, 'sales/s1/items should be gone');

    // Keep set is intact.
    assert.strictEqual(await count('users'), 1);
    assert.strictEqual(await count('settings'), 1);
    assert.strictEqual(await count('products'), 1);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd tools/reset-db && npm test`
Expected: FAIL — `Cannot find module '../lib/reset'` (emulator boots, mocha errors on the missing module).

- [ ] **Step 3: Create `lib/reset.js`**

`tools/reset-db/lib/reset.js`:

```js
'use strict';

const { WIPE_COLLECTIONS } = require('./config');

/**
 * Resets the database by clearing every collection in WIPE_COLLECTIONS
 * (and their subcollections). With { dryRun: true } it only counts.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{ dryRun?: boolean, log?: (msg: string) => void }} [opts]
 * @returns {Promise<Array<{collection: string, count?: number, deleted: boolean}>>}
 */
async function resetDatabase(db, { dryRun = false, log = () => {} } = {}) {
  const results = [];
  for (const name of WIPE_COLLECTIONS) {
    const col = db.collection(name);
    if (dryRun) {
      const count = (await col.count().get()).data().count;
      log(`  [dry-run] ${name}: ${count} docs would be deleted`);
      results.push({ collection: name, count, deleted: false });
    } else {
      log(`  deleting ${name} ...`);
      await db.recursiveDelete(col); // removes docs + nested subcollections
      results.push({ collection: name, deleted: true });
    }
  }
  return results;
}

module.exports = { resetDatabase };
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd tools/reset-db && npm test`
Expected: PASS — both `reset.test.js` cases AND `config.test.js` (mocha runs all of `test/`) pass under the emulator.

- [ ] **Step 5: Commit**

```bash
git add tools/reset-db/lib/reset.js tools/reset-db/test/reset.test.js
git commit -m "feat(reset-db): resetDatabase core + emulator test"
```

---

## Task 3: Guarded CLI entry + README

**Files:**
- Create: `tools/reset-db/reset.js`
- Create: `tools/reset-db/README.md`

CLI behavior is verified manually (a dry-run against the emulator); no automated test for the prompt/credential wiring.

- [ ] **Step 1: Create the CLI entry**

`tools/reset-db/reset.js`:

```js
'use strict';

const readline = require('readline');
const admin = require('firebase-admin');
const { WIPE_COLLECTIONS, KEEP_COLLECTIONS, isConfirmed } = require('./lib/config');
const { resetDatabase } = require('./lib/reset');

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const skipPrompt = args.includes('--yes');
const usingEmulator = !!process.env.FIRESTORE_EMULATOR_HOST;

function fail(msg) {
  console.error(`\n✖ ${msg}\n`);
  process.exit(1);
}

function ask(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) =>
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer);
    }),
  );
}

async function main() {
  // Credentials / project resolution.
  let projectId;
  if (usingEmulator) {
    projectId = process.env.GCLOUD_PROJECT || 'demo-maki-pos';
    admin.initializeApp({ projectId });
  } else {
    if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      fail(
        'GOOGLE_APPLICATION_CREDENTIALS is not set.\n' +
          'Download a service-account key (Firebase console → Project settings →\n' +
          'Service accounts → Generate new private key) and:\n' +
          '  export GOOGLE_APPLICATION_CREDENTIALS=/abs/path/to/key.json',
      );
    }
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
    projectId =
      admin.app().options.projectId ||
      process.env.GOOGLE_CLOUD_PROJECT ||
      process.env.GCLOUD_PROJECT;
    if (!projectId) {
      fail('Could not resolve the project id. Set GOOGLE_CLOUD_PROJECT=<id>.');
    }
  }

  const db = admin.firestore();

  console.log('\n================ Firestore reset ================');
  console.log(`Project : ${projectId}${usingEmulator ? '  (EMULATOR)' : ''}`);
  console.log(`Mode    : ${dryRun ? 'DRY RUN (no deletes)' : 'LIVE DELETE'}`);
  console.log(`WIPE    : ${WIPE_COLLECTIONS.join(', ')}`);
  console.log(`KEEP    : ${KEEP_COLLECTIONS.join(', ')}`);
  console.log('=================================================\n');

  if (dryRun) {
    const results = await resetDatabase(db, { dryRun: true, log: (m) => console.log(m) });
    const total = results.reduce((n, r) => n + (r.count || 0), 0);
    console.log(`\nDry run complete — ${total} docs would be deleted. Nothing changed.\n`);
    process.exit(0);
  }

  if (!skipPrompt) {
    const answer = await ask(
      `This PERMANENTLY deletes the WIPE collections in "${projectId}".\n` +
        `Type the project id to confirm: `,
    );
    if (!isConfirmed(answer, projectId)) {
      fail('Confirmation did not match. Aborted — nothing deleted.');
    }
  }

  console.log('\nDeleting ...');
  await resetDatabase(db, { dryRun: false, log: (m) => console.log(m) });
  console.log('\n✓ Reset complete.\n');
  process.exit(0);
}

main().catch((e) => fail(`Reset failed: ${e.message || e}`));
```

- [ ] **Step 2: Create the README**

`tools/reset-db/README.md`:

````markdown
# reset-db

Resets the MAKI Firestore database to a clean operational state.

> ⚠️ **This permanently deletes data and cannot be undone.** Run `reset:dry` first.

## What it does

**Wipes** (and their subcollections): `sales` (+`items`), `drafts`, `receivings`,
`expenses`, `daily_closings`, `void_requests`, `user_logs`.

**Keeps** (never touched): `users`, `settings`, `products` (+`price_history`),
`suppliers`, `product_categories`, `expense_categories`, `units`, `void_reasons`.

## Setup

```bash
cd tools/reset-db
npm install
```

Get a service-account key: Firebase console → Project settings → Service accounts →
**Generate new private key**. Save it OUTSIDE the repo (or it's git-ignored here), then:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/key.json
# If the project id isn't picked up from the key:
export GOOGLE_CLOUD_PROJECT=maki-mobile-pos
```

## Usage

```bash
npm run reset:dry     # counts what WOULD be deleted; deletes nothing
npm run reset         # prompts: type the project id to confirm, then deletes
```

`--yes` skips the prompt (automation only — dangerous).

## Tests

```bash
npm run test:config   # pure unit tests (no emulator)
npm test              # runs all tests against the Firestore emulator
```
````

- [ ] **Step 3: Manual smoke (dry-run against the emulator)**

Run:
```bash
cd tools/reset-db && npx firebase emulators:exec --only firestore --project demo-maki-pos 'node reset.js --dry-run'
```
Expected: prints `Project : demo-maki-pos  (EMULATOR)`, `Mode : DRY RUN`, the WIPE/KEEP lists, per-collection `[dry-run] <name>: 0 docs`, and "Dry run complete — 0 docs ... Nothing changed." Exit 0, no prompt.

- [ ] **Step 4: Commit**

```bash
git add tools/reset-db/reset.js tools/reset-db/README.md
git commit -m "feat(reset-db): guarded CLI entry + README"
```

---

## Task 4: Full verification

- [ ] **Step 1: Run the package test suite**

Run: `cd tools/reset-db && npm test`
Expected: all mocha tests pass (config + reset) under the emulator.

- [ ] **Step 2: Confirm the key-ignore works**

Run: `cd tools/reset-db && printf '{}' > serviceAccount.json && git status --porcelain tools/reset-db/serviceAccount.json && rm serviceAccount.json`
Expected: **no output** from `git status` (the file is ignored). Then it's removed.

- [ ] **Step 3: Confirm no Flutter impact**

This package is isolated Node tooling under `tools/`; it does not touch `lib/` or `pubspec.yaml`. No `flutter analyze`/`flutter test` change expected. (Optional sanity: `git status` shows changes only under `tools/reset-db/` and `docs/`.)

- [ ] **Step 4: Do NOT run against the live project.** Running `npm run reset` against `maki-mobile-pos` is the operator's manual decision, outside this plan.

---

## Self-Review notes

- **Spec coverage:** WIPE/KEEP scope (T1 `config.js`); `resetDatabase` with `recursiveDelete` + dry-run (T2); guarded CLI with credential check, project echo, typed confirmation, `--dry-run`/`--yes`, emulator-awareness (T3); `.gitignore` for keys (T1); README warning + setup (T3); pure + emulator tests (T1, T2). All covered.
- **Safety invariant:** the only deletion path iterates `WIPE_COLLECTIONS`; `config.test.js` asserts it's disjoint from KEEP and excludes users/settings/products.
- **Emulator-awareness refinement (vs spec):** the CLI requires `GOOGLE_APPLICATION_CREDENTIALS` only for a real (non-emulator) run; when `FIRESTORE_EMULATOR_HOST` is set it initializes by project id so the dry-run smoke + tests need no key. This keeps the prod guard while making the tool testable.
- **Type/name consistency:** `WIPE_COLLECTIONS`, `KEEP_COLLECTIONS`, `isConfirmed`, `resetDatabase(db, {dryRun, log})` used identically across module, CLI, and tests.
- **`count()` + `recursiveDelete`:** both are firebase-admin Firestore APIs (admin ≥ v12) and work against the emulator.
