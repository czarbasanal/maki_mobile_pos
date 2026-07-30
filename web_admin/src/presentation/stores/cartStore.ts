import { create, type StoreApi, type UseBoundStore } from 'zustand';
import type { JobOrder, Product } from '@/domain/entities';
import type { LaborLine } from '@/domain/entities/LaborLine';
import type { FeeLine } from '@/domain/entities/FeeLine';
import type { SellingOption } from '@/domain/entities/SellingOption';
import { sellingOptionPricePerPiece } from '@/domain/entities/SellingOption';
import { saleItemQuantityStep } from '@/domain/entities/SaleItem';
import { cartLineId, type CartLine } from '@/domain/sales/cart';
import { DiscountType } from '@/domain/enums/DiscountType';

interface CartState {
  lines: CartLine[];
  discountType: DiscountType;
  laborLines: LaborLine[];
  // Shop fees carried from a resumed job order (no web POS entry UI yet — this
  // exists so a fee-bearing mobile JO doesn't lose its fee money on bill-out).
  feeLines: FeeLine[];
  mechanicId: string | null;
  mechanicName: string | null;
  jobOrderId: string | null;
  jobOrderName: string | null;
  // Optional sale/JO notes — restored on job order resume, carried onto the sale
  // at checkout (mobile parity). The JO-edit textarea buffers raw text here,
  // so '' can transiently appear; every PERSIST site normalizes ''/blank to
  // null before writing.
  notes: string | null;
  addLine: (product: Product) => void;
  addLineWithOption: (product: Product, option: SellingOption) => void;
  setQty: (lineId: string, quantity: number) => void;
  setLineDiscount: (lineId: string, discountValue: number) => void;
  removeLine: (lineId: string) => void;
  setDiscountType: (discountType: DiscountType) => void;
  addLaborLine: () => void;
  setLaborLine: (id: string, patch: Partial<Pick<LaborLine, 'description' | 'fee'>>) => void;
  removeLaborLine: (id: string) => void;
  setMechanic: (id: string | null, name: string | null) => void;
  setNotes: (notes: string | null) => void;
  loadJobOrder: (jobOrder: JobOrder) => void;
  clear: () => void;
}

export function createCartStore(): UseBoundStore<StoreApi<CartState>> {
  return create<CartState>((set) => ({
    lines: [],
    discountType: DiscountType.amount,
    laborLines: [],
    feeLines: [],
    mechanicId: null,
    mechanicName: null,
    jobOrderId: null,
    jobOrderName: null,
    notes: null,
    addLine: (product) =>
      set((s) => {
        // Match on id, not productId, so this never merges into an option
        // line (a plain sale of a product that also has selling options).
        if (s.lines.some((l) => l.id === product.id)) {
          return {
            lines: s.lines.map((l) =>
              l.id === product.id ? { ...l, quantity: l.quantity + 1 } : l,
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
          optionId: null,
          optionLabel: null,
          optionPieces: null,
          optionPrice: null,
        };
        return { lines: [...s.lines, line] };
      }),
    addLineWithOption: (product, option) =>
      set((s) => {
        const id = cartLineId(product.id, option.id);
        if (s.lines.some((l) => l.id === id)) {
          return {
            lines: s.lines.map((l) =>
              l.id === id ? { ...l, quantity: l.quantity + option.pieces } : l,
            ),
          };
        }
        const line: CartLine = {
          id,
          productId: product.id,
          sku: product.sku,
          name: product.name,
          // Per-piece, so every existing report that multiplies unitPrice by
          // quantity keeps working. optionPrice below is what the UI shows.
          unitPrice: sellingOptionPricePerPiece(option),
          unitCost: product.cost,
          quantity: option.pieces,
          discountValue: 0,
          unit: product.unit,
          optionId: option.id,
          optionLabel: option.label,
          optionPieces: option.pieces,
          optionPrice: option.price,
        };
        return { lines: [...s.lines, line] };
      }),
    setQty: (lineId, quantity) =>
      set((s) => ({
        lines: s.lines.map((l) => {
          if (l.id !== lineId) return l;
          // On an option line the typed number is SETS; stored quantity is pieces.
          const step = saleItemQuantityStep(l);
          const n = Math.max(1, Math.floor(quantity) || 1);
          return { ...l, quantity: n * step };
        }),
      })),
    setLineDiscount: (lineId, discountValue) =>
      set((s) => {
        // Percentage discounts cap at 100 so a line can't go negative.
        const max = s.discountType === DiscountType.percentage ? 100 : Infinity;
        const value = Math.min(max, Math.max(0, discountValue));
        return {
          lines: s.lines.map((l) => (l.id === lineId ? { ...l, discountValue: value } : l)),
        };
      }),
    removeLine: (lineId) =>
      set((s) => ({ lines: s.lines.filter((l) => l.id !== lineId) })),
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
    setNotes: (notes) => set({ notes }),
    loadJobOrder: (jobOrder) =>
      set({
        lines: jobOrder.items,
        discountType: jobOrder.discountType,
        laborLines: jobOrder.laborLines,
        feeLines: jobOrder.feeLines,
        mechanicId: jobOrder.mechanicId,
        mechanicName: jobOrder.mechanicName,
        jobOrderId: jobOrder.id,
        jobOrderName: jobOrder.name,
        notes: jobOrder.notes,
      }),
    clear: () =>
      set({
        lines: [],
        discountType: DiscountType.amount,
        laborLines: [],
        feeLines: [],
        mechanicId: null,
        mechanicName: null,
        jobOrderId: null,
        jobOrderName: null,
        notes: null,
      }),
  }));
}

export const useCartStore = createCartStore();
export type CartStore = typeof useCartStore;
