import { beforeEach, describe, expect, it } from 'vitest';
import { createCartStore, useCartStore } from './cartStore';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { JobOrder, Product } from '@/domain/entities';
import type { SellingOption } from '@/domain/entities/SellingOption';

const product = (over: Partial<Product> = {}): Product =>
  ({ id: 'p1', sku: 'A', name: 'A', price: 100, cost: 60, unit: 'pcs', quantity: 10, ...over } as Product);

describe('cartStore', () => {
  beforeEach(() => useCartStore.getState().clear());

  it('adds a product as a line and merges quantity on re-add', () => {
    useCartStore.getState().addLine(product());
    useCartStore.getState().addLine(product());
    const { lines } = useCartStore.getState();
    expect(lines).toHaveLength(1);
    expect(lines[0].quantity).toBe(2);
    expect(lines[0].unitPrice).toBe(100);
    expect(lines[0].unitCost).toBe(60);
  });

  it('resets line discounts when the discount type changes', () => {
    useCartStore.getState().addLine(product());
    useCartStore.getState().setLineDiscount('p1', 15);
    expect(useCartStore.getState().lines[0].discountValue).toBe(15);
    useCartStore.getState().setDiscountType(DiscountType.percentage);
    expect(useCartStore.getState().discountType).toBe(DiscountType.percentage);
    expect(useCartStore.getState().lines[0].discountValue).toBe(0);
  });

  it('clamps a percentage discount to 100', () => {
    useCartStore.getState().addLine(product());
    useCartStore.getState().setDiscountType(DiscountType.percentage);
    useCartStore.getState().setLineDiscount('p1', 150);
    expect(useCartStore.getState().lines[0].discountValue).toBe(100);
  });

  it('clamps quantity to a positive integer and removes lines', () => {
    useCartStore.getState().addLine(product());
    useCartStore.getState().setQty('p1', 0);
    expect(useCartStore.getState().lines[0].quantity).toBe(1);
    useCartStore.getState().removeLine('p1');
    expect(useCartStore.getState().lines).toHaveLength(0);
  });

  it('adds, edits, and removes labor lines (fee clamps at 0)', () => {
    const store = useCartStore.getState();
    store.addLaborLine();
    let lines = useCartStore.getState().laborLines;
    expect(lines).toHaveLength(1);
    expect(lines[0].description).toBe('');
    expect(lines[0].fee).toBe(0);

    const id = lines[0].id;
    store.setLaborLine(id, { description: 'Tune-up' });
    store.setLaborLine(id, { fee: -5 });
    lines = useCartStore.getState().laborLines;
    expect(lines[0].description).toBe('Tune-up');
    expect(lines[0].fee).toBe(0); // clamped

    store.setLaborLine(id, { fee: 300 });
    expect(useCartStore.getState().laborLines[0].fee).toBe(300);

    store.removeLaborLine(id);
    expect(useCartStore.getState().laborLines).toHaveLength(0);
  });

  it('sets and clears the mechanic, and clear() resets labor + mechanic', () => {
    const store = useCartStore.getState();
    store.setMechanic('m1', 'Juan');
    expect(useCartStore.getState().mechanicId).toBe('m1');
    expect(useCartStore.getState().mechanicName).toBe('Juan');

    store.addLaborLine();
    store.clear();
    expect(useCartStore.getState().laborLines).toHaveLength(0);
    expect(useCartStore.getState().mechanicId).toBeNull();
    expect(useCartStore.getState().mechanicName).toBeNull();
  });

  it('loadJobOrder hydrates the cart and marks the jobOrder active; clear resets it', () => {
    const store = useCartStore.getState();
    const jobOrder: JobOrder = {
      id: 'd1',
      name: 'Mr Cruz bike',
      items: [
        { id: 'i1', productId: 'p1', sku: 'A', name: 'Plug', unitPrice: 100, unitCost: 60, quantity: 2, discountValue: 0, unit: 'pcs', optionId: null, optionLabel: null, optionPieces: null, optionPrice: null },
      ],
      laborLines: [{ id: 'l1', description: 'Tune-up', fee: 500 }],
      feeLines: [{ id: 'f1', name: 'Convenience fee', amount: 50 }],
      mechanicId: 'm1',
      mechanicName: 'Juan',
      motorcycleModel: 'Honda Click 125i',
      discountType: DiscountType.percentage,
      createdBy: 'u1',
      createdByName: 'Cashier',
      createdAt: new Date('2026-02-01'),
      updatedAt: null,
      updatedBy: null,
      isConverted: false,
      convertedToSaleId: null,
      convertedAt: null,
      notes: 'Check brakes',
    };

    store.loadJobOrder(jobOrder);
    let s = useCartStore.getState();
    expect(s.notes).toBe('Check brakes');
    expect(s.lines).toHaveLength(1);
    expect(s.discountType).toBe(DiscountType.percentage);
    expect(s.laborLines).toEqual(jobOrder.laborLines);
    // Money-correctness carry: a fee-bearing job order's feeLines must survive
    // resume, or the shop-fee money is lost when the job order is billed out.
    expect(s.feeLines).toEqual(jobOrder.feeLines);
    expect(s.mechanicId).toBe('m1');
    expect(s.mechanicName).toBe('Juan');
    // The bike is what the job was about — it must survive into the sale, or
    // billing out on web silently loses what mobile recorded.
    expect(s.motorcycleModel).toBe('Honda Click 125i');
    expect(s.jobOrderId).toBe('d1');
    expect(s.jobOrderName).toBe('Mr Cruz bike');

    store.clear();
    s = useCartStore.getState();
    expect(s.jobOrderId).toBeNull();
    expect(s.jobOrderName).toBeNull();
    expect(s.motorcycleModel).toBeNull();
    expect(s.lines).toHaveLength(0);
    expect(s.feeLines).toHaveLength(0);
    expect(s.notes).toBeNull();
  });

  it('addLine merges into a resumed job-order line matching productId, not the JO item id', () => {
    const store = useCartStore.getState();
    // Mirrors a job order created on a phone: the line's `id` is the
    // mobile-minted JO item id ('i1'), never the product id ('p1'). See
    // job_order_model.dart's SaleItemModel.toMap(includeId: true).
    const jobOrder: JobOrder = {
      id: 'd2',
      name: 'Resumed ticket',
      items: [
        { id: 'i1', productId: 'p1', sku: 'A', name: 'Plug', unitPrice: 100, unitCost: 60, quantity: 2, discountValue: 0, unit: 'pcs', optionId: null, optionLabel: null, optionPieces: null, optionPrice: null },
      ],
      laborLines: [],
      feeLines: [],
      mechanicId: null,
      mechanicName: null,
      motorcycleModel: null,
      discountType: DiscountType.amount,
      createdBy: 'u1',
      createdByName: 'Cashier',
      createdAt: new Date('2026-02-01'),
      updatedAt: null,
      updatedBy: null,
      isConverted: false,
      convertedToSaleId: null,
      convertedAt: null,
      notes: null,
    };

    store.loadJobOrder(jobOrder);
    // Re-adding the same product from the search panel — the shop's real
    // mobile-JO -> web-bill-out workflow — must increment the resumed line,
    // not append a duplicate ('i1' !== 'p1', so a merge predicate keyed on
    // line id rather than productId would wrongly create a second line).
    store.addLine(product());
    let s = useCartStore.getState();
    expect(s.lines).toHaveLength(1);
    expect(s.lines[0].id).toBe('i1'); // the pre-existing line's id is preserved
    expect(s.lines[0].quantity).toBe(3); // 2 (resumed) + 1 (re-added)

    // setQty / setLineDiscount / removeLine target by line id — confirm they
    // still hit the resumed (JO-minted-id) line correctly after the merge.
    store.setQty('i1', 5);
    expect(useCartStore.getState().lines[0].quantity).toBe(5);
    store.setLineDiscount('i1', 20);
    expect(useCartStore.getState().lines[0].discountValue).toBe(20);
    store.removeLine('i1');
    expect(useCartStore.getState().lines).toHaveLength(0);
  });

  it('setNotes sets and clears sale notes', () => {
    const store = useCartStore.getState();
    store.setNotes('Customer waiting');
    expect(useCartStore.getState().notes).toBe('Customer waiting');
    store.setNotes(null);
    expect(useCartStore.getState().notes).toBeNull();
  });

  it('createCartStore() instances are independent', () => {
    const a = createCartStore();
    const b = createCartStore();
    a.getState().addLine(product());
    expect(a.getState().lines).toHaveLength(1);
    expect(b.getState().lines).toHaveLength(0);
  });
});

