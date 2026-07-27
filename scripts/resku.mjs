// Re-SKU migration: converts old auto-generated SKUs (name-slug or SKU-xxxx
// patterns) to the coded scheme (4-digit category code + 4-digit sequence).
// See docs/superpowers/specs/2026-07-27-resku-migration-design.md for the
// full design. Pure planning logic lives in resku-lib.mjs; this file only
// does I/O (read plan inputs, print/write the plan, verify + write on
// --execute).
//
// Dry run:  node resku.mjs                     (prints plan, writes scripts/data/resku-plan.json, writes nothing to Firestore)
// Execute:  node resku.mjs --execute
// Emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node resku.mjs --execute
import { mkdir, writeFile } from 'node:fs/promises';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { planResku } from './resku-lib.mjs';

const PROJECT_ID = 'maki-mobile-pos';
const BATCH_SIZE = 400;
const DATA_DIR = new URL('./data/', import.meta.url);

// Keep IDENTICAL to lib/core/utils/sku_generator.dart's normalizeSku and
// scripts/backfill-product-skus.mjs: trim + uppercase.
function normalizeSku(s) {
  return String(s ?? '').trim().toUpperCase();
}

const execute = process.argv.includes('--execute');
const skipPrompt = process.argv.includes('--yes');
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
console.log(EMULATOR
  ? `TARGET: emulator (${EMULATOR})`
  : `TARGET: PRODUCTION (${PROJECT_ID})`);

console.log('\n--- scanning products ---');
const productsSnap = await db.collection('products').get();
const products = productsSnap.docs.map(doc => ({
  id: doc.id,
  sku: doc.get('sku'),
  category: doc.get('category'),
  baseSku: doc.get('baseSku'),
  createdAt: doc.get('createdAt'),
}));
console.log(`found ${products.length} products`);

console.log('\n--- scanning product_categories ---');
const categoriesSnap = await db.collection('product_categories').get();
const categories = categoriesSnap.docs.map(doc => ({
  name: doc.get('name'),
  code: doc.get('code'),
}));
console.log(`found ${categories.length} categories`);

console.log('\n--- scanning category_codes registry ---');
const registrySnap = await db.collection('category_codes').get();
const registry = {};
for (const doc of registrySnap.docs) {
  if (doc.id === '_counter') continue; // not a per-category code doc
  registry[doc.id] = doc.get('nextSequence') ?? 1;
}
console.log(`found ${Object.keys(registry).length} registry entries`);

console.log('\n--- planning ---');
const plan = planResku({ products, categories, registry });

console.log(`\n--- summary ---`);
console.log(`renames:        ${plan.renames.length}`);
console.log(`baseSku fixes:  ${plan.baseSkuFixes.length}`);
console.log(`skipped:        ${plan.skipped.length}`);

const countsByCategory = new Map();
for (const rename of plan.renames) {
  countsByCategory.set(rename.categoryCode, (countsByCategory.get(rename.categoryCode) ?? 0) + 1);
}
console.log(`\n--- renames per category code ---`);
for (const [code, count] of [...countsByCategory.entries()].sort()) {
  console.log(`  ${code}: ${count}`);
}

if (plan.skipped.length > 0) {
  console.log(`\n--- skipped (${plan.skipped.length}) ---`);
  for (const s of plan.skipped) {
    console.log(`  ${s.id}  ${s.oldSku}  -- ${s.reason}`);
  }
}

console.log(`\n--- sample renames (first 15 of ${plan.renames.length}) ---`);
for (const r of plan.renames.slice(0, 15)) {
  console.log(`  ${r.id}  ${r.oldSku} -> ${r.newSku}  (category ${r.categoryCode})`);
}

if (!execute) {
  await mkdir(DATA_DIR, { recursive: true });
  const planPath = new URL('resku-plan.json', DATA_DIR);
  await writeFile(planPath, JSON.stringify(plan, null, 2));
  console.log(`\nDRY RUN — nothing written to Firestore. Full plan written to ${planPath.pathname}`);
  console.log('Re-run with --execute to apply.');
  process.exit(0);
}

// Zero-work early exit
if (plan.renames.length === 0 && plan.baseSkuFixes.length === 0) {
  console.log('\nNo renames or baseSku fixes to apply. Exiting.');
  process.exit(0);
}

