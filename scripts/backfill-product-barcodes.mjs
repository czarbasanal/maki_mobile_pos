// One-off, idempotent backfill for the BARCODE-uniqueness guard (Slice A).
// Claims a product_barcodes/{normalizeBarcode(code)} doc for every in-use barcode
// (a product's `barcodes` array ∪ a legacy singular `barcode`) so slices B/C can
// enforce uniqueness atomically. Barcodes are OPTIONAL (no barcode → no claim).
// Safe to re-run.
//
// Run:
//   cd scripts && npm install
//   gcloud auth application-default login        # OR export GOOGLE_APPLICATION_CREDENTIALS=<sa.json>
//   node backfill-product-barcodes.mjs
//
// Exit code 1 (and a printed report) if any barcodes collide on the normalized key
// (two products share a code) or a code can't be a Firestore doc id — resolve those
// manually (rename/clear one) and re-run until collisions == 0 and invalid == 0.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const PROJECT_ID = 'maki-mobile-pos';

// Keep IDENTICAL to the Dart/TS normalizeBarcode in slices B/C: trim only
// (case-sensitive — barcodes are exact scanned tokens).
function normalizeBarcode(s) {
  return String(s ?? '').trim();
}

// Firestore doc-id constraints: non-empty, no '/', not '.'/'..', not __.*__, <=1500 bytes.
function isValidDocId(id) {
  return (
    id.length > 0 &&
    Buffer.byteLength(id, 'utf8') <= 1500 &&
    !id.includes('/') &&
    id !== '.' &&
    id !== '..' &&
    !/^__.*__$/.test(id)
  );
}

// A product's barcode set: the `barcodes` array ∪ a legacy singular `barcode`,
// normalized and de-duped by key.
function barcodeKeys(doc) {
  const raw = [];
  const arr = doc.get('barcodes');
  if (Array.isArray(arr)) raw.push(...arr);
  const legacy = doc.get('barcode');
  if (legacy != null) raw.push(legacy);
  const keys = new Set();
  for (const r of raw) {
    const key = normalizeBarcode(r);
    if (key) keys.add(key);
  }
  return [...keys];
}

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

async function main() {
  const products = await db.collection('products').get();
  let barcodesFound = 0;
  let newlyClaimed = 0;
  let alreadyOwned = 0;
  const collisions = [];
  const invalid = [];

  for (const doc of products.docs) {
    for (const key of barcodeKeys(doc)) {
      barcodesFound += 1;
      if (!isValidDocId(key)) {
        invalid.push({ key, productId: doc.id });
        continue;
      }
      const claimRef = db.collection('product_barcodes').doc(key);
      const existing = await claimRef.get();
      if (existing.exists) {
        if (existing.get('productId') === doc.id) {
          alreadyOwned += 1; // idempotent re-run
        } else {
          collisions.push({
            key,
            claimedProductId: existing.get('productId'),
            conflictingProductId: doc.id,
          });
        }
        continue;
      }
      await claimRef.create({
        barcode: key,
        productId: doc.id,
        claimedBy: 'backfill',
        claimedAt: FieldValue.serverTimestamp(),
      });
      newlyClaimed += 1;
    }
  }

  const claimsSnap = await db.collection('product_barcodes').get();
  console.log('--- product_barcodes backfill reconciliation ---');
  console.log(`products       = ${products.size}`);
  console.log(`barcodes found = ${barcodesFound}`);
  console.log(`claims         = ${claimsSnap.size}`);
  console.log(`newly claimed  = ${newlyClaimed}`);
  console.log(`already owned  = ${alreadyOwned}`);
  console.log(`collisions     = ${collisions.length}`);
  console.log(`invalid        = ${invalid.length}`);

  if (collisions.length || invalid.length) {
    if (collisions.length) {
      console.log('\n!!! COLLISIONS — two products share a barcode; resolve before B/C:');
      for (const c of collisions) console.log('  ' + JSON.stringify(c));
    }
    if (invalid.length) {
      console.log('\n!!! INVALID barcodes (cannot be a doc id) — fix/clear before B/C:');
      for (const i of invalid) console.log('  ' + JSON.stringify(i));
    }
    console.log('\nFix the offending products, then re-run.');
    process.exitCode = 1;
    return;
  }
  console.log('\nOK: every in-use barcode has a unique claim. Backfill complete.');
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
