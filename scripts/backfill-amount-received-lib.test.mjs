import test from 'node:test';
import assert from 'node:assert/strict';
import { planPatch } from './backfill-amount-received-lib.mjs';

test('bug-signature cash sale is patched to received+change', () => {
  assert.deepEqual(
    planPatch({ paymentMethod: 'cash', amountReceived: 320,
                changeGiven: 680, tenders: { cash: 320 } }),
    { amountReceived: 1000 });
});

test('web-written correct doc is skipped (received != tenders.cash)', () => {
  assert.equal(
    planPatch({ paymentMethod: 'cash', amountReceived: 1000,
                changeGiven: 680, tenders: { cash: 320 } }),
    null);
});

test('zero-change and non-cash docs are skipped', () => {
  assert.equal(planPatch({ paymentMethod: 'cash', amountReceived: 320,
                           changeGiven: 0, tenders: { cash: 320 } }), null);
  assert.equal(planPatch({ paymentMethod: 'gcash', amountReceived: 320,
                           changeGiven: 680, tenders: { gcash: 320 } }), null);
});

test('docs missing amountReceived or tenders are rejected by NaN guard', () => {
  assert.equal(planPatch({ paymentMethod: 'cash', changeGiven: 5 }), null);
});
