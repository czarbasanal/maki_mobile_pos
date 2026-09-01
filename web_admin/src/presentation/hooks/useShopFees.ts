import { useShopFeeRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { ShopFee } from '@/domain/entities/ShopFee';

/** Active shop fees, name-sorted — the POS fee-picker source. */
export function useShopFees() {
  const repo = useShopFeeRepo();
  return useFirestoreSubscription<ShopFee[]>(
    (onData, onError) => repo.watchActive(onData, onError),
    [repo],
    'shopFees',
  );
}
