import {
  businessDayFor,
  isPreviousDayUnsettled,
  isRegisterOpen,
  type DrawerState,
} from '@/domain/entities';
import { useDrawerStateRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';

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
