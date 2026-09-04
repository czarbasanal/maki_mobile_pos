import type { AdjustmentReason } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface AdjustmentReasonCreateInput {
  name: string;
  requiresNote?: boolean;
}

export interface AdjustmentReasonUpdateInput {
  name?: string;
  requiresNote?: boolean;
  isActive?: boolean;
}

export interface AdjustmentReasonRepository {
  watchAll(cb: (reasons: AdjustmentReason[]) => void, opts?: { includeInactive?: boolean }): Unsubscribe;
  /** Exact-name existence check (any active state). */
  nameExists(name: string): Promise<boolean>;
  create(input: AdjustmentReasonCreateInput, actorId: string): Promise<AdjustmentReason>;
  update(id: string, input: AdjustmentReasonUpdateInput, actorId: string): Promise<void>;
  /** Hard-deletes the adjustment reason doc. */
  delete(id: string): Promise<void>;
  /** Seed defaults: one batch writing six SEED_REASONS docs with audit fields.
   *  Called only when the watched list is empty (first-run auto-seed) or from the editor's
   *  "Seed defaults" action; does not check emptiness itself. */
  seedDefaults(actorId: string): Promise<void>;
}
