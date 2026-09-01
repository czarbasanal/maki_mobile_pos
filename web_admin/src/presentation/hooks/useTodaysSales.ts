import { useSaleRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import { useShopDay } from './useShopDay';
import type { Sale } from '@/domain/entities';

export function useTodaysSales() {
  const repo = useSaleRepo();
  // Keyed to the SHOP day: at PHT midnight useShopDay flips, the deps
  // change, and the subscription re-windows to the new day — no reload
  // needed, and a pre-midnight snapshot never paints onto the next day.
  const shopDay = useShopDay();
  return useFirestoreSubscription<Sale[]>(
    (onData, onError) => repo.watchToday(onData, onError),
    [repo, shopDay],
    `sales:today:${shopDay}`,
  );
}
