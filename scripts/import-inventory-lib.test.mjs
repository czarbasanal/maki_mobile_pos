import test from 'node:test';
import assert from 'node:assert/strict';
import { parseCsv, parseMoney, parseQty, encodeCostCode, generateSku, slugifyForSku, normalizeSku, SKU_CHARS } from './import-inventory-lib.mjs';

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
