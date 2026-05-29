'use strict';

const { WIPE_COLLECTIONS } = require('./config');

/**
 * Resets the database by clearing every collection in WIPE_COLLECTIONS
 * (and their subcollections). With { dryRun: true } it only counts.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{ dryRun?: boolean, log?: (msg: string) => void }} [opts]
 * @returns {Promise<Array<{collection: string, count?: number, deleted: boolean}>>}
 */
async function resetDatabase(db, { dryRun = false, log = () => {} } = {}) {
  const results = [];
  for (const name of WIPE_COLLECTIONS) {
    const col = db.collection(name);
    if (dryRun) {
      const count = (await col.count().get()).data().count;
      log(`  [dry-run] ${name}: ${count} docs would be deleted`);
      results.push({ collection: name, count, deleted: false });
    } else {
      log(`  deleting ${name} ...`);
      await db.recursiveDelete(col); // removes docs + nested subcollections
      results.push({ collection: name, deleted: true });
    }
  }
  return results;
}

module.exports = { resetDatabase };
