// One-off DEMO script: injects backdated mock price_history entries under a few
// real products so the price-history screen / price-change report have data to show.
//
// Every injected doc carries `mock: true` (ignored by app readers) so cleanup is:
//   node inject-mock-price-history.mjs --clean
//
// Run:
//   cd scripts && npm install
//   gcloud auth application-default login   # OR export GOOGLE_APPLICATION_CREDENTIALS=<sa.json>
//   node inject-mock-price-history.mjs
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

const PROJECT_ID = 'maki-mobile-pos';
const PRODUCT_COUNT = 5;      // how many products get mock history
const ENTRIES_PER_PRODUCT = 6; // backdated entries per product (spread over ~90 days)

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

async function clean() {
  const snap = await db.collectionGroup('price_history').where('mock', '==', true).get();
  for (const doc of snap.docs) await doc.ref.delete();
  console.log(`Deleted ${snap.size} mock price_history docs.`);
}

function round2(n) {
  return Math.round(n * 100) / 100;
}

async function inject() {
  // A real uid so the UIs resolve a display name (prefer an admin).
  const users = await db.collection('users').limit(20).get();
  if (users.empty) throw new Error('No users found — need a uid for changedBy.');
  const admin = users.docs.find((d) => d.get('role') === 'admin') ?? users.docs[0];
  const changedBy = admin.id;
  console.log(`changedBy = ${changedBy} (${admin.get('name') ?? admin.get('email') ?? 'unknown'})`);

  const products = await db
    .collection('products')
    .where('isActive', '==', true)
    .limit(PRODUCT_COUNT)
    .get();
  if (products.empty) throw new Error('No active products found.');

  const now = Date.now();
  const DAY = 24 * 60 * 60 * 1000;
  let written = 0;

  for (const prod of products.docs) {
    const currentPrice = Number(prod.get('price') ?? 0) || 100;
    const currentCost = Number(prod.get('cost') ?? 0) || 60;

    // Walk backwards from the current values so the newest entry matches the
    // product doc and older entries drift away from it.
    let price = currentPrice;
    let cost = currentCost;
    const entries = [];
    for (let i = 0; i < ENTRIES_PER_PRODUCT; i += 1) {
      const daysAgo = 3 + i * (85 / ENTRIES_PER_PRODUCT) + Math.random() * 6;
      const changedAt = new Date(now - daysAgo * DAY);

      const kind = i % 3; // vary which metric moved
      const reasons = ['Price update', 'Cost update', 'Price + cost update'];
      let reason = reasons[kind];
      let note = null;
      if (i === ENTRIES_PER_PRODUCT - 2) {
        reason = 'Stock receiving';
        const d = changedAt;
        const ymd = `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}`;
        note = `Mock demo — RCV-${ymd}-0001`;
      }

      entries.push({ price: round2(price), cost: round2(cost), changedAt, reason, note });

      // Prepare the OLDER values for the next (earlier) entry: undo a change.
      const priceStep = round2(currentPrice * (0.03 + Math.random() * 0.07));
      const costStep = round2(currentCost * (0.03 + Math.random() * 0.07));
      if (kind === 0) price = round2(price - (Math.random() < 0.7 ? priceStep : -priceStep));
      else if (kind === 1) cost = round2(cost - (Math.random() < 0.7 ? costStep : -costStep));
      else {
        price = round2(price - priceStep);
        cost = round2(cost - costStep);
      }
      if (price <= 0) price = round2(currentPrice * 0.5);
      if (cost <= 0) cost = round2(currentCost * 0.5);
    }

    const ref = prod.ref.collection('price_history');
    for (const e of entries) {
      await ref.add({
        price: e.price,
        cost: e.cost,
        changedAt: Timestamp.fromDate(e.changedAt),
        changedBy,
        reason: e.reason,
        note: e.note,
        mock: true,
      });
      written += 1;
    }
    console.log(`${prod.get('name') ?? prod.id}: +${entries.length} entries (₱${entries[entries.length - 1].price} → ₱${entries[0].price})`);
  }

  console.log(`\nDone. Wrote ${written} mock docs across ${products.size} products.`);
  console.log('Cleanup: node inject-mock-price-history.mjs --clean');
}

if (process.argv.includes('--clean')) await clean();
else await inject();
