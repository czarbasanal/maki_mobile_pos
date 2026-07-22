import test from 'node:test';
import assert from 'node:assert/strict';
import {
  parseCsv, parseMoney, parseQty, encodeCostCode, generateSku, slugifyForSku, normalizeSku, SKU_CHARS, toSearchKeywords, productSearchKeywords, supplierSearchKeywords,
  nameKey, transform, COST_CORRECTIONS, NAME_CORRECTIONS,
} from './import-inventory-lib.mjs';

test('parseCsv handles quoted fields containing commas and a BOM', () => {
  const text = '﻿' + 'NAME,COST\n"TIRE, BIG","₱1,280.00"\nPLAIN,5\n';
  const { header, records } = parseCsv(text);
  assert.deepEqual(header, ['NAME', 'COST']);
  assert.equal(records.length, 2);
  assert.equal(records[0].NAME, 'TIRE, BIG');
  assert.equal(records[0].COST, '₱1,280.00');
});

test('parseCsv handles escaped quotes, CRLF, and no trailing newline', () => {
  const text = 'A,B\r\n"say ""hi""",x\r\nlast,row';
  const { records } = parseCsv(text);
  assert.equal(records.length, 2);
  assert.equal(records[0].A, 'say "hi"');
  assert.equal(records[1].B, 'row');
});

test('parseCsv drops all-empty lines and pads short rows', () => {
  const text = 'A,B,C\nx,y\n,,\n';
  const { records } = parseCsv(text);
  assert.equal(records.length, 1);
  assert.equal(records[0].C, '');
});

test('parseMoney strips peso signs and thousands separators', () => {
  assert.equal(parseMoney('₱55.00'), 55);
  assert.equal(parseMoney('₱1,280.00'), 1280);
  assert.equal(parseMoney('40'), 40);
  assert.equal(parseMoney('6U0'), null);
  assert.equal(parseMoney(''), null);
  assert.equal(parseMoney('  '), null);
});

test('parseQty floors decimals and reports the original', () => {
  assert.deepEqual(parseQty('4'), { qty: 4, original: null });
  assert.deepEqual(parseQty('27.5'), { qty: 27, original: '27.5' });
  assert.equal(parseQty('abc'), null);
  assert.equal(parseQty('-3'), null);
  assert.equal(parseQty(''), null);
});

test('encodeCostCode matches real rows from the master CSV', () => {
  // Every pair below is a real (cost, CODE) row verified during data profiling.
  assert.equal(encodeCostCode(55), 'FF');
  assert.equal(encodeCostCode(285), 'BLF');
  assert.equal(encodeCostCode(80), 'LS');
  assert.equal(encodeCostCode(110), 'NNS');
  assert.equal(encodeCostCode(100), 'NSC');
  assert.equal(encodeCostCode(400), 'MSC');
  assert.equal(encodeCostCode(1204), 'NBSM');
  assert.equal(encodeCostCode(1688), 'NZLL');
  assert.equal(encodeCostCode(1750), 'NVFS');
  assert.equal(encodeCostCode(360), 'QZS');
});

test('encodeCostCode zero runs and edge cases (algorithm-derived)', () => {
  assert.equal(encodeCostCode(1000), 'NSCS'); // N + '000'→SCS
  assert.equal(encodeCostCode(10000), 'NSCSS'); // N + '000'→SCS + '0'→S
  assert.equal(encodeCostCode(0), 'S');
  assert.equal(encodeCostCode(680.75), 'ZLS'); // decimals truncated
});

test('SKU alphabet excludes ambiguous chars', () => {
  assert.equal(SKU_CHARS, 'ABCDEFGHJKMNPQRSTUVWXYZ23456789');
});

test('generateSku matches the Dart generateForName contract', () => {
  const zeros = () => 0; // always picks 'A'
  // Dart doc example: 'Milk Chocolate 500g Box' -> prefix MLKCHCLT50
  assert.equal(generateSku('Milk Chocolate 500g Box', zeros), 'MLKCHCLT50-AAAAAA');
  // First char kept even if vowel; later vowels dropped.
  assert.equal(generateSku('Ice', zeros), 'IC-AAAAAA');
  // Empty slug falls back to SKU- + 8 random chars.
  assert.equal(generateSku('///', zeros), 'SKU-AAAAAAAA');
  // Real item name.
  assert.equal(
    generateSku('BELT BANDO SKYDRIVE SPORT 115I', zeros),
    'BLTBNDSKYD-AAAAAA',
  );
});

