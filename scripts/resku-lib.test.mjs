import test from 'node:test';
import assert from 'node:assert/strict';
import { classifyOldAuto, planResku } from './resku-lib.mjs';

// --- classifyOldAuto ---

test('generateForName pattern (name-prefix + 6-char suffix) classifies as old-auto', () => {
  assert.equal(classifyOldAuto('MLKCHCLT50-A3B7K9'), true);
  assert.equal(classifyOldAuto('IC-A3B7K9'), true);
});

test('generate pattern (SKU- + 8-char suffix) classifies as old-auto', () => {
  assert.equal(classifyOldAuto('SKU-A3B7K9M2'), true);
});

test('manual part number without a hyphen is not old-auto', () => {
  assert.equal(classifyOldAuto('01A0266B'), false);
});

test('already-coded 8-digit sku is not old-auto', () => {
  assert.equal(classifyOldAuto('00070153'), false);
});

test('7-char suffix (not 6, not 8) is rejected', () => {
  assert.equal(classifyOldAuto('ABC-1234567'), false);
});

test('lowercase variants are rejected (alphabet is uppercase-only)', () => {
  assert.equal(classifyOldAuto('abc-a3b7k9'), false);
  assert.equal(classifyOldAuto('sku-a3b7k9m2'), false);
});

// --- planResku ---

test('two categories: groups renames by category code, orders by createdAt asc within category', () => {
  const products = [
    { id: 'p-bev-2', sku: 'BVRGS-A3B7K9', category: 'Beverages', baseSku: 'BVRGS-A3B7K9', createdAt: 200 },
    { id: 'p-bev-1', sku: 'BVRGS-Z9Y8X7', category: 'Beverages', baseSku: 'BVRGS-Z9Y8X7', createdAt: 100 },
    { id: 'p-snk-1', sku: 'SKU-A3B7K9M2', category: 'Snacks', baseSku: 'SKU-A3B7K9M2', createdAt: 150 },
  ];
  const categories = [
    { name: 'Beverages', code: '0001' },
    { name: 'Snacks', code: '0002' },
  ];
  const registry = { '0001': 1, '0002': 1 };

  const plan = planResku({ products, categories, registry });

  assert.deepEqual(plan.skipped, []);
  assert.deepEqual(plan.renames, [
    { id: 'p-bev-1', oldSku: 'BVRGS-Z9Y8X7', newSku: '00010001', categoryCode: '0001' },
    { id: 'p-bev-2', oldSku: 'BVRGS-A3B7K9', newSku: '00010002', categoryCode: '0001' },
    { id: 'p-snk-1', oldSku: 'SKU-A3B7K9M2', newSku: '00020001', categoryCode: '0002' },
  ]);
  assert.deepEqual(plan.registryAfter, { '0001': 3, '0002': 2 });
});

test('createdAt tie-breaks by doc id within a category', () => {
  const products = [
    { id: 'p-z', sku: 'AAA-A3B7K9', category: 'Tools', baseSku: 'AAA-A3B7K9', createdAt: 100 },
    { id: 'p-a', sku: 'BBB-Z9Y8X7', category: 'Tools', baseSku: 'BBB-Z9Y8X7', createdAt: 100 },
  ];
  const categories = [{ name: 'Tools', code: '0005' }];
  const registry = { '0005': 1 };

  const plan = planResku({ products, categories, registry });

  assert.deepEqual(plan.renames.map(r => r.id), ['p-a', 'p-z']);
  assert.deepEqual(plan.renames.map(r => r.newSku), ['00050001', '00050002']);
});

test('registry continuation: nextSequence > 1 picks up where the registry left off', () => {
  const products = [
    { id: 'p-1', sku: 'AAA-A3B7K9', category: 'Tools', baseSku: 'AAA-A3B7K9', createdAt: 100 },
  ];
  const categories = [{ name: 'Tools', code: '0005' }];
  const registry = { '0005': 42 };

  const plan = planResku({ products, categories, registry });

  assert.deepEqual(plan.renames, [
    { id: 'p-1', oldSku: 'AAA-A3B7K9', newSku: '00050042', categoryCode: '0005' },
  ]);
  assert.deepEqual(plan.registryAfter, { '0005': 43 });
});

