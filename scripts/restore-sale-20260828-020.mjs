// One-off: restore SALE-20260828-020 and correct its payment.
//
// The sale was real — parts ₱85 plus ₱200 labour ("Ilis carbon brass", mechanic
// Jeric, from job order 7aivsax8whA9DQoeVZzW). The cashier tried to take ₱85 on
// Maya and ₱200 in cash, but the Mixed screen seeded GCash, so the whole ₱285
// was booked as GCash. It was voided for "Payment issue" — the record was
// wrong, not the transaction.
//
// This restores it as a completed MIXED sale, tenders {maya: 85, cash: 200},
// and clears the void fields from the sale document so it reads as an ordinary
// completed sale in history.
//
// Stock: the void restored +1 of each item (verified — both products carry
// updatedBy=Czar at the void timestamp, 2026-08-28T21:47:1x). Restoring the
// sale therefore decrements each by 1 again, back to what it was when the sale
// stood.
//
// NOT touched:
//  - user_logs. The two void entries record something that genuinely happened;
//    deleting audit history to tidy a record is worse than the untidiness.
//  - daily_closings/2026-08-28. It is an immutable snapshot, and it was sealed
//    at 21:24 — BEFORE the 21:47 void — so it already counted this sale as
//    GCash ₱285. After this correction the day recomputes with ₱200 more cash,
//    so the sealed expected (₱5,241) trails a recomputed ₱5,441. See the report.
//
// Dry run:  node restore-sale-20260828-020.mjs
// Execute:  node restore-sale-20260828-020.mjs --execute --backup=<path>
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { writeFileSync } from 'node:fs';

const PROJECT_ID = 'maki-mobile-pos';
const SALE_NUMBER = 'SALE-20260828-020';
const TENDERS = { maya: 85, cash: 200 };

const execute = process.argv.includes('--execute');
const backupArg = process.argv.find((a) => a.startsWith('--backup='));
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();
console.log(process.env.FIRESTORE_EMULATOR_HOST
  ? `TARGET: emulator` : `TARGET: PRODUCTION (${PROJECT_ID})`);

const q = await db.collection('sales').where('saleNumber', '==', SALE_NUMBER).get();
if (q.size !== 1) { console.error(`expected exactly 1 sale, found ${q.size}`); process.exit(1); }
const saleDoc = q.docs[0];
const sale = saleDoc.data();
const itemsSnap = await saleDoc.ref.collection('items').get();
const items = itemsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

const sum = Object.values(TENDERS).reduce((a, b) => a + b, 0);
console.log(`\n${SALE_NUMBER}  (${saleDoc.id})`);
console.log(`  status         ${sale.status}  ->  completed`);
console.log(`  paymentMethod  ${sale.paymentMethod}  ->  mixed`);
console.log(`  tenders        ${JSON.stringify(sale.tenders)}  ->  ${JSON.stringify(TENDERS)}  (sums to ${sum})`);
console.log(`  clearing       voidedBy, voidedByName, voidedAt, voidReason`);
if (sum !== Number(sale.amountReceived)) {
  console.error(`\nABORT: tenders sum ${sum} != amountReceived ${sale.amountReceived}`);
  process.exit(1);
}

console.log(`\n  stock to re-decrement (the void had restored these):`);
const stock = [];
for (const it of items) {
  const p = await db.collection('products').doc(it.productId).get();
  if (!p.exists) { console.error(`ABORT: product ${it.productId} missing`); process.exit(1); }
  stock.push({ productId: it.productId, name: it.name, qty: it.quantity, before: p.data().quantity });
  console.log(`    ${it.name.padEnd(26)} ${p.data().quantity} -> ${p.data().quantity - it.quantity}`);
}

if (!execute) {
  console.log('\nDRY RUN — nothing written. Re-run with --execute --backup=<path>.');
  process.exit(0);
}
if (!backupArg) { console.error('--backup=<path> is required for --execute'); process.exit(1); }

const backupPath = backupArg.slice('--backup='.length);
writeFileSync(backupPath, JSON.stringify({
  correctedAt: new Date().toISOString(),
  sale: { id: saleDoc.id, data: sale },
  items,
  stockBefore: stock,
}, null, 1));
console.log(`\nBACKUP -> ${backupPath}`);

await db.runTransaction(async (tx) => {
  tx.update(saleDoc.ref, {
    status: 'completed',
    paymentMethod: 'mixed',
    tenders: TENDERS,
    voidedBy: FieldValue.delete(),
    voidedByName: FieldValue.delete(),
    voidedAt: FieldValue.delete(),
    voidReason: FieldValue.delete(),
  });
  for (const s of stock) {
    tx.update(db.collection('products').doc(s.productId), {
      quantity: FieldValue.increment(-s.qty),
    });
  }
});
console.log('\nRestored. Re-run the dry run to confirm it now reads as completed/mixed.');
