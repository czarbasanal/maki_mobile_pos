import { useQuery } from '@tanstack/react-query';
import { useReceivingRepo } from '@/infrastructure/di/container';

/** One-shot fetch of a single (immutable) receiving by id. */
export function useReceiving(id: string) {
  const repo = useReceivingRepo();
  return useQuery({
    queryKey: ['receiving', id],
    queryFn: () => repo.getById(id),
    enabled: id.length > 0,
  });
}
