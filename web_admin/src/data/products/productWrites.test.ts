// buildProductUpdate is the web mirror of ProductModel.toUpdateMap. The
// includeSellingOptions gate is load-bearing (see the doc comment in
// productWrites.ts): sellingOptions is admin-only in firestore.rules, and a
// doc lacking the field would have it ADDED by an unconditional write,
// landing in diff().affectedKeys() and tripping the staff/cashier denylist on
// an otherwise-legitimate edit. serverTimestamp()/deleteField() are pure
// sentinel factories — no emulator or app init needed to call them directly.
import { describe, expect, it, vi } from 'vitest';
import type { Firestore } from 'firebase/firestore';
import { buildProductUpdate, buildProductWrites } from './productWrites';
import type { ProductCreateInput, ProductUpdateInput } from '@/domain/repositories/ProductRepository';
import type { SellingOption } from '@/domain/entities/SellingOption';

// buildProductWrites() calls doc(db, ...) to build refs, but productData —
// what these tests inspect — doesn't depend on what doc() returns, so a
// lightweight fake avoids needing a real Firestore app instance. Everything
// else (serverTimestamp, deleteField, ...) stays the real implementation via
// importOriginal, so the buildProductUpdate tests above are unaffected.
vi.mock('firebase/firestore', async (importOriginal) => {
  const actual = await importOriginal<typeof import('firebase/firestore')>();
  return {
    ...actual,
    doc: vi.fn(() => ({ id: 'fake-id', path: 'fake/path' })),
  };
});

const by6: SellingOption = { id: 'o1', label: 'By 6', pieces: 6, price: 600 };

/** Full ProductCreateInput, including sellingOptions: [] like every real
 *  call site (FirestoreProductRepository.create, executeReceivePlan). */
function createInput(o: Partial<ProductCreateInput> = {}): ProductCreateInput {
  return {
    sku: 'ABC1',
    name: 'Widget',
    costCode: 'AA',
    cost: 10,
    price: 20,
    quantity: 5,
    reorderLevel: 1,
    unit: 'pcs',
    supplierId: null,
    supplierName: null,
    isActive: true,
    createdBy: null,
    updatedBy: null,
    createdByName: null,
    updatedByName: null,
    baseSku: null,
    variationNumber: null,
    barcodes: [],
    sellingOptions: [],
    category: null,
    imageUrl: null,
    notes: null,
    ...o,
  };
}

describe('buildProductWrites — create path (unrestricted, matching how price already works)', () => {
  it('persists selling options supplied at creation — asserted on the write payload itself, not on whether a function was merely called', () => {
    const options: SellingOption[] = [by6];
    const { productData } = buildProductWrites(
      {} as Firestore,
      createInput({ sellingOptions: options }),
      'actor-1',
      'p1',
    );
    expect(productData.sellingOptions).toEqual(options);
  });

  it('writes an empty array, not undefined, when the caller supplies none', () => {
    // Deliberately omits the key rather than passing `sellingOptions: []` —
    // this is the actual runtime shape once CreateProductInput.sellingOptions
    // is optional and an admin creates a product without touching the
    // editor: the `as ProductCreateInput` cast in useCreateProduct means the
    // "required" field can genuinely be absent at runtime despite the type.
    const { sellingOptions: _omitted, ...rest } = createInput();
    const input = rest as ProductCreateInput;

    const { productData } = buildProductWrites({} as Firestore, input, 'actor-1', 'p1');

    expect(productData.sellingOptions).toEqual([]);
    expect(productData.sellingOptions).not.toBeUndefined();
  });
});

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

describe('nameKey', () => {
  it('is written on create, word-order-insensitive with the category', () => {
    const { productData } = buildProductWrites(
      {} as Firestore,
      createInput({ name: 'GLOBAL CHAIN 428-120L', category: 'CHAINS' }),
      'u1',
      'p1',
    );
    expect(productData.nameKey).toBe('428-120l chain global|chains');
  });

  it('two word-order variants of one name produce the same key', () => {
    const a = buildProductWrites(
      {} as Firestore,
      createInput({ name: 'CHAIN GLOBAL 428-120L', category: 'CHAINS' }),
      'u1',
      'p1',
    );
    const b = buildProductWrites(
      {} as Firestore,
      createInput({ name: 'GLOBAL CHAIN 428-120L', category: 'CHAINS' }),
      'u1',
      'p2',
    );
    expect(a.productData.nameKey).toBe(b.productData.nameKey);
  });

  it('is rebuilt on a rename', () => {
    const data = buildProductUpdate({ name: 'GLOBAL CHAIN 428-120L', category: 'CHAINS' }, 'u1');
    expect(data.nameKey).toBe('428-120l chain global|chains');
  });

  it('is left alone when the name is not part of the update', () => {
    const data = buildProductUpdate({ price: 100 }, 'u1');
    expect(data.nameKey).toBeUndefined();
  });

  it('a name-only update on a categorised product does NOT write a half-formed key', () => {
    // Without the category in the patch we don't know the product's real
    // category, so writing `productDuplicateKey(name, null)` (e.g.
    // "foo bar|") would be silently WRONG for a categorised product and the
    // lookup would then never match it. Better to leave nameKey untouched
    // than to write a key we know is malformed.
    const data = buildProductUpdate({ name: 'Renamed' }, 'u1');
    expect(data.nameKey).toBeUndefined();
  });

  it('a category-only update does not write nameKey either — the name is unknown here', () => {
    const data = buildProductUpdate({ category: 'CHAINS' }, 'u1');
    expect(data.nameKey).toBeUndefined();
  });
});
