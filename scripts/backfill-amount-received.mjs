// Backfill script for amountReceived bug in mobile cash sales.
// Bug: sales written since 2026-05-28 stored amountReceived = total instead of tendered cash.
// Truth: amountReceived + changeGiven = total.
//
// Dry run:  node backfill-amount-received.mjs           (prints all planned patches, writes nothing)
// Execute:  node backfill-amount-received.mjs --execute
// Emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node backfill-amount-received.mjs --execute
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { planPatch } from './backfill-amount-received-lib.mjs';

const PROJECT_ID = 'maki-mobile-pos';
const BATCH_SIZE = 400;

const execute = process.argv.includes('--execute');
const skipPrompt = process.argv.includes('--yes');
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
console.log(EMULATOR
  ? `TARGET: emulator (${EMULATOR})`
  : `TARGET: PRODUCTION (${PROJECT_ID})`);

// Collect patches to write
const patches = []; // { docId, data: { amountReceived: newValue } }

console.log('\n--- scanning sales for patches ---');

// Stream all sales docs
// Deliberately patches ALL sales regardless of status (incl. voided): the bug lives in the doc's own fields and voided sales are excluded from report math — record accuracy only.
const salesRef = db.collection('sales');
const snapshot = await salesRef.get();

for (const doc of snapshot.docs) {
  const data = doc.data();
  const patch = planPatch(data);

  if (patch) {
    const saleNumber = data.saleNumber || doc.id;
    console.log(`${saleNumber} ${data.amountReceived} → ${patch.amountReceived}`);
    patches.push({ docId: doc.id, data: patch });
  }
}

console.log(`\n--- summary ---`);
console.log(`patches found: ${patches.length}`);

if (!execute) {
  console.log(`DRY RUN — nothing written. Re-run with --execute to apply patches.`);
  process.exit(0);
}

// Zero-patch early exit
if (patches.length === 0) {
  console.log('No patches to apply. Exiting.');
  process.exit(0);
}

// Execute mode: write patches in batches
if (!EMULATOR) {
  if (!skipPrompt) {
    process.stdout.write(`\nIrreversible update to PRODUCTION. Type the project id (${PROJECT_ID}) to confirm: `);
    const line = await new Promise((resolve, reject) => {
      let buf = '';
      process.stdin.setEncoding('utf8');
      process.stdin.on('data', (chunk) => {
        buf += chunk;
        const nl = buf.indexOf('\n');
        if (nl !== -1) { process.stdin.pause(); resolve(buf.slice(0, nl).trim()); }
      });
      process.stdin.on('end', () => {
        process.stdin.pause();
        reject(new Error('stdin closed — use --yes for non-interactive runs'));
      });
      process.stdin.resume();
    }).catch((err) => {
      console.error(err.message);
      process.exit(1);
    });
    if (line !== PROJECT_ID) {
      console.error('Confirmation mismatch — aborting. Nothing written.');
      process.exit(1);
    }
  }
}

console.log(`\nwriting ${patches.length} patches in batches of ${BATCH_SIZE}...`);

for (let i = 0; i < patches.length; i += BATCH_SIZE) {
  const batch = db.batch();
  const batchPatches = patches.slice(i, i + BATCH_SIZE);

  for (const { docId, data } of batchPatches) {
    batch.update(db.collection('sales').doc(docId), data);
  }

  await batch.commit();
  console.log(`committed batch ${Math.floor(i / BATCH_SIZE) + 1} (${batchPatches.length} docs)`);
}

console.log(`\nBackfill complete. ${patches.length} sales updated.`);
