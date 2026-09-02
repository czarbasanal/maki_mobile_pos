// Job Orders list — per design/JO-Sale-Detail-Hand-off §A and its reference
// implementation (Job Orders & Sale Detail.dc.html). Three bands over the
// table card: saved status views + date range + primary action, then filters
// (search · mechanic dropdown · clear · count), then the DataTable with its
// pagination footer inside the card. Status is a saved-view strip with live
// counts; each row carries ONE action (View sale / Resume) and the whole row
// clicks the same way.
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { PlusIcon } from '@heroicons/react/24/outline';
import { useJobOrders } from '@/presentation/hooks/useJobOrders';
import { useCartStore } from '@/presentation/stores/cartStore';
import { cartGrandTotal } from '@/domain/sales/cart';
import { formatMoney } from '@/core/utils/money';
import { RoutePaths } from '@/presentation/router/routePaths';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { usePageClamp } from '@/presentation/hooks/usePageClamp';
import { usePageSize, type PageSize } from '@/presentation/hooks/usePageSize';
import { Badge } from '@/presentation/components/ui/Badge';
import { Button } from '@/presentation/components/ui/Button';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { SearchInput } from '@/presentation/components/ui/SearchInput';
import { Segmented } from '@/presentation/components/ui/Segmented';
import { SelectFilter } from '@/presentation/components/ui/SelectFilter';
import { statusTone } from '@/presentation/components/ui/statusTone';
import { formatInShopZone } from '@/domain/time/shopTime';
import { cn } from '@/core/utils/cn';
import type { JobOrder } from '@/domain/entities';
import { NewJobOrderDialog } from './NewJobOrderDialog';
import { nextJobOrderNumber } from '@/domain/jobOrders/joNumber';
import { resolvePreset, type DateRange, type RangePreset } from '@/domain/reports/dateRange';

type StatusView = 'all' | 'open' | 'billed';
type DatePreset = Extract<RangePreset, 'today' | 'yesterday' | 'last7' | 'last30'>;

const DATE_OPTIONS: Array<{ value: DatePreset; label: string }> = [
  { value: 'today', label: 'Today' },
  { value: 'yesterday', label: 'Yesterday' },
  { value: 'last7', label: '7 days' },
  { value: 'last30', label: '30 days' },
];

const FOOTER_SIZES = [25, 50, 100] as const;

const openedFmt = (d: Date) =>
  `${formatInShopZone(d, { month: 'short', day: 'numeric' })} · ${formatInShopZone(d, {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  })}`;

