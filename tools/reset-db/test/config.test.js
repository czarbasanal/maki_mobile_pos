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
