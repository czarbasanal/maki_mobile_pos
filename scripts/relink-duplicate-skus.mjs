// Relinks accidental duplicate products as cost variations of one base.
//
// For every group of products sharing a name + category that are NOT already
// linked, the LOWEST SKU stays as the base and the others are rewritten to
// `<base>-N`, gaining baseSku + variationNumber. Stock is NOT merged — each
// variation keeps its own quantity and cost, which is the point: they are the
// same part bought at different prices.
//
// Per product rewritten, in ONE transaction:
//   - claim the new SKU in product_skus (fails if taken)
//   - release the old claim
//   - update the product: sku, baseSku, variationNumber, searchKeywords
//
// NOT rewritten: history. sales/{id}/items, receivings.items and
// purchase_orders.items store the SKU as text at the time of the sale, which
// is what an audit trail is for. Those lines keep the old code; they still
// resolve by productId.
//
// Dry run:  node relink-duplicate-skus.mjs
// Execute:  node relink-duplicate-skus.mjs --execute
// Emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node relink-duplicate-skus.mjs --execute
//
// NOTE: this machine's IPv6 route is unreliable; if it hangs or reports a
// bogus credentials error, prefix with
//   node --dns-result-order=ipv4first --no-network-family-autoselection
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { planRelink } from './relink-duplicate-skus-lib.mjs';

const PROJECT_ID = 'maki-mobile-pos';
const execute = process.argv.includes('--execute');
const skipPrompt = process.argv.includes('--yes');
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
console.log(EMULATOR ? `TARGET: emulator (${EMULATOR})` : `TARGET: PRODUCTION (${PROJECT_ID})`);

// Mirrors ProductModel._generateSearchKeywords / generateSearchKeywords.
const toKeywords = (v) => {
  const out = new Set();
  for (const word of String(v ?? '').toLowerCase().split(/\s+/)) {
    if (!word) continue;
    for (let i = 1; i <= word.length && i <= 10; i += 1) out.add(word.slice(0, i));
  }
  return [...out];
};
const keywordsFor = (p) => {
  const out = new Set();
  for (const part of [p.sku, p.name, ...(p.barcodes ?? []), p.category]) {
    if (!part) continue;
    for (const k of toKeywords(part)) out.add(k);
  }
  return [...out];
};

const snap = await db.collection('products').get();
const products = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
console.log(`\nfound ${products.length} products`);

const plan = planRelink(products);
const byBase = new Map();
for (const r of plan) {
  if (!byBase.has(r.baseSku)) byBase.set(r.baseSku, []);
  byBase.get(r.baseSku).push(r);
}
console.log(`groups to relink: ${byBase.size}    products to rewrite: ${plan.length}\n`);
for (const [base, rs] of byBase) {
  console.log(`  base ${base}  "${rs[0].name}"`);
  for (const r of rs) console.log(`      ${r.fromSku}  ->  ${r.toSku}   cost ${r.cost}  qty ${r.quantity}`);
}

if (!execute) {
  console.log('\nDRY RUN — nothing written. Re-run with --execute to apply.');
  process.exit(0);
}
if (plan.length === 0) { console.log('\nNothing to relink. Exiting.'); process.exit(0); }

if (!EMULATOR && !skipPrompt) {
  process.stdout.write(`\nIrreversible update to PRODUCTION. Type the project id (${PROJECT_ID}) to confirm: `);
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
  if (line !== PROJECT_ID) { console.error('Confirmation mismatch — aborting. Nothing written.'); process.exit(1); }
}

const byId = new Map(products.map((p) => [p.id, p]));
let done = 0, failed = 0;
for (const r of plan) {
  const product = byId.get(r.id);
  const productRef = db.collection('products').doc(r.id);
  const oldClaim = db.collection('product_skus').doc(String(r.fromSku).trim().toUpperCase());
  const newClaim = db.collection('product_skus').doc(String(r.toSku).trim().toUpperCase());
  try {
    await db.runTransaction(async (tx) => {
      const taken = await tx.get(newClaim);
      if (taken.exists) throw new Error(`claim ${r.toSku} already exists`);
      tx.set(newClaim, { sku: r.toSku, productId: r.id, claimedBy: 'relink-duplicate-skus', claimedAt: new Date() });
      tx.delete(oldClaim);
      tx.update(productRef, {
        sku: r.toSku,
        baseSku: r.baseSku,
        variationNumber: r.variationNumber,
        searchKeywords: keywordsFor({ ...product, sku: r.toSku }),
        updatedBy: 'relink-duplicate-skus',
        updatedAt: new Date(),
      });
    });
    done += 1;
    console.log(`  ok   ${r.fromSku} -> ${r.toSku}`);
  } catch (e) {
    failed += 1;
    console.error(`  FAIL ${r.fromSku} -> ${r.toSku}: ${e.message}`);
  }
}
console.log(`\nRelink complete. ${done} rewritten, ${failed} failed.`);
console.log('Re-run in dry-run mode to confirm it now reports zero.');
if (failed > 0) process.exit(1);
