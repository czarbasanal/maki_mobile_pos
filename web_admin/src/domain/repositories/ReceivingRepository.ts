import type { Receiving } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface ReceivingRepository {
  getById(id: string): Promise<Receiving | null>;
  list(start?: Date, end?: Date): Promise<Receiving[]>;
  watchAll(callback: (records: Receiving[]) => void): Unsubscribe;
  create(input: Omit<Receiving, 'id' | 'createdAt' | 'completedAt' | 'completedBy'>, actorId: string, actorName: string): Promise<Receiving>;
  complete(id: string, actorId: string): Promise<void>;
}
