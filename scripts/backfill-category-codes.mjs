// Backfill script for category code assignments.
// Assigns 4-digit codes (0001, 0002, etc.) to categories that don't have one.
// Creates registry entries and a counter for future assignments.
//
// Dry run:  node backfill-category-codes.mjs           (prints all planned assignments, writes nothing)
// Execute:  node backfill-category-codes.mjs --execute
// Emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node backfill-category-codes.mjs --execute
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, serverTimestamp } from 'firebase-admin/firestore';
import { planAssignments, counterAfter } from './backfill-category-codes-lib.mjs';

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

// Collect assignments to write
const writes = []; // { type: 'category' | 'registry', docId?, data }
let counterValue = 0;

console.log('\n--- scanning product_categories ---');

// Stream all category docs
const categoriesRef = db.collection('product_categories');
const snapshot = await categoriesRef.get();

const categories = snapshot.docs.map(doc => ({
  ...doc.data(),
  id: doc.id,
}));

console.log(`found ${categories.length} categories`);

// Plan assignments
const assignments = planAssignments(categories);

console.log(`\n--- assignments ---`);

if (assignments.length === 0) {
  console.log('No uncoded categories. Nothing to do.');
  process.exit(0);
}

// Prepare writes for each assignment
for (const assignment of assignments) {
  const { id: categoryId, code, name } = assignment;
  console.log(`${categoryId} → ${code} (${name})`);

  // Write 1: category doc with code field
  writes.push({
    type: 'category',
    docId: categoryId,
    data: { code },
  });

  // Write 2: registry doc
  writes.push({
    type: 'registry',
    docId: code,
    data: {
      categoryId,
      nameSnapshot: name,
      assignedAt: serverTimestamp(),
      nextSequence: 1,
    },
  });
}

// Calculate counter value
const existingCodes = categories
  .filter(cat => cat.code)
  .map(cat => parseInt(cat.code, 10))
  .filter(code => !isNaN(code));
const maxExisting = existingCodes.length > 0 ? Math.max(...existingCodes) : 0;
counterValue = counterAfter(assignments, maxExisting);

console.log(`\n--- summary ---`);
console.log(`assignments: ${assignments.length}`);
console.log(`registry entries: ${assignments.length}`);
console.log(`counter will be set to: ${counterValue}`);
console.log(`total writes: ${writes.length + 1}`);

if (!execute) {
  console.log(`DRY RUN — nothing written. Re-run with --execute to apply assignments.`);
  process.exit(0);
}

// Zero-work early exit
if (writes.length === 0) {
  console.log('No writes to apply. Exiting.');
  process.exit(0);
}

// Execute mode: write assignments in batches
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

console.log(`\nwriting ${writes.length} docs in batches of ${BATCH_SIZE}...`);

for (let i = 0; i < writes.length; i += BATCH_SIZE) {
  const batch = db.batch();
  const batchWrites = writes.slice(i, i + BATCH_SIZE);

  for (const write of batchWrites) {
    if (write.type === 'category') {
      batch.update(db.collection('product_categories').doc(write.docId), write.data);
    } else if (write.type === 'registry') {
      batch.set(db.collection('category_codes').doc(write.docId), write.data);
    }
  }

  await batch.commit();
  console.log(`committed batch ${Math.floor(i / BATCH_SIZE) + 1} (${batchWrites.length} docs)`);
}

// Write counter (in its own batch)
console.log(`\nwriting counter...`);
const counterBatch = db.batch();
counterBatch.set(db.collection('category_codes').doc('_counter'), { next: counterValue });
await counterBatch.commit();
console.log(`committed counter (next: ${counterValue})`);

console.log(`\nBackfill complete. ${assignments.length} categories coded, counter set to ${counterValue}.`);
