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
  update(id: string, input: MechanicUpdateInput, actorId: string): Promise<void>;
}