test('normalizeSku is trim + uppercase (claim-key parity)', () => {
  assert.equal(normalizeSku('  abC-12 '), 'ABC-12');
});

test('slugifyForSku strips non-alphanumerics', () => {
  assert.equal(slugifyForSku('W/ Stand (TMX)'), 'WSTANDTMX');
});

test('toSearchKeywords matches the Dart doc example', () => {
  assert.deepEqual(
    [...toSearchKeywords('Hello World')].sort(),
    ['h', 'he', 'hel', 'hell', 'hello', 'w', 'wo', 'wor', 'worl', 'world'].sort(),
  );
});

test('toSearchKeywords caps prefixes at 10 chars', () => {
  const kw = toSearchKeywords('ADJUSTABLE1234');
  assert.ok(kw.includes('adjustable')); // length 10
  assert.ok(!kw.includes('adjustable1')); // length 11 — capped
});

test('productSearchKeywords unions sku, name, category', () => {
  const kw = productSearchKeywords({ sku: 'MS-AB', name: 'OIL X', category: 'LUBE&FLUIDS' });
  for (const expected of ['ms-ab', 'oil', 'x', 'lube&fluid', 'm', 'o', 'l']) {
    assert.ok(kw.includes(expected), `missing ${expected}`);
  }
  assert.equal(new Set(kw).size, kw.length, 'no duplicates');
});

test('supplierSearchKeywords is name-only prefixes', () => {
  assert.deepEqual([...supplierSearchKeywords('KS')].sort(), ['k', 'ks'].sort());
});

test('nameKey ignores word order', () => {
  assert.equal(nameKey('ASK BRAKE SHOE XRM'), nameKey('BRAKE SHOE  ASK XRM'));
  assert.notEqual(nameKey('OIL FILTER SUZUKI'), nameKey('OIL FILTER YAMAHA'));
});

const REC = (over = {}) => ({
  NAME: 'WIDGET A', CATEGORY: 'ENGINE', CODE: 'FF', 'UNIT COST': '₱55.00',
  'SELLING PRICE': '₱100.00', QTY: '2', UNIT: 'PC', REORDER_LEVEL: '0',
  SUPPLIER: 'NA', ...over,
});

test('transform: plain row becomes a standalone item', () => {
  const { standalone, pairs, report } = transform([REC()]);
  assert.equal(standalone.length, 1);
  assert.equal(pairs.length, 0);
  assert.deepEqual(standalone[0], {
    name: 'WIDGET A', category: 'ENGINE', costCode: 'FF', cost: 55, price: 100,
    quantity: 2, reorderLevel: 0, unit: 'pcs', supplierCode: null, notes: null,
  });
  assert.equal(report.cipherMismatches.length, 0);
  assert.equal(report.expected.products, 1);
  assert.equal(report.expected.inventoryValue, 110);
});

test('transform: skips nameless (totals) rows', () => {
  const { standalone, report } = transform([REC({ NAME: '  ' })]);
  assert.equal(standalone.length, 0);
  assert.equal(report.skippedNoName, 1);
});

test('transform: different costCode pair becomes base + variation', () => {
  const { standalone, pairs } = transform([
    REC({ QTY: '1' }),
    REC({ CODE: 'ZS', 'UNIT COST': '₱60.00', QTY: '3' }),
  ]);
  assert.equal(standalone.length, 0);
  assert.equal(pairs.length, 1);
  assert.equal(pairs[0].base.cost, 55);
  assert.equal(pairs[0].variation.cost, 60);
  assert.equal(pairs[0].variation.quantity, 3);
});

