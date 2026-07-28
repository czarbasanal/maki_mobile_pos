import type { JobOrder } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface JobOrderRepository {
  getById(id: string): Promise<JobOrder | null>;
  watchAll(callback: (jobOrders: JobOrder[]) => void): Unsubscribe;
  create(jobOrder: Omit<JobOrder, 'id' | 'createdAt' | 'updatedAt'>): Promise<JobOrder>;
  update(id: string, jobOrder: Partial<Omit<JobOrder, 'id' | 'createdAt'>>, actorId: string): Promise<void>;
  delete(id: string): Promise<void>;
}
