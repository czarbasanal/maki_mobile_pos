// Tests for the pure planners behind repair-preview-skus.mjs.
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  duplicateSkusIn,
  planKeywordRepair,
  planReceivingItemFixes,
} from './repair-preview-skus-lib.mjs';

const product = (over = {}) => ({
  id: 'p1', sku: '00070006', name: 'Brake Pad', category: 'Brakes',
  barcodes: [], searchKeywords: [], ...over,
});

test('a product whose keywords carry the stale preview sku is repaired', () => {
  const p = product({
    // Keywords built from the preview 00070005 the scan moved past.
    searchKeywords: ['0', '00', '000', '0007', '00070', '000700', '0007000', '00070005', 'brake', 'brakes'],
  });
  const fix = planKeywordRepair(p);
  assert.ok(fix, 'expected a repair');
  assert.ok(fix.keywords.includes('00070006'), 'real sku token added');
  assert.ok(!fix.keywords.includes('00070005'), 'stale sku token dropped');
});

test('a product already carrying its own sku tokens is left alone', () => {
  const p = product({
    searchKeywords: ['0', '00', '000', '0007', '00070', '000700', '0007000', '00070006', 'brake', 'brakes'],
  });
  assert.equal(planKeywordRepair(p), null);
});

test('repair keeps barcode tokens that mobile-created products carry', () => {
  const p = product({
    barcodes: ['4800111222333'],
    searchKeywords: ['00070005', '4800111222', 'brake'],
  });
  const fix = planKeywordRepair(p);
  assert.ok(fix.keywords.includes('4800111222'), 'barcode token survives');
});

test('keyword tokens cap at 10 characters, like both generators', () => {
  const fix = planKeywordRepair(product({ sku: 'SUPERLONGSKU12345', searchKeywords: ['x'] }));
  assert.ok(fix.keywords.includes('superlongs'));
  assert.ok(!fix.keywords.includes('superlongsk'));
});

test('a receiving line whose sku disagrees with its linked product is corrected', () => {
  const receiving = {
    id: 'r1',
    referenceNumber: 'RCV-20260801-001',
    items: [
      { productId: 'p1', newProductId: null, sku: '00070005', name: 'Brake Pad' },
      { productId: 'p2', newProductId: null, sku: '00070007', name: 'Oil Filter' },
    ],
  };
  const byId = new Map([
    ['p1', product({ id: 'p1', sku: '00070006' })],
    ['p2', product({ id: 'p2', sku: '00070007' })],
  ]);
  const fixes = planReceivingItemFixes(receiving, byId);
  assert.deepEqual(fixes, [{ index: 0, from: '00070005', to: '00070006', name: 'Brake Pad' }]);
});

test('a variation line is matched through newProductId, not productId', () => {
  const receiving = {
    id: 'r1',
    items: [{ productId: 'p-orig', newProductId: 'p-var', sku: 'ABC-1', name: 'Belt' }],
  };
  const byId = new Map([
    ['p-orig', product({ id: 'p-orig', sku: 'ABC' })],
    ['p-var', product({ id: 'p-var', sku: 'ABC-2' })],
  ]);
  const fixes = planReceivingItemFixes(receiving, byId);
  assert.deepEqual(fixes, [{ index: 0, from: 'ABC-1', to: 'ABC-2', name: 'Belt' }]);
});

test('a line whose product is gone is left untouched', () => {
  const receiving = { id: 'r1', items: [{ productId: 'deleted', newProductId: null, sku: 'X-1', name: 'Gone' }] };
  assert.deepEqual(planReceivingItemFixes(receiving, new Map()), []);
});

test('a line with no product link at all is left untouched', () => {
  const receiving = { id: 'r1', items: [{ productId: null, newProductId: null, sku: 'X-1', name: 'Loose' }] };
  assert.deepEqual(planReceivingItemFixes(receiving, new Map()), []);
});

test('duplicate skus inside one receiving are reported with their counts', () => {
  const receiving = {
    items: [
      { sku: '00070005', name: 'Brake Pad' },
      { sku: '00070005', name: 'Oil Filter' },
      { sku: 'ABC-1', name: 'Belt' },
    ],
  };
  assert.deepEqual(duplicateSkusIn(receiving), [{ sku: '00070005', count: 2 }]);
});
