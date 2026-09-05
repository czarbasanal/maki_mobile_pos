// Void Requests — per design/maki-pos-void-requests-redesign. KPI strip,
// then the waiting queue (never scoped by the date range — a pending request
// from three weeks ago is still pending), then the resolved history scoped
// by the range with search + outcome chips and a "Total voided" foot. Row
// actions open VoidDecisionModal: approve confirms, reject collects a note.
//
// Every figure reads summarizeVoidQueue over the one subscription, so the
// KPIs, the chip counts, the sidebar badge and the foot cannot disagree.
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { RoutePaths } from '@/presentation/router/routePaths';
import { ArrowDownTrayIcon, CheckIcon, ClockIcon } from '@heroicons/react/24/outline';
import { useResolvedVoidRequests, useVoidRequests } from '@/presentation/hooks/useVoidRequests';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useNow } from '@/presentation/hooks/useNow';
import { REPORT_RANGE_OPTIONS, useReportRange } from '@/presentation/hooks/useReportRange';
import {
  ageLabel,
  ageMinutes,
  ageTone,
  durationLabel,
  summarizeVoidQueue,
  voidReasonTone,
} from '@/domain/voidRequests/voidRequestQueue';
import { matchesProductQuery } from '@/domain/products/productSearch';
import { formatMoney } from '@/core/utils/money';
import { toCsv, downloadCsv } from '@/core/utils/csv';
import { csvFileName, whenLabel } from '@/core/utils/reportFormat';
import { cn } from '@/core/utils/cn';
import type { VoidRequest } from '@/domain/entities';
import { StatCard } from '@/presentation/components/ui/StatCard';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { Badge } from '@/presentation/components/ui/Badge';
import { Button } from '@/presentation/components/ui/Button';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { SearchInput } from '@/presentation/components/ui/SearchInput';
import { ViewChips } from '@/presentation/components/ui/ViewChips';
import { DateRangeControl } from '@/presentation/components/ui/DateRangeControl';
import { FirstRunState, NoMatchesState } from '@/presentation/components/ui/TableEmptyStates';
import { EmptyRangeState } from '@/presentation/components/ui/EmptyRangeState';
import { ErrorState } from '@/presentation/components/ui/ErrorState';
import { VoidDecisionModal, type VoidDecision } from './VoidDecisionModal';

type Outcome = 'all' | 'approved' | 'rejected';

const ageCls: Record<ReturnType<typeof ageTone>, string> = {
  'ink-3': 'text-ink-3',
  'accent-text': 'text-accent-text',
  neg: 'text-neg',
};

function ReasonCell({ r, dim = false }: { r: VoidRequest; dim?: boolean }) {
  return (
    <div className="flex min-w-0 flex-col gap-[3px]">
      <Badge tone={voidReasonTone(r.reason)} shape="tag" wrap>{r.reason}</Badge>
      {r.itemsSummary ? (
        <span className={cn('text-[11.5px] [text-wrap:pretty]', dim ? 'text-ink-3' : 'text-ink-2')}>{r.itemsSummary}</span>
      ) : null}
    </div>
  );
}

function SaleCell({ r }: { r: VoidRequest }) {
  return (
    <div className="flex items-center gap-1.5">
      <Link
        to={`${RoutePaths.reports}/sale/${r.saleId}`}
        className="whitespace-nowrap font-mono text-ctl-md font-medium text-ink hover:text-accent-text"
      >
        {r.saleNumber}
      </Link>
      <CopyButton value={r.saleNumber} label="sale number" />
    </div>
  );
}

