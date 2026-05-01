import type { Sale } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface SaleListFilters {
  start?: Date;
  end?: Date;
  cashierId?: string;
  status?: string;
  limit?: number;
}

export interface SaleRepository {
  getById(id: string): Promise<Sale | null>;
  list(filters?: SaleListFilters): Promise<Sale[]>;
  watchRecent(limit: number, callback: (sales: Sale[]) => void): Unsubscribe;
  create(sale: Omit<Sale, 'id' | 'createdAt' | 'updatedAt'>, actorId: string): Promise<Sale>;
  voidSale(id: string, reason: string, actorId: string, actorName: string): Promise<void>;
}
