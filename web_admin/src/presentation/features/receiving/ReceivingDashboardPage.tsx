import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ArrowUpTrayIcon } from '@heroicons/react/24/outline';
import { useReceivingSummary } from '@/presentation/hooks/useReceivingSummary';
import { formatMoney } from '@/core/utils/money';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { RoutePaths } from '@/presentation/router/routePaths';
import { ReceivingStatusBadge } from './ReceivingStatusBadge';

const dtFmt = new Intl.DateTimeFormat('en-PH', { dateStyle: 'medium', timeStyle: 'short' });

export function ReceivingDashboardPage() {
  const [now] = useState(() => new Date());
  const summary = useReceivingSummary(now);
  const navigate = useNavigate();

  useEffect(() => {
    document.title = 'Receiving · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Receiving</h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Record incoming stock from suppliers, and track what you've received.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-tk-sm">
          <Link
            to={RoutePaths.receivingNew}
            className="rounded-md bg-primary-dark px-tk-md py-[8px] text-bodySmall font-medium text-white hover:opacity-90"
          >
            + New Receiving
          </Link>
          <Link
            to={RoutePaths.bulkReceiving}
            className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-[8px] text-bodySmall text-light-text hover:bg-light-subtle"
          >
            <ArrowUpTrayIcon className="h-4 w-4" />
            Import CSV
          </Link>
        </div>
      </header>

      {summary.isLoading ? (
        <div className="h-32"><LoadingView label="Loading receiving…" /></div>
      ) : (
        <>
          <section className="grid grid-cols-1 gap-tk-md sm:grid-cols-3">
            <Card label="Completed this month" value={String(summary.completedCount)} />
            <Card label="Open drafts" value={String(summary.draftCount)} />
            <Card label="Received this month" value={formatMoney(summary.receivedTotal)} />
          </section>

          {summary.drafts.length > 0 ? (
            <section className="space-y-tk-sm">
              <h2 className="text-bodyMedium font-semibold text-light-text">Drafts</h2>
              <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
                <table className="w-full text-bodySmall">
                  <tbody className="divide-y divide-light-hairline">
                    {summary.drafts.map((r) => (
                      <tr key={r.id} className="hover:bg-light-subtle">
                        <td className="px-tk-md py-tk-sm font-medium text-light-text">{r.referenceNumber}</td>
                        <td className="px-tk-md py-tk-sm text-light-text-secondary">{r.supplierName ?? '—'}</td>
                        <td className="px-tk-md py-tk-sm text-right tabular-nums">{r.totalQuantity} items</td>
                        <td className="px-tk-md py-tk-sm text-right">
                          <Link to={`/receiving/new/${r.id}`} className="text-light-text underline hover:opacity-80">
                            Resume
                          </Link>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          ) : null}

          <section className="space-y-tk-sm">
            <div className="flex items-center justify-between">
              <h2 className="text-bodyMedium font-semibold text-light-text">Recent receivings</h2>
              <Link to={RoutePaths.receivingHistory} className="text-bodySmall text-light-text-secondary hover:underline">
                View all →
              </Link>
            </div>
            {summary.recent.length === 0 ? (
              <EmptyState
                title="No receivings yet this month"
                description="Use New Receiving to record stock, or Import CSV for a batch."
              />
            ) : (
              <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
                <table className="w-full text-bodySmall">
                  <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
                    <tr>
                      <th className="px-tk-md py-tk-sm text-left font-medium">Reference</th>
                      <th className="px-tk-md py-tk-sm text-left font-medium">Date</th>
                      <th className="px-tk-md py-tk-sm text-left font-medium">Supplier</th>
                      <th className="px-tk-md py-tk-sm text-right font-medium">Items</th>
                      <th className="px-tk-md py-tk-sm text-right font-medium">Total</th>
                      <th className="px-tk-md py-tk-sm text-left font-medium">Status</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-light-hairline">
                    {summary.recent.map((r) => (
                      <tr
                        key={r.id}
                        onClick={() => navigate(`/receiving/${r.id}`)}
                        className="cursor-pointer hover:bg-light-subtle"
                      >
                        <td className="px-tk-md py-tk-sm font-medium text-light-text">{r.referenceNumber}</td>
                        <td className="px-tk-md py-tk-sm text-light-text-secondary">
                          {dtFmt.format(r.completedAt ?? r.createdAt)}
                        </td>
                        <td className="px-tk-md py-tk-sm text-light-text-secondary">{r.supplierName ?? '—'}</td>
                        <td className="px-tk-md py-tk-sm text-right tabular-nums">{r.totalQuantity}</td>
                        <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(r.totalCost)}</td>
                        <td className="px-tk-md py-tk-sm"><ReceivingStatusBadge status={r.status} /></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </>
      )}
    </div>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-light-hairline bg-light-card p-tk-lg">
      <div className="text-bodySmall text-light-text-secondary">{label}</div>
      <div className="mt-tk-xs text-headingSmall font-semibold tabular-nums text-light-text">{value}</div>
    </div>
  );
}
