import { create } from 'zustand';
import type { Product } from '@/domain/entities';
import type { CartLine } from '@/domain/sales/cart';
import { DiscountType } from '@/domain/enums/DiscountType';

interface CartState {
  lines: CartLine[];
  discountType: DiscountType;
  addLine: (product: Product) => void;
  setQty: (productId: string, quantity: number) => void;
  setLineDiscount: (productId: string, discountValue: number) => void;
  removeLine: (productId: string) => void;
  setDiscountType: (discountType: DiscountType) => void;
  clear: () => void;
}

export const useCartStore = create<CartState>((set) => ({
  lines: [],
  discountType: DiscountType.amount,
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
    set((s) => ({
      lines: s.lines.map((l) =>
        l.productId === productId ? { ...l, discountValue: Math.max(0, discountValue) } : l,
      ),
    })),
  removeLine: (productId) =>
    set((s) => ({ lines: s.lines.filter((l) => l.productId !== productId) })),
  setDiscountType: (discountType) =>
    set((s) => ({ discountType, lines: s.lines.map((l) => ({ ...l, discountValue: 0 })) })),
  clear: () => set({ lines: [], discountType: DiscountType.amount }),
}));
