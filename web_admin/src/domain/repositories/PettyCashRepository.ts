import type { PettyCash } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface PettyCashRepository {
  list(start?: Date, end?: Date): Promise<PettyCash[]>;
  watchAll(callback: (entries: PettyCash[]) => void): Unsubscribe;
  getCurrentBalance(): Promise<number>;
  create(entry: Omit<PettyCash, 'id' | 'createdAt' | 'balance'>, actorId: string, actorName: string): Promise<PettyCash>;
  performCutOff(actorId: string, actorName: string): Promise<void>;
}
