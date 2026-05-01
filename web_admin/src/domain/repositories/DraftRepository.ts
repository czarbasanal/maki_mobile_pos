import type { Draft } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface DraftRepository {
  getById(id: string): Promise<Draft | null>;
  watchAll(callback: (drafts: Draft[]) => void): Unsubscribe;
  create(draft: Omit<Draft, 'id' | 'createdAt' | 'updatedAt'>): Promise<Draft>;
  update(id: string, draft: Partial<Omit<Draft, 'id' | 'createdAt'>>, actorId: string): Promise<void>;
  delete(id: string): Promise<void>;
  markConverted(id: string, saleId: string): Promise<void>;
}
