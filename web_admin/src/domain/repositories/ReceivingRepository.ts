import type { CostCode, Receiving } from '../entities';
import type { Unsubscribe } from './AuthRepository';
import type { ClassifiedReceivingRow } from '../receiving/classifyReceivingRows';

export interface BulkReceiveInput {
  rows: ClassifiedReceivingRow[];
  /** All active products — used for variation numbering. */
  products: { sku: string }[];
  supplier: { id: string; name: string } | null;
  cipher: CostCode;
  actor: { id: string; name: string };
}

export interface ReceivingResult {
  referenceNumber: string;
  received: number; // line items committed
  newProducts: number;
  variations: number;
  failed: { row: number; message: string }[];
}

export interface ReceivingRepository {
  getById(id: string): Promise<Receiving | null>;
  list(start?: Date, end?: Date): Promise<Receiving[]>;
  watchAll(callback: (records: Receiving[]) => void): Unsubscribe;
  create(
    input: Omit<Receiving, 'id' | 'createdAt' | 'completedAt' | 'completedBy'>,
    actorId: string,
    actorName: string,
  ): Promise<Receiving>;
  complete(id: string, actorId: string): Promise<void>;
  /** Bulk CSV receiving — creates a completed receiving + applies stock. */
  bulkReceive(input: BulkReceiveInput): Promise<ReceivingResult>;
}
