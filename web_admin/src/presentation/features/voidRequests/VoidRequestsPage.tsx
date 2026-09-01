// The admin void-request queue — the web counterpart of mobile's
// VoidRequestsScreen.
//
// Was a dropdown off a bell in the sidebar header. A queue that decides whether
// money gets reversed is not notification chrome: it needs room for the reason,
// the items, and a rejection note, and it needs to be reachable by URL and by
// nav rather than only by noticing a dot.

import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  useVoidRequests,
  useResolveVoidRequest,
} from '@/presentation/hooks/useVoidRequests';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { RoutePaths } from '@/presentation/router/routePaths';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import type { VoidRequest } from '@/domain/entities';

const dtFmt = new Intl.DateTimeFormat('en-PH', {
  month: 'short',
  day: 'numeric',
  hour: 'numeric',
  minute: '2-digit',
});

export function VoidRequestsPage() {
  const { requests, pending, isLoading, error } = useVoidRequests();

  useEffect(() => {
    document.title = 'Void Requests · MAKI POS Admin';
  }, []);

  if (error) return <ErrorView title="Could not load void requests" message={error.message} />;
  if (isLoading) return <LoadingView label="Loading void requests…" />;

  const resolved = requests.filter((r) => r.status !== 'pending');

  return (
    <div className="space-y-tk-lg">
      <section className="space-y-tk-sm">
        <h2 className="text-bodyMedium font-semibold text-light-text">
          Waiting {pending.length > 0 ? `(${pending.length})` : ''}
        </h2>
        {pending.length === 0 ? (
          <EmptyState
            title="Nothing waiting"
            description="Void requests filed by cashiers show up here for approval."
          />
        ) : (
          <ul className="space-y-tk-sm">
            {pending.map((r) => (
              <li key={r.id}>
                <PendingCard request={r} />
              </li>
            ))}
          </ul>
        )}
      </section>

      {resolved.length > 0 ? (
        <section className="space-y-tk-sm">
          <h2 className="text-bodyMedium font-semibold text-light-text">Resolved</h2>
          <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
            <table className="w-full text-bodySmall">
              <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
                <tr>
                  <th className="px-tk-md py-tk-sm text-left font-medium">Sale</th>
                  <th className="px-tk-md py-tk-sm text-right font-medium">Amount</th>
                  <th className="px-tk-md py-tk-sm text-left font-medium">Requested by</th>
                  <th className="px-tk-md py-tk-sm text-left font-medium">Outcome</th>
                  <th className="px-tk-md py-tk-sm text-left font-medium">Resolved by</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-light-hairline">
                {resolved.map((r) => (
                  <tr key={r.id}>
                    <td className="px-tk-md py-tk-sm">
                      <Link
                        to={`${RoutePaths.reports}/sale/${r.saleId}`}
                        className="font-mono text-light-text hover:underline"
                      >
                        {r.saleNumber}
                      </Link>
                    </td>
                    <td className="px-tk-md py-tk-sm text-right tabular-nums">
                      {formatMoney(r.saleGrandTotal)}
                    </td>
                    <td className="px-tk-md py-tk-sm text-light-text-secondary">
                      {r.requestedByName}
                    </td>
                    <td className="px-tk-md py-tk-sm">
                      <StatusPill status={r.status} />
                      {r.rejectionReason ? (
                        <span className="ml-tk-sm text-[11px] text-light-text-hint">
                          {r.rejectionReason}
                        </span>
                      ) : null}
                    </td>
                    <td className="px-tk-md py-tk-sm text-light-text-secondary">
                      {r.resolvedByName ?? '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      ) : null}
    </div>
  );
}

function StatusPill({ status }: { status: VoidRequest['status'] }) {
  const approved = status === 'approved';
  return (
    <span
      className={cn(
        'rounded-full px-tk-sm py-[1px] text-[11px] font-semibold uppercase tracking-wider',
        approved
          ? 'bg-success-light/40 text-success-dark'
          : 'bg-light-subtle text-light-text-secondary',
      )}
    >
      {approved ? 'Approved' : 'Rejected'}
    </span>
  );
}

function PendingCard({ request }: { request: VoidRequest }) {
  const resolve = useResolveVoidRequest();
  const [rejecting, setRejecting] = useState(false);
  const [reason, setReason] = useState('');
  const busy = resolve.isPending;

  return (
    <div className="space-y-tk-sm rounded-lg border border-light-hairline bg-light-card p-tk-lg">
      <div className="flex flex-wrap items-baseline justify-between gap-tk-sm">
        <div className="flex items-baseline gap-tk-sm">
          <Link
            to={`${RoutePaths.reports}/sale/${request.saleId}`}
            className="font-mono text-bodyMedium font-medium text-light-text hover:underline"
          >
            {request.saleNumber}
          </Link>
          <span className="text-[11px] text-light-text-hint">
            {request.requestedByName} · {dtFmt.format(request.createdAt)}
          </span>
        </div>
        <span className="tabular-nums text-bodyMedium font-semibold text-light-text">
          {formatMoney(request.saleGrandTotal)}
        </span>
      </div>

      <p className="text-bodySmall text-light-text">Reason: {request.reason}</p>
      {request.itemsSummary ? (
        <p className="text-bodySmall text-light-text-hint">{request.itemsSummary}</p>
      ) : null}

      {resolve.error ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {resolve.error.message}
        </p>
      ) : null}

      {rejecting ? (
        <div className="space-y-tk-xs">
          <input
            type="text"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="Why is this being rejected?"
            className="w-full max-w-md rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
          />
          <div className="flex gap-tk-sm">
            <button
              type="button"
              disabled={busy || !reason.trim()}
              onClick={() =>
                resolve.mutate({ request, approve: false, rejectionReason: reason.trim() })
              }
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall font-medium text-light-text hover:bg-light-subtle disabled:opacity-50"
            >
              Confirm reject
            </button>
            <button
              type="button"
              onClick={() => { setRejecting(false); setReason(''); }}
              className="px-tk-sm py-tk-sm text-bodySmall text-light-text-secondary hover:underline"
            >
              Cancel
            </button>
          </div>
        </div>
      ) : (
        <div className="flex gap-tk-sm">
          <button
            type="button"
            disabled={busy}
            onClick={() => resolve.mutate({ request, approve: true })}
            className="rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-50"
          >
            {busy ? 'Voiding…' : 'Approve'}
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={() => setRejecting(true)}
            className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall font-medium text-light-text hover:bg-light-subtle disabled:opacity-50"
          >
            Reject
          </button>
        </div>
      )}
    </div>
  );
}
