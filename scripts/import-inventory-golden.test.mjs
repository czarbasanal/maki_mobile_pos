import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { parseCsv, transform } from './import-inventory-lib.mjs';

const CSV = fileURLToPath(new URL('./data/master-inventory-2026-07-21.csv', import.meta.url));

test('golden: full master CSV transforms to the approved shape', () => {
  const { records } = parseCsv(readFileSync(CSV, 'utf8'));
  const { standalone, pairs, categories, units, report } = transform(records);

  assert.equal(report.recordsTotal, 1250); // 1249 items + totals row
  assert.equal(report.skippedNoName, 1); // the totals row
  assert.equal(report.errors.length, 0);
  assert.equal(report.cipherMismatches.length, 0); // corrections make it 8/8 clean
  assert.equal(report.costCorrectionsApplied.length, 8);
  assert.deepEqual(report.nameCorrectionsApplied, ['HEADLIGHT RS100 -> HEADLIGHT RS100 BLK']);
  assert.equal(report.categoryNormalized, 23); // CHAIN & SPROCKET rows
  assert.equal(report.decimalQtyRounded.length, 4);
  assert.equal(report.mergedDoubles.length, 8);
  assert.equal(report.mergedBatches.length, 1); // TOP GASKET
  assert.equal(report.variationPairs.length, 12);
  assert.equal(report.supplierLinks.length, 5); // HD, HMJ, HNG, KS×2
  assert.equal(report.unmappedUnits.length, 0);
  assert.deepEqual(units, ['m', 'pcs', 'ruler', 'set']);

  assert.equal(standalone.length, 1216); // 1207 singles + 9 merges
  assert.equal(pairs.length, 12);
  assert.equal(report.expected.products, 1240);
  assert.equal(categories.length, 24);
  assert.ok(!categories.includes('LENS'), 'LENS folded into ACCESSORIES');
  assert.ok(!categories.includes('CHAIN & SPROCKET'), 'spaced form normalized');

  // Spot values (user-verified decisions).
  const byName = new Map(standalone.map((i) => [i.name, i]));
  const gasket = byName.get('TOP GASKET AMCO W125');
  assert.deepEqual(
    { qty: gasket.quantity, price: gasket.price, code: gasket.costCode },
    { qty: 15, price: 150, code: 'QF' },
  );
  const carb = byName.get('CARBURETOR SUNTAL CT150BOXER');
  assert.deepEqual({ cost: carb.cost, code: carb.costCode }, { cost: 680, code: 'ZLS' });
  assert.ok(byName.has('HEADLIGHT RS100 BLK'));
  assert.ok(!byName.has('HEADLIGHT RS100'));
  const hose = byName.get('FUEL HOSE BLK');
  assert.equal(hose.quantity, 27);
  assert.equal(hose.unit, 'ruler');
  assert.match(hose.notes, /rounded down from 27\.5/);
  const oilFilter = byName.get('OIL FILTER BAJAJ/CT100');
  assert.deepEqual({ qty: oilFilter.quantity, cat: oilFilter.category }, { qty: 16, cat: 'LUBE&FLUIDS' });
});