export function JobOrdersPage() {
  useEffect(() => {
    document.title = 'Job Orders · MAKI POS Admin';
  }, []);

  const { data: jobOrders, isLoading, error } = useJobOrders();
  const lines = useCartStore((s) => s.lines);
  const loadJobOrder = useCartStore((s) => s.loadJobOrder);
  const navigate = useNavigate();

  // Today by default: the list is opened to work the day's tickets.
  const [preset, setPreset] = useState<DatePreset>('today');
  const range = useMemo<DateRange>(() => resolvePreset(preset), [preset]);
  const [view, setView] = useState<StatusView>('all');
  const [search, setSearch] = useState('');
  const [mechanicId, setMechanicId] = useState('');
  // Escape hatch past the 30-day preset cap: a bike can sit for months, and
  // an open ticket the date range hides would otherwise be unreachable from
  // this list (the guide's custom range picker isn't built yet).
  const [showOutsideOpen, setShowOutsideOpen] = useState(false);
  const [newOpen, setNewOpen] = useState(false);

  // Same collision-safe numbering as the POS save dialog: null while the
  // live list is loading so a stale/empty name set can't mint a duplicate.
  const newJobOrderNumber =
    isLoading || !jobOrders ? null : nextJobOrderNumber(new Date(), jobOrders.map((d) => d.name));

  // Range + search + mechanic — everything EXCEPT the status view, so the
  // view chips' counts can't contradict the rows they'd show.
  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return (jobOrders ?? []).filter((jo) => {
      const outsideRange = jo.createdAt < range.start || jo.createdAt > range.end;
      if (outsideRange && !(showOutsideOpen && !jo.isConverted)) return false;
      if (mechanicId && jo.mechanicId !== mechanicId) return false;
      if (!q) return true;
      return (
        jo.name.toLowerCase().includes(q) ||
        (jo.motorcycleModel ?? '').toLowerCase().includes(q) ||
        (jo.mechanicName ?? '').toLowerCase().includes(q)
      );
    });
  }, [jobOrders, range, search, mechanicId, showOutsideOpen]);

  const counts = useMemo(
    () => ({
      all: filtered.length,
      open: filtered.filter((jo) => !jo.isConverted).length,
      billed: filtered.filter((jo) => jo.isConverted).length,
    }),
    [filtered],
  );

  const rows = useMemo(
    () =>
      view === 'all'
        ? filtered
        : filtered.filter((jo) => (view === 'billed' ? jo.isConverted : !jo.isConverted)),
    [filtered, view],
  );

  // Mechanic options come from the ranged set (not the status view), each
  // with its ticket count for the active range.
  const mechanicOptions = useMemo(() => {
    const byId = new Map<string, { value: string; label: string; count: number }>();
    for (const jo of jobOrders ?? []) {
      if (jo.createdAt < range.start || jo.createdAt > range.end) continue;
      if (!jo.mechanicId || !jo.mechanicName) continue;
      const cur = byId.get(jo.mechanicId);
      if (cur) cur.count += 1;
      else byId.set(jo.mechanicId, { value: jo.mechanicId, label: jo.mechanicName, count: 1 });
    }
    return [...byId.values()].sort((a, b) => a.label.localeCompare(b.label));
  }, [jobOrders, range]);

  // A bike left overnight is still an open ticket. Filtering by date would
  // hide it, so say how many are out there rather than losing them quietly.
  const openOutsideRange = useMemo(
    () =>
      (jobOrders ?? []).filter(
        (jo) => !jo.isConverted && (jo.createdAt < range.start || jo.createdAt > range.end),
      ).length,
    [jobOrders, range],
  );

  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = usePageSize('jobOrders');
  usePageClamp(page, setPage, rows.length, pageSize);
  const paged = useMemo(
    () => rows.slice((page - 1) * pageSize, page * pageSize),
    [rows, page, pageSize],
  );

  // Reference semantics: the status view IS a filter — Clear resets it too.
  const isFiltered = view !== 'all' || search.trim() !== '' || mechanicId !== '';
  const clearFilters = () => {
    setView('all');
    setSearch('');
    setMechanicId('');
    setPage(1);
  };

  const onResume = (jobOrder: JobOrder) => {
    if (lines.length > 0 && !window.confirm('Replace the current cart with this Job Order?')) return;
    loadJobOrder(jobOrder);
    navigate(RoutePaths.pos);
  };
  const onRow = (jo: JobOrder) => {
    if (jo.isConverted) {
      if (jo.convertedToSaleId) navigate(RoutePaths.saleDetail.replace(':id', jo.convertedToSaleId));
      return;
    }
    onResume(jo);
  };

  const columns: Array<Column<JobOrder>> = [
    {
      key: 'no', header: 'JO no.', mono: true,
      render: (jo) => (
        <span className="flex items-center gap-1.5 font-medium">
          {jo.name}
          <CopyButton value={jo.name} label="JO number" />
        </span>
      ),
    },
    {
      key: 'status', header: 'Status',
      render: (jo) => {
        const status = jo.isConverted ? 'Billed' : 'Open';
        return <Badge tone={statusTone(status)}>{status}</Badge>;
      },
    },
    {
      key: 'motorcycle', header: 'Motorcycle',
      render: (jo) => <span className="font-medium">{jo.motorcycleModel ?? '—'}</span>,
    },
    {
      key: 'mechanic', header: 'Mechanic',
      render: (jo) => <span className="text-ink-2">{jo.mechanicName ?? '—'}</span>,
    },
    {
      key: 'opened', header: 'Opened', mono: true,
      render: (jo) => <span className="text-micro text-ink-2">{openedFmt(jo.createdAt)}</span>,
    },
    {
      key: 'items', header: 'Items', align: 'right', mono: true,
      render: (jo) => {
        const n = jo.items.length + jo.laborLines.length;
        return n === 0 ? <span className="text-ink-3">—</span> : <span className="text-ink-2">{n}</span>;
      },
    },
    {
      key: 'total', header: 'Total', align: 'right', mono: true,
      render: (jo) => {
        const total = cartGrandTotal(jo.items, jo.laborLines, jo.discountType, jo.feeLines);
        return total === 0 ? (
          <span className="text-ink-3">—</span>
        ) : (
          <span className="text-[13px] font-semibold tracking-[-0.3px]">{formatMoney(total)}</span>
        );
      },
    },
    {
      // ONE action per row (reference): View sale on billed, Resume on open.
      // The whole row does the same thing.
      key: 'action', header: '', align: 'right', width: '112px',
      render: (jo) => {
        if (jo.isConverted && !jo.convertedToSaleId) return null;
        const billed = jo.isConverted;
        return (
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation();
              onRow(jo);
            }}
            className={cn(
              'rounded-[9px] border border-line px-3 py-1.5 text-[11.5px] font-medium hover:border-accent-line hover:text-ink',
              billed ? 'text-ink-2' : 'text-accent-text',
            )}
          >
            {billed ? 'View sale' : 'Resume'}
          </button>
        );
      },
    },
  ];

  if (error) return <ErrorView title="Could not load Job Orders" message={error.message} />;

  const firstRun = !isLoading && (jobOrders ?? []).length === 0;
  const totalPages = Math.max(1, Math.ceil(rows.length / pageSize));
  const footerSizes: number[] = FOOTER_SIZES.includes(pageSize as (typeof FOOTER_SIZES)[number])
    ? [...FOOTER_SIZES]
    : [...FOOTER_SIZES, pageSize].sort((a, b) => a - b);

  return (
    <div className="flex flex-col gap-3">
      {/* Band 1 — saved views + date range + primary action */}
      <div className="flex flex-wrap items-center gap-2">
        {(
          [
            { value: 'all', label: 'All' },
            { value: 'open', label: 'Open' },
            { value: 'billed', label: 'Billed' },
          ] as const
        ).map((v) => (
          <button
            key={v.value}
            type="button"
            aria-pressed={view === v.value}
            onClick={() => {
              setView(v.value);
              setPage(1);
            }}
            className={cn(
              'flex items-center gap-[7px] whitespace-nowrap rounded-pill border px-[13px] py-[7px] text-ctl-sm transition-[color]',
              view === v.value
                ? 'border-accent-text bg-accent-soft font-semibold text-accent-text'
                : 'border-line bg-surface font-medium text-ink-2 hover:text-ink',
            )}
          >
            {v.label}
            <span className="font-mono text-[11px] opacity-70">{counts[v.value]}</span>
          </button>
        ))}
        <div className="ml-auto flex items-center gap-2.5">
          <Segmented
            label="Date range"
            options={DATE_OPTIONS}
            value={preset}
            onChange={(p) => {
              setPreset(p);
              setShowOutsideOpen(false);
              setPage(1);
            }}
          />
          <Button variant="primary" icon={<PlusIcon className="h-3.5 w-3.5" />} onClick={() => setNewOpen(true)}>
            New Job Order
          </Button>
        </div>
      </div>

      {/* Band 2 — filters */}
      <div className="flex flex-wrap items-center gap-2.5">
        <div className="w-[290px]">
          <SearchInput
            variant="bar"
            value={search}
            onChange={(v) => {
              setSearch(v);
              setPage(1);
            }}
            placeholder="Search JO no., mechanic, motorcycle"
          />
        </div>
        <SelectFilter
          label="Mechanic"
          value={mechanicId}
          options={mechanicOptions}
          onChange={(v) => {
            setMechanicId(v);
            setPage(1);
          }}
          allLabel="All mechanics"
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
          {rows.length} {rows.length === 1 ? 'ticket' : 'tickets'}
        </span>
      </div>

      {openOutsideRange > 0 && !showOutsideOpen ? (
        <p className="text-ctl-sm text-ink-2">
          {openOutsideRange} open job order{openOutsideRange === 1 ? '' : 's'} outside this range —{' '}
          <button
            type="button"
            onClick={() => setShowOutsideOpen(true)}
            className="font-medium text-accent-text hover:underline"
          >
            show {openOutsideRange === 1 ? 'it' : 'them'}
          </button>
          .
        </p>
      ) : null}
      {showOutsideOpen ? (
        <p className="text-ctl-sm text-ink-2">
          Also showing open job orders from outside this date range.{' '}
          <button
            type="button"
            onClick={() => setShowOutsideOpen(false)}
            className="font-medium text-accent-text hover:underline"
          >
            Hide
          </button>
        </p>
      ) : null}

      {/* Band 3 — the table card */}
      <section className="overflow-hidden rounded-card border border-line bg-surface shadow-card">
        <DataTable
          columns={columns}
          rows={paged}
          rowKey={(jo) => jo.id}
          onRowClick={onRow}
          loading={isLoading}
          minWidth="820px"
          empty={
            firstRun ? (
              <div className="flex flex-col items-center gap-[5px] px-6 py-16 text-center">
                <div className="mb-[9px] flex h-[52px] w-[52px] items-center justify-center rounded-[15px] border border-accent-line bg-accent-soft">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--accent-text)" strokeWidth="1.6">
                    <rect x="4.5" y="3.5" width="15" height="17" rx="2.6" />
                    <line x1="8.4" y1="8.6" x2="15.6" y2="8.6" />
                    <line x1="8.4" y1="12.4" x2="15.6" y2="12.4" />
                    <line x1="8.4" y1="16.2" x2="12.6" y2="16.2" />
                  </svg>
                </div>
                <span className="text-[14.5px] font-semibold tracking-[-0.2px] text-ink">
                  No job orders yet
                </span>
                <span className="max-w-[330px] text-ctl-sm text-ink-3 [text-wrap:pretty]">
                  Open a ticket when a unit comes in for service. Add parts and labor as the work
                  goes, then bill it at the register.
                </span>
                <div className="mt-3.5">
                  <Button variant="primary" icon={<PlusIcon className="h-3.5 w-3.5" />} onClick={() => setNewOpen(true)}>
                    New Job Order
                  </Button>
                </div>
              </div>
            ) : (
              <div className="flex flex-col items-center gap-[7px] px-5 py-[52px] text-center">
                <span className="text-[13px] font-medium text-ink-2">
                  No job orders match these filters
                </span>
                <span className="text-[12px] text-ink-3">
                  Try another date range, mechanic, or clear the search.
                </span>
                <button
                  type="button"
                  onClick={clearFilters}
                  className="mt-1.5 rounded-ctl border border-line px-3.5 py-2 text-[12px] font-medium text-ink-2 hover:border-accent-line hover:text-ink"
                >
                  Clear filters
                </button>
              </div>
            )
          }
        />
        {rows.length > 0 ? (
          <div className="flex items-center gap-3 border-t border-line bg-surface-2 px-5 py-3">
            <span className="font-mono text-[11.5px] text-ink-3">
              {(page - 1) * pageSize + 1}–{Math.min(page * pageSize, rows.length)} of {rows.length}
            </span>
            <div className="ml-auto flex items-center gap-2">
              <span className="text-[11.5px] text-ink-3">Rows per page</span>
              <div className="flex gap-[3px]">
                {footerSizes.map((n) => (
                  <button
                    key={n}
                    type="button"
                    onClick={() => {
                      setPageSize(n as PageSize);
                      setPage(1);
                    }}
                    className={cn(
                      'rounded-[7px] px-[9px] py-1 font-mono text-[11.5px]',
                      n === pageSize ? 'bg-surface font-semibold text-ink' : 'text-ink-3 hover:text-ink-2',
                    )}
                  >
                    {n}
                  </button>
                ))}
              </div>
              <div className="ml-1.5 flex gap-[5px]">
                <button
                  type="button"
                  onClick={() => setPage(page - 1)}
                  disabled={page <= 1}
                  className="rounded-[8px] border border-line px-[11px] py-[5px] text-[11.5px] text-ink-2 hover:border-accent-line hover:text-ink disabled:cursor-not-allowed disabled:text-ink-3 disabled:hover:border-line"
                >
                  Prev
                </button>
                <button
                  type="button"
                  onClick={() => setPage(page + 1)}
                  disabled={page >= totalPages}
                  className="rounded-[8px] border border-line px-[11px] py-[5px] text-[11.5px] text-ink-2 hover:border-accent-line hover:text-ink disabled:cursor-not-allowed disabled:text-ink-3 disabled:hover:border-line"
                >
                  Next
                </button>
              </div>
            </div>
          </div>
        ) : null}
      </section>

      <NewJobOrderDialog
        open={newOpen}
        jobOrderNumber={newJobOrderNumber}
        onClose={() => setNewOpen(false)}
      />
    </div>
  );
}
