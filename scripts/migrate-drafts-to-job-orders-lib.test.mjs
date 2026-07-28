import test from 'node:test';
import assert from 'node:assert/strict';
import { DELETE_FIELD, planSalePatch, shouldCopy, tsMillis } from './migrate-drafts-to-job-orders-lib.mjs';

const t = (ms) => ({ toMillis: () => ms });

test('missing target is copied', () => {
  assert.deepEqual(shouldCopy({ createdAt: t(100) }, null), { copy: true, reason: 'target-missing' });
});

test('converted target is never clobbered by an unconverted source', () => {
  assert.deepEqual(
    shouldCopy({ isConverted: false, updatedAt: t(999) }, { isConverted: true, updatedAt: t(1) }),
    { copy: false, reason: 'target-converted' },
  );
});

test('strictly-newer source overwrites; equal or older does not (re-run = no-op)', () => {
  assert.equal(shouldCopy({ updatedAt: t(200) }, { updatedAt: t(100) }).copy, true);
  assert.equal(shouldCopy({ updatedAt: t(100) }, { updatedAt: t(100) }).copy, false);
  assert.equal(shouldCopy({ updatedAt: t(50) }, { updatedAt: t(100) }).copy, false);
});

test('createdAt is the fallback clock when updatedAt is absent', () => {
  assert.equal(shouldCopy({ createdAt: t(300) }, { createdAt: t(100) }).copy, true);
  assert.equal(shouldCopy({ createdAt: t(100) }, { updatedAt: t(300) }).copy, false);
});

test('converted source may still overwrite a converted target only when newer', () => {
  assert.equal(
    shouldCopy({ isConverted: true, updatedAt: t(200) }, { isConverted: true, updatedAt: t(100) }).copy,
    true,
  );
  assert.equal(
    shouldCopy({ isConverted: true, updatedAt: t(100) }, { isConverted: true, updatedAt: t(200) }).copy,
    false,
  );
});

test('sale with only draftId moves the field', () => {
  assert.deepEqual(planSalePatch({ draftId: 'd1' }), { jobOrderId: 'd1', draftId: DELETE_FIELD });
});

test('sale with both fields only drops the old one (never clobbers jobOrderId)', () => {
  assert.deepEqual(planSalePatch({ draftId: 'd1', jobOrderId: 'j1' }), { draftId: DELETE_FIELD });
});

test('already-migrated and plain sales are no-ops', () => {
  assert.equal(planSalePatch({ jobOrderId: 'j1' }), null);
  assert.equal(planSalePatch({}), null);
  assert.equal(planSalePatch({ draftId: null }), null);
});

test('tsMillis handles Timestamp-like, Date, number, null', () => {
  assert.equal(tsMillis(t(5)), 5);
  assert.equal(tsMillis(new Date(7)), 7);
  assert.equal(tsMillis(9), 9);
  assert.equal(tsMillis(null), null);
});
