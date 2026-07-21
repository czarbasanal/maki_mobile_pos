// Initial inventory import — see docs/superpowers/specs/2026-07-21-initial-inventory-import-design.md
//
// Dry run (default):  node import-inventory.mjs data/master-inventory-2026-07-21.csv
// Execute:            node import-inventory.mjs data/master-inventory-2026-07-21.csv --execute
// Emulator:           FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node import-inventory.mjs ... --execute
//
// Auth: gcloud auth application-default login   (not needed for emulator)
import { readFileSync } from 'node:fs';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import {
  parseCsv, transform, generateSku, normalizeSku, nameKey,
  productSearchKeywords, supplierSearchKeywords,
  IMPORT_TAG, IMPORT_DISPLAY_NAME,
} from './import-inventory-lib.mjs';

const PROJECT_ID = 'maki-mobile-pos';

const args = process.argv.slice(2);
const execute = args.includes('--execute');
const csvPath = args.find((a) => !a.startsWith('--'));
if (!csvPath) {
  console.error('Usage: node import-inventory.mjs <csv-path> [--execute]');
  process.exit(2);
}

function section(title) {
  console.log(`\n=== ${title} ===`);
}

function printList(title, list) {
  section(`${title} (${list.length})`);
  for (const entry of list) {
    console.log(`  ${typeof entry === 'string' ? entry : JSON.stringify(entry)}`);
  }
}

const { records } = parseCsv(readFileSync(csvPath, 'utf8'));
const result = transform(records);
const { report } = result;

section('TRANSFORM REPORT');
console.log(`records read          = ${report.recordsTotal}`);
console.log(`skipped (no name)     = ${report.skippedNoName}`);
console.log(`category normalized   = ${report.categoryNormalized}`);
console.log(`expected products     = ${report.expected.products} (${report.expected.standaloneOrBase} base/standalone + ${report.expected.variations} variations)`);
console.log(`expected categories   = ${report.expected.categories}`);
console.log(`inventory value       = ₱${report.expected.inventoryValue.toLocaleString()}`);
console.log(`retail value          = ₱${report.expected.retailValue.toLocaleString()}`);
printList('COST CORRECTIONS APPLIED', report.costCorrectionsApplied);
printList('NAME CORRECTIONS APPLIED', report.nameCorrectionsApplied);
printList('MERGED DOUBLE-LISTINGS (qty kept once)', report.mergedDoubles);
printList('MERGED SAME-COST BATCHES (qty summed)', report.mergedBatches);
printList('VARIATION PAIRS', report.variationPairs);
printList('DECIMAL QTY ROUNDED DOWN', report.decimalQtyRounded);
printList('SUPPLIER LINKS', report.supplierLinks);
printList('CIPHER MISMATCHES (expect none)', report.cipherMismatches);
printList('BLOCKING ERRORS', report.errors);

