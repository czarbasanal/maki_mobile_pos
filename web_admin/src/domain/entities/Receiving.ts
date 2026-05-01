// Mirror of lib/domain/entities/receiving_entity.dart.
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
}
