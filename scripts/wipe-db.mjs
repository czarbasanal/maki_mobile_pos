// Pre-import prod wipe — deletes transaction + inventory data, keeps users/defaults.
// Scope confirmed by user 2026-07-21 — see spec §11. NO backup was requested.
//
// Dry run:  node wipe-db.mjs           (prints per-collection plan, deletes nothing)
// Execute:  node wipe-db.mjs --execute
// Emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node wipe-db.mjs --execute
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID = 'maki-mobile-pos';
const DELETE = [
  'products', 'product_skus', 'product_categories', 'suppliers',
  'sales', 'receivings', 'drafts', 'purchase_orders',
  'expenses', 'daily_closings', 'user_logs', 'void_requests',
];
const KEEP = [
  'users', 'settings', 'units', 'expense_categories',
  'void_reasons', 'motorcycle_models', 'mechanics',
];

const execute = process.argv.includes('--execute');
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

const all = await db.listCollections();
console.log('--- wipe plan ---');
const unknown = [];
for (const col of all.sort((a, b) => a.id.localeCompare(b.id))) {
  const count = (await col.count().get()).data().count;
  const action = DELETE.includes(col.id) ? 'DELETE' : KEEP.includes(col.id) ? 'keep' : 'UNKNOWN';
  if (action === 'UNKNOWN') unknown.push(col.id);
  console.log(`${action.padEnd(8)} ${col.id.padEnd(22)} ${count}`);
}
if (unknown.length) {
  console.error(`\nUnknown collections not in DELETE or KEEP: ${unknown.join(', ')}`);
  console.error('Add each to one of the lists (with user sign-off) before running.');
  process.exit(1);
}
if (!execute) {
  console.log('\nDRY RUN — nothing deleted. Re-run with --execute to wipe.');
  process.exit(0);
}
for (const id of DELETE) {
  const ref = db.collection(id);
  const before = (await ref.count().get()).data().count;
  await db.recursiveDelete(ref); // subcollections too (sale items, price_history)
  console.log(`deleted ${id} (${before} docs)`);
}
console.log('\n--- post-wipe collections ---');
for (const col of await db.listCollections()) {
  const count = (await col.count().get()).data().count;
  console.log(`${col.id.padEnd(22)} ${count}`);
}
console.log('\nWipe complete.');
