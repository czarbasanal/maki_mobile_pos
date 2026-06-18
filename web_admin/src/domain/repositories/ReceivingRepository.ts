import type { CostCode, Receiving } from '../entities';
import type { Unsubscribe } from './AuthRepository';
import type { ClassifiedReceivingRow } from '../receiving/classifyReceivingRows';
import type { DateRange } from '../reports/dateRange';

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

/** Editable fields of a receiving (manual entry / drafts). */
export type ReceivingInput = Omit<Receiving, 'id' | 'createdAt' | 'completedAt' | 'completedBy'>;

export interface ReceivingRepository {
  getById(id: string): Promise<Receiving | null>;
  /** The next `RCV-YYYYMMDD-NNN` reference, for display while drafting a new
   *  receiving (and reused by create()). */
  nextReferenceNumber(): Promise<string>;
  list(start?: Date, end?: Date): Promise<Receiving[]>;
  watchAll(
    range: DateRange,
    onData: (records: Receiving[]) => void,
    onError?: (err: Error) => void,
  ): Unsubscribe;
  /** Realtime list of all open (draft) receivings, any age. */
  watchDrafts(onData: (records: Receiving[]) => void, onError?: (err: Error) => void): Unsubscribe;
  /** Write a new receiving. A 'completed' status applies stock immediately;
   *  a 'draft' just persists. Generates the reference number when blank. */
  create(input: ReceivingInput, actorId: string): Promise<Receiving>;
  /** Replace a draft's editable fields. Throws if already completed. */
  update(id: string, input: ReceivingInput, actorId: string): Promise<void>;
  /** Transition a draft to completed — applies stock/variations/price history.
   *  Idempotent: a no-op if already completed. `cipher` encodes variation cost
   *  codes for new/mismatch lines. */
  complete(
    id: string,
    actor: { id: string; name: string | null },
    cipher: CostCode,
  ): Promise<void>;
  /** Bulk CSV receiving — creates a completed receiving + applies stock. */
  bulkReceive(input: BulkReceiveInput): Promise<ReceivingResult>;
}
