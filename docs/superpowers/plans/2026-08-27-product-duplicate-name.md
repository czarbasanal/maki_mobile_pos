# Product Duplicate-Name Detection + Variation Price Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the same part being saved twice under a new auto-SKU, by detecting a duplicate name+category at save time and offering to make it a cost variation instead — and let that variation carry the price the operator typed.

**Architecture:** One pure `productNameKey` helper, mirrored in Dart and TypeScript, sorts a name's words so word order stops mattering. Products gain a stored `nameKey` field so the two product forms can look a duplicate up with a single indexed query; the two receiving classifiers already hold every active product in memory and match with the same helper, needing no stored field. The form path gains a blocking three-way dialog. `VariationOptions` gains `price`; mobile's shared `createVariation` gains an **optional** `newPrice` so receiving keeps inheriting.

**Tech Stack:** Flutter/Dart (mobile), React + TypeScript + Vitest (web_admin), Firestore, Node ESM scripts.

**Spec:** `docs/superpowers/specs/2026-08-27-product-duplicate-name-design.md`

## Global Constraints

- **Receiving keeps inheriting the base price entirely.** No receiving path may pass a typed price into a variation. This is the single most important invariant in this plan — Task 7 pins it with a regression test.
- **Name matching is word-order-insensitive, plus an exact category match.** Punctuation stays inside tokens (`90/90-14`, `428-120l` must survive).
- **The duplicate dialog is a choice, never a hard block.** Two genuinely different parts may share a name; the operator must always be able to save anyway.
- **Dart and TS name-key implementations must agree.** Both test files carry the same vector table; changing one without the other is a bug.
- **No `firestore.rules` change.** Product `create` is not key-validated, and the staff-update guard forbids only `sku/price/cost/costCode/sellingOptions`. Do not edit or deploy rules in this plan.
- Run Flutter commands from the repo root, web commands from inside `web_admin/`.

---

## Task 1: Shared name-key helpers (pure)

**Files:**
- Create: `lib/core/utils/product_name_key.dart`
- Create: `web_admin/src/domain/products/nameKey.ts`
- Test: `test/core/utils/product_name_key_test.dart`
- Test: `web_admin/src/domain/products/nameKey.test.ts`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - Dart: `String productNameKey(String name)`, `String productDuplicateKey(String name, String? category)`
  - TS: `export function productNameKey(name: string): string`, `export function productDuplicateKey(name: string, category: string | null): string`

- [ ] **Step 1: Write the failing Dart test**

Create `test/core/utils/product_name_key_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/product_name_key.dart';

/// MIRRORED in web_admin/src/domain/products/nameKey.test.ts — the two
/// implementations must agree token for token. Change one, change both.
const sharedVectors = <List<String>>[
  ['BELT BANDO SKYDRIVE SPORT 115I', '115i bando belt skydrive sport'],
  ['CHAIN GLOBAL 428-120L', '428-120l chain global'],
  ['GLOBAL CHAIN 428-120L', '428-120l chain global'],
  ['TIRE TL MAXXIS MAV6 46P 90/90-14', '46p 90/90-14 maxxis mav6 tire tl'],
  ['  Yamalube   AT  Blue Core 10W-40  ', '10w-40 at blue core yamalube'],
];

void main() {
  group('productNameKey', () {
    test('agrees with the shared vector table', () {
      for (final v in sharedVectors) {
        expect(productNameKey(v[0]), v[1], reason: v[0]);
      }
    });

    test('word order does not matter', () {
      expect(
        productNameKey('CHAIN GLOBAL 428-120L'),
        productNameKey('GLOBAL CHAIN 428-120L'),
      );
    });

    test('keeps punctuation inside a token', () {
      // 90/90-14 is a tyre size — stripping the punctuation would merge
      // genuinely different sizes.
      expect(productNameKey('TIRE 90/90-14'), '90/90-14 tire');
      expect(productNameKey('TIRE 90/90-17'), '90/90-17 tire');
      expect(
        productNameKey('TIRE 90/90-14') == productNameKey('TIRE 90/90-17'),
        isFalse,
      );
    });

    test('empty and whitespace-only names collapse to empty', () {
      expect(productNameKey(''), '');
      expect(productNameKey('   '), '');
    });
  });

  group('productDuplicateKey', () {
    test('includes the category', () {
      expect(
        productDuplicateKey('BELT BANDO', 'CVT/TRANS'),
        'bando belt|cvt/trans',
      );
    });

    test('a null category is an empty segment, not the word null', () {
      expect(productDuplicateKey('BELT BANDO', null), 'bando belt|');
    });

    test('the same name in two categories does not collide', () {
      expect(
        productDuplicateKey('GASKET', 'ENGINE') ==
            productDuplicateKey('GASKET', 'BRAKES'),
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run the Dart test to verify it fails**

Run: `flutter test test/core/utils/product_name_key_test.dart`
Expected: FAIL — `Error when reading 'lib/core/utils/product_name_key.dart': No such file or directory`.

- [ ] **Step 3: Write the Dart implementation**

Create `lib/core/utils/product_name_key.dart`:

```dart
/// Word-order-insensitive product name key, for duplicate detection.
///
/// The catalog is full of terse part names whose word order drifts between
/// entries — "CHAIN GLOBAL 428-120L" and "GLOBAL CHAIN 428-120L" are the same
/// part. Sorting the tokens makes both collapse to one key.
///
/// Punctuation stays INSIDE tokens on purpose: `90/90-14` and `90/90-17` are
/// different tyre sizes, and `428-120l` is a chain length. Stripping it would
/// merge genuinely different products.
///
/// MIRRORED in web_admin/src/domain/products/nameKey.ts — keep in lock-step.
library;

/// Lowercased, whitespace-collapsed, token-sorted form of [name].
String productNameKey(String name) {
  final tokens = name
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList()
    ..sort();
  return tokens.join(' ');
}

/// The key two products must share to be considered the same item: the
/// name key plus an exact category match. A null/absent category is an
/// empty segment so it can never read as the literal word "null".
String productDuplicateKey(String name, String? category) =>
    '${productNameKey(name)}|${(category ?? '').trim().toLowerCase()}';
```

- [ ] **Step 4: Run the Dart test to verify it passes**

Run: `flutter test test/core/utils/product_name_key_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Write the failing TS test**

Create `web_admin/src/domain/products/nameKey.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { productDuplicateKey, productNameKey } from './nameKey';

// MIRRORED in test/core/utils/product_name_key_test.dart — the two
// implementations must agree token for token. Change one, change both.
const SHARED_VECTORS: [string, string][] = [
  ['BELT BANDO SKYDRIVE SPORT 115I', '115i bando belt skydrive sport'],
  ['CHAIN GLOBAL 428-120L', '428-120l chain global'],
  ['GLOBAL CHAIN 428-120L', '428-120l chain global'],
  ['TIRE TL MAXXIS MAV6 46P 90/90-14', '46p 90/90-14 maxxis mav6 tire tl'],
  ['  Yamalube   AT  Blue Core 10W-40  ', '10w-40 at blue core yamalube'],
];

describe('productNameKey', () => {
  it('agrees with the shared vector table', () => {
    for (const [input, expected] of SHARED_VECTORS) {
      expect(productNameKey(input)).toBe(expected);
    }
  });

  it('word order does not matter', () => {
    expect(productNameKey('CHAIN GLOBAL 428-120L')).toBe(
      productNameKey('GLOBAL CHAIN 428-120L'),
    );
  });

  it('keeps punctuation inside a token', () => {
    expect(productNameKey('TIRE 90/90-14')).toBe('90/90-14 tire');
    expect(productNameKey('TIRE 90/90-14')).not.toBe(productNameKey('TIRE 90/90-17'));
  });

  it('empty and whitespace-only names collapse to empty', () => {
    expect(productNameKey('')).toBe('');
    expect(productNameKey('   ')).toBe('');
  });
});

describe('productDuplicateKey', () => {
  it('includes the category', () => {
    expect(productDuplicateKey('BELT BANDO', 'CVT/TRANS')).toBe('bando belt|cvt/trans');
  });

  it('a null category is an empty segment, not the word null', () => {
    expect(productDuplicateKey('BELT BANDO', null)).toBe('bando belt|');
  });

  it('the same name in two categories does not collide', () => {
    expect(productDuplicateKey('GASKET', 'ENGINE')).not.toBe(
      productDuplicateKey('GASKET', 'BRAKES'),
    );
  });
});
```

