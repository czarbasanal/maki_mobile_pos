// PERMANENTLY deletes every archived (isActive === false) product.
//
// For each one, in a batch: the product doc, every doc in its price_history
// subcollection, its product_skus claim, and any product_barcodes claims.
// Releasing the claims is what frees the SKU and barcode for reuse — a bare
// product delete would leave them claimed forever.
//
// DESTRUCTIVE AND IRREVERSIBLE. Before writing anything, --execute dumps every
// product and subdoc it is about to remove to a timestamped JSON file and
// prints the path. That file is the only way back.
//
// History is NOT rewritten: sale, receiving, purchase-order and job-order
// lines keep the productId and SKU they recorded. Those references become
// orphans — the line still shows what was sold, but the product it points at
// no longer exists.
//
// Dry run:  node purge-archived-products.mjs
// Execute:  node purge-archived-products.mjs --execute
// Emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node purge-archived-products.mjs --execute
//
// NOTE: prefix with `node --dns-result-order=ipv4first --no-network-family-autoselection`
// on this machine — its IPv6 route is unreliable and Node reports the timeout
// as a bogus credentials error.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { writeFileSync } from 'node:fs';

const PROJECT_ID = 'maki-mobile-pos';
const BATCH_SIZE = 300;
const execute = process.argv.includes('--execute');
const skipPrompt = process.argv.includes('--yes');
const outArg = process.argv.find((a) => a.startsWith('--backup='));
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
console.log(EMULATOR ? `TARGET: emulator (${EMULATOR})` : `TARGET: PRODUCTION (${PROJECT_ID})`);

const all = (await db.collection('products').get()).docs;
const dead = all.filter((d) => d.data().isActive === false);
console.log(`\n${all.length} products, ${dead.length} archived`);
if (dead.length === 0) { console.log('Nothing to purge. Exiting.'); process.exit(0); }

const units = dead.reduce((s, d) => s + Number(d.data().quantity ?? 0), 0);
const value = dead.reduce((s, d) => s + Number(d.data().quantity ?? 0) * Number(d.data().cost ?? 0), 0);
console.log(`stock riding on them: ${units} units, cost value ₱${value.toLocaleString('en-PH')}`);

// gather everything so the backup is complete before any delete
const payload = [];
let phCount = 0;
for (const d of dead) {
  const ph = (await d.ref.collection('price_history').get()).docs;
  phCount += ph.length;
  payload.push({
    id: d.id,
    product: d.data(),
    priceHistory: ph.map((h) => ({ id: h.id, data: h.data() })),
  });
}
const skuClaims = (await db.collection('product_skus').get()).docs
  .filter((c) => dead.some((d) => d.id === c.data().productId));
const barcodeClaims = (await db.collection('product_barcodes').get()).docs
  .filter((c) => dead.some((d) => d.id === c.data().productId));

console.log(`\nwould delete:`);
console.log(`  ${dead.length} product docs`);
console.log(`  ${phCount} price_history subdocs`);
console.log(`  ${skuClaims.length} product_skus claims`);
console.log(`  ${barcodeClaims.length} product_barcodes claims`);
console.log(`\nthe 10 largest by stock value:`);
for (const d of [...dead]
  .sort((a, b) => Number(b.data().quantity ?? 0) * Number(b.data().cost ?? 0) -
                  Number(a.data().quantity ?? 0) * Number(a.data().cost ?? 0)).slice(0, 10)) {
  const p = d.data();
  const v = Number(p.quantity ?? 0) * Number(p.cost ?? 0);
  console.log(`  ${String(p.sku).padEnd(12)} qty ${String(p.quantity ?? 0).padStart(3)}  ₱${String(v.toLocaleString('en-PH')).padStart(9)}  "${p.name}"`);
}

if (!execute) {
  console.log('\nDRY RUN — nothing written. Re-run with --execute to apply.');
  process.exit(0);
}

if (!EMULATOR && !skipPrompt) {
  process.stdout.write(`\nPERMANENT DELETE from PRODUCTION. Type the project id (${PROJECT_ID}) to confirm: `);
  const line = await new Promise((resolve, reject) => {
    let buf = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (c) => {
      buf += c;
      const nl = buf.indexOf('\n');
      if (nl !== -1) { process.stdin.pause(); resolve(buf.slice(0, nl).trim()); }
    });
    process.stdin.on('end', () => { process.stdin.pause(); reject(new Error('stdin closed — use --yes for non-interactive runs')); });
    process.stdin.resume();
  }).catch((e) => { console.error(e.message); process.exit(1); });
  if (line !== PROJECT_ID) { console.error('Confirmation mismatch — aborting. Nothing deleted.'); process.exit(1); }
}

const backupPath = outArg ? outArg.slice('--backup='.length) : `./archived-products-backup.json`;
writeFileSync(backupPath, JSON.stringify({
  purgedAt: new Date().toISOString(),
  products: payload,
  skuClaims: skuClaims.map((c) => ({ id: c.id, data: c.data() })),
  barcodeClaims: barcodeClaims.map((c) => ({ id: c.id, data: c.data() })),
}, null, 1));
console.log(`\nBACKUP WRITTEN -> ${backupPath}  (${payload.length} products) — this is the only way back`);

const refs = [];
for (const entry of payload) {
  for (const h of entry.priceHistory) refs.push(db.collection('products').doc(entry.id).collection('price_history').doc(h.id));
  refs.push(db.collection('products').doc(entry.id));
}
for (const c of skuClaims) refs.push(c.ref);
for (const c of barcodeClaims) refs.push(c.ref);

console.log(`deleting ${refs.length} docs in batches of ${BATCH_SIZE}...`);
for (let i = 0; i < refs.length; i += BATCH_SIZE) {
  const batch = db.batch();
  const slice = refs.slice(i, i + BATCH_SIZE);
  for (const r of slice) batch.delete(r);
  await batch.commit();
  console.log(`  committed batch ${Math.floor(i / BATCH_SIZE) + 1} (${slice.length} docs)`);
}
console.log(`\nPurge complete. ${dead.length} archived products permanently deleted.`);