// Pre-write verification: every target product_skus/{newSku} claim must be
// absent. Any conflict aborts the WHOLE run (nothing partially applied) —
// re-run resku.mjs (dry-run) to replan against fresh state.
console.log(`\n--- pre-write verification: checking ${plan.renames.length} target claims ---`);
const conflicts = [];
const oldClaimSnaps = new Map(); // oldNormalizedKey -> claim doc data (for claimedBy carry-forward)
for (const rename of plan.renames) {
  const targetRef = db.collection('product_skus').doc(rename.newSku);
  const targetSnap = await targetRef.get();
  if (targetSnap.exists) {
    conflicts.push({ newSku: rename.newSku, id: rename.id, existingProductId: targetSnap.get('productId') });
  }
  const oldKey = normalizeSku(rename.oldSku);
  const oldSnap = await db.collection('product_skus').doc(oldKey).get();
  oldClaimSnaps.set(oldKey, oldSnap.exists ? oldSnap.data() : null);
}

if (conflicts.length > 0) {
  console.error(`\nABORT: ${conflicts.length} target sku(s) already claimed — nothing written.`);
  for (const c of conflicts) {
    console.error(`  ${c.id} -> ${c.newSku} already claimed by ${c.existingProductId}`);
  }
  process.exit(1);
}
console.log('OK: no target claim conflicts.');

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

// Build the write list. Per rename: product doc {sku: newSku} (+ baseSku
// where remapped in the same doc), delete old claim, create new claim.
// Per baseSku-only fix (product not itself renamed): product doc
// {baseSku: newBaseSku}. Per category: registry nextSequence update.
const baseSkuFixByProductId = new Map(plan.baseSkuFixes.map(f => [f.id, f.newBaseSku]));
const renamedProductIds = new Set(plan.renames.map(r => r.id));

const writes = []; // { type: 'productUpdate' | 'claimDelete' | 'claimCreate' | 'registry', ... }

for (const rename of plan.renames) {
  const productData = { sku: rename.newSku };
  const remappedBaseSku = baseSkuFixByProductId.get(rename.id);
  if (remappedBaseSku !== undefined) {
    productData.baseSku = remappedBaseSku;
  }
  writes.push({ type: 'productUpdate', docId: rename.id, data: productData });

  const oldKey = normalizeSku(rename.oldSku);
  writes.push({ type: 'claimDelete', docId: oldKey });

  const oldClaim = oldClaimSnaps.get(oldKey);
  writes.push({
    type: 'claimCreate',
    docId: rename.newSku,
    data: {
      sku: rename.newSku,
      productId: rename.id,
      claimedBy: oldClaim?.claimedBy ?? 'resku-backfill',
      claimedAt: FieldValue.serverTimestamp(),
    },
  });
}

// baseSku fixes for products that were NOT themselves renamed.
for (const fix of plan.baseSkuFixes) {
  if (renamedProductIds.has(fix.id)) continue; // already folded into productUpdate above
  writes.push({ type: 'productUpdate', docId: fix.id, data: { baseSku: fix.newBaseSku } });
}

for (const [code, nextSequence] of Object.entries(plan.registryAfter)) {
  writes.push({ type: 'registry', docId: code, data: { nextSequence } });
}

console.log(`\nwriting ${writes.length} operations in batches of ${BATCH_SIZE}...`);

for (let i = 0; i < writes.length; i += BATCH_SIZE) {
  const batch = db.batch();
  const batchWrites = writes.slice(i, i + BATCH_SIZE);

  for (const write of batchWrites) {
    if (write.type === 'productUpdate') {
      batch.update(db.collection('products').doc(write.docId), write.data);
    } else if (write.type === 'claimDelete') {
      batch.delete(db.collection('product_skus').doc(write.docId));
    } else if (write.type === 'claimCreate') {
      batch.set(db.collection('product_skus').doc(write.docId), write.data);
    } else if (write.type === 'registry') {
      batch.update(db.collection('category_codes').doc(write.docId), write.data);
    }
  }

  await batch.commit();
  console.log(`committed batch ${Math.floor(i / BATCH_SIZE) + 1} (${batchWrites.length} ops)`);
}

const appliedAt = new Date().toISOString();
await mkdir(DATA_DIR, { recursive: true });
// Colon-free name: ':' in an ISO timestamp makes new URL() parse it as a scheme.
  const mapPath = new URL(`resku-map-${appliedAt.replaceAll(':', '-')}.json`, DATA_DIR);
await writeFile(mapPath, JSON.stringify({
  appliedAt,
  renames: plan.renames,
  baseSkuFixes: plan.baseSkuFixes,
  registryAfter: plan.registryAfter,
}, null, 2));

console.log(`\nRe-SKU migration complete. ${plan.renames.length} renamed, ${plan.baseSkuFixes.length} baseSku fixes, ${Object.keys(plan.registryAfter).length} registries updated.`);
console.log(`Applied mapping written to ${mapPath.pathname}`);
