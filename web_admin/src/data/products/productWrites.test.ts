// buildProductUpdate is the web mirror of ProductModel.toUpdateMap. The
// includeSellingOptions gate is load-bearing (see the doc comment in
// productWrites.ts): sellingOptions is admin-only in firestore.rules, and a
// doc lacking the field would have it ADDED by an unconditional write,
// landing in diff().affectedKeys() and tripping the staff/cashier denylist on
// an otherwise-legitimate edit. serverTimestamp()/deleteField() are pure
// sentinel factories — no emulator or app init needed to call them directly.
import { describe, expect, it } from 'vitest';
import { buildProductUpdate } from './productWrites';
import type { ProductUpdateInput } from '@/domain/repositories/ProductRepository';
import type { SellingOption } from '@/domain/entities/SellingOption';

const by6: SellingOption = { id: 'o1', label: 'By 6', pieces: 6, price: 600 };

describe('buildProductUpdate', () => {
  it('omits sellingOptions by default even when the caller supplies it', () => {
    const input: ProductUpdateInput = { name: 'Renamed', sellingOptions: [by6] };
    const map = buildProductUpdate(input, 'u1');
    expect(map).not.toHaveProperty('sellingOptions');
  });

  it('omits sellingOptions when includeSellingOptions is explicitly false', () => {
    const input: ProductUpdateInput = { name: 'Renamed', sellingOptions: [by6] };
    const map = buildProductUpdate(input, 'u1', false);
    expect(map).not.toHaveProperty('sellingOptions');
  });

  it('includes sellingOptions when includeSellingOptions is true and the caller supplied it', () => {
    const input: ProductUpdateInput = { name: 'Renamed', sellingOptions: [by6] };
    const map = buildProductUpdate(input, 'u1', true);
    expect(map.sellingOptions).toEqual([by6]);
  });

  it('does not add a sellingOptions key when includeSellingOptions is true but the caller never set it', () => {
    const map = buildProductUpdate({ name: 'Renamed' }, 'u1', true);
    expect(map).not.toHaveProperty('sellingOptions');
  });

  it('always writes updatedBy', () => {
    const map = buildProductUpdate({ name: 'x' }, 'actor-1');
    expect(map.updatedBy).toBe('actor-1');
  });

  it('only writes fields the caller actually supplied', () => {
    const map = buildProductUpdate({ name: 'Renamed' }, 'u1');
    expect(map).not.toHaveProperty('price');
    expect(map).not.toHaveProperty('cost');
    expect(map).not.toHaveProperty('sku');
  });
});
