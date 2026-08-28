import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  isLinkedGroup,
  planGroupRewrite,
  planRelink,
  unlinkedDuplicateGroups,
} from './relink-duplicate-skus-lib.mjs';

const p = (sku, over = {}) => ({ id: sku, sku, name: 'BELT BANDO', category: 'CVT', baseSku: null, variationNumber: null, cost: 1, price: 2, quantity: 0, ...over });

test('keeps the lowest sku as the base and numbers the rest from 1', () => {
  const plan = planGroupRewrite([p('00020051'), p('00020048'), p('00020052')]);
  assert.deepEqual(plan.map(r => [r.fromSku, r.toSku]), [
    ['00020051', '00020048-1'],
    ['00020052', '00020048-2'],
  ]);
  assert.equal(plan[0].baseSku, '00020048');
  assert.deepEqual(plan.map(r => r.variationNumber), [1, 2]);
});

test('skips a candidate suffix that is already taken elsewhere', () => {
  const plan = planGroupRewrite([p('00020048'), p('00020051')], s => s === '00020048-1');
  assert.equal(plan[0].toSku, '00020048-2');
});

test('an already-linked group is recognised and left alone', () => {
  const group = [p('00020152'), p('00020153', { baseSku: '00020152', variationNumber: 1 })];
  assert.equal(isLinkedGroup(group), true);
  assert.deepEqual(unlinkedDuplicateGroups(group), []);
});

test('a group whose baseSku points OUTSIDE the group is treated as unlinked', () => {
  const group = [p('00020048'), p('00020051', { baseSku: '00009999' })];
  assert.equal(isLinkedGroup(group), false);
  assert.equal(unlinkedDuplicateGroups(group).length, 1);
});

test('word order and category are respected when grouping', () => {
  const all = [
    p('1', { name: 'CHAIN GLOBAL 428' }),
    p('2', { name: 'GLOBAL CHAIN 428' }),
    p('3', { name: 'CHAIN GLOBAL 428', category: 'OTHER' }),
  ];
  const groups = unlinkedDuplicateGroups(all);
  assert.equal(groups.length, 1);
  assert.deepEqual(groups[0].map(x => x.sku).sort(), ['1', '2']);
});

test('a unique product is never rewritten', () => {
  assert.deepEqual(planRelink([p('00010001', { name: 'ONLY ONE' })]), []);
});

test('planRelink is idempotent — a second pass plans nothing', () => {
  const all = [p('00020048'), p('00020051')];
  const first = planRelink(all);
  assert.equal(first.length, 1);
  const applied = all.map(x => {
    const r = first.find(f => f.id === x.id);
    return r ? { ...x, sku: r.toSku, baseSku: r.baseSku, variationNumber: r.variationNumber } : x;
  });
  assert.deepEqual(planRelink(applied), []);
});