test('missing category on the product → skipped with reason, no rename', () => {
  const products = [
    { id: 'p-1', sku: 'AAA-A3B7K9', category: null, baseSku: 'AAA-A3B7K9', createdAt: 100 },
  ];
  const categories = [{ name: 'Tools', code: '0005' }];
  const registry = {};

  const plan = planResku({ products, categories, registry });

  assert.deepEqual(plan.renames, []);
  assert.equal(plan.skipped.length, 1);
  assert.equal(plan.skipped[0].id, 'p-1');
  assert.equal(plan.skipped[0].oldSku, 'AAA-A3B7K9');
  assert.match(plan.skipped[0].reason, /missing category/i);
});

test('category name not present in categories collection → skipped with reason', () => {
  const products = [
    { id: 'p-1', sku: 'AAA-A3B7K9', category: 'Ghost Category', baseSku: 'AAA-A3B7K9', createdAt: 100 },
  ];
  const categories = [{ name: 'Tools', code: '0005' }];
  const registry = {};

  const plan = planResku({ products, categories, registry });

  assert.deepEqual(plan.renames, []);
  assert.equal(plan.skipped.length, 1);
  assert.match(plan.skipped[0].reason, /not found/i);
});

test('category found but uncoded (no code field) → skipped with reason', () => {
  const products = [
    { id: 'p-1', sku: 'AAA-A3B7K9', category: 'Misc', baseSku: 'AAA-A3B7K9', createdAt: 100 },
  ];
  const categories = [{ name: 'Misc' }];
  const registry = {};

  const plan = planResku({ products, categories, registry });

  assert.deepEqual(plan.renames, []);
  assert.equal(plan.skipped.length, 1);
  assert.match(plan.skipped[0].reason, /uncoded/i);
});

test('baseSku remap: covers a non-renamed child whose baseSku points at a renamed parent', () => {
  const products = [
    { id: 'parent', sku: 'AAA-A3B7K9', category: 'Tools', baseSku: 'AAA-A3B7K9', createdAt: 100 },
    // child's own sku is a manual/coded sku (NOT old-auto) so it is never itself renamed,
    // but its baseSku points at the parent's OLD sku and must be remapped.
    { id: 'child', sku: 'AAA-A3B7K9-1', category: 'Tools', baseSku: 'AAA-A3B7K9', createdAt: 110 },
  ];
  const categories = [{ name: 'Tools', code: '0005' }];
  const registry = { '0005': 1 };

  const plan = planResku({ products, categories, registry });

  assert.equal(plan.renames.length, 1);
  assert.equal(plan.renames[0].id, 'parent');
  assert.equal(plan.renames[0].newSku, '00050001');

  assert.deepEqual(plan.baseSkuFixes.sort((a, b) => a.id.localeCompare(b.id)), [
    { id: 'child', oldBaseSku: 'AAA-A3B7K9', newBaseSku: '00050001' },
    { id: 'parent', oldBaseSku: 'AAA-A3B7K9', newBaseSku: '00050001' },
  ]);
});

test('in-plan duplicate target sku → throws', () => {
  // A stale/lagging registry computes a rename target that collides with
  // another product's CURRENT sku (a manual/coded sku that happens to look
  // like a valid coded sku and is therefore never itself renamed). Applying
  // the plan would leave two products claiming the same sku, so planning
  // must abort instead of silently producing the collision.
  const products = [
    { id: 'p-1', sku: 'AAA-A3B7K9', category: 'Tools', baseSku: 'AAA-A3B7K9', createdAt: 100 },
    { id: 'p-2', sku: '00050001', category: 'Tools', baseSku: '00050001', createdAt: 50 },
  ];
  const categories = [{ name: 'Tools', code: '0005' }];
  const registry = { '0005': 1 };

  assert.throws(() => planResku({ products, categories, registry }), /duplicate/i);
});

test('sequence overflow past 9999 in a category → throws', () => {
  const products = [
    { id: 'p-1', sku: 'AAA-A3B7K9', category: 'Tools', baseSku: 'AAA-A3B7K9', createdAt: 100 },
  ];
  const categories = [{ name: 'Tools', code: '0005' }];
  const registry = { '0005': 9999 };

  const plan1 = planResku({ products, categories, registry });
  assert.equal(plan1.renames[0].newSku, '00059999');

  const registryOverflow = { '0005': 10000 };
  assert.throws(() => planResku({ products, categories, registry: registryOverflow }), /overflow|9999/i);
});
