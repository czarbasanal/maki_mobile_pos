import type { ReceivingStatus } from '@/domain/entities';

const TONE: Record<ReceivingStatus, string> = {
  completed: 'bg-success-light text-success-dark',
  draft: 'bg-warning-light text-warning-dark',
  cancelled: 'bg-light-subtle text-light-text-secondary',
};

export function ReceivingStatusBadge({ status }: { status: ReceivingStatus }) {
  return (
    <span
      className={`rounded-full px-tk-sm py-[2px] text-[11px] font-semibold uppercase tracking-wider ${TONE[status]}`}
    >
      {status}
    </span>
  );
}
