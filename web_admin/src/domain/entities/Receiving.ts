// Mirror of lib/domain/entities/receiving_entity.dart.
import type { SellingOption } from './SellingOption';
export const ReceivingStatus = {
  draft: 'draft',
  completed: 'completed',
  cancelled: 'cancelled',
} as const;

export type ReceivingStatus = (typeof ReceivingStatus)[keyof typeof ReceivingStatus];

export interface ReceivingItem {
  id: string;
  productId: string | null;
  sku: string;
  name: string;
  quantity: number;
  unit: string;
  unitCost: number;
  costCode: string;
  isNewVariation: boolean;
  newProductId: string | null;
  notes: string | null;
  /** Draft-only: a not-yet-created product's spec, created at complete time.
   *  Absent/null on completed-doc items. */
  pendingNewProduct?: {
    category: string | null;
    price: number;
    reorderLevel: number;
    autoGenerateSku: boolean;
    /** Category code driving auto-SKU; the item's sku is then only a peeked
     *  preview. Optional — drafts saved before the receiving modal existed
     *  don't carry these. */
    autoSkuCategoryCode?: string | null;
    barcodes?: string[];
    notes?: string | null;
    sellingOptions?: SellingOption[];
  } | null;
}

export interface Receiving {
  id: string;
  referenceNumber: string;
  supplierId: string | null;
  supplierName: string | null;
  items: ReceivingItem[];
  totalCost: number;
  totalQuantity: number;
  status: ReceivingStatus;
  notes: string | null;
  createdAt: Date;
  completedAt: Date | null;
  createdBy: string;
  createdByName: string;
  completedBy: string | null;
  /** Optimistic-concurrency counter; 0 on docs written before versioning. */
  version: number;
}
