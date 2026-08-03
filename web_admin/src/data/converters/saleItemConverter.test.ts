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

  it('truncates a non-exact multiple instead of returning a fraction', () => {
    // 7 / 3 = 2.333...; a plain `/` would return that fraction. Only a
    // truncating division (Dart's `~/`, matched here by Math.floor) gives 2.
    const sevenPieces = { ...withOption, quantity: 7 };
    expect(saleItemOptionSets(sevenPieces)).toBe(2);
  });

  it('treats optionPieces: 0 as no option, not a division by zero', () => {
    // optionId is still set here, so this only passes if hasOption's third
    // clause (optionPieces! > 0) is actually checked — dropping it would
    // make this `true` (and optionSets a division-by-zero Infinity/NaN
    // instead of null).
    const zeroPieces = { ...withOption, optionPieces: 0 };
    expect(saleItemHasOption(zeroPieces)).toBe(false);
    expect(saleItemOptionSets(zeroPieces)).toBeNull();
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

  it('reads a legacy job-order item with no option fields as nulls', () => {
    const [back] = parseJobOrderItems([
      { id: 'i2', productId: 'p2', sku: 'XYZ', name: 'Old Item', unitPrice: 50, unitCost: 20, quantity: 3, discountValue: 0, unit: 'pcs' },
    ]);
    expect(back.optionId).toBeNull();
    expect(back.optionLabel).toBeNull();
    expect(back.optionPieces).toBeNull();
    expect(back.optionPrice).toBeNull();
    expect(saleItemHasOption(back)).toBe(false);
  });
});