export function VoidRequestsPage() {
  const user = useAuthStore((s) => s.user);
  const now = useNow();
  const range = useReportRange('last30');
  // Two subscriptions, neither capped: every pending request (a queue that
  // drops old ones lies), and the resolved ones inside the range.
  const pendingQ = useVoidRequests();
  const resolvedQ = useResolvedVoidRequests(range.effectiveRange);
  const requests = useMemo(() => [...pendingQ.pending, ...resolvedQ.requests], [pendingQ.pending, resolvedQ.requests]);
  const isLoading = pendingQ.isLoading || resolvedQ.isLoading;
  const error = pendingQ.error ?? resolvedQ.error;
  const [query, setQuery] = useState('');
  const [outcome, setOutcome] = useState<Outcome>('all');
  const [decision, setDecision] = useState<VoidDecision | null>(null);

  useEffect(() => {
    document.title = 'Void Requests · MAKI POS Admin';
  }, []);

  const s = useMemo(() => summarizeVoidQueue(requests, range.effectiveRange), [requests, range.effectiveRange]);

  // Search narrows the scoped history; the outcome chips narrow that further.
  // Counts respect range + search but NOT the outcome, or the chips lie.
  const searched = useMemo(() => {
    const q = query.trim();
    if (!q) return s.resolvedInRange;
    return s.resolvedInRange.filter((r) => matchesProductQuery({ name: r.requestedByName, sku: r.saleNumber }, q));
  }, [s.resolvedInRange, query]);
  const rows = useMemo(
    () => (outcome === 'all' ? searched : searched.filter((r) => r.status === outcome)),
    [searched, outcome],
  );
  const approvedShown = rows.filter((r) => r.status === 'approved');
  const isFiltered = outcome !== 'all' || query.trim() !== '';
  const clearFilters = () => {
    setOutcome('all');
    setQuery('');
  };

  const exportCsv = () =>
    downloadCsv(
      csvFileName('void-requests', range.effectiveRange),
      toCsv(
        ['Sale', 'Amount', 'Reason', 'Items', 'Requested by', 'Requested at', 'Outcome', 'Resolved by', 'Resolved at', 'Took', 'Note'],
        rows.map((r) => [
          r.saleNumber, r.saleGrandTotal.toFixed(2), r.reason, r.itemsSummary ?? '', r.requestedByName,
          r.createdAt.toISOString(), r.status, r.resolvedByName ?? '', r.resolvedAt?.toISOString() ?? '',
          r.resolvedAt ? durationLabel(r.createdAt, r.resolvedAt) : '', r.rejectionReason ?? '',
        ]),
      ),
    );

  const waitingColumns: Array<Column<VoidRequest>> = [
    { key: 'sale', header: 'Sale', render: (r) => <SaleCell r={r} /> },
    { key: 'reason', header: 'Reason', render: (r) => <ReasonCell r={r} /> },
    { key: 'by', header: 'Requested by', width: '130px', render: (r) => <span className="text-ink-2">{r.requestedByName}</span> },
    {
      key: 'at', header: 'Requested', width: '154px',
      render: (r) => {
        const mins = ageMinutes(r.createdAt, now);
        return (
          <div className="flex flex-col gap-0.5">
            <span className="font-mono text-[12px] text-ink-2">{whenLabel(r.createdAt)}</span>
            <span className={cn('text-[10.5px]', ageCls[ageTone(mins)])}>{ageLabel(mins)} waiting</span>
          </div>
        );
      },
    },
    { key: 'amount', header: 'Amount', align: 'right', width: '120px', mono: true, render: (r) => <span className="text-[13px] font-semibold tracking-[-0.3px]">{formatMoney(r.saleGrandTotal)}</span> },
    {
      key: 'actions', header: '', width: '186px',
      render: (r) => {
        // Whoever raised the request cannot decide it (guide §3 rule 5). The
        // hook refuses too; this is the visible half.
        const own = !!user && r.requestedBy === user.id;
        return (
          <div className="flex flex-col items-end gap-1">
            <div className="flex justify-end gap-[7px]">
              <Button variant="secondary" size="sm" disabled={own} onClick={() => setDecision({ mode: 'reject', request: r })}>
                Reject
              </Button>
              <Button variant="primary" size="sm" disabled={own} onClick={() => setDecision({ mode: 'approve', request: r })}>
                Approve void
              </Button>
            </div>
            {own ? <span className="text-[10.5px] text-ink-3">Yours — another admin decides</span> : null}
          </div>
        );
      },
    },
  ];

  const resolvedColumns: Array<Column<VoidRequest>> = [
    { key: 'sale', header: 'Sale', render: (r) => <SaleCell r={r} /> },
    { key: 'reason', header: 'Reason', render: (r) => <ReasonCell r={r} dim /> },
    {
      key: 'at', header: 'Requested', width: '154px',
      render: (r) => (
        <div className="flex flex-col gap-0.5">
          <span className="font-mono text-[12px] text-ink-2">{whenLabel(r.createdAt)}</span>
          <span className="text-[10.5px] text-ink-3">by {r.requestedByName}</span>
        </div>
      ),
    },
    {
      key: 'outcome', header: 'Outcome', width: '110px',
      render: (r) => (
        <div className="flex flex-col gap-[3px]">
          <Badge tone={r.status === 'approved' ? 'positive' : 'negative'} shape="pill">
            {r.status === 'approved' ? 'Approved' : 'Rejected'}
          </Badge>
          {r.rejectionReason ? <span className="text-[10.5px] text-ink-3 [text-wrap:pretty]">{r.rejectionReason}</span> : null}
        </div>
      ),
    },
    {
      key: 'resolved', header: 'Resolved', width: '170px',
      render: (r) => (
        <div className="flex flex-col gap-0.5">
          <span className="font-mono text-[12px] text-ink-2">{r.resolvedAt ? whenLabel(r.resolvedAt) : '—'}</span>
          <span className="text-[10.5px] text-ink-3">
            by {r.resolvedByName ?? '—'}{r.resolvedAt ? ` · ${durationLabel(r.createdAt, r.resolvedAt)}` : ''}
          </span>
        </div>
      ),
    },
    { key: 'amount', header: 'Amount', align: 'right', width: '120px', mono: true, render: (r) => <span className="text-[13px] font-semibold tracking-[-0.3px]">{formatMoney(r.saleGrandTotal)}</span> },
  ];

  if (error) return <ErrorState message="Could not load void requests." onRetry={() => window.location.reload()} />;

  return (
    <div className="flex flex-col gap-5">
      <div className="grid grid-cols-[repeat(auto-fit,minmax(212px,1fr))] gap-3">
        <StatCard lead label="Waiting on you" value={s.waiting.length} format="number" loading={isLoading}
          note={s.waiting.length ? `${formatMoney(s.waitingHeld)} held` : 'queue is clear'} />
        <StatCard label="Oldest request" format="text" loading={isLoading}
          value={s.oldest ? ageLabel(ageMinutes(s.oldest.createdAt, now)) : null}
          note={s.oldest ? s.oldest.saleNumber : 'nothing pending'} />
        <StatCard label="Approved" value={s.approvedCount} format="number" loading={isLoading}
          note={`${formatMoney(s.voidedTotal)} voided`} />
        <StatCard label="Approval rate" format="percent" loading={isLoading} value={s.approvalRate}
          note={s.resolvedInRange.length ? `${s.resolvedInRange.length} resolved in range` : 'nothing resolved in range'} />
      </div>

      {/* Waiting — never scoped by the range */}
      <div className="flex flex-col gap-2.5">
        <div className="flex items-center gap-[9px]">
          <h2 className="text-card-title text-ink">Waiting</h2>
          {s.waiting.length > 0 ? (
            <span className="rounded-[6px] bg-accent-soft px-[7px] py-[2px] font-mono text-[10.5px] font-semibold text-accent-text">
              {s.waiting.length}
            </span>
          ) : null}
          <span className="ml-auto text-[11.5px] text-ink-3">
            {s.waiting.length ? 'Approving returns stock to inventory' : 'Cashiers cannot void a sale themselves'}
          </span>
        </div>
        <div className="overflow-hidden rounded-card border border-line bg-surface shadow-card">
          <DataTable
            columns={waitingColumns}
            rows={s.waiting}
            rowKey={(r) => r.id}
            loading={isLoading}
            skeletonRows={2}
            minWidth="1000px"
            empty={
              <FirstRunState
                tone="positive"
                icon={<CheckIcon className="h-[22px] w-[22px] text-pos" />}
                title="Nothing waiting"
                description="Void requests filed by cashiers show up here for approval. Until then, no sale is being held."
              />
            }
          />
        </div>
      </div>

      {/* Resolved — scoped by the range */}
      <div className="flex flex-col gap-2.5">
        <div className="flex flex-wrap items-center gap-[9px]">
          <h2 className="text-card-title text-ink">Resolved</h2>
          <div className="ml-auto flex flex-wrap items-center justify-end gap-[9px]">
            <DateRangeControl
              options={REPORT_RANGE_OPTIONS}
              value={range.preset}
              onChange={range.setPreset}
              customStart={range.customStart}
              customEnd={range.customEnd}
              onCustomStart={range.setCustomStart}
              onCustomEnd={range.setCustomEnd}
            />
            <button
              type="button"
              title="Export CSV"
              onClick={exportCsv}
              disabled={rows.length === 0}
              className="flex h-9 w-9 shrink-0 items-center justify-center rounded-ctl border border-line bg-surface text-ink-2 shadow-card hover:border-accent-line hover:text-ink disabled:opacity-50"
            >
              <ArrowDownTrayIcon className="h-[15px] w-[15px]" />
            </button>
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-[9px]">
          <div className="w-[250px]">
            <SearchInput variant="bar" value={query} onChange={setQuery} placeholder="Search sale no. or cashier" />
          </div>
          <ViewChips
            value={outcome}
            onChange={setOutcome}
            options={[
              { value: 'all', label: 'All', count: searched.length },
              { value: 'approved', label: 'Approved', count: searched.filter((r) => r.status === 'approved').length },
              { value: 'rejected', label: 'Rejected', count: searched.filter((r) => r.status === 'rejected').length },
            ]}
          />
        </div>
        <div className="overflow-hidden rounded-card border border-line bg-surface shadow-card">
          <DataTable
            columns={resolvedColumns}
            rows={rows}
            rowKey={(r) => r.id}
            loading={isLoading}
            skeletonRows={3}
            minWidth="1060px"
            foot={
              <tr className="border-t border-line bg-surface-2">
                <td colSpan={5} className="px-5 py-3 text-[12px] font-semibold text-ink-2">Total voided</td>
                <td data-testid="total-voided" className="px-5 py-3 text-right font-mono text-[15px] font-semibold tracking-[-0.5px] text-ink">
                  {formatMoney(approvedShown.reduce((n, r) => n + r.saleGrandTotal, 0))}
                </td>
              </tr>
            }
            empty={
              s.resolvedInRange.length === 0 ? (
                <EmptyRangeState
                  icon={<ClockIcon className="h-[22px] w-[22px] text-ink-3" />}
                  title="No resolved requests in this range"
                  description={`Nothing was voided or rejected ${range.rangeNote}.${range.widen ? '' : ' Pick a custom range above to look further back.'}`}
                  onWiden={range.widen}
                  widenLabel={range.widenLabel}
                />
              ) : (
                <NoMatchesState
                  title="No resolved requests match"
                  hint="Try another outcome, or clear the search."
                  onClear={isFiltered ? clearFilters : undefined}
                />
              )
            }
          />
        </div>
      </div>

      <VoidDecisionModal decision={decision} onClose={() => setDecision(null)} />
    </div>
  );
}
