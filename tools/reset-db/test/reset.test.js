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
