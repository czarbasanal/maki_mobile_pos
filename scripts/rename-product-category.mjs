// One-off: rename a product category and re-point every product's denormalized
// `category` string. Historical records (receivings) keep their snapshot names.
//
// Run:
//   cd scripts && npm install
//   gcloud auth application-default login   # OR export GOOGLE_APPLICATION_CREDENTIALS=<sa.json>
//   node rename-product-category.mjs "Old Name" "New Name"          # dry-run
//   node rename-product-category.mjs "Old Name" "New Name" --apply  # write
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const PROJECT_ID = 'maki-mobile-pos';

const [oldName, newName, applyFlag] = process.argv.slice(2);
if (!oldName || !newName) {
  console.error('Usage: node rename-product-category.mjs "Old Name" "New Name" [--apply]');
  process.exit(1);
}
const apply = applyFlag === '--apply';

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

async function main() {
  const cats = await db.collection('product_categories').get();
  const matches = cats.docs.filter((d) => d.get('name') === oldName);
  const conflicts = cats.docs.filter((d) => d.get('name') === newName);
  const similar = cats.docs.filter((d) =>
    String(d.get('name') ?? '').toLowerCase().includes(oldName.split(/[^a-z0-9]+/i)[0].toLowerCase()),
  );

  console.log(`Categories matching "${oldName}" exactly: ${matches.length}`);
  for (const d of similar) console.log(`  (similar) ${d.id}: "${d.get('name')}" isActive=${d.get('isActive')}`);

  if (conflicts.length > 0) {
    console.error(`ABORT: a category named "${newName}" already exists (${conflicts.map((d) => d.id).join(', ')}) — this would create a duplicate.`);
    process.exit(1);
  }
  if (matches.length !== 1) {
    console.error(`ABORT: expected exactly 1 category named "${oldName}", found ${matches.length}.`);
    process.exit(1);
  }

  const products = await db.collection('products').where('category', '==', oldName).get();
  console.log(`Products with category "${oldName}": ${products.size}`);

  if (!apply) {
    console.log('\nDry run only — re-run with --apply to write.');
    return;
  }

  await matches[0].ref.update({ name: newName, updatedAt: FieldValue.serverTimestamp() });
  console.log(`Renamed category ${matches[0].id} -> "${newName}"`);

  let updated = 0;
  const docs = products.docs;
  for (let i = 0; i < docs.length; i += 500) {
    const batch = db.batch();
    for (const d of docs.slice(i, i + 500)) {
      batch.update(d.ref, { category: newName, updatedAt: FieldValue.serverTimestamp() });
    }
    await batch.commit();
    updated += Math.min(500, docs.length - i);
    console.log(`  products updated: ${updated}/${docs.length}`);
  }

  const leftover = await db.collection('products').where('category', '==', oldName).get();
  console.log(`\nDone. Products still on "${oldName}": ${leftover.size} (expect 0)`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
