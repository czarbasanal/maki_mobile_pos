import { useCostCodeRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { CostCode } from '@/domain/entities';

export function useCostCode() {
  const repo = useCostCodeRepo();
  return useFirestoreSubscription<CostCode>(
    (onData) => repo.watch(onData),
    [repo],
  );
}
