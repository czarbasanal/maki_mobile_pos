// Repairs the stale PEEKED-preview SKUs left behind before the withAllocatedSku
// fix in web_admin.
//
// A product created through receiving (or the New Product page) with an
// auto-generated SKU was written with a preview code, and the real code was
// only allocated inside the claiming transaction. When the in-transaction scan
// moved past the preview, two things kept the stale value:
//   1. products/{id}.searchKeywords — derived from the SKU, so the product
//      could not be found by typing the SKU actually printed on it.
//   2. receivings/{id}.items[].sku — so receiving history showed a SKU
//      belonging to some other product, identical across every new line that
//      peeked the same sequence.
// The product's own `sku` field was always correct; only these two derived
// copies drifted. This script repairs both. Planning is pure — see
// repair-preview-skus-lib.mjs and its tests.
//
// The two repairs are scoped SEPARATELY and default to receivings only. The
// keyword pass currently also matches ~950 import-era products that were never
// preview victims: they carry no SKU tokens at all AND a consonant-skeleton
// token family ("pllybllpts" for PULLEY BALL PITSBIKE) that no generator in
// this repo produces. Rebuilding their keywords would add the missing SKU
// tokens but DROP the skeleton ones, so that pass stays opt-in until someone
// decides whether those tokens are still wanted. See scripts/README.md.
//
// Dry run:  node repair-preview-skus.mjs                    (report only, writes nothing)
// Execute:  node repair-preview-skus.mjs --execute          (receiving lines only)
// Keywords: node repair-preview-skus.mjs --scope=keywords --execute
// Both:     node repair-preview-skus.mjs --scope=all --execute
// Emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node repair-preview-skus.mjs --execute
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import {
  duplicateSkusIn,
  planKeywordRepair,
  planReceivingItemFixes,
} from './repair-preview-skus-lib.mjs';

const PROJECT_ID = 'maki-mobile-pos';
const BATCH_SIZE = 400;

const execute = process.argv.includes('--execute');
const skipPrompt = process.argv.includes('--yes');

// 'receivings' (default) | 'keywords' | 'all'
const scopeArg = process.argv.find((a) => a.startsWith('--scope='));
const scope = scopeArg ? scopeArg.slice('--scope='.length) : 'receivings';
if (!['receivings', 'keywords', 'all'].includes(scope)) {
  console.error(`unknown --scope=${scope} (expected receivings, keywords or all)`);
  process.exit(2);
}
const doKeywords = scope === 'keywords' || scope === 'all';
const doReceivings = scope === 'receivings' || scope === 'all';
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
console.log(EMULATOR
  ? `TARGET: emulator (${EMULATOR})`
  : `TARGET: PRODUCTION (${PROJECT_ID})`);

// --- scan products -----------------------------------------------------
console.log('\n--- scanning products ---');
const productSnap = await db.collection('products').get();

// Every product, keyed by id — the receiving pass copies the authoritative
// sku from here, so it needs the whole set, not just the broken ones.
const productsById = new Map();
for (const doc of productSnap.docs) {
  productsById.set(doc.id, { id: doc.id, ...doc.data() });
}
console.log(`found ${productsById.size} products`);

const keywordPatches = []; // { docId, keywords }
for (const product of productsById.values()) {
  const fix = planKeywordRepair(product);
  if (!fix) continue;
  console.log(
    `  ${fix.sku}  ${product.name ?? '(unnamed)'}  ` +
    `+${fix.keywords.length} kw, dropping ${fix.dropped.length}` +
    (fix.dropped.length ? ` [${fix.dropped.join(' ')}]` : ''),
  );
  keywordPatches.push({ docId: fix.id, keywords: fix.keywords });
}
console.log(`products needing keyword repair: ${keywordPatches.length}`);
if (!doKeywords && keywordPatches.length > 0) {
  console.log('  (reported only — re-run with --scope=keywords to write these)');
}

// --- scan receivings ---------------------------------------------------
console.log('\n--- scanning receivings ---');
const receivingSnap = await db.collection('receivings').get();
console.log(`found ${receivingSnap.size} receivings`);

const itemPatches = []; // { docId, items }
let lineFixCount = 0;
for (const doc of receivingSnap.docs) {
  const data = doc.data();
  const receiving = { id: doc.id, ...data };
  const fixes = planReceivingItemFixes(receiving, productsById);
  const dupes = duplicateSkusIn(receiving);

  if (dupes.length > 0) {
    const label = data.referenceNumber || doc.id;
    for (const d of dupes) {
      console.log(`  ${label}: sku ${d.sku} appears on ${d.count} lines`);
    }
  }
  if (fixes.length === 0) continue;

  const label = data.referenceNumber || doc.id;
  for (const f of fixes) {
    console.log(`  ${label}: line ${f.index} ${f.name} — ${f.from} → ${f.to}`);
  }

  // Rewrite the whole array: Firestore has no index-addressed array update,
  // and the lines are read as a unit anyway.
  const items = (data.items ?? []).map((it, i) => {
    const fix = fixes.find((f) => f.index === i);
    return fix ? { ...it, sku: fix.to } : it;
  });
  itemPatches.push({ docId: doc.id, items });
  lineFixCount += fixes.length;
}
console.log(`receivings needing line repair: ${itemPatches.length} (${lineFixCount} lines)`);

// --- summary -----------------------------------------------------------
console.log('\n--- summary ---');
console.log(`scope: ${scope}`);
console.log(
  `product keyword patches: ${keywordPatches.length}` +
  (doKeywords ? '' : ' (NOT in scope — reported only)'),
);
console.log(
  `receiving item patches:  ${itemPatches.length} (${lineFixCount} lines)` +
  (doReceivings ? '' : ' (NOT in scope — reported only)'),
);
const totalPatches =
  (doKeywords ? keywordPatches.length : 0) + (doReceivings ? itemPatches.length : 0);

if (!execute) {
  console.log('\nDRY RUN — nothing written. Re-run with --execute to apply.');
  process.exit(0);
}

if (totalPatches === 0) {
  console.log('\nNothing to repair. Exiting.');
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

// --- write -------------------------------------------------------------
const writes = [
  ...(doKeywords
    ? keywordPatches.map((p) => ({
        ref: db.collection('products').doc(p.docId),
        data: { searchKeywords: p.keywords },
      }))
    : []),
  ...(doReceivings
    ? itemPatches.map((p) => ({
        ref: db.collection('receivings').doc(p.docId),
        data: { items: p.items },
      }))
    : []),
];

console.log(`\nwriting ${writes.length} patches in batches of ${BATCH_SIZE}...`);
for (let i = 0; i < writes.length; i += BATCH_SIZE) {
  const batch = db.batch();
  const slice = writes.slice(i, i + BATCH_SIZE);
  for (const { ref, data } of slice) batch.update(ref, data);
  await batch.commit();
  console.log(`committed batch ${Math.floor(i / BATCH_SIZE) + 1} (${slice.length} docs)`);
}

console.log(
  `\nRepair complete. ` +
  `${doKeywords ? keywordPatches.length : 0} products, ` +
  `${doReceivings ? itemPatches.length : 0} receivings updated.`,
);
console.log('Re-run in dry-run mode to confirm it now reports zero patches.');
