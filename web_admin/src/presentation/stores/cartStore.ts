import { create } from 'zustand';
import type { Product } from '@/domain/entities';
import type { LaborLine } from '@/domain/entities/LaborLine';
import type { CartLine } from '@/domain/sales/cart';
import { DiscountType } from '@/domain/enums/DiscountType';

interface CartState {
  lines: CartLine[];
  discountType: DiscountType;
  laborLines: LaborLine[];
  mechanicId: string | null;
  mechanicName: string | null;
  addLine: (product: Product) => void;
  setQty: (productId: string, quantity: number) => void;
  setLineDiscount: (productId: string, discountValue: number) => void;
  removeLine: (productId: string) => void;
  setDiscountType: (discountType: DiscountType) => void;
  addLaborLine: () => void;
  setLaborLine: (id: string, patch: Partial<Pick<LaborLine, 'description' | 'fee'>>) => void;
  removeLaborLine: (id: string) => void;
  setMechanic: (id: string | null, name: string | null) => void;
  clear: () => void;
}

export const useCartStore = create<CartState>((set) => ({
  lines: [],
  discountType: DiscountType.amount,
  laborLines: [],
  mechanicId: null,
  mechanicName: null,
  addLine: (product) =>
    set((s) => {
      if (s.lines.some((l) => l.productId === product.id)) {
        return {
          lines: s.lines.map((l) =>
            l.productId === product.id ? { ...l, quantity: l.quantity + 1 } : l,
          ),
        };
      }
      const line: CartLine = {
        id: product.id,
        productId: product.id,
        sku: product.sku,
        name: product.name,
        unitPrice: product.price,
        unitCost: product.cost,
        quantity: 1,
        discountValue: 0,
        unit: product.unit,
      };
      return { lines: [...s.lines, line] };
    }),
  setQty: (productId, quantity) =>
    set((s) => ({
      lines: s.lines.map((l) =>
        l.productId === productId ? { ...l, quantity: Math.max(1, Math.floor(quantity) || 1) } : l,
      ),
    })),
  setLineDiscount: (productId, discountValue) =>
    set((s) => {
      // Percentage discounts cap at 100 so a line can't go negative.
      const max = s.discountType === DiscountType.percentage ? 100 : Infinity;
      const value = Math.min(max, Math.max(0, discountValue));
      return {
        lines: s.lines.map((l) => (l.productId === productId ? { ...l, discountValue: value } : l)),
      };
    }),
  removeLine: (productId) =>
    set((s) => ({ lines: s.lines.filter((l) => l.productId !== productId) })),
  setDiscountType: (discountType) =>
    set((s) => ({ discountType, lines: s.lines.map((l) => ({ ...l, discountValue: 0 })) })),
  addLaborLine: () =>
    set((s) => ({
      laborLines: [...s.laborLines, { id: crypto.randomUUID(), description: '', fee: 0 }],
    })),
  setLaborLine: (id, patch) =>
    set((s) => ({
      laborLines: s.laborLines.map((l) => {
        if (l.id !== id) return l;
        const next = { ...l, ...patch };
        if (patch.fee !== undefined) next.fee = Math.max(0, patch.fee || 0);
        return next;
      }),
    })),
  removeLaborLine: (id) =>
    set((s) => ({ laborLines: s.laborLines.filter((l) => l.id !== id) })),
  setMechanic: (id, name) => set({ mechanicId: id, mechanicName: name }),
  clear: () =>
    set({
      lines: [],
      discountType: DiscountType.amount,
      laborLines: [],
      mechanicId: null,
      mechanicName: null,
    }),
}));
