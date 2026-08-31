// Mirror of lib/domain/entities/purchase_order_entity.dart, with one addition
// the mobile model does not have: a per-LINE supplier.
//
// A purchase order here is a buying list for one trip, not a supplier order.
// The shop lists everything it needs, then decides on the road where each part
// is actually bought. So the order itself carries no supplier — the model
// already allows that — and each line records where it came from once known.

export const PurchaseOrderStatus = {
  draft: 'draft',
  ordered: 'ordered',
  received: 'received',
  cancelled: 'cancelled',
} as const;

export type PurchaseOrderStatus =
  (typeof PurchaseOrderStatus)[keyof typeof PurchaseOrderStatus];

/** Unknown values fall back to draft, matching mobile's parser. */
export function purchaseOrderStatusFromString(v: unknown): PurchaseOrderStatus {
  return v === 'ordered' || v === 'received' || v === 'cancelled' ? v : 'draft';
}

export interface PurchaseOrderItem {
  id: string;
  productId: string;
  sku: string;
  name: string;
  quantity: number;
  unit: string;
  /** Expected cost, prefilled from the product; the real cost is set on the
   *  receiving at delivery time. */
  unitCost: number;
  costCode: string;
  /** Where this line was actually bought. Null until decided on the road. */
  supplierId: string | null;
  supplierName: string | null;
}

export interface PurchaseOrder {
  id: string;
  referenceNumber: string;
  /** Null for a buying list — supplier lives on the lines. */
  supplierId: string | null;
  supplierName: string | null;
  items: PurchaseOrderItem[];
  totalCost: number;
  totalQuantity: number;
  status: PurchaseOrderStatus;
  notes: string | null;
  createdAt: Date;
  createdBy: string;
  createdByName: string;
  orderedAt: Date | null;
  receivedAt: Date | null;
  receivingId: string | null;
}

/** Still unfinished business: being built, or out being bought. */
export function isPendingPurchaseOrder(po: PurchaseOrder): boolean {
  return po.status === 'draft' || po.status === 'ordered';
}

export function purchaseOrderTotalCost(items: PurchaseOrderItem[]): number {
  return items.reduce((n, i) => n + i.unitCost * i.quantity, 0);
}

export function purchaseOrderTotalQuantity(items: PurchaseOrderItem[]): number {
  return items.reduce((n, i) => n + i.quantity, 0);
}
