import test from 'node:test';
import assert from 'node:assert/strict';
import { safeToDelete } from './delete-legacy-drafts-lib.mjs';

const draft = (o = {}) => ({
  name: 'JO-072826-001',
  createdBy: 'u1',
  isConverted: false,
  convertedToSaleId: null,
  items: [{}, {}],
  ...o,
});

test('a faithful copy is safe to delete', () => {
  assert.equal(safeToDelete(draft(), draft()).safe, true);
});

test('a missing counterpart is never safe', () => {
  const r = safeToDelete(draft(), null);
  assert.equal(r.safe, false);
  assert.match(r.reason, /no job_orders counterpart/);
});

test('identity mismatches block the delete', () => {
  assert.equal(safeToDelete(draft(), draft({ name: 'OTHER' })).safe, false);
  assert.equal(safeToDelete(draft(), draft({ createdBy: 'u2' })).safe, false);
  assert.equal(safeToDelete(draft(), draft({ isConverted: true })).safe, false);
  assert.equal(
    safeToDelete(draft(), draft({ convertedToSaleId: 's9' })).safe,
    false,
  );
});

test('a truncated copy blocks the delete (item count differs)', () => {
  const r = safeToDelete(draft(), draft({ items: [{}] }));
  assert.equal(r.safe, false);
  assert.match(r.reason, /item count differs/);
});

test('absent vs null are treated as equal, not a mismatch', () => {
  const legacy = draft();
  delete legacy.convertedToSaleId;
  assert.equal(safeToDelete(legacy, draft()).safe, true);
});
