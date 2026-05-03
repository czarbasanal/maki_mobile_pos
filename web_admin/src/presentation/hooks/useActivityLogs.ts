import { useActivityLogRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { ActivityLog, ActivityType } from '@/domain/entities';

export interface UseActivityLogsOptions {
  type?: ActivityType;
  userId?: string;
  limit?: number;
}

export function useActivityLogs(opts: UseActivityLogsOptions = {}) {
  const repo = useActivityLogRepo();
  const { type, userId, limit = 100 } = opts;
  return useFirestoreSubscription<ActivityLog[]>(
    (onData) => repo.watch({ type, userId, limit }, onData),
    [repo, type, userId, limit],
  );
}
