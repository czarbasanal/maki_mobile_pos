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
  ['TIRE TL MAXXIS MAV6 46P 90/90-14', '46p 90/90-14 mav6 maxxis tire tl'],
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
