import type { Mechanic } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface MechanicUpdateInput {
  name?: string;
  isActive?: boolean;
}

export interface MechanicRepository {
  watchAll(cb: (mechanics: Mechanic[]) => void, opts?: { includeInactive?: boolean }): Unsubscribe;
  create(name: string, actorId: string): Promise<Mechanic>;
  update(id: string, input: MechanicUpdateInput, actorId: string): Promise<void>;
}
