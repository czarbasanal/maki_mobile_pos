// Deletes the legacy `drafts` documents left as a backup by the
// drafts→job_orders migration (2026-07-28). IRREVERSIBLE.
//
// All-or-nothing by design: every draft must have a verified
// `job_orders/{sameId}` counterpart. If even one doesn't, nothing is deleted.
//
// Dry run:  node delete-legacy-drafts.mjs             (writes nothing)
// Execute:  node delete-legacy-drafts.mjs --execute   (prompts for project id)
// Unattended: add --yes to skip the confirm prompt
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { safeToDelete } from './delete-legacy-drafts-lib.mjs';

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

const [draftsSnap, jobOrdersSnap] = await Promise.all([
  db.collection('drafts').get(),
  db.collection('job_orders').get(),
]);
const copies = new Map(jobOrdersSnap.docs.map((d) => [d.id, d.data()]));

console.log(`\nlegacy drafts: ${draftsSnap.size} · job_orders: ${jobOrdersSnap.size}`);
console.log('\n--- verifying every legacy doc against its copy ---');

const deletable = [];
const blocked = [];
for (const doc of draftsSnap.docs) {
  const verdict = safeToDelete(doc.data(), copies.get(doc.id) ?? null);
  if (verdict.safe) {
    deletable.push(doc.ref);
  } else {
    blocked.push({ id: doc.id, name: doc.data().name ?? '?', reason: verdict.reason });
    console.log(`BLOCKED ${doc.id} (${doc.data().name ?? '?'}) — ${verdict.reason}`);
  }
}

console.log(`\nverified deletable: ${deletable.length} · blocked: ${blocked.length}`);

if (blocked.length > 0) {
  console.error('\nABORT: at least one legacy doc has no verified copy. '
    + 'Nothing deleted — investigate the entries above first.');
  process.exit(1);
}
if (deletable.length === 0) {
  console.log('Nothing to delete. Exiting.');
  process.exit(0);
}
if (!execute) {
  console.log('DRY RUN — nothing written. Re-run with --execute to delete.');
  process.exit(0);
}

if (!EMULATOR && !skipPrompt) {
  process.stdout.write(`\nIRREVERSIBLE delete of ${deletable.length} legacy drafts in PRODUCTION. `
    + `Type the project id (${PROJECT_ID}) to confirm: `);
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
    console.error('Confirmation mismatch — aborting. Nothing deleted.');
    process.exit(1);
  }
}

for (let i = 0; i < deletable.length; i += BATCH_SIZE) {
  const batch = db.batch();
  for (const ref of deletable.slice(i, i + BATCH_SIZE)) batch.delete(ref);
  await batch.commit();
  console.log(`  deleted ${Math.min(i + BATCH_SIZE, deletable.length)}/${deletable.length}`);
}
console.log('DONE. Re-run to confirm the collection is empty.');
