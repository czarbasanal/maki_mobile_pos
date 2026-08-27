import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildSeedPayload, DEFAULT_SEED } from './seed-shop-timezone-lib.mjs';

test('defaults to Asia/Manila at +480', () => {
  assert.equal(DEFAULT_SEED.timezoneId, 'Asia/Manila');
  assert.equal(DEFAULT_SEED.tzOffsetMinutes, 480);
});

test('builds a payload with both keys', () => {
  const p = buildSeedPayload({ timezoneId: 'Asia/Tokyo', offsetMinutes: 540 });
  assert.equal(p.timezoneId, 'Asia/Tokyo');
  assert.equal(p.tzOffsetMinutes, 540);
});

test('rejects an out-of-range offset', () => {
  assert.throws(() => buildSeedPayload({ timezoneId: 'X', offsetMinutes: 99999 }));
});

test('rejects a non-integer offset', () => {
  assert.throws(() => buildSeedPayload({ timezoneId: 'X', offsetMinutes: 8.5 }));
});

test('rejects an empty timezone id', () => {
  assert.throws(() => buildSeedPayload({ timezoneId: '', offsetMinutes: 480 }));
});
