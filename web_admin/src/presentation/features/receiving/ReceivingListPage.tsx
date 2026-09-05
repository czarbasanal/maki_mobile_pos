// Receiving list — per design/maki-pos-receiving-redesign §A and its
// reference (Receiving.dc.html). One summary row (the month's pipeline card
// + money cards), then saved-view chips with the primary actions, then the
// filter band (search · Supplier dropdown · date range · clear · count),
// then the full table with its footer — replacing the old dashboard's three
// small cards + unfilterable "Recent receivings" preview and the separate
// history page.
//
// Counts must agree (the guide's trap): the chips, the supplier menu and the
// row count all derive from the same scoped set; only the pipeline card is
// month-scoped, and it says so in its label. Our statuses have no 'partial',
// so the pipeline is Completed / Drafts / Cancelled.
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowUpTrayIcon, PlusIcon } from '@heroicons/react/24/outline';
import { useReceivings } from '@/presentation/hooks/useReceivings';
import { useDraftReceivings } from '@/presentation/hooks/useDraftReceivings';
import { RoutePaths } from '@/presentation/router/routePaths';
import type { Receiving, ReceivingStatus } from '@/domain/entities';
import { formatInShopZone } from '@/domain/time/shopTime';
import { resolvePreset } from '@/domain/reports/dateRange';
import { useDateRangeControlState } from '@/presentation/hooks/useDateRangeControlState';
import { formatMoney } from '@/core/utils/money';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { usePageClamp } from '@/presentation/hooks/usePageClamp';
import { usePageSize } from '@/presentation/hooks/usePageSize';
import { Badge } from '@/presentation/components/ui/Badge';
import { Button } from '@/presentation/components/ui/Button';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { BreakdownCard } from '@/presentation/components/ui/BreakdownCard';
import { MoneyCard } from '@/presentation/components/ui/MoneyCard';
import { FirstRunState, NoMatchesState } from '@/presentation/components/ui/TableEmptyStates';
import { ViewChips } from '@/presentation/components/ui/ViewChips';
import { SearchInput } from '@/presentation/components/ui/SearchInput';
import { DateRangeControl } from '@/presentation/components/ui/DateRangeControl';
import { SelectFilter } from '@/presentation/components/ui/SelectFilter';
import { TableFooter } from '@/presentation/components/ui/TableFooter';
import { statusTone } from '@/presentation/components/ui/statusTone';
import { useAuthStore } from '@/presentation/stores/authStore';
import { hasPermission, Permission } from '@/domain/permissions/Permission';

type StatusView = 'all' | ReceivingStatus;
type Range = 'today' | 'yesterday' | 'last7' | 'last30' | 'custom';

const RANGE_OPTIONS: Array<{ value: Range; label: string }> = [
  { value: 'today', label: 'Today' },
  { value: 'yesterday', label: 'Yesterday' },
  { value: 'last7', label: '7 days' },
  { value: 'last30', label: '30 days' },
  { value: 'custom', label: 'Custom' },
];

const STATUS_LABEL: Record<ReceivingStatus, string> = {
  draft: 'Draft',
  completed: 'Completed',
  cancelled: 'Cancelled',
};

const UNASSIGNED = '(unassigned)';

const receivedAt = (r: Receiving) => r.completedAt ?? r.createdAt;
const receivedFmt = (d: Date) =>
  `${formatInShopZone(d, { month: 'short', day: 'numeric' })}, ${formatInShopZone(d, {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  })}`;