- [ ] **Step 6: Run the TS test to verify it fails**

Run (from `web_admin/`): `npm run test -- nameKey --run`
Expected: FAIL — cannot resolve `./nameKey`.

- [ ] **Step 7: Write the TS implementation**

Create `web_admin/src/domain/products/nameKey.ts`:

```ts
// Word-order-insensitive product name key, for duplicate detection.
//
// The catalog is full of terse part names whose word order drifts between
// entries — "CHAIN GLOBAL 428-120L" and "GLOBAL CHAIN 428-120L" are the same
// part. Sorting the tokens makes both collapse to one key.
//
// Punctuation stays INSIDE tokens on purpose: 90/90-14 and 90/90-17 are
// different tyre sizes, and 428-120l is a chain length. Stripping it would
// merge genuinely different products.
//
// MIRRORED in lib/core/utils/product_name_key.dart — keep in lock-step.

/** Lowercased, whitespace-collapsed, token-sorted form of `name`. */
export function productNameKey(name: string): string {
  return name
    .toLowerCase()
    .split(/\s+/)
    .filter((t) => t.length > 0)
    .sort()
    .join(' ');
}

/**
 * The key two products must share to be considered the same item: the name
 * key plus an exact category match. A null/absent category is an empty
 * segment so it can never read as the literal string "null".
 */
export function productDuplicateKey(name: string, category: string | null): string {
  return `${productNameKey(name)}|${(category ?? '').trim().toLowerCase()}`;
}
```

- [ ] **Step 8: Run both suites to verify they pass**

Run (from `web_admin/`): `npm run test -- nameKey --run` → PASS (7 tests)
Run (repo root): `flutter test test/core/utils/product_name_key_test.dart` → PASS

- [ ] **Step 9: Commit**

```bash
git add lib/core/utils/product_name_key.dart test/core/utils/product_name_key_test.dart \
  web_admin/src/domain/products/nameKey.ts web_admin/src/domain/products/nameKey.test.ts
git commit -m "feat(products): word-order-insensitive name key, mirrored Dart/TS"
```

---

## Task 2: Web writes `nameKey` on create and rename

**Files:**
- Modify: `web_admin/src/data/products/productWrites.ts`
- Test: `web_admin/src/data/products/productWrites.test.ts` (extend)

**Interfaces:**
- Consumes: `productDuplicateKey` (Task 1).
- Produces: every product doc written by web carries `nameKey: string`.

- [ ] **Step 1: Write the failing test**

Append to `web_admin/src/data/products/productWrites.test.ts`:

```ts
describe('nameKey', () => {
  it('is written on create, word-order-insensitive with the category', () => {
    const w = buildProductWrites(db, input({ name: 'GLOBAL CHAIN 428-120L', category: 'CHAINS' }), 'u1', 'p1');
    expect(w.productData.nameKey).toBe('428-120l chain global|chains');
  });

  it('two word-order variants of one name produce the same key', () => {
    const a = buildProductWrites(db, input({ name: 'CHAIN GLOBAL 428-120L', category: 'CHAINS' }), 'u1', 'p1');
    const b = buildProductWrites(db, input({ name: 'GLOBAL CHAIN 428-120L', category: 'CHAINS' }), 'u1', 'p2');
    expect(a.productData.nameKey).toBe(b.productData.nameKey);
  });

  it('is rebuilt on a rename', () => {
    const data = buildProductUpdate({ name: 'GLOBAL CHAIN 428-120L', category: 'CHAINS' }, 'u1');
    expect(data.nameKey).toBe('428-120l chain global|chains');
  });

  it('is left alone when the name is not part of the update', () => {
    const data = buildProductUpdate({ price: 100 }, 'u1');
    expect(data.nameKey).toBeUndefined();
  });
});
```

Use the file's existing `db` and `input(...)` helpers; if it has none, mirror the helpers already used by the neighbouring `describe` blocks in that file.

- [ ] **Step 2: Run test to verify it fails**

Run (from `web_admin/`): `npm run test -- productWrites --run`
Expected: FAIL — `expected undefined to be '428-120l chain global|chains'`.

- [ ] **Step 3: Write the implementation**

In `productWrites.ts`, add the import:

```ts
import { productDuplicateKey } from '@/domain/products/nameKey';
```

In `buildProductWrites`, add one line to `productData`, immediately after `searchKeywords`:

```ts
      searchKeywords,
      // Indexed duplicate-detection key — see domain/products/nameKey.ts.
      nameKey: productDuplicateKey(input.name, input.category),
```

In `buildProductUpdate`, inside the existing `if (input.name !== undefined) { ... }` block that rebuilds `searchKeywords`, add after the `data.searchKeywords = ...` assignment:

```ts
    data.nameKey = productDuplicateKey(input.name, input.category ?? null);
```

- [ ] **Step 4: Run tests to verify they pass**

Run (from `web_admin/`): `npm run test -- productWrites --run`
Expected: PASS.

Run: `npm run typecheck && npm run test -- --run`
Expected: clean, full suite green.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/data/products/productWrites.ts web_admin/src/data/products/productWrites.test.ts
git commit -m "feat(products): web writes nameKey on create and rename"
```

---

## Task 3: Mobile writes `nameKey` on create and rename

**Files:**
- Modify: `lib/data/models/product_model.dart`
- Test: `test/data/models/product_model_test.dart` (extend; create if absent)

**Interfaces:**
- Consumes: `productDuplicateKey` (Task 1).
- Produces: every product doc written by mobile carries `nameKey: String`.

- [ ] **Step 1: Write the failing test**

Append to `test/data/models/product_model_test.dart` (create the file with the standard imports if it does not exist):

```dart
  group('nameKey', () {
    test('toMap writes a word-order-insensitive key with the category', () {
      final model = productModel(name: 'GLOBAL CHAIN 428-120L', category: 'CHAINS');
      expect(model.toMap()['nameKey'], '428-120l chain global|chains');
    });

    test('two word-order variants of one name produce the same key', () {
      final a = productModel(name: 'CHAIN GLOBAL 428-120L', category: 'CHAINS');
      final b = productModel(name: 'GLOBAL CHAIN 428-120L', category: 'CHAINS');
      expect(a.toMap()['nameKey'], b.toMap()['nameKey']);
    });

    test('toUpdateMap carries the key so a rename keeps it correct', () {
      final model = productModel(name: 'GLOBAL CHAIN 428-120L', category: 'CHAINS');
      expect(model.toUpdateMap('u1')['nameKey'], '428-120l chain global|chains');
    });
  });
