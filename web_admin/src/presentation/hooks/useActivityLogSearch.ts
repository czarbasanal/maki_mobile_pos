// One-shot activity-log read, fired by the Search button. Deliberately not
// built on useFirestoreSubscription — /admin/logs must issue no read until
// the admin asks for one.

import { useCallback, useRef, useState } from 'react';
import { useActivityLogRepo } from '@/infrastructure/di/container';
import type { ActivityLogQuery } from '@/domain/repositories/ActivityLogRepository';
import type { ActivityLog } from '@/domain/entities';

/** Ceiling on a single search. Hitting it means the range was too wide. */
export const ACTIVITY_LOG_SEARCH_LIMIT = 500;

export interface ActivityLogSearchState {
  data: ActivityLog[] | null;
  error: Error | null;
  isLoading: boolean;
}

export function useActivityLogSearch() {
  const repo = useActivityLogRepo();
  const [state, setState] = useState<ActivityLogSearchState>({
    data: null,
    error: null,
    isLoading: false,
  });
  // Guards against an out-of-order reply when Search is clicked twice.
  const runId = useRef(0);

  const run = useCallback(
    async (query: ActivityLogQuery) => {
      const id = ++runId.current;
      setState({ data: null, error: null, isLoading: true });
      try {
        const rows = await repo.list(query);
        if (runId.current === id) setState({ data: rows, error: null, isLoading: false });
      } catch (e) {
        if (runId.current === id) {
          setState({
            data: null,
            error: e instanceof Error ? e : new Error(String(e)),
            isLoading: false,
          });
        }
      }
    },
    [repo],
  );

  return { ...state, run };
}