export function ReceivingListPage() {
  useEffect(() => {
    document.title = 'Receiving · MAKI POS Admin';
  }, []);
  const navigate = useNavigate();

  // Custom range: the pill opens DateRangeControl's popover with the
  // browser's own date inputs. Dates are SHOP calendar days.
  const {
    preset: range,
    setPreset: setRange,
    customStart,
    setCustomStart,
    customEnd,
    setCustomEnd,
    range: dateRange,
  } = useDateRangeControlState<Range>('last30');
  const [view, setView] = useState<StatusView>('all');
  const [search, setSearch] = useState('');
  const [supplier, setSupplier] = useState('');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = usePageSize('receiving');
  const [now] = useState(() => new Date());

  const { data: ranged, isLoading, error } = useReceivings(dateRange);
  const { data: drafts } = useDraftReceivings();
  // The pipeline + money cards are month-scoped whatever the range picker
  // says, so they get their own always-full-month subscription (cached
  // per-range) instead of leaning on the picker's fetch — with Today active,
  // "Received this month" must still mean the month.
  const monthRange = useMemo(() => resolvePreset('thisMonth'), []);
  const { data: monthReceipts } = useReceivings(monthRange);

  // A draft is open work — it stays visible whatever the date range says,
  // the same reasoning as open job orders outside the range. Everything on
  // screen (chips, supplier menu, row count) derives from this one set.
  const source = useMemo(() => {
    const byId = new Map<string, Receiving>();
    for (const r of ranged ?? []) byId.set(r.id, r);
    for (const r of drafts ?? []) byId.set(r.id, r);
    return [...byId.values()].sort(
      (a, b) => receivedAt(b).getTime() - receivedAt(a).getTime(),
    );
  }, [ranged, drafts]);

  // The pipeline card is SHOP-month-scoped and says so in its label.
  const monthLabel = formatInShopZone(now, { month: 'long' });
  const inMonth = useMemo(() => monthReceipts ?? [], [monthReceipts]);
  const monthByStatus = useMemo(() => {
    const counts: Record<ReceivingStatus, number> = { draft: 0, completed: 0, cancelled: 0 };
    for (const r of inMonth) counts[r.status] += 1;
    return counts;
  }, [inMonth]);
  const monthCompleted = useMemo(() => inMonth.filter((r) => r.status === 'completed'), [inMonth]);
  const monthReceivedCost = monthCompleted.reduce((n, r) => n + r.totalCost, 0);
  const monthUnitsIn = monthCompleted.reduce((n, r) => n + r.totalQuantity, 0);
  const draftCost = (drafts ?? []).reduce((n, r) => n + r.totalCost, 0);

  // Search + supplier scope — everything EXCEPT the status view, so the chip
  // counts can't contradict the rows they'd show.
  const scoped = useMemo(() => {
    const q = search.trim().toLowerCase();
    return source.filter((r) => {
      if (supplier === UNASSIGNED && r.supplierName) return false;
      if (supplier && supplier !== UNASSIGNED && r.supplierName !== supplier) return false;
      if (!q) return true;
      return (
        r.referenceNumber.toLowerCase().includes(q) ||
        (r.supplierName ?? '').toLowerCase().includes(q)
      );
    });
  }, [source, search, supplier]);

  const viewCounts = useMemo(() => {
    const counts: Record<StatusView, number> = {
      all: scoped.length,
      draft: 0,
      completed: 0,
      cancelled: 0,
    };
    for (const r of scoped) counts[r.status] += 1;
    return counts;
  }, [scoped]);

  const rows = useMemo(
    () => (view === 'all' ? scoped : scoped.filter((r) => r.status === view)),
    [scoped, view],
  );
  usePageClamp(page, setPage, rows.length, pageSize);
  useEffect(() => {
    setPage(1);
  }, [search, view, supplier, range]);
  const paged = useMemo(
    () => rows.slice((page - 1) * pageSize, page * pageSize),
    [rows, page, pageSize],
  );

  // Supplier options respect the range + search (same rule as the chips).
  const supplierOptions = useMemo(() => {
    const q = search.trim().toLowerCase();
    const base = source.filter(
      (r) =>
        !q ||
        r.referenceNumber.toLowerCase().includes(q) ||
        (r.supplierName ?? '').toLowerCase().includes(q),
    );
    const byName = new Map<string, number>();
    for (const r of base) {
      const name = r.supplierName ?? UNASSIGNED;
      byName.set(name, (byName.get(name) ?? 0) + 1);
    }
    const named = [...byName.entries()]
      .filter(([name]) => name !== UNASSIGNED)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([name, count]) => ({ value: name, label: name, count }));
    const unassigned = byName.get(UNASSIGNED);
    return unassigned
      ? [...named, { value: UNASSIGNED, label: 'Unassigned', count: unassigned }]
      : named;
  }, [source, search]);

  const user = useAuthStore((s) => s.user);
  const canReceive = !!user && hasPermission(user.role, Permission.receiveStock);
  const canImport = !!user && hasPermission(user.role, Permission.bulkReceive);

  const isFiltered = view !== 'all' || supplier !== '' || search.trim() !== '';
  const clearFilters = () => {
    setView('all');
    setSupplier('');
    setSearch('');
    setPage(1);
  };

  // "No receipts yet" is a first-run claim. With no All-time view the best
  // available signal is every live subscription coming back empty (picker
  // range, shop month, and drafts) with nothing filtered — a shop with any
  // recent activity never sees it.
  const firstRun =
    !isLoading &&
    !isFiltered &&
    source.length === 0 &&
    (monthReceipts ?? []).length === 0 &&
    (drafts ?? []).length === 0;

  // Draft rows resume the form; completed and cancelled open the detail.
  const onRow = (r: Receiving) => {
    if (r.status === 'draft') navigate(`/receiving/new/${r.id}`);
    else navigate(`/receiving/${r.id}`);
  };

  const columns: Array<Column<Receiving>> = [
    {
      key: 'reference', header: 'Reference', mono: true,
      render: (r) => (
        <span className="flex items-center gap-1.5 font-medium">
          {r.referenceNumber}
          <CopyButton value={r.referenceNumber} label="reference" />
        </span>
      ),
    },
    {
      key: 'status', header: 'Status',
      render: (r) => <Badge tone={statusTone(r.status)}>{STATUS_LABEL[r.status]}</Badge>,
    },
    {
      key: 'supplier', header: 'Supplier',
      render: (r) =>
        r.supplierName ? (
          <span className="font-medium">{r.supplierName}</span>
        ) : (
          // "Nobody recorded it", not "no data" (guide §A).
          <span className="text-ink-3">Unassigned</span>
        ),
    },
    {
      key: 'received', header: 'Received',
      render: (r) => (
        <span className="flex flex-col gap-[2px]">
          <span className="font-mono text-micro text-ink-2">{receivedFmt(receivedAt(r))}</span>
          <span className="text-[10.5px] text-ink-3">by {r.createdByName || '—'}</span>
        </span>
      ),
    },
    {
      key: 'lines', header: 'Lines', align: 'right', width: '86px', mono: true,
      render: (r) => <span className="text-micro text-ink-2">{r.items.length}</span>,
    },
    {
      key: 'units', header: 'Units', align: 'right', width: '86px', mono: true,
      render: (r) =>
        r.totalQuantity > 0 ? r.totalQuantity : <span className="text-ink-3">—</span>,
    },
    {
      key: 'total', header: 'Total cost', align: 'right', width: '126px', mono: true,
      render: (r) =>
        r.totalCost > 0 ? (
          <span className="text-[13px] font-semibold tracking-[-0.3px]">
            {formatMoney(r.totalCost)}
          </span>
        ) : (
          <span className="text-ink-3">—</span>
        ),
    },
  ];

  if (error) return <ErrorView title="Could not load receiving" message={error.message} />;

  return (
    <div className="flex flex-col gap-3">
      {/* Summary row — pipeline card + money cards */}
      <div className="grid grid-cols-[repeat(auto-fit,minmax(236px,1fr))] gap-3">
        <BreakdownCard
          label={monthLabel}
          total={`${inMonth.length} ${inMonth.length === 1 ? 'receipt' : 'receipts'}`}
          rows={(
            [
              { status: 'completed' as const, label: 'Completed', color: 'var(--pos)' },
              { status: 'draft' as const, label: 'Drafts', color: 'var(--info)' },
              { status: 'cancelled' as const, label: 'Cancelled', color: 'var(--neg)' },
            ]
          ).map((p) => ({
            key: p.status,
            label: p.label,
            color: p.color,
            count: monthByStatus[p.status],
            active: view === p.status,
            onClick: () => {
              setView((cur) => (cur === p.status ? 'all' : p.status));
              setPage(1);
            },
          }))}
        />

        <MoneyCard
          label="Received this month"
          value={formatMoney(monthReceivedCost)}
          note="landed cost, completed only"
        />
        <MoneyCard
          label="Units in"
          value={monthUnitsIn.toLocaleString('en-PH')}
          note={`across ${monthCompleted.length} completed ${monthCompleted.length === 1 ? 'receipt' : 'receipts'}`}
        />
        <MoneyCard
          label="In drafts"
          value={formatMoney(draftCost)}
          note={`${(drafts ?? []).length} open ${(drafts ?? []).length === 1 ? 'draft' : 'drafts'}`}
        />
      </div>

      {/* Views row — chips | New receiving + Import CSV */}
      <div className="flex flex-wrap items-center gap-2">
        <ViewChips
          options={[
            { value: 'all' as const, label: 'All', count: viewCounts.all },
            { value: 'draft' as const, label: 'Draft', count: viewCounts.draft },
            { value: 'completed' as const, label: 'Completed', count: viewCounts.completed },
            { value: 'cancelled' as const, label: 'Cancelled', count: viewCounts.cancelled },
          ]}
          value={view}
          onChange={(v) => {
            setView(v);
            setPage(1);
          }}
        />
        <div className="ml-auto flex items-center gap-[9px]">
          <DateRangeControl
            options={RANGE_OPTIONS}
            value={range}
            onChange={(r) => {
              setRange(r);
              setPage(1);
            }}
            customStart={customStart}
            customEnd={customEnd}
            onCustomStart={(v) => {
              setCustomStart(v);
              setPage(1);
            }}
            onCustomEnd={(v) => {
              setCustomEnd(v);
              setPage(1);
            }}
          />
          {canReceive ? (
            <Button
              variant="primary"
              icon={<PlusIcon className="h-3.5 w-3.5" />}
              onClick={() => navigate(RoutePaths.receivingNew)}
            >
              New receiving
            </Button>
          ) : null}
          {canImport ? (
            <button
              type="button"
              title="Import CSV"
              onClick={() => navigate(RoutePaths.bulkReceiving)}
              className="flex h-9 w-9 shrink-0 items-center justify-center rounded-ctl border border-line bg-surface text-ink-2 hover:border-accent-line hover:text-ink"
            >
              <ArrowUpTrayIcon className="h-[15px] w-[15px]" />
            </button>
          ) : null}
        </div>
      </div>

      {/* Filters row */}
      <div className="flex flex-wrap items-center gap-2.5">
        <div className="w-[290px]">
          <SearchInput
            variant="bar"
            value={search}
            onChange={(v) => {
              setSearch(v);
              setPage(1);
            }}
            placeholder="Search reference or supplier"
          />
        </div>
        <SelectFilter
          label="Supplier"
          value={supplier}
          options={supplierOptions}
          onChange={(v) => {
            setSupplier(v);
            setPage(1);
          }}
          allLabel="All suppliers"
          allTriggerLabel="All"
        />
        {isFiltered ? (
          <button
            type="button"
            onClick={clearFilters}
            className="border-b border-line text-[11.5px] text-ink-3 hover:text-neg"
          >
            Clear filters
          </button>
        ) : null}
        <span className="ml-auto font-mono text-[12px] text-ink-3">
          {rows.length} {rows.length === 1 ? 'receipt' : 'receipts'}
        </span>
      </div>

      {/* Table card */}
      <section className="overflow-hidden rounded-card border border-line bg-surface shadow-card">
        <DataTable
          columns={columns}
          rows={paged}
          rowKey={(r) => r.id}
          onRowClick={onRow}
          loading={isLoading}
          minWidth="900px"
          empty={
            firstRun ? (
              <FirstRunState
                icon={
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--accent-text)" strokeWidth="1.6">
                    <path d="M3.5 8.5h11v8.5h-11z" />
                    <path d="M14.5 11.2h3.4l2.6 2.8v3h-6z" />
                    <circle cx="7" cy="18.4" r="1.6" />
                    <circle cx="17" cy="18.4" r="1.6" />
                  </svg>
                }
                title="No receipts yet"
                description="Record a delivery when stock arrives. Counting it in here is what updates on-hand quantities and the cost the register sells against."
              >
                {canReceive ? (
                  <Button
                    variant="primary"
                    icon={<PlusIcon className="h-3.5 w-3.5" />}
                    onClick={() => navigate(RoutePaths.receivingNew)}
                  >
                    New receiving
                  </Button>
                ) : null}
                {canImport ? (
                  <Button onClick={() => navigate(RoutePaths.bulkReceiving)}>Import CSV</Button>
                ) : null}
              </FirstRunState>
            ) : (
              <NoMatchesState
                title="No receipts match these filters"
                hint="Try another supplier or date range, or clear the search."
                onClear={clearFilters}
              />
            )
          }
        />
        {rows.length > 0 ? (
          <TableFooter
            total={rows.length}
            page={page}
            pageSize={pageSize}
            onPage={setPage}
            onPageSize={(n) => {
              setPageSize(n);
              setPage(1);
            }}
          />
        ) : null}
      </section>
    </div>
  );
}
