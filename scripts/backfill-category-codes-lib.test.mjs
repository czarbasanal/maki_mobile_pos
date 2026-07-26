import test from 'node:test';
import assert from 'node:assert/strict';
import { planAssignments, counterAfter } from './backfill-category-codes-lib.mjs';

test('fresh 3 categories → codes 0001..0003 by createdAt', () => {
  const categories = [
    { id: 'cat-a', name: 'Category A', createdAt: { seconds: 100 } },
    { id: 'cat-b', name: 'Category B', createdAt: { seconds: 200 } },
    { id: 'cat-c', name: 'Category C', createdAt: { seconds: 300 } },
  ];
  const assignments = planAssignments(categories);
  assert.deepEqual(assignments, [
    { id: 'cat-a', code: '0001', name: 'Category A' },
    { id: 'cat-b', code: '0002', name: 'Category B' },
    { id: 'cat-c', code: '0003', name: 'Category C' },
  ]);
  const counter = counterAfter(assignments, 0);
  assert.equal(counter, 4);
});

test('createdAt tie-breaker by id', () => {
  const categories = [
    { id: 'cat-z', name: 'Cat Z', createdAt: { seconds: 100 } },
    { id: 'cat-a', name: 'Cat A', createdAt: { seconds: 100 } },
    { id: 'cat-m', name: 'Cat M', createdAt: { seconds: 100 } },
  ];
  const assignments = planAssignments(categories);
  // Should order by id when createdAt is the same
  assert.deepEqual(assignments, [
    { id: 'cat-a', code: '0001', name: 'Cat A' },
    { id: 'cat-m', code: '0002', name: 'Cat M' },
    { id: 'cat-z', code: '0003', name: 'Cat Z' },
  ]);
});

test('one pre-coded + two uncoded → assigns 0003, 0004, counter 5', () => {
  const categories = [
    { id: 'cat-1', name: 'Cat 1', createdAt: { seconds: 100 }, code: '0002' },
    { id: 'cat-2', name: 'Cat 2', createdAt: { seconds: 200 } },
    { id: 'cat-3', name: 'Cat 3', createdAt: { seconds: 300 } },
  ];
  const assignments = planAssignments(categories);
  assert.deepEqual(assignments, [
    { id: 'cat-2', code: '0003', name: 'Cat 2' },
    { id: 'cat-3', code: '0004', name: 'Cat 3' },
  ]);
  const counter = counterAfter(assignments, 2);
  assert.equal(counter, 5);
});

test('all coded → empty plan', () => {
  const categories = [
    { id: 'cat-1', name: 'Cat 1', createdAt: { seconds: 100 }, code: '0001' },
    { id: 'cat-2', name: 'Cat 2', createdAt: { seconds: 200 }, code: '0002' },
    { id: 'cat-3', name: 'Cat 3', createdAt: { seconds: 300 }, code: '0003' },
  ];
  const assignments = planAssignments(categories);
  assert.deepEqual(assignments, []);
});

test('counterAfter with no assignments returns existingMax + 1', () => {
  const counter = counterAfter([], 5);
  assert.equal(counter, 6);
});

test('counterAfter with assignments and higher existingMax uses existingMax', () => {
  const assignments = [
    { id: 'cat-1', code: '0001', name: 'Cat 1' },
    { id: 'cat-2', code: '0002', name: 'Cat 2' },
  ];
  const counter = counterAfter(assignments, 10);
  assert.equal(counter, 11);
});

// --- registry-aware floor (post-delete re-run safety) ---

test('deleted-category scenario: registry has 0002, categories max 0001, counter 4 -> new assignments start at 0004 and never touch 0002/0003', () => {
  const categories = [
    { id: 'cat-1', name: 'Cat 1', createdAt: { seconds: 100 }, code: '0001' },
    { id: 'cat-2', name: 'Cat 2', createdAt: { seconds: 200 } },
  ];
  const assignments = planAssignments(categories, {
    registryCodes: ['0002'],
    counterNext: 4,
  });
  assert.deepEqual(assignments, [
    { id: 'cat-2', code: '0004', name: 'Cat 2' },
  ]);
  assert.ok(!assignments.some(a => a.code === '0002'));
  assert.ok(!assignments.some(a => a.code === '0003'));

  const counter = counterAfter(assignments, 1, 4);
  assert.equal(counter, 5);
});

test('deleted-category scenario with a gap the counter has not caught up to: registry codes 0002 and 0005 are both skipped', () => {
  const categories = [
    { id: 'cat-2', name: 'Cat 2', createdAt: { seconds: 200 } },
  ];
  const assignments = planAssignments(categories, {
    registryCodes: ['0002', '0005'],
    counterNext: 2,
  });
  // floor = max(0, max(2,5), 2-1) = 5 -> next candidate is 0006, nothing to skip
  assert.deepEqual(assignments, [
    { id: 'cat-2', code: '0006', name: 'Cat 2' },
  ]);
});

test('counter-only floor: no category codes, empty registry, counter already at 7 -> assignment starts at 0007', () => {
  const categories = [
    { id: 'cat-1', name: 'Cat 1', createdAt: { seconds: 100 } },
  ];
  const assignments = planAssignments(categories, {
    registryCodes: [],
    counterNext: 7,
  });
  assert.deepEqual(assignments, [
    { id: 'cat-1', code: '0007', name: 'Cat 1' },
  ]);

  const counter = counterAfter(assignments, 0, 7);
  assert.equal(counter, 8);
});

test('counterAfter never regresses below the current counterNext even with no new assignments', () => {
  const counter = counterAfter([], 1, 4);
  assert.equal(counter, 4);
});

test('planAssignments with no options behaves exactly as before (backward compatible)', () => {
  const categories = [
    { id: 'cat-a', name: 'Category A', createdAt: { seconds: 100 } },
  ];
  const assignments = planAssignments(categories);
  assert.deepEqual(assignments, [
    { id: 'cat-a', code: '0001', name: 'Category A' },
  ]);
});
