// Backfills the `nameKey` duplicate-detection field onto every product, and
// reports the products that already share a name+category.
//
// nameKey is additive and unread until the duplicate-name feature ships, so
// this is safe to run before or after that deploy.
//
// Dry run:  node backfill-product-name-keys.mjs
// Execute:  node backfill-product-name-keys.mjs --execute
// Emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node backfill-product-name-keys.mjs --execute
//
// NOTE: this machine's IPv6 route is unreliable; if the run hangs or reports a
// bogus credentials error, prefix with
//   node --dns-result-order=ipv4first --no-network-family-autoselection
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { duplicateGroups, planNameKeyBackfill } from './backfill-product-name-keys-lib.mjs';

const PROJECT_ID = 'maki-mobile-pos';
const BATCH_SIZE = 400;

const execute = process.argv.includes('--execute');
const skipPrompt = process.argv.includes('--yes');
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
console.log(EMULATOR ? `TARGET: emulator (${EMULATOR})` : `TARGET: PRODUCTION (${PROJECT_ID})`);

const snap = await db.collection('products').get();
const products = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
console.log(`\nfound ${products.length} products`);

const plan = planNameKeyBackfill(products);
console.log(`products needing a nameKey write: ${plan.length}`);

const groups = duplicateGroups(products);
console.log(`\n--- existing duplicate name+category groups: ${groups.length} ---`);
for (const g of groups) {
  console.log(`  ${g.members.length}x  ${g.members.map((m) => m.sku ?? m.id).join('  vs  ')}   "${g.members[0].name}"`);
}
console.log('(report only — merging these is a separate job)');

if (!execute) {
  console.log('\nDRY RUN — nothing written. Re-run with --execute to apply.');
  process.exit(0);
}
if (plan.length === 0) {
  console.log('\nNothing to backfill. Exiting.');
  process.exit(0);
}

if (!EMULATOR && !skipPrompt) {
  process.stdout.write(`\nIrreversible update to PRODUCTION. Type the project id (${PROJECT_ID}) to confirm: `);
  const line = await new Promise((resolve, reject) => {
    let buf = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => {
      buf += chunk;
      const nl = buf.indexOf('\n');
      if (nl !== -1) { process.stdin.pause(); resolve(buf.slice(0, nl).trim()); }
    });
    process.stdin.on('end', () => { process.stdin.pause(); reject(new Error('stdin closed — use --yes for non-interactive runs')); });
    process.stdin.resume();
  }).catch((err) => { console.error(err.message); process.exit(1); });
  if (line !== PROJECT_ID) {
    console.error('Confirmation mismatch — aborting. Nothing written.');
    process.exit(1);
  }
}

console.log(`\nwriting ${plan.length} patches in batches of ${BATCH_SIZE}...`);
for (let i = 0; i < plan.length; i += BATCH_SIZE) {
  const batch = db.batch();
  const slice = plan.slice(i, i + BATCH_SIZE);
  for (const p of slice) batch.update(db.collection('products').doc(p.id), { nameKey: p.nameKey });
  await batch.commit();
  console.log(`committed batch ${Math.floor(i / BATCH_SIZE) + 1} (${slice.length} docs)`);
}
console.log(`\nBackfill complete. ${plan.length} products updated.`);