if (report.errors.length > 0) {
  console.error('\nBlocking errors above — fix the data or the transform before importing.');
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
console.log(EMULATOR
  ? `TARGET: emulator (${EMULATOR})`
  : `TARGET: PRODUCTION (${PROJECT_ID})`);

/** Map nameKey -> [{id, sku, name, baseSku}] for every existing product. */
async function loadExistingProducts() {
  const snap = await db.collection('products').get();
  const byKey = new Map();
  for (const doc of snap.docs) {
    const key = nameKey(doc.get('name') ?? '');
    if (!byKey.has(key)) byKey.set(key, []);
    byKey.get(key).push({
      id: doc.id,
      sku: doc.get('sku'),
      name: doc.get('name'),
      baseSku: doc.get('baseSku') ?? null,
    });
  }
  return { byKey, count: snap.size };
}

/** Resolve skips/resume against existing docs. Returns the concrete write list. */
function planWrites(existingByKey) {
  const skips = [];
  const singles = []; // {item, baseSku: null, variationNumber: null}
  const pairJobs = []; // {writeBase: Item|null, variation: Item, baseSkuFixed: string|null}
  for (const item of result.standalone) {
    const existing = existingByKey.get(nameKey(item.name));
    if (existing) {
      skips.push(`${item.name} (exists as '${existing[0].name}', id ${existing[0].id})`);
      continue;
    }
    singles.push(item);
  }
  for (const { base, variation } of result.pairs) {
    const existing = existingByKey.get(nameKey(base.name)) ?? [];
    if (existing.length >= 2) {
      skips.push(`${base.name} (pair — both docs already exist)`);
    } else if (existing.length === 1) {
      if (existing[0].baseSku) {
        skips.push(`${base.name} (pair — lone existing doc is itself a variation; resolve manually)`);
      } else {
        skips.push(`${base.name} (base exists — will write variation only)`);
        pairJobs.push({ writeBase: null, variation, baseSkuFixed: existing[0].sku });
      }
    } else {
      pairJobs.push({ writeBase: base, variation, baseSkuFixed: null });
    }
  }
  return { skips, singles, pairJobs };
}

let existing;
try {
  existing = await loadExistingProducts();
} catch (err) {
  if (execute) throw err;
  console.log(`\n(existing-product check skipped — could not reach Firestore: ${err.message})`);
  console.log('\nDRY RUN — nothing written. Re-run with --execute to import.');
  process.exit(0);
}

const plan = planWrites(existing.byKey);
printList('SKIPPED — NAME ALREADY IN SYSTEM', plan.skips);
const totalToWrite = plan.singles.length
  + plan.pairJobs.reduce((s, j) => s + (j.writeBase ? 2 : 1), 0);
section('WRITE PLAN');
console.log(`existing products     = ${existing.count}`);
console.log(`products to write     = ${totalToWrite}`);

if (!execute) {
  console.log('\nDRY RUN — nothing written. Re-run with --execute to import.');
  process.exit(0);
}

await runImport(db, plan, result.categories, result.units);

async function runImport(db, plan, categories, unitsUsed) {
  section('EXECUTE');

  // Shared helper: admin name-lists (product_categories, units) use the
  // CategoryModel doc shape.
  async function ensureNameList(collection, names) {
    const snap = await db.collection(collection).get();
    const existingNames = new Set(snap.docs.map((d) => (d.get('name') ?? '').trim()));
    let created = 0;
    for (const name of names) {
      if (existingNames.has(name)) continue;
      await db.collection(collection).add({
        name,
        isActive: true,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        createdBy: IMPORT_TAG,
        updatedBy: IMPORT_TAG,
      });
      created += 1;
    }
    return created;
  }

  // ---- Categories + units ----
  const catsCreated = await ensureNameList('product_categories', categories);
  console.log(`categories created    = ${catsCreated}`);
  const unitsCreated = await ensureNameList('units', unitsUsed);
  console.log(`units created         = ${unitsCreated}`);

  // ---- Suppliers ----
  const writeItems = [
    ...plan.singles.map((item) => ({ item, kind: 'single' })),
    ...plan.pairJobs.flatMap((job) => [
      ...(job.writeBase ? [{ item: job.writeBase, kind: 'base', job }] : []),
      { item: job.variation, kind: 'variation', job },
    ]),
  ];
  const neededCodes = new Set(
    writeItems.map(({ item }) => item.supplierCode).filter(Boolean),
  );
  const supSnap = await db.collection('suppliers').get();
  const suppliers = new Map(
    supSnap.docs.map((d) => [(d.get('name') ?? '').trim().toUpperCase(), { id: d.id, name: d.get('name') }]),
  );
  let supsCreated = 0;
  for (const code of neededCodes) {
    if (suppliers.has(code.toUpperCase())) continue;
    const ref = await db.collection('suppliers').add({
      name: code,
      address: null,
      contactPerson: null,
      contactNumber: null,
      alternativeNumber: null,
      email: null,
      transactionType: 'na',
      isActive: true,
      notes: null,
      productCount: 0,
      totalInventoryValue: 0,
      searchKeywords: supplierSearchKeywords(code),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      createdBy: IMPORT_TAG,
      updatedBy: IMPORT_TAG,
    });
    suppliers.set(code.toUpperCase(), { id: ref.id, name: code });
    supsCreated += 1;
  }
  console.log(`suppliers created     = ${supsCreated}`);

  // ---- Products (+ claims, atomically per product) ----
  const aggregates = new Map(); // supplierKey -> {count, value}

  async function writeProduct(item, { baseSku, variationNumber }) {
    const docRef = db.collection('products').doc();
    const supplier = item.supplierCode ? suppliers.get(item.supplierCode.toUpperCase()) : null;
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const sku = generateSku(item.name);
      const claimRef = db.collection('product_skus').doc(normalizeSku(sku));
      const batch = db.batch();
      batch.create(claimRef, {
        sku,
        productId: docRef.id,
        claimedBy: IMPORT_TAG,
        claimedAt: FieldValue.serverTimestamp(),
      });
      batch.create(docRef, {
        sku,
        name: item.name,
        costCode: item.costCode,
        cost: item.cost,
        price: item.price,
        quantity: item.quantity,
        reorderLevel: item.reorderLevel,
        unit: item.unit,
        supplierId: supplier?.id ?? null,
        supplierName: supplier?.name ?? null,
        isActive: true,
        searchKeywords: productSearchKeywords({ sku, name: item.name, category: item.category }),
        baseSku,
        variationNumber,
        barcodes: [],
        category: item.category,
        imageUrl: null,
        notes: item.notes,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        createdBy: IMPORT_TAG,
        updatedBy: IMPORT_TAG,
        createdByName: IMPORT_DISPLAY_NAME,
        updatedByName: IMPORT_DISPLAY_NAME,
      });
      try {
        await batch.commit();
        if (supplier) {
          const key = item.supplierCode.toUpperCase();
          const agg = aggregates.get(key) ?? { count: 0, value: 0 };
          agg.count += 1;
          agg.value += item.cost * item.quantity;
          aggregates.set(key, agg);
        }
        return sku;
      } catch (err) {
        if (err.code === 6 || err.code === 'already-exists') continue; // claim collision → new suffix
        throw err;
      }
    }
    throw new Error(`Could not claim a unique SKU for ${item.name} after 5 attempts`);
  }

  let written = 0;
  const progress = () => {
    written += 1;
    if (written % 100 === 0) console.log(`  ...${written} products written`);
  };
  for (const item of plan.singles) {
    await writeProduct(item, { baseSku: null, variationNumber: null });
    progress();
  }
  for (const job of plan.pairJobs) {
    let baseSku = job.baseSkuFixed;
    if (job.writeBase) {
      baseSku = await writeProduct(job.writeBase, { baseSku: null, variationNumber: null });
      progress();
    }
    await writeProduct(job.variation, { baseSku, variationNumber: 1 });
    progress();
  }
  console.log(`products written      = ${written}`);

  // ---- Supplier aggregates ----
  for (const [key, agg] of aggregates) {
    const supplier = suppliers.get(key);
    await db.collection('suppliers').doc(supplier.id).update({
      productCount: FieldValue.increment(agg.count),
      totalInventoryValue: FieldValue.increment(agg.value),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: IMPORT_TAG,
    });
  }
  console.log(`supplier aggregates   = ${aggregates.size} updated`);

  // ---- Reconciliation ----
  section('RECONCILIATION');
  // Orphan claims: import-tagged claims whose product doc is missing (crashed run).
  const importClaims = await db.collection('product_skus')
    .where('claimedBy', '==', IMPORT_TAG).get();
  let orphans = 0;
  for (const claim of importClaims.docs) {
    const productRef = db.collection('products').doc(claim.get('productId'));
    if (!(await productRef.get()).exists) {
      console.log(`  deleting orphan claim ${claim.id} (product ${claim.get('productId')} missing)`);
      await claim.ref.delete();
      orphans += 1;
    }
  }
  if (orphans) console.log(`orphan claims removed = ${orphans}`);

  const productsCount = (await db.collection('products').count().get()).data().count;
  const claimsCount = (await db.collection('product_skus').count().get()).data().count;
  console.log(`products in db        = ${productsCount}`);
  console.log(`claims in db          = ${claimsCount}`);
  const expectedTotal = existing.count + written;
  let ok = true;
  if (claimsCount !== productsCount) {
    console.error(`MISMATCH: claims (${claimsCount}) != products (${productsCount})`);
    ok = false;
  }
  if (productsCount !== expectedTotal) {
    console.error(`MISMATCH: products (${productsCount}) != existing ${existing.count} + written ${written}`);
    ok = false;
  }
  if (!ok) process.exit(1);
  console.log('\nOK — import reconciled cleanly.');
}
