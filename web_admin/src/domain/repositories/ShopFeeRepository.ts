import type { ShopFee } from '../entities/ShopFee';
import type { Unsubscribe } from './AuthRepository';

export interface ShopFeeRepository {
  /** Live list of ACTIVE fees, name-sorted — the POS picker source. */
  watchActive(onData: (fees: ShopFee[]) => void, onError?: (e: Error) => void): Unsubscribe;
}