describe('cartStore selling options', () => {
  const by6: SellingOption = { id: 'o1', label: 'By 6', pieces: 6, price: 600 };
  const by3: SellingOption = { id: 'o2', label: 'By 3', pieces: 3, price: 330 };

  const optionProduct = () =>
    ({
      id: 'p1',
      sku: 'ABC-1',
      name: 'Pulley Ball',
      cost: 60,
      price: 120,
      unit: 'pcs',
      quantity: 12,
      sellingOptions: [by6, by3],
    }) as Product;

  it('merges the same option and keeps quantity in pieces', () => {
    const store = createCartStore();
    store.getState().addLineWithOption(optionProduct(), by3);
    store.getState().addLineWithOption(optionProduct(), by3);
    const { lines } = store.getState();
    expect(lines).toHaveLength(1);
    expect(lines[0].quantity).toBe(6);
    expect(lines[0].unitPrice).toBe(110);
  });

  it('keeps two different options of one product as separate lines', () => {
    const store = createCartStore();
    store.getState().addLineWithOption(optionProduct(), by6);
    store.getState().addLineWithOption(optionProduct(), by3);
    expect(store.getState().lines.map((l) => l.id)).toEqual(['p1::o1', 'p1::o2']);
  });

  it('keeps a plain line separate from an option line', () => {
    const store = createCartStore();
    store.getState().addLine(optionProduct());
    store.getState().addLineWithOption(optionProduct(), by3);
    expect(store.getState().lines).toHaveLength(2);
  });

  it('setQty targets one option line by its line id', () => {
    const store = createCartStore();
    store.getState().addLineWithOption(optionProduct(), by6);
    store.getState().addLineWithOption(optionProduct(), by3);
    store.getState().setQty('p1::o2', 2);
    const byLine = Object.fromEntries(store.getState().lines.map((l) => [l.id, l.quantity]));
    // by6 line untouched (still its initial 1 set = 6 pieces); by3 line now 2
    // sets = 6 pieces. If setQty mistakenly stored sets as pieces, this would
    // be 2 instead of 6 and would be indistinguishable from the by6 line by
    // coincidence alone if we didn't also assert the untouched line.
    expect(byLine['p1::o2']).toBe(6);
    expect(byLine['p1::o1']).toBe(6);
  });

  it('setQty on an option line is in sets and stores pieces', () => {
    const store = createCartStore();
    store.getState().addLineWithOption(optionProduct(), by3);
    store.getState().setQty('p1::o2', 3);
    // 3 sets of 3 pieces = 9 pieces. A wrong implementation that treats the
    // typed number as pieces directly would leave this at 3.
    expect(store.getState().lines[0].quantity).toBe(9);
  });

  it('removeLine targets one option line', () => {
    const store = createCartStore();
    store.getState().addLineWithOption(optionProduct(), by6);
    store.getState().addLineWithOption(optionProduct(), by3);
    store.getState().removeLine('p1::o1');
    expect(store.getState().lines.map((l) => l.id)).toEqual(['p1::o2']);
  });

  it('a plain line still uses the product id as its line id', () => {
    const store = createCartStore();
    store.getState().addLine(optionProduct());
    expect(store.getState().lines[0].id).toBe('p1');
  });

  it('addLineWithOption merges into a resumed job-order option line matching productId+optionId, not the JO item id', () => {
    const store = createCartStore();
    const jobOrder: JobOrder = {
      id: 'd3',
      name: 'Resumed ticket w/ option',
      items: [
        { id: 'i9', productId: 'p1', sku: 'ABC-1', name: 'Pulley Ball', unitPrice: 110, unitCost: 60, quantity: 3, discountValue: 0, unit: 'pcs', optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, optionPrice: 330 },
      ],
      laborLines: [],
      feeLines: [],
      mechanicId: null,
      mechanicName: null,
      motorcycleModel: null,
      discountType: DiscountType.amount,
      createdBy: 'u1',
      createdByName: 'Cashier',
      createdAt: new Date('2026-02-01'),
      updatedAt: null,
      updatedBy: null,
      isConverted: false,
      convertedToSaleId: null,
      convertedAt: null,
      notes: null,
    };

    store.getState().loadJobOrder(jobOrder);
    store.getState().addLineWithOption(optionProduct(), by3);
    const { lines } = store.getState();
    expect(lines).toHaveLength(1);
    expect(lines[0].id).toBe('i9'); // the pre-existing line's id is preserved
    expect(lines[0].quantity).toBe(6); // 3 (resumed) + 3 (by3.pieces)
  });
});
