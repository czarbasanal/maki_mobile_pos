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
  // Live stream of today's sales, items eagerly loaded so the consumer can
  // compute totals without further round trips. Mirrors the Flutter
  // SaleRepository.watchTodaysSales contract.
  watchToday(callback: (sales: Sale[]) => void, onError?: (e: Error) => void): Unsubscribe;
  watchRecent(limit: number, callback: (sales: Sale[]) => void): Unsubscribe;
  create(sale: Omit<Sale, 'id' | 'createdAt' | 'updatedAt'>, actorId: string): Promise<Sale>;
  voidSale(id: string, reason: string, actorId: string, actorName: string): Promise<void>;
}