```

Add a `productModel({required String name, String? category})` helper at the top of the file that builds a `ProductModel` with those two fields and benign defaults for the rest (sku `'00010001'`, cost `1`, price `2`, quantity `0`, unit `'pcs'`, `isActive: true`) — match the constructor's required parameters exactly.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/models/product_model_test.dart`
Expected: FAIL — `Expected: '428-120l chain global|chains'  Actual: <null>`.

- [ ] **Step 3: Write the implementation**

In `lib/data/models/product_model.dart`, add the import:

```dart
import 'package:maki_mobile_pos/core/utils/product_name_key.dart';
```

In `toMap`, add one entry to the map literal immediately after `'searchKeywords': searchKeywords,`:

```dart
      // Indexed duplicate-detection key — see core/utils/product_name_key.dart.
      'nameKey': productDuplicateKey(name, category),
```

`toUpdateMap` calls `copyWith(...).toMap(forUpdate: true)`, so it inherits the new key with no further change. The test in Step 1 pins that.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/models/product_model_test.dart` → PASS
Run: `flutter analyze && flutter test` → "No issues found!" and green.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/product_model.dart test/data/models/product_model_test.dart
git commit -m "feat(products): mobile writes nameKey on create and rename"
```

---

## Task 4: Backfill `nameKey` onto the existing catalog

**Files:**
- Create: `scripts/backfill-product-name-keys-lib.mjs`
- Create: `scripts/backfill-product-name-keys.mjs`
- Test: `scripts/backfill-product-name-keys-lib.test.mjs`
- Modify: `scripts/README.md`

**Interfaces:**
- Consumes: the `nameKey` field shape from Tasks 2 and 3.
- Produces: `productNameKey(name)`, `productDuplicateKey(name, category)`, `planNameKeyBackfill(products)`, `duplicateGroups(products)`.

**Why a third copy of the helper:** scripts are standalone Node ESM and cannot import from `web_admin/src` (path aliases, TS). The lib file carries its own copy, and its test uses the same shared vector table as Task 1 so all three stay in lock-step.

- [ ] **Step 1: Write the failing test**

Create `scripts/backfill-product-name-keys-lib.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  duplicateGroups,
  planNameKeyBackfill,
  productDuplicateKey,
  productNameKey,
} from './backfill-product-name-keys-lib.mjs';

// Same table as test/core/utils/product_name_key_test.dart and
// web_admin/src/domain/products/nameKey.test.ts.
const SHARED_VECTORS = [
  ['BELT BANDO SKYDRIVE SPORT 115I', '115i bando belt skydrive sport'],
  ['CHAIN GLOBAL 428-120L', '428-120l chain global'],
  ['GLOBAL CHAIN 428-120L', '428-120l chain global'],
  ['TIRE TL MAXXIS MAV6 46P 90/90-14', '46p 90/90-14 maxxis mav6 tire tl'],
  ['  Yamalube   AT  Blue Core 10W-40  ', '10w-40 at blue core yamalube'],
];

test('agrees with the shared vector table', () => {
  for (const [input, expected] of SHARED_VECTORS) {
    assert.equal(productNameKey(input), expected);
  }
});

test('duplicate key includes the category', () => {
  assert.equal(productDuplicateKey('BELT BANDO', 'CVT/TRANS'), 'bando belt|cvt/trans');
  assert.equal(productDuplicateKey('BELT BANDO', null), 'bando belt|');
});

test('plans a write for products whose key is missing or stale', () => {
  const plan = planNameKeyBackfill([
    // absent -> needs writing
    { id: 'a', name: 'CHAIN GLOBAL', category: 'CHAINS' },
    // already correct -> skipped
    { id: 'b', name: 'CHAIN GLOBAL', category: 'CHAINS', nameKey: 'chain global|chains' },
    // STALE: renamed since the key was written -> needs rewriting
    { id: 'c', name: 'CHAIN GLOBAL HEAVY', category: 'CHAINS', nameKey: 'chain global|chains' },
    // STALE: re-categorised since the key was written -> needs rewriting
    { id: 'd', name: 'CHAIN GLOBAL', category: 'DRIVETRAIN', nameKey: 'chain global|chains' },
  ]);
  assert.deepEqual(plan.map((p) => p.id), ['a', 'c', 'd']);
  assert.equal(plan.find((p) => p.id === 'c').nameKey, 'chain global heavy|chains');
  assert.equal(plan.find((p) => p.id === 'd').nameKey, 'chain global|drivetrain');
});

test('is idempotent — a second pass plans nothing', () => {
  const products = [{ id: 'a', name: 'CHAIN GLOBAL', category: 'CHAINS' }];
  const first = planNameKeyBackfill(products);
  const applied = products.map((p) => ({ ...p, nameKey: first[0].nameKey }));
  assert.deepEqual(planNameKeyBackfill(applied), []);
});

test('reports duplicate groups, largest first', () => {
  const groups = duplicateGroups([
    { id: '1', name: 'YAMALUBE 1L', category: 'OIL' },
    { id: '2', name: 'YAMALUBE 1L', category: 'OIL' },
    { id: '3', name: '1L YAMALUBE', category: 'OIL' },
    { id: '4', name: 'BELT BANDO', category: 'CVT' },
    { id: '5', name: 'UNIQUE PART', category: 'MISC' },
  ]);
  assert.equal(groups.length, 1);
  assert.equal(groups[0].members.length, 3);
});

test('does not group across categories', () => {
  const groups = duplicateGroups([
    { id: '1', name: 'GASKET', category: 'ENGINE' },
    { id: '2', name: 'GASKET', category: 'BRAKES' },
  ]);
  assert.deepEqual(groups, []);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test scripts/backfill-product-name-keys-lib.test.mjs`
Expected: FAIL — module not found.

- [ ] **Step 3: Write the implementation**

Create `scripts/backfill-product-name-keys-lib.mjs`:

```js
/**
 * Pure planners for backfill-product-name-keys.mjs.
 *
 * Third copy of the name-key helper by necessity: scripts are standalone Node
 * ESM and cannot import web_admin's TypeScript or the Flutter source. The test
 * shares its vector table with both other implementations so the three cannot
 * drift apart silently.
 */

/** Lowercased, whitespace-collapsed, token-sorted form of `name`. */
export function productNameKey(name) {
  return String(name ?? '')
    .toLowerCase()
    .split(/\s+/)
    .filter((t) => t.length > 0)
    .sort()
    .join(' ');
}

/** Name key plus an exact category match. */
export function productDuplicateKey(name, category) {
  return `${productNameKey(name)}|${String(category ?? '').trim().toLowerCase()}`;
}

/**
 * Products whose stored `nameKey` is missing or no longer matches their name
 * and category. Returning only the stale ones makes a re-run a no-op.
 */
export function planNameKeyBackfill(products) {
  const out = [];
  for (const p of products) {
    const nameKey = productDuplicateKey(p.name, p.category);
    if (p.nameKey !== nameKey) out.push({ id: p.id, nameKey, name: p.name });
  }
  return out;
}

/**
 * Products that already share a duplicate key, largest group first. This is a
 * report only — merging existing duplicates is deliberately out of scope.
 */
export function duplicateGroups(products) {
  const byKey = new Map();
  for (const p of products) {
    const key = productDuplicateKey(p.name, p.category);
    if (!byKey.has(key)) byKey.set(key, []);
    byKey.get(key).push(p);
  }
  return [...byKey.entries()]
    .filter(([, members]) => members.length > 1)
    .map(([key, members]) => ({ key, members }))
    .sort((a, b) => b.members.length - a.members.length);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test scripts/backfill-product-name-keys-lib.test.mjs`
