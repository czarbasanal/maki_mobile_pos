import type { Unsubscribe } from './AuthRepository';
import type {
  PurchaseOrder,
  PurchaseOrderItem,
  PurchaseOrderStatus,
} from '../entities';

/** A buying list as it is created — reference number and totals are derived. */
export interface PurchaseOrderInput {
  items: PurchaseOrderItem[];
  notes: string | null;
  createdBy: string;
  createdByName: string;
  /** `draft` while still being built, `ordered` once committed to. */
  status: Extract<PurchaseOrderStatus, 'draft' | 'ordered'>;
}

export interface PurchaseOrderRepository {
  /** Live list, newest first. */
  watchAll(
    callback: (orders: PurchaseOrder[]) => void,
    onError?: (e: Error) => void,
  ): Unsubscribe;
  getById(id: string): Promise<PurchaseOrder | null>;
  /** Allocates `PO-YYYYMMDD-NNN` from a counter inside the same transaction,
   *  so two clients creating at once cannot land on the same number. */
  create(input: PurchaseOrderInput): Promise<PurchaseOrder>;
  /** Field-wise patch. Only the named keys are written. */
  update(
    id: string,
    patch: Partial<Pick<PurchaseOrder, 'items' | 'notes' | 'status'>>,
    actorId: string,
  ): Promise<void>;
  cancel(id: string, actorId: string): Promise<void>;
}
