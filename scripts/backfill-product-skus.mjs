// One-off, idempotent backfill for the SKU-uniqueness guard (Slice A).
// Claims a product_skus/{normalizeSku(sku)} doc for every product so slices B/C can
// enforce uniqueness atomically. Safe to re-run.
//
// Run:
//   cd scripts && npm install
//   gcloud auth application-default login        # OR export GOOGLE_APPLICATION_CREDENTIALS=<sa.json>
//   node backfill-product-skus.mjs
//
// Exit code 1 (and a printed report) if any SKUs collide on the normalized key —
// resolve those manually (rename one product) and re-run until collisions == 0.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const PROJECT_ID = 'maki-mobile-pos';

// Keep IDENTICAL to the Dart/TS normalizeSku in slices B/C: trim + uppercase.
function normalizeSku(s) {
  return String(s ?? '').trim().toUpperCase();
}

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

async function main() {
  const products = await db.collection('products').get();
  let newlyClaimed = 0;
  let alreadyOwned = 0;
  const collisions = [];

  for (const doc of products.docs) {
    const sku = doc.get('sku');
    const key = normalizeSku(sku);
    if (!key) {
      collisions.push({ key: '(empty)', productId: doc.id, sku, reason: 'empty/invalid sku' });
      continue;
    }
    const claimRef = db.collection('product_skus').doc(key);
    const existing = await claimRef.get();
    if (existing.exists) {
      if (existing.get('productId') === doc.id) {
        alreadyOwned += 1; // idempotent re-run
      } else {
        collisions.push({
          key,
          claimedProductId: existing.get('productId'),
          conflictingProductId: doc.id,
          skus: [existing.get('sku'), sku],
        });
      }
      continue;
    }
    await claimRef.create({
      sku,
      productId: doc.id,
      claimedBy: 'backfill',
      claimedAt: FieldValue.serverTimestamp(),
    });
    newlyClaimed += 1;
  }

  const claimsSnap = await db.collection('product_skus').get();
  console.log('--- product_skus backfill reconciliation ---');
  console.log(`products      = ${products.size}`);
  console.log(`claims        = ${claimsSnap.size}`);
  console.log(`newly claimed = ${newlyClaimed}`);
  console.log(`already owned = ${alreadyOwned}`);
  console.log(`collisions    = ${collisions.length}`);

  if (collisions.length) {
    console.log('\n!!! COLLISIONS — resolve manually before slices B/C go strict:');
    for (const c of collisions) console.log('  ' + JSON.stringify(c));
    console.log('\nFix: rename one of each colliding pair (or fix the empty SKU), then re-run.');
    process.exitCode = 1;
    return;
  }
  if (claimsSnap.size !== products.size) {
    console.log(`\nWARNING: claims (${claimsSnap.size}) != products (${products.size}). Investigate before going strict.`);
    process.exitCode = 1;
    return;
  }
  console.log('\nOK: every product has a unique claim. Backfill complete.');
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