Expected: PASS (6 tests).

- [ ] **Step 5: Write the runner**

Create `scripts/backfill-product-name-keys.mjs`, following `scripts/repair-preview-skus.mjs` exactly for the flag handling, the production confirmation prompt and the batched writes:

```js
// Backfills the `nameKey` duplicate-detection field onto every product, and
// reports the products that already share a name+category.
//
// nameKey is additive and unread until the duplicate-name feature ships, so
// this is safe to run before or after that deploy.
//
// Dry run:  node backfill-product-name-keys.mjs
// Execute:  node backfill-product-name-keys.mjs --execute
// Emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node backfill-product-name-keys.mjs --execute
//
// NOTE: this machine's IPv6 route is unreliable; if the run hangs or reports a
// bogus credentials error, prefix with
//   node --dns-result-order=ipv4first --no-network-family-autoselection
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { duplicateGroups, planNameKeyBackfill } from './backfill-product-name-keys-lib.mjs';

const PROJECT_ID = 'maki-mobile-pos';
const BATCH_SIZE = 400;

const execute = process.argv.includes('--execute');
const skipPrompt = process.argv.includes('--yes');
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
console.log(EMULATOR ? `TARGET: emulator (${EMULATOR})` : `TARGET: PRODUCTION (${PROJECT_ID})`);

const snap = await db.collection('products').get();
const products = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
console.log(`\nfound ${products.length} products`);

const plan = planNameKeyBackfill(products);
console.log(`products needing a nameKey write: ${plan.length}`);

const groups = duplicateGroups(products);
console.log(`\n--- existing duplicate name+category groups: ${groups.length} ---`);
for (const g of groups) {
  console.log(`  ${g.members.length}x  ${g.members.map((m) => m.sku ?? m.id).join('  vs  ')}   "${g.members[0].name}"`);
}
console.log('(report only — merging these is a separate job)');

if (!execute) {
  console.log('\nDRY RUN — nothing written. Re-run with --execute to apply.');
  process.exit(0);
}
if (plan.length === 0) {
  console.log('\nNothing to backfill. Exiting.');
  process.exit(0);
}

if (!EMULATOR && !skipPrompt) {
  process.stdout.write(`\nIrreversible update to PRODUCTION. Type the project id (${PROJECT_ID}) to confirm: `);
  const line = await new Promise((resolve, reject) => {
    let buf = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => {
      buf += chunk;
      const nl = buf.indexOf('\n');
      if (nl !== -1) { process.stdin.pause(); resolve(buf.slice(0, nl).trim()); }
    });
    process.stdin.on('end', () => { process.stdin.pause(); reject(new Error('stdin closed — use --yes for non-interactive runs')); });
    process.stdin.resume();
  }).catch((err) => { console.error(err.message); process.exit(1); });
  if (line !== PROJECT_ID) {
    console.error('Confirmation mismatch — aborting. Nothing written.');
    process.exit(1);
  }
}

console.log(`\nwriting ${plan.length} patches in batches of ${BATCH_SIZE}...`);
for (let i = 0; i < plan.length; i += BATCH_SIZE) {
  const batch = db.batch();
  const slice = plan.slice(i, i + BATCH_SIZE);
  for (const p of slice) batch.update(db.collection('products').doc(p.id), { nameKey: p.nameKey });
  await batch.commit();
  console.log(`committed batch ${Math.floor(i / BATCH_SIZE) + 1} (${slice.length} docs)`);
}
console.log(`\nBackfill complete. ${plan.length} products updated.`);
```

- [ ] **Step 6: Dry-run against production and document**

Run: `node --dns-result-order=ipv4first --no-network-family-autoselection scripts/backfill-product-name-keys.mjs`
Expected: reports ~1,625 products, ~1,625 needing a write, and roughly 37 duplicate groups. Writes nothing.

Add a `## backfill-product-name-keys.mjs` section to `scripts/README.md` describing the flags, the idempotence, and that the duplicate list is a report only.

- [ ] **Step 7: Commit**

```bash
git add scripts/backfill-product-name-keys.mjs scripts/backfill-product-name-keys-lib.mjs \
  scripts/backfill-product-name-keys-lib.test.mjs scripts/README.md
git commit -m "chore(products): nameKey backfill script + duplicate report"
```

---

## Task 5: Web repository — `findByNameKey` and a variation that carries price

**Files:**
- Modify: `web_admin/src/domain/repositories/ProductRepository.ts`
- Modify: `web_admin/src/domain/products/costVariation.ts`
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts`
- Test: `web_admin/src/domain/products/costVariation.test.ts` (extend)

**Interfaces:**
- Consumes: `productDuplicateKey` (Task 1); `nameKey` on the doc (Task 2).
- Produces:
  - `ProductRepository.findByNameKey(key: string): Promise<Product | null>`
  - `VariationOptions` gains `price: number`
  - `ProductRepository.createVariation(existing, opts: { cost: number; costCode: string; price: number; actorId: string; actorName: string | null })`

- [ ] **Step 1: Write the failing test**

Append to `web_admin/src/domain/products/costVariation.test.ts`:

```ts
describe('variation price', () => {
  it('uses the typed price rather than inheriting the base', () => {
    const input = buildVariationInput(product({ price: 250 }), {
      cost: 120,
      costCode: 'NBS',
      price: 300,
      variationNumber: 1,
      actorId: 'u1',
      actorName: 'U',
    });
    expect(input.price).toBe(300);
  });

  it('still inherits everything descriptive', () => {
    const base = product({ name: 'BELT BANDO', unit: 'pcs', category: 'CVT', price: 250 });
    const input = buildVariationInput(base, {
      cost: 120, costCode: 'NBS', price: 300, variationNumber: 1, actorId: 'u1', actorName: 'U',
    });
    expect(input.name).toBe('BELT BANDO');
    expect(input.unit).toBe('pcs');
    expect(input.category).toBe('CVT');
    expect(input.quantity).toBe(0);
    expect(input.barcodes).toEqual([]);
  });
});
```

Use the file's existing `product(...)` fixture helper.

- [ ] **Step 2: Run test to verify it fails**

Run (from `web_admin/`): `npm run test -- costVariation --run`
Expected: FAIL — TypeScript rejects the unknown `price` property, and `input.price` is 250.

- [ ] **Step 3: Write the implementation**

In `costVariation.ts`, add `price` to the options and use it:

```ts
export interface VariationOptions {
  cost: number;
  costCode: string;
  /** The SRP typed on the form. Receiving never routes through here — it
   *  builds its own product input and keeps inheriting the base price. */
  price: number;
  variationNumber: number;
  actorId: string;
  actorName: string | null;
}
```

and in `buildVariationInput`, replace `price: existing.price,` with:

```ts
    price: opts.price,
```

In `ProductRepository.ts`, widen the `createVariation` opts and add the lookup:

```ts
  createVariation(
    existing: Product,
    opts: { cost: number; costCode: string; price: number; actorId: string; actorName: string | null },
  ): Promise<Product>;

  /** The active product sharing this duplicate key, or null. Key comes from
   *  `productDuplicateKey(name, category)`. */
  findByNameKey(key: string): Promise<Product | null>;
