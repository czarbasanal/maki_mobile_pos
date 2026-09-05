// The empty-RANGE state (reports guide §1): explains why and offers a way
// out. Deliberately a different message from an empty FILTER result, which
// is the shared NoMatchesState.
import type { ReactNode } from 'react';
import { Button } from '@/presentation/components/ui/Button';
import { FirstRunState } from '@/presentation/components/ui/TableEmptyStates';

export function EmptyRangeState({
  icon,
  title,
  description,
  onWiden,
  widenLabel,
}: {
  icon: ReactNode;
  title: string;
  description: string;
  /** useReportRange's `widen` — null for daily-only roles or when nothing is wider. */
  onWiden: (() => void) | null;
  widenLabel: string | null;
}) {
  return (
    <FirstRunState tone="muted" icon={icon} title={title} description={description}>
      {onWiden && widenLabel ? (
        <Button variant="secondary" size="sm" onClick={onWiden}>
          {widenLabel}
        </Button>
      ) : null}
    </FirstRunState>
  );
}
