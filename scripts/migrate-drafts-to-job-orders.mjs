// drafts → job_orders schema migration (2026-07-27 rename).
// Phase 1: copy every drafts/{id} → job_orders/{id} (same doc id).
//          Re-run safe: converted targets are never clobbered by unconverted
//          sources, and only strictly-newer sources overwrite.
// Phase 2: sales field move draftId → jobOrderId (old field deleted).
//
// Dry run:  node migrate-drafts-to-job-orders.mjs            (writes nothing)
// Execute:  node migrate-drafts-to-job-orders.mjs --execute        (prompts for the project id)
// Unattended: add --yes to skip the confirm prompt
// Emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node migrate-drafts-to-job-orders.mjs --execute
//
// Old drafts docs are LEFT IN PLACE as backup — deleting them is a separate
// manual cleanup after all phones are confirmed on +18.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { DELETE_FIELD, planSalePatch, shouldCopy } from './migrate-drafts-to-job-orders-lib.mjs';

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

async function commitInBatches(ops) {
  // ops: array of (batch) => void appliers
  for (let i = 0; i < ops.length; i += BATCH_SIZE) {
    const batch = db.batch();
    for (const apply of ops.slice(i, i + BATCH_SIZE)) apply(batch);
    await batch.commit();
    console.log(`  committed ${Math.min(i + BATCH_SIZE, ops.length)}/${ops.length}`);
  }
}

// ---------- Phase 1: copy drafts → job_orders ----------
console.log('\n--- phase 1: drafts → job_orders ---');
const [draftsSnap, jobOrdersSnap] = await Promise.all([
  db.collection('drafts').get(),
  db.collection('job_orders').get(),
]);
const targets = new Map(jobOrdersSnap.docs.map((d) => [d.id, d.data()]));

const copies = [];
let skipped = 0;
for (const doc of draftsSnap.docs) {
  const decision = shouldCopy(doc.data(), targets.get(doc.id) ?? null);
  if (decision.copy) {
    console.log(`COPY ${doc.id} (${doc.data().name ?? '?'}) — ${decision.reason}`);
    copies.push((batch) => batch.set(db.collection('job_orders').doc(doc.id), doc.data()));
  } else {
    skipped += 1;
  }
}
console.log(`drafts: ${draftsSnap.size} · to copy: ${copies.length} · skipped (${skipped}) up-to-date/converted`);

// ---------- Phase 2: sales draftId → jobOrderId ----------
console.log('\n--- phase 2: sales draftId → jobOrderId ---');
const salesSnap = await db.collection('sales').get();
const salePatches = [];
for (const doc of salesSnap.docs) {
  const patch = planSalePatch(doc.data());
  if (!patch) continue;
  const data = Object.fromEntries(
    Object.entries(patch).map(([k, v]) => [k, v === DELETE_FIELD ? FieldValue.delete() : v]),
  );
  console.log(`PATCH sale ${doc.data().saleNumber ?? doc.id}: ${Object.keys(patch).join(', ')}`);
  salePatches.push((batch) => batch.update(doc.ref, data));
}
console.log(`sales: ${salesSnap.size} · to patch: ${salePatches.length}`);

console.log('\n--- summary ---');
console.log(`copies: ${copies.length} · sale patches: ${salePatches.length}`);

if (!execute) {
  console.log('DRY RUN — nothing written. Re-run with --execute to apply.');
  process.exit(0);
}
if (copies.length === 0 && salePatches.length === 0) {
  console.log('Nothing to do. Exiting.');
  process.exit(0);
}

// Production confirm gate (same shape as the sibling backfill scripts): a
// stray --execute would copy every ticket and rewrite every sale doc.
if (!EMULATOR && !skipPrompt) {
  process.stdout.write(`\nIrreversible write to PRODUCTION. Type the project id (${PROJECT_ID}) to confirm: `);
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

await commitInBatches(copies);
await commitInBatches(salePatches);
console.log('DONE. Re-run to verify idempotence (expect 0 copies / 0 patches).');