```

In `FirestoreProductRepository.ts`, implement the lookup next to `findBySkuClaim`:

```ts
  async findByNameKey(key: string): Promise<Product | null> {
    const snap = await getDocs(
      query(this.col(), where('nameKey', '==', key), where('isActive', '==', true), limit(1)),
    );
    return snap.empty ? null : snap.docs[0].data();
  }
```

Add `limit` to the existing `firebase/firestore` import if it is not already there.

- [ ] **Step 4: Run tests to verify they pass**

Run (from `web_admin/`): `npm run test -- costVariation --run` → PASS
Run: `npm run typecheck`

Expected: typecheck FAILS in `InventoryFormPage.tsx`, because `createVariation` now needs a `price`. That is the deliberate compile break Task 6 closes. Record the error list.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/repositories/ProductRepository.ts \
  web_admin/src/domain/products/costVariation.ts \
  web_admin/src/domain/products/costVariation.test.ts \
  web_admin/src/data/repositories/FirestoreProductRepository.ts
git commit -m "feat(products): findByNameKey + variations carry their own price"
```

---

## Task 6: Web form — duplicate-name dialog

**Files:**
- Modify: `web_admin/src/presentation/features/inventory/InventoryFormPage.tsx`
- Test: `web_admin/src/presentation/features/inventory/InventoryFormPage.test.tsx` (extend)

**Interfaces:**
- Consumes: `productDuplicateKey` (Task 1); `findByNameKey`, `createVariation` with `price` (Task 5).
- Produces: no new exports.

- [ ] **Step 1: Write the failing test**

Append to `InventoryFormPage.test.tsx`, matching the file's existing harness:

```tsx
describe('duplicate name detection', () => {
  it('stops the save and offers a choice when name+category already exist', async () => {
    const findByNameKey = vi.fn(async () => product({ name: 'BELT BANDO', category: 'CVT', sku: '00020152', cost: 120, price: 250 }));
    const create = vi.fn();
    harness({ findByNameKey, create });

    await fillForm({ name: 'BANDO BELT', category: 'CVT', cost: '130', price: '300' });
    await userEvent.click(screen.getByRole('button', { name: /save/i }));

    expect(await screen.findByText(/already exists/i)).toBeInTheDocument();
    expect(create).not.toHaveBeenCalled();
  });

  it('makes a variation carrying the typed cost and price', async () => {
    const existing = product({ name: 'BELT BANDO', category: 'CVT', sku: '00020152', cost: 120, price: 250 });
    const findByNameKey = vi.fn(async () => existing);
    const createVariation = vi.fn(async () => existing);
    harness({ findByNameKey, createVariation });

    await fillForm({ name: 'BANDO BELT', category: 'CVT', cost: '130', price: '300' });
    await userEvent.click(screen.getByRole('button', { name: /save/i }));
    await userEvent.click(await screen.findByRole('button', { name: /make it a variation/i }));

    await waitFor(() => expect(createVariation).toHaveBeenCalledTimes(1));
    expect(createVariation.mock.calls[0][1]).toMatchObject({ cost: 130, price: 300 });
  });

  it('saves a separate product when the operator says they are different', async () => {
    const findByNameKey = vi.fn(async () => product({ name: 'BELT BANDO', category: 'CVT' }));
    const create = vi.fn(async () => product({}));
    harness({ findByNameKey, create });

    await fillForm({ name: 'BANDO BELT', category: 'CVT', cost: '130', price: '300' });
    await userEvent.click(screen.getByRole('button', { name: /save/i }));
    await userEvent.click(await screen.findByRole('button', { name: /separate product/i }));

    await waitFor(() => expect(create).toHaveBeenCalledTimes(1));
  });

  it('writes nothing when the operator cancels', async () => {
    const findByNameKey = vi.fn(async () => product({ name: 'BELT BANDO', category: 'CVT' }));
    const create = vi.fn();
    const createVariation = vi.fn();
    harness({ findByNameKey, create, createVariation });

    await fillForm({ name: 'BANDO BELT', category: 'CVT', cost: '130', price: '300' });
    await userEvent.click(screen.getByRole('button', { name: /save/i }));
    await userEvent.click(await screen.findByRole('button', { name: /cancel/i }));

    expect(create).not.toHaveBeenCalled();
    expect(createVariation).not.toHaveBeenCalled();
  });

  it('saves straight through when no duplicate exists', async () => {
    const findByNameKey = vi.fn(async () => null);
    const create = vi.fn(async () => product({}));
    harness({ findByNameKey, create });

    await fillForm({ name: 'BRAND NEW PART', category: 'CVT', cost: '130', price: '300' });
    await userEvent.click(screen.getByRole('button', { name: /save/i }));

    await waitFor(() => expect(create).toHaveBeenCalledTimes(1));
    expect(screen.queryByText(/already exists/i)).not.toBeInTheDocument();
  });
});
```

Add a `fillForm(...)` helper to the file if one does not already exist, filling the name, category, cost and price inputs by their labels.

- [ ] **Step 2: Run tests to verify they fail**

Run (from `web_admin/`): `npm run test -- InventoryFormPage --run`
Expected: FAIL — no dialog appears and `create` is called.

- [ ] **Step 3: Write the implementation**

Add the import:

```tsx
import { productDuplicateKey } from '@/domain/products/nameKey';
```

Add state beside the existing `variationDialog` state:

```tsx
  const [dupDialog, setDupDialog] = useState<{
    open: boolean;
    existing: Product | null;
    values: FormValues | null;
  }>({ open: false, existing: null, values: null });
```

Add the pre-create gate. In the submit handler, before the create call:

```tsx
    // Duplicate NAME gate. Runs before create, unlike the SKU gate which can
    // only fire after Firestore rejects a claim — the auto-SKU flow never
    // produces a SKU collision, which is why duplicates accumulated.
    const dupKey = productDuplicateKey(values.name, values.category ?? null);
    let dupExisting: Product | null = null;
    try {
      dupExisting = await repo.findByNameKey(dupKey);
    } catch {
      // A failed lookup must never block a legitimate save.
      dupExisting = null;
    }
    if (dupExisting && dupExisting.id !== editingProductId) {
      setDupDialog({ open: true, existing: dupExisting, values });
      return;
    }
```

`editingProductId` is the id of the product being edited, or `undefined` when creating — the guard stops an edit flagging itself. Use whatever the file already calls that value.

Render the dialog next to the existing variation dialog, reusing the same `Dialog` component:

```tsx
      <Dialog
        open={dupDialog.open}
        onClose={() => setDupDialog({ open: false, existing: null, values: null })}
        title="A product with this name already exists"
      >
        <div className="space-y-tk-md">
          <p className="text-bodySmall text-light-text">
            “{dupDialog.existing?.name}” ({displaySku(dupDialog.existing?.sku ?? '')}) is already
            on file in {dupDialog.existing?.category ?? 'no category'}, at a cost of ₱
            {dupDialog.existing?.cost.toFixed(2)} and selling at ₱
            {dupDialog.existing?.price.toFixed(2)}.
          </p>
          <p className="text-bodySmall text-light-text-secondary">
            If this is the same part at a new cost, make it a variation — it keeps one item on
            the shelf and one stock history. If it is genuinely a different part, save it
            separately.
          </p>
          <div className="flex flex-wrap justify-end gap-tk-sm">
            <button
              type="button"
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall"
              onClick={() => setDupDialog({ open: false, existing: null, values: null })}
            >
              Cancel
            </button>
            <button
              type="button"
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall"
              onClick={async () => {
                const v = dupDialog.values;
                setDupDialog({ open: false, existing: null, values: null });
                if (v) await submitCreate(v);
              }}
            >
              Save as a separate product
            </button>
            <button
              type="button"
              className="rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background"
              onClick={async () => {
                const { existing, values: v } = dupDialog;
                setDupDialog({ open: false, existing: null, values: null });
                if (!existing || !v) return;
                await createVariation.mutateAsync({
                  existing,
                  cost: Number(v.cost),
                  costCode: encodeCostCode(cipher, Number(v.cost)),
                  price: Number(v.price),
                });
              }}
            >
              Make it a variation
            </button>
          </div>
        </div>
      </Dialog>
```

