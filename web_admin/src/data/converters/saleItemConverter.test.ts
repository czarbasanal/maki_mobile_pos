import { describe, expect, it } from 'vitest';
import type { DocumentData, QueryDocumentSnapshot } from 'firebase/firestore';
import { saleItemConverter } from './saleItemConverter';
import { jobOrderItemsToMaps, parseJobOrderItems } from './jobOrderConverter';
import {
  saleItemHasOption,
  saleItemOptionSets,
  saleItemQuantityStep,
  type SaleItem,
} from '@/domain/entities/SaleItem';

const withOption: SaleItem = {
  id: 'i1',
  productId: 'p1',
  sku: 'ABC-1',
  name: 'Pulley Ball',
  unitPrice: 110,
  unitCost: 60,
  quantity: 6,
  discountValue: 0,
  unit: 'pcs',
  optionId: 'o2',
  optionLabel: 'By 3',
  optionPieces: 3,
  optionPrice: 330,
};

function snap(data: Record<string, unknown>): QueryDocumentSnapshot<DocumentData> {
  return { id: 'i1', data: () => data } as unknown as QueryDocumentSnapshot<DocumentData>;
}

describe('SaleItem option helpers', () => {
  it('derives sets from pieces', () => {
    expect(saleItemOptionSets(withOption)).toBe(2);
    expect(saleItemHasOption(withOption)).toBe(true);
    expect(saleItemQuantityStep(withOption)).toBe(3);
  });

  it('returns null sets and a step of 1 with no option', () => {
    const plain = { ...withOption, optionId: null, optionPieces: null, optionPrice: null, optionLabel: null };
    expect(saleItemOptionSets(plain)).toBeNull();
    expect(saleItemHasOption(plain)).toBe(false);
    expect(saleItemQuantityStep(plain)).toBe(1);
  });
});

describe('saleItemConverter option fields', () => {
  it('round-trips option fields', () => {
    const out = saleItemConverter.toFirestore(withOption) as Record<string, unknown>;
    const back = saleItemConverter.fromFirestore(snap(out));
    expect(back.optionLabel).toBe('By 3');
    expect(back.optionPieces).toBe(3);
    expect(back.optionPrice).toBe(330);
  });

  it('reads a legacy doc with no option fields as nulls', () => {
    const back = saleItemConverter.fromFirestore(
      snap({ productId: 'p1', sku: 'ABC-1', name: 'x', unitPrice: 120, unitCost: 60, quantity: 2 }),
    );
    expect(back.optionId).toBeNull();
    expect(saleItemHasOption(back)).toBe(false);
  });
});

describe('jobOrderConverter option fields', () => {
  it('round-trips option fields through the inline items array', () => {
    const [back] = parseJobOrderItems(jobOrderItemsToMaps([withOption]));
    expect(back.optionLabel).toBe('By 3');
    expect(back.optionPieces).toBe(3);
    expect(saleItemOptionSets(back)).toBe(2);
  });
});
