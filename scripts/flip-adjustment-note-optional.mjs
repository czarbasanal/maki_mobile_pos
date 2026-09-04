// One-off (2026-09-04, user decision): notes on stock adjustments are always
// OPTIONAL — the required reason already explains the change. Flips
// requiresNote -> false on every adjustment_reasons doc. Behavior is
// data-driven on both surfaces, so this takes effect everywhere at once.
// Safe to re-run.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault(), projectId: 'maki-mobile-pos' });
const db = getFirestore();

const snap = await db.collection('adjustment_reasons').get();
console.log(`adjustment_reasons docs: ${snap.size}`);
let flipped = 0;
for (const doc of snap.docs) {
  const d = doc.data();
  console.log(`- ${doc.id}: ${d.name} requiresNote=${d.requiresNote} isActive=${d.isActive}`);
  if (d.requiresNote === true) {
    await doc.ref.update({ requiresNote: false });
    flipped++;
  }
}
console.log(`flipped: ${flipped}`);