`submitCreate(values)` is the existing create path extracted so the dialog can call it after the gate; if the file inlines that logic in the submit handler, extract it into a named function first and have both callers use it. `encodeCostCode` and `cipher` are already used by this file for the SKU-collision variation path — reuse the same expressions.

Finally, pass the price through the existing SKU-collision path too, so both routes agree. In the variation dialog's confirm handler, add `price: Number(getValues('price'))` to the `createVariation.mutateAsync({...})` call, and update the `useCreateVariation` hook's argument type to include `price: number`.

- [ ] **Step 4: Run tests to verify they pass**

Run (from `web_admin/`): `npm run test -- InventoryFormPage --run` → PASS
Run: `npm run typecheck && npm run test -- --run && npm run build`
Expected: clean, full suite green, build clean. The Task 5 compile break is now closed.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/presentation/features/inventory/InventoryFormPage.tsx \
  web_admin/src/presentation/features/inventory/InventoryFormPage.test.tsx \
  web_admin/src/presentation/hooks/useProductMutations.ts
git commit -m "feat(inventory): duplicate-name gate on the web product form"
```

---

## Task 7: Mobile repository — name lookup and an optional variation price

**Files:**
- Modify: `lib/domain/repositories/product_repository.dart`
- Modify: `lib/data/repositories/product_repository_impl.dart`
- Test: `test/data/repositories/product_repository_variation_test.dart` (create)

**Interfaces:**
- Consumes: `productDuplicateKey` (Task 1); `nameKey` on the doc (Task 3).
- Produces:
  - `Future<ProductEntity?> getProductByNameKey(String nameKey)`
  - `createVariation({required ProductEntity originalProduct, required double newCost, required String newCostCode, double? newPrice, required String createdBy, String? createdByName})`

**The optional price is load-bearing.** `createVariation` is called by the mobile form **and** by `lib/data/repositories/receiving_repository_impl.dart:298`. A required parameter would silently change receiving, which this plan must not do.

- [ ] **Step 1: Write the failing test**

Create `test/data/repositories/product_repository_variation_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/product_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProductRepositoryImpl repo;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repo = ProductRepositoryImpl(firestore: firestore);
    await firestore.collection('products').doc('base1').set({
      'sku': '00020152',
      'name': 'BELT BANDO SKYDRIVE',
      'category': 'CVT',
      'nameKey': 'bando belt skydrive|cvt',
      'cost': 120.0,
      'price': 250.0,
      'quantity': 5,
      'reorderLevel': 0,
      'unit': 'pcs',
      'isActive': true,
      'costCode': 'NBS',
      'barcodes': <String>[],
      'searchKeywords': <String>[],
      'sellingOptions': <Map<String, dynamic>>[],
    });
  });

  test('getProductByNameKey finds an active product by its key', () async {
    final found = await repo.getProductByNameKey('bando belt skydrive|cvt');
    expect(found?.sku, '00020152');
  });

  test('getProductByNameKey returns null when nothing matches', () async {
    expect(await repo.getProductByNameKey('nothing|here'), isNull);
  });

  test('createVariation uses the given price when one is passed', () async {
    final base = (await repo.getProductByNameKey('bando belt skydrive|cvt'))!;
    final v = await repo.createVariation(
      originalProduct: base,
      newCost: 130,
      newCostCode: 'NBT',
      newPrice: 300,
      createdBy: 'u1',
    );
    expect(v.price, 300);
    expect(v.cost, 130);
  });

  test('createVariation INHERITS the base price when none is passed', () async {
    // Receiving relies on this — receiving_repository_impl.dart:298 passes no
    // price and must keep the base's SRP.
    final base = (await repo.getProductByNameKey('bando belt skydrive|cvt'))!;
    final v = await repo.createVariation(
      originalProduct: base,
      newCost: 130,
      newCostCode: 'NBT',
      createdBy: 'u1',
    );
    expect(v.price, 250);
  });

  test('a variation starts at zero stock with no barcodes', () async {
    final base = (await repo.getProductByNameKey('bando belt skydrive|cvt'))!;
    final v = await repo.createVariation(
      originalProduct: base, newCost: 130, newCostCode: 'NBT', createdBy: 'u1',
    );
    expect(v.quantity, 0);
    expect(v.barcodes, isEmpty);
  });
}
```

If `ProductRepositoryImpl`'s constructor takes different named parameters, match them; check the top of `product_repository_impl.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/repositories/product_repository_variation_test.dart`
Expected: FAIL — `getProductByNameKey` is not defined and `newPrice` is not a parameter.

- [ ] **Step 3: Write the implementation**

In `lib/domain/repositories/product_repository.dart`, add beside `getProductBySku`:

```dart
  /// The active product sharing this duplicate key, or null. Key comes from
  /// `productDuplicateKey(name, category)`.
  Future<ProductEntity?> getProductByNameKey(String nameKey);
```

and widen `createVariation`:

```dart
  Future<ProductEntity> createVariation({
    required ProductEntity originalProduct,
    required double newCost,
    required String newCostCode,
    /// The SRP typed on the form. NULL inherits the base's price — receiving
    /// passes nothing and must keep inheriting.
    double? newPrice,
    required String createdBy,
    String? createdByName,
  });
