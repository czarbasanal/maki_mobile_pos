import { useMemo } from 'react';
import { endOfDay, startOfMonth } from 'date-fns';
import { useReceivings } from './useReceivings';
import { useDraftReceivings } from './useDraftReceivings';

/** Dashboard cards: this-month completed count + ₱ total, open drafts count,
 *  and the most-recent receivings. `now` is passed in (stable per render) so
 *  the hook stays pure. */
export function useReceivingSummary(now: Date) {
  const monthRange = useMemo(() => ({ start: startOfMonth(now), end: endOfDay(now) }), [now]);
  const { data: month, isLoading: lm } = useReceivings(monthRange);
  const { data: drafts, isLoading: ld } = useDraftReceivings();

  const completed = (month ?? []).filter((r) => r.status === 'completed');
  return {
    isLoading: lm || ld,
    completedCount: completed.length,
    receivedTotal: completed.reduce((n, r) => n + r.totalCost, 0),
    draftCount: (drafts ?? []).length,
    // The dashboard "recent receivings" preview is the completed history; open
    // drafts have their own card, so don't intermix them here.
    recent: completed.slice(0, 8),
  };
}
