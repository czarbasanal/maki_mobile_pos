import {
  businessDayFor,
  isPreviousDayUnsettled,
  isRegisterOpen,
  type DrawerState,
} from '@/domain/entities';
import { useDrawerStateRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import { useShopDay } from './useShopDay';

export function useRegisterStatus(): {
  open: boolean;
  businessDayInt: number;
  /** An earlier day has sales but no closing — selling is blocked (mobile
   *  parity; firestore.rules enforces the same server-side). Deliberately
   *  false while loading: the gate never blocks on a slow read. */
  previousDayUnsettled: boolean;
  isLoading: boolean;
} {
  const repo = useDrawerStateRepo();
  // Re-render at PHT midnight so the header's business date and gates
  // recompute in an idle tab (mobile business_day_provider parity).
  useShopDay();
  const { data, isLoading } = useFirestoreSubscription<DrawerState>(
    (onData, onError) => repo.watch(onData, onError),
    [repo],
    'drawerState',
  );
  const now = new Date();
  return {
    open: data ? isRegisterOpen(data) : false,
    businessDayInt: businessDayFor(data, now),
    previousDayUnsettled: isPreviousDayUnsettled(data, now),
    isLoading,
  };
}