```

In `lib/data/repositories/product_repository_impl.dart`, implement the lookup:

```dart
  @override
  Future<ProductEntity?> getProductByNameKey(String nameKey) async {
    try {
      final snapshot = await _productsRef
          .where('nameKey', isEqualTo: nameKey)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return ProductModel.fromFirestore(snapshot.docs.first).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to look up product by name: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
```

Add `double? newPrice,` to the `createVariation` signature, and in the `copyWith` that builds the variation add:

```dart
          price: newPrice ?? originalProduct.price,
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/repositories/product_repository_variation_test.dart` → PASS (5 tests)
Run: `flutter analyze && flutter test` → clean and green. `receiving_repository_impl.dart` must compile untouched — it passes no `newPrice` and keeps inheriting.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/repositories/product_repository.dart \
  lib/data/repositories/product_repository_impl.dart \
  test/data/repositories/product_repository_variation_test.dart
git commit -m "feat(products): mobile name lookup + optional variation price"
```

---

## Task 8: Mobile form — duplicate-name dialog

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/product_form_screen.dart`
- Modify: `lib/presentation/providers/product_provider.dart` (thread `newPrice` through `createVariation`)
- Test: `test/presentation/screens/product_form_duplicate_name_test.dart` (create)

**Interfaces:**
- Consumes: `productDuplicateKey` (Task 1); `getProductByNameKey`, `createVariation(newPrice:)` (Task 7).
- Produces: no new exports.

- [ ] **Step 1: Write the failing test**

Create `test/presentation/screens/product_form_duplicate_name_test.dart` with a fake `ProductRepository` whose `getProductByNameKey` returns a seeded product, and assert:

```dart
  testWidgets('offers a choice instead of saving when the name already exists',
      (tester) async {
    await pumpForm(tester, existing: seededBelt());
    await enterName(tester, 'BANDO BELT');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('already exists'), findsOneWidget);
    expect(fakeRepo.createCalls, 0);
  });

  testWidgets('Make it a variation passes the typed cost and price',
      (tester) async {
    await pumpForm(tester, existing: seededBelt());
    await enterName(tester, 'BANDO BELT');
    await enterCost(tester, '130');
    await enterPrice(tester, '300');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make it a variation'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastVariationCost, 130);
    expect(fakeRepo.lastVariationPrice, 300);
  });

  testWidgets('Save as a separate product creates normally', (tester) async {
    await pumpForm(tester, existing: seededBelt());
    await enterName(tester, 'BANDO BELT');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save as a separate product'));
    await tester.pumpAndSettle();

    expect(fakeRepo.createCalls, 1);
  });

  testWidgets('Cancel writes nothing', (tester) async {
    await pumpForm(tester, existing: seededBelt());
    await enterName(tester, 'BANDO BELT');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(fakeRepo.createCalls, 0);
    expect(fakeRepo.variationCalls, 0);
  });
```

Model the fake and the `pumpForm` helper on the nearest existing widget test in `test/presentation/screens/` — reuse its `ProviderScope` override style.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/screens/product_form_duplicate_name_test.dart`
Expected: FAIL — no dialog appears; the form saves directly.

- [ ] **Step 3: Write the implementation**

In `product_form_screen.dart`, add the import:

```dart
import 'package:maki_mobile_pos/core/utils/product_name_key.dart';
```

In the save handler, before the create call, add the gate:

```dart
    // Duplicate NAME gate — mirrors the web form. Runs BEFORE create, unlike
    // the SKU gate which can only fire once Firestore rejects a claim; the
    // auto-SKU flow never collides, which is why duplicates accumulated.
    final dupKey = productDuplicateKey(name, category);
    ProductEntity? dupExisting;
    try {
      dupExisting = await ref
          .read(productRepositoryProvider)
          .getProductByNameKey(dupKey);
    } catch (_) {
      // A failed lookup must never block a legitimate save.
      dupExisting = null;
    }
    if (dupExisting != null && dupExisting.id != _existingProduct?.id) {
      if (!mounted) return;
      final choice = await _showDuplicateNameDialog(dupExisting);
      if (choice == _DuplicateChoice.cancel) return;
      if (choice == _DuplicateChoice.variation) {
        await _createVariationFrom(dupExisting, cost: cost, price: price);
        return;
      }
      // _DuplicateChoice.separate falls through to the normal create.
    }
```

Add the enum and dialog beside the screen's other private helpers:

```dart
enum _DuplicateChoice { cancel, separate, variation }
```

Build `_showDuplicateNameDialog` with `AppDialog` (the repo's shared dialog — check `lib/presentation/shared/widgets/common/` for the exact constructor the other screens use), naming the existing product, its `SkuGenerator.displaySku(sku)`, cost and price, with three actions returning the enum values. Copy the wording from the web dialog in Task 6 so the two surfaces read identically.

`_createVariationFrom` calls the provider's `createVariation`, passing `newPrice: price`.

In `lib/presentation/providers/product_provider.dart`, add `double? newPrice` to the notifier's `createVariation` parameters and forward it to the repository call.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/presentation/screens/product_form_duplicate_name_test.dart` → PASS
Run: `flutter analyze && flutter test` → clean and green.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/product_form_screen.dart \
  lib/presentation/providers/product_provider.dart \
  test/presentation/screens/product_form_duplicate_name_test.dart
git commit -m "feat(inventory): duplicate-name gate on the mobile product form"
```

---

## Task 9: Web receiving — `duplicate-name` row status

**Files:**
- Modify: `web_admin/src/domain/receiving/classifyReceivingRows.ts`
- Modify: `web_admin/src/presentation/features/receiving/ReceivingEntryPage.tsx`
- Test: `web_admin/src/domain/receiving/classifyReceivingRows.test.ts` (extend)

**Interfaces:**
- Consumes: `productDuplicateKey` (Task 1).
- Produces: `ReceivingRowStatus` gains `'duplicate-name'`; `ClassifiedReceivingRow.existing` carries the matched product for that status.

- [ ] **Step 1: Write the failing test**

Append to `classifyReceivingRows.test.ts`:

```ts
describe('duplicate-name rows', () => {
  it('flags a GENERATE row whose name+category already exists', () => {
    const existing = product({ name: 'BELT BANDO SKYDRIVE', category: 'CVT', sku: '00020152' });
    const [row] = classifyReceivingRows(
      [parsedRow({ autoGenerateSku: true, name: 'BANDO SKYDRIVE BELT', category: 'CVT' })],
      [existing],
      new Map([['CVT', '0002']]),
    );
    expect(row.status).toBe('duplicate-name');
    expect(row.existing?.sku).toBe('00020152');
  });

  it('leaves a genuinely new GENERATE row as new', () => {
    const [row] = classifyReceivingRows(
      [parsedRow({ autoGenerateSku: true, name: 'BRAND NEW PART', category: 'CVT' })],
      [product({ name: 'BELT BANDO', category: 'CVT' })],
      new Map([['CVT', '0002']]),
    );
    expect(row.status).toBe('new');
  });

  it('does not flag across categories', () => {
    const [row] = classifyReceivingRows(
      [parsedRow({ autoGenerateSku: true, name: 'GASKET', category: 'ENGINE' })],
      [product({ name: 'GASKET', category: 'BRAKES' })],
      new Map([['ENGINE', '0017']]),
    );
    expect(row.status).toBe('new');
  });

  it('a typed-SKU row is unaffected — SKU matching still wins', () => {
    const existing = product({ name: 'BELT BANDO', category: 'CVT', sku: '00020152', cost: 120 });
    const [row] = classifyReceivingRows(
      [parsedRow({ autoGenerateSku: false, sku: '00020152', name: 'BELT BANDO', category: 'CVT', cost: 120 })],
      [existing],
      new Map(),
    );
    expect(row.status).toBe('match');
  });
});
```

Use the file's existing `product(...)` and `parsedRow(...)` helpers.

- [ ] **Step 2: Run test to verify it fails**

Run (from `web_admin/`): `npm run test -- classifyReceivingRows --run`
Expected: FAIL — `expected 'new' to be 'duplicate-name'`.

- [ ] **Step 3: Write the implementation**

In `classifyReceivingRows.ts`, add the import and widen the status union:

```ts
import { productDuplicateKey } from '@/domain/products/nameKey';

export type ReceivingRowStatus = 'new' | 'match' | 'mismatch' | 'error' | 'duplicate-name';
```

Build a name index next to the SKU one:

```ts
  const bySku = new Map<string, Product>();
  const byNameKey = new Map<string, Product>();
  for (const p of activeProducts) {
    bySku.set(p.sku.toLowerCase(), p);
    // First writer wins: with duplicates already in the catalog, the report
    // only needs to name one of them.
    const key = productDuplicateKey(p.name, p.category);
    if (!byNameKey.has(key)) byNameKey.set(key, p);
  }
```

In the `row.autoGenerateSku` branch, replace the final `return { row, status: 'new', existing: null };` with:

```ts
      const nameMatch = byNameKey.get(productDuplicateKey(row.name, row.category)) ?? null;
      if (nameMatch) return { row, status: 'duplicate-name', existing: nameMatch };
      return { row, status: 'new', existing: null };
```

In `ReceivingEntryPage.tsx`, render the new status: show the matched product's name and `displaySku(existing.sku)`, and a per-row `<select>` defaulting to **Make variation**, with **Create as new** as the alternative. Store the choice in the page's existing per-row state and treat "Make variation" as a typed-SKU row against `existing.sku` when building the plan, so it flows into the current cost-mismatch/variation machinery unchanged. Follow the styling of the existing `mismatch` row treatment in that file.

- [ ] **Step 4: Run tests to verify they pass**

Run (from `web_admin/`): `npm run test -- classifyReceivingRows --run` → PASS
Run: `npm run typecheck && npm run test -- --run && npm run build` → clean and green. Any exhaustive `switch` over `ReceivingRowStatus` will fail to compile until it handles the new case — fix each one it reports.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/receiving/classifyReceivingRows.ts \
  web_admin/src/domain/receiving/classifyReceivingRows.test.ts \
  web_admin/src/presentation/features/receiving/ReceivingEntryPage.tsx
git commit -m "feat(receiving): flag duplicate-name rows in the web preview"
```

---

## Task 10: Mobile receiving — `DuplicateNameRow`

**Files:**
- Modify: `lib/core/utils/batch_import.dart`
- Modify: `lib/presentation/mobile/widgets/receiving/import_preview.dart`
- Test: `test/core/utils/batch_import_test.dart` (extend)

**Interfaces:**
- Consumes: `productDuplicateKey` (Task 1).
- Produces: `class DuplicateNameRow extends ClassifiedRow { final ParsedImportRow row; final ProductEntity existing; }`

- [ ] **Step 1: Write the failing test**

Append to `test/core/utils/batch_import_test.dart`:

```dart
  group('duplicate-name rows', () {
    test('a GENERATE row whose name+category exists is flagged', () {
      final existing = productEntity(
        sku: '00020152', name: 'BELT BANDO SKYDRIVE', category: 'CVT',
      );
      final rows = classifyRows(
        rows: [parsedRow(autoGenerateSku: true, name: 'BANDO SKYDRIVE BELT', category: 'CVT')],
        activeProducts: [existing],
      );
      expect(rows.single, isA<DuplicateNameRow>());
      expect((rows.single as DuplicateNameRow).existing.sku, '00020152');
    });

    test('a genuinely new GENERATE row stays a NewProductRow', () {
      final rows = classifyRows(
        rows: [parsedRow(autoGenerateSku: true, name: 'BRAND NEW PART', category: 'CVT')],
        activeProducts: [productEntity(sku: '1', name: 'BELT BANDO', category: 'CVT')],
      );
      expect(rows.single, isA<NewProductRow>());
    });

    test('does not flag across categories', () {
      final rows = classifyRows(
        rows: [parsedRow(autoGenerateSku: true, name: 'GASKET', category: 'ENGINE')],
        activeProducts: [productEntity(sku: '1', name: 'GASKET', category: 'BRAKES')],
      );
      expect(rows.single, isA<NewProductRow>());
    });
  });
```

Use the file's existing `parsedRow(...)` and product fixture helpers.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/batch_import_test.dart`
Expected: FAIL — `DuplicateNameRow` is not defined.

- [ ] **Step 3: Write the implementation**

In `lib/core/utils/batch_import.dart`, add the import and the class beside `NewProductRow`:

```dart
import 'package:maki_mobile_pos/core/utils/product_name_key.dart';

/// GENERATE row whose name + category already belongs to an active product.
/// The operator resolves it per row in the preview: make a variation of
/// [existing], or create it as a genuinely separate product.
class DuplicateNameRow extends ClassifiedRow {
  final ParsedImportRow row;
  final ProductEntity existing;
  const DuplicateNameRow({required this.row, required this.existing});
}
```

In `classifyRows`, build the name index and use it:

```dart
  final byNameKey = <String, ProductEntity>{};
  for (final p in activeProducts) {
    // First writer wins: duplicates already exist, and naming one is enough.
    byNameKey.putIfAbsent(productDuplicateKey(p.name, p.category), () => p);
  }
```

and replace the `if (row.autoGenerateSku) { return NewProductRow(row: row); }` branch with:

```dart
    if (row.autoGenerateSku) {
      final match = byNameKey[productDuplicateKey(row.name, row.category)];
      if (match != null) return DuplicateNameRow(row: row, existing: match);
      return NewProductRow(row: row);
    }
```

In `import_preview.dart`, add a chip and per-row control for the new type, matching how `CostMismatchRow` is already presented: show the matched product's name and `SkuGenerator.displaySku(existing.sku)`, with a toggle defaulting to **Make variation** and **Create as new** as the alternative. Every exhaustive `switch`/`if-else` chain over `ClassifiedRow` in the receiving use-case must handle the new type — `flutter analyze` will point at each.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/utils/batch_import_test.dart` → PASS
Run: `flutter analyze && flutter test` → clean and green.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/batch_import.dart \
  lib/presentation/mobile/widgets/receiving/import_preview.dart \
  test/core/utils/batch_import_test.dart
git commit -m "feat(receiving): flag duplicate-name rows in the mobile preview"
```

---

## Task 11: Full verification sweep

- [ ] **Step 1: Run everything and confirm the output**

```bash
flutter analyze
flutter test
cd web_admin && npm run typecheck && npm run test -- --run && npm run build && cd ..
node --test scripts/backfill-product-name-keys-lib.test.mjs
```

All must be clean and green before the feature is called done.

- [ ] **Step 2: Confirm the receiving invariant by hand**

Grep to prove no receiving path passes a typed price into a variation:

```bash
grep -rn "createVariation" lib/data/repositories/receiving_repository_impl.dart
grep -rn "price:" web_admin/src/data/receiving/planReceive.ts
```

Expected: the mobile call still passes no `newPrice`; `planReceive` still reads `price: p.price`. If either changed, it is a bug — revert it.

- [ ] **Step 3: Rollout (each step needs the user's explicit go-ahead)**

These touch production. Confirm before each, per CLAUDE.md.

1. Backfill: `node --dns-result-order=ipv4first --no-network-family-autoselection scripts/backfill-product-name-keys.mjs` (dry run first, then `--execute`). Safe before or after deploy — `nameKey` is additive and unread by the old code.
2. Deploy web: `npm run build && firebase deploy --only hosting`.
3. Ship mobile in the next APK, bumping `pubspec.yaml`.

No `firestore.rules` deploy is part of this feature.

---

## Notes for the executor

- **The receiving invariant is the thing to protect.** Two paths spawn variations from receiving — mobile `receiving_repository_impl.dart:298` and web `planReceive.ts` — and neither may gain a typed price. Task 7's inherit test and Task 11's grep both exist to catch a regression here.
- **Three copies of the name key exist by necessity** (Dart, TS, Node script). All three test files carry the same vector table. If you change tokenization, change all three or the backfill will write keys the app cannot match.
- **The dialog is never a block.** Every duplicate path must leave "save it anyway" reachable; two genuinely different parts are allowed to share a name.
- **Do not try to merge existing duplicates.** The backfill reports them and stops there, by design.
