import type { Mechanic } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface MechanicCreateInput {
  name: string;
  address?: string | null;
  contactNumber?: string | null;
}

export interface MechanicUpdateInput {
  name?: string;
  isActive?: boolean;
  // null clears the stored value; undefined leaves it untouched.
  address?: string | null;
  contactNumber?: string | null;
}

export interface MechanicRepository {
  watchAll(cb: (mechanics: Mechanic[]) => void, opts?: { includeInactive?: boolean }): Unsubscribe;
  create(input: MechanicCreateInput, actorId: string): Promise<Mechanic>;
  /** Exact-name existence check (any active state) — the inline-add picker
   *  uses it to refuse resurrecting an archived mechanic's name. */
  nameExists(name: string): Promise<boolean>;
  update(id: string, input: MechanicUpdateInput, actorId: string): Promise<void>;
  /** Hard-deletes the mechanic doc. Past sales keep the name they recorded. */
  delete(id: string): Promise<void>;
}
