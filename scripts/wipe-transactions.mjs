// Transaction-data wipe — clears sales/logs/EOD/JO/expense/receiving history,
// KEEPS the full product catalog, lists, suppliers, users, and settings.
// Scope confirmed by user 2026-07-24. NO backup requested (same as 2026-07-21).
//
// Dry run:  node wipe-transactions.mjs           (prints per-collection plan, deletes nothing)
// Execute:  node wipe-transactions.mjs --execute
// Emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node wipe-transactions.mjs --execute
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID = 'maki-mobile-pos';
const DELETE = [
  'sales', // recursiveDelete also removes the items subcollection
  'user_logs',
  'void_requests',
  'daily_closings',
  'drafts',
  'expenses',
  'receivings',
  'purchase_orders',
  'counters', // sale/JO numbering restarts from 1 (absent = no-op)
];
const KEEP = [
  'users', 'settings',
  'products', 'product_skus', 'product_barcodes',
  'product_categories', 'expense_categories', 'units', 'void_reasons',
  'suppliers', 'mechanics', 'motorcycle_models',
  'employees', 'payslips', // HR — not transaction data
];

const execute = process.argv.includes('--execute');
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
console.log(EMULATOR
  ? `TARGET: emulator (${EMULATOR})`
  : `TARGET: PRODUCTION (${PROJECT_ID})`);

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
if (execute && !EMULATOR) {
  process.stdout.write(`\nIrreversible deletion from PRODUCTION. Type the project id (${PROJECT_ID}) to confirm: `);
  const line = await new Promise((resolve) => {
    let buf = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => {
      buf += chunk;
      const nl = buf.indexOf('\n');
      if (nl !== -1) { process.stdin.pause(); resolve(buf.slice(0, nl).trim()); }
    });
    process.stdin.resume();
  });
  if (line !== PROJECT_ID) {
    console.error('Confirmation mismatch — aborting. Nothing deleted.');
    process.exit(1);
  }
}
for (const id of DELETE) {
  const ref = db.collection(id);
  const before = (await ref.count().get()).data().count;
  await db.recursiveDelete(ref); // subcollections too (sale items)
  console.log(`deleted ${id} (${before} docs)`);
}
console.log('\n--- post-wipe collections ---');
for (const col of await db.listCollections()) {
  const count = (await col.count().get()).data().count;
  console.log(`${col.id.padEnd(22)} ${count}`);
}
console.log('\nWipe complete.');
