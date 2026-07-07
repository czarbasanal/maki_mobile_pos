import { useQuery } from '@tanstack/react-query';
import { useDraftRepo } from '@/infrastructure/di/container';
import { queryKeys } from '@/infrastructure/query/queryKeys';
import type { Draft } from '@/domain/entities';

/** One draft by id (for the draft-edit page). Null when it doesn't exist. */
export function useDraft(id: string) {
  const repo = useDraftRepo();
  return useQuery<Draft | null, Error>({
    queryKey: queryKeys.drafts.byId(id),
    queryFn: () => repo.getById(id),
  });
}
