import { businessDayFor, isRegisterOpen, type DrawerState } from '@/domain/entities';
import { useDrawerStateRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';

export function useRegisterStatus(): { open: boolean; businessDayInt: number; isLoading: boolean } {
  const repo = useDrawerStateRepo();
  const { data, isLoading } = useFirestoreSubscription<DrawerState>(
    (onData, onError) => repo.watch(onData, onError),
    [repo],
    'drawerState',
  );
  return {
    open: data ? isRegisterOpen(data) : false,
    businessDayInt: businessDayFor(data, new Date()),
    isLoading,
  };
}
