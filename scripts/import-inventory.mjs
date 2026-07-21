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

async function runImport() { throw new Error('not implemented — Task 8'); }
