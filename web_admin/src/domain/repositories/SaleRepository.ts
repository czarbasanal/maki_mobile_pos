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
  /** `saleId` is the cart's checkout id: passing it makes the write
   *  idempotent (a retry returns the already-recorded sale instead of
   *  creating a duplicate). Omitting it keeps the auto-id behavior. */
  create(
    sale: Omit<Sale, 'id' | 'createdAt' | 'updatedAt'>,
    actorId: string,
    saleId?: string,
    /** A pre-minted JO number: a direct sale carrying a mechanic or
     *  motorcycle (service work billed on the spot) records a job order in
     *  the same transaction, already billed and linked — so the JO ledger
     *  is the complete service history, not just deferred tickets. */
    autoJobOrderName?: string | null,
  ): Promise<Sale>;
  voidSale(id: string, reason: string, actorId: string, actorName: string): Promise<void>;
}
