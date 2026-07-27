import { useQuery } from '@tanstack/react-query';
import { useJobOrderRepo } from '@/infrastructure/di/container';
import { queryKeys } from '@/infrastructure/query/queryKeys';
import type { JobOrder } from '@/domain/entities';

/** One job order by id (for the job order-edit page). Null when it doesn't exist. */
export function useJobOrder(id: string) {
  const repo = useJobOrderRepo();
  return useQuery<JobOrder | null, Error>({
    queryKey: queryKeys.jobOrders.byId(id),
    queryFn: () => repo.getById(id),
  });
}
