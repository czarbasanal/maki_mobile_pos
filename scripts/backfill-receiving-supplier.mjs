// Backfills a completed receiving's supplier onto the products its stock
// actually came from, matching the fixed receive behavior (2026-09-02):
//   - products CREATED by the receiving (variations / new products, via
//     newProductId) that have NO supplier -> stamped with the receiving's
//   - MATCHED products (existing productId lines) that have NO supplier ->
//     filled with the receiving's (fill-when-empty)
// A product that already names ANY supplier is never touched.
//
// Dry run:  node backfill-receiving-supplier.mjs RCV-20260901-001
// Execute:  node backfill-receiving-supplier.mjs RCV-20260901-001 --execute
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID = 'maki-mobile-pos';
const execute = process.argv.includes('--execute');
const reference = process.argv.find((a) => a.startsWith('RCV-'));
if (!reference) {
  console.error('Usage: node backfill-receiving-supplier.mjs <RCV-reference> [--execute]');
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
console.log(EMULATOR ? `TARGET: emulator (${EMULATOR})` : `TARGET: PRODUCTION (${PROJECT_ID})`);
console.log(execute ? 'MODE: EXECUTE' : 'MODE: dry run (nothing written)');

const snap = await db
  .collection('receivings')
  .where('referenceNumber', '==', reference)
  .get();
if (snap.empty) {
  console.error(`No receiving found with reference ${reference}`);
  process.exit(1);
}
if (snap.size > 1) {
  console.error(`${snap.size} receivings share reference ${reference} — refusing to guess.`);
  process.exit(1);
}
const receiving = snap.docs[0].data();
if (receiving.status !== 'completed') {
  console.error(`Receiving ${reference} is ${receiving.status}, not completed — nothing to backfill.`);
  process.exit(1);
}
if (!receiving.supplierId) {
  console.error(`Receiving ${reference} has no supplier — nothing to backfill.`);
  process.exit(1);
}
const supplier = { supplierId: receiving.supplierId, supplierName: receiving.supplierName ?? null };
console.log(`\n${reference}: supplier ${supplier.supplierName} (${supplier.supplierId})`);
console.log(`${(receiving.items ?? []).length} lines\n`);

const fills = [];
for (const it of receiving.items ?? []) {
  const productId = it.newProductId ?? it.productId;
  const origin = it.newProductId ? 'created-by-receiving' : 'matched';
  if (!productId) continue;
  const ref = db.collection('products').doc(productId);
  const doc = await ref.get();
  if (!doc.exists) {
    console.log(`  SKIP ${it.sku} — product ${productId} no longer exists`);
    continue;
  }
  const p = doc.data();
  if (p.supplierId != null) {
    console.log(`  KEEP ${it.sku} — already supplied by ${p.supplierName ?? p.supplierId}`);
    continue;
  }
  fills.push({ ref, sku: it.sku, name: it.name, origin });
  console.log(`  FILL ${it.sku} (${origin}) — ${it.name}`);
}

console.log(`\n${fills.length} product(s) to fill.`);
if (!execute) {
  console.log('Dry run — re-run with --execute to write.');
  process.exit(0);
}

const batch = db.batch();
for (const f of fills) batch.update(f.ref, supplier);
await batch.commit();
console.log(`DONE — ${fills.length} product(s) now supplied by ${supplier.supplierName}.`);