test('transform: same code + same qty merges without summing', () => {
  const { standalone, report } = transform([
    REC({ NAME: 'SIGNAL LIGHT LENS W100 WHT', CATEGORY: 'LENS', QTY: '20' }),
    REC({ NAME: 'SIGNAL LIGHT LENS W100 WHT', CATEGORY: 'ACCESSORIES', QTY: '20' }),
  ]);
  assert.equal(standalone.length, 1);
  assert.equal(standalone[0].quantity, 20);
  assert.equal(standalone[0].category, 'ACCESSORIES'); // MERGE_CATEGORY_OVERRIDES
  assert.equal(report.mergedDoubles.length, 1);
});

test('transform: same code + different qty sums and takes max price', () => {
  const { standalone, report } = transform([
    REC({ NAME: 'TOP GASKET AMCO W125', CODE: 'QF', 'UNIT COST': '35', QTY: '10', 'SELLING PRICE': '120' }),
    REC({ NAME: 'TOP GASKET AMCO W125', CODE: 'QF', 'UNIT COST': '35', QTY: '5', 'SELLING PRICE': '150' }),
  ]);
  assert.equal(standalone.length, 1);
  assert.equal(standalone[0].quantity, 15);
  assert.equal(standalone[0].price, 150);
  assert.equal(report.mergedBatches.length, 1);
});

test('transform: applies cost and name corrections', () => {
  const { standalone } = transform([
    REC({ NAME: 'HEADLIGHT RS100', CATEGORY: 'LIGHTS', CODE: 'BQX', 'UNIT COST': '23X', 'SELLING PRICE': '₱480.00' }),
  ]);
  assert.equal(standalone[0].name, 'HEADLIGHT RS100 BLK');
  assert.equal(standalone[0].cost, 230);
  assert.equal(standalone[0].costCode, 'BQS');
});

test('transform: normalizes CHAIN & SPROCKET and floors decimal qty with note', () => {
  const { standalone, report } = transform([
    REC({ NAME: 'FUEL HOSE BLK', CATEGORY: 'CHAIN & SPROCKET', QTY: '27.5', UNIT: 'RULER', CODE: 'Q', 'UNIT COST': '3' }),
  ]);
  assert.equal(standalone[0].category, 'CHAIN&SPROCKET');
  assert.equal(standalone[0].quantity, 27);
  assert.equal(standalone[0].notes, 'Imported qty rounded down from 27.5');
  assert.equal(report.categoryNormalized, 1);
  assert.equal(report.decimalQtyRounded.length, 1);
});

test('transform: maps CSV units to app vocabulary, keeps unknowns verbatim', () => {
  const mapped = transform([
    REC({ NAME: 'A1' }), // PC
    REC({ NAME: 'A2', UNIT: 'SET' }),
    REC({ NAME: 'A3', UNIT: 'RULER' }),
    REC({ NAME: 'A4', UNIT: 'METER' }),
    REC({ NAME: 'A5', UNIT: 'DOZEN' }),
  ]);
  assert.deepEqual(mapped.standalone.map((i) => i.unit), ['pcs', 'set', 'ruler', 'm', 'DOZEN']);
  assert.deepEqual(mapped.units, ['DOZEN', 'm', 'pcs', 'ruler', 'set']);
  assert.equal(mapped.report.unmappedUnits.length, 1);
});

test('transform: unparsable cost is a blocking error, >2 group is an error', () => {
  const bad = transform([REC({ 'UNIT COST': 'URX' })]);
  assert.equal(bad.report.errors.length, 1);
  const triple = transform([REC(), REC(), REC()]);
  assert.equal(triple.report.errors.length, 1);
});

test('corrections tables carry the user-verified values', () => {
  assert.deepEqual(COST_CORRECTIONS['CARBURETOR SUNTAL CT150BOXER'], { costCode: 'ZLS', cost: 680 });
  assert.deepEqual(COST_CORRECTIONS['TAIL LIGHT COVER XRM110 BLK'], { costCode: 'MS', cost: 40 });
  assert.equal(Object.keys(COST_CORRECTIONS).length, 8);
  assert.equal(NAME_CORRECTIONS['HEADLIGHT RS100'], 'HEADLIGHT RS100 BLK');
});
