// Job Orders list — reskinned per design/JO-Sale-Detail-Hand-off §A.
// Three bands over the table card: saved status views + primary action,
// then filters (search · mechanic dropdown · clear), then the DataTable with
// its pagination footer. Status is a saved-view strip with live counts, not
// a column of identical pills.
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { PlusIcon, TrashIcon } from '@heroicons/react/24/outline';
import { useJobOrders } from '@/presentation/hooks/useJobOrders';
import { useDeleteJobOrder } from '@/presentation/hooks/useJobOrderMutations';
import { useCartStore } from '@/presentation/stores/cartStore';
import { cartGrandTotal } from '@/domain/sales/cart';
import { formatMoney } from '@/core/utils/money';
import { RoutePaths } from '@/presentation/router/routePaths';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { Pager } from '@/presentation/components/common/Pager';
import { usePageClamp } from '@/presentation/hooks/usePageClamp';
import { usePageSize } from '@/presentation/hooks/usePageSize';
import { Badge } from '@/presentation/components/ui/Badge';
import { Button } from '@/presentation/components/ui/Button';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { IconButton } from '@/presentation/components/ui/IconButton';
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
  const deleteJobOrder = useDeleteJobOrder();
  const navigate = useNavigate();

  // Today by default: the list is opened to work the day's tickets.
  const [preset, setPreset] = useState<DatePreset>('today');
  const range = useMemo<DateRange>(() => resolvePreset(preset), [preset]);
  const [view, setView] = useState<StatusView>('all');
  const [search, setSearch] = useState('');
  const [mechanicId, setMechanicId] = useState('');
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
      if (jo.createdAt < range.start || jo.createdAt > range.end) return false;
      if (mechanicId && jo.mechanicId !== mechanicId) return false;
      if (!q) return true;
      return (
        jo.name.toLowerCase().includes(q) ||
        (jo.motorcycleModel ?? '').toLowerCase().includes(q) ||
        (jo.mechanicName ?? '').toLowerCase().includes(q)
      );
    });
  }, [jobOrders, range, search, mechanicId]);

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

  const isFiltered = search.trim() !== '' || mechanicId !== '';
  const clearFilters = () => {
    setSearch('');
    setMechanicId('');
    setPage(1);
  };

  const onResume = (jobOrder: JobOrder) => {
    if (lines.length > 0 && !window.confirm('Replace the current cart with this Job Order?')) return;
    loadJobOrder(jobOrder);
    navigate(RoutePaths.pos);
  };
  const onDelete = (jobOrder: JobOrder) => {
    if (!window.confirm(`Delete Job Order "${jobOrder.name}"?`)) return;
    deleteJobOrder.mutate({ id: jobOrder.id, name: jobOrder.name });
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
        <span className="flex items-center gap-[7px] font-medium">
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
        return n === 0 ? <span className="text-ink-3">—</span> : n;
      },
    },
    {
      key: 'total', header: 'Total', align: 'right', mono: true,
      render: (jo) => {
        const total = cartGrandTotal(jo.items, jo.laborLines, jo.discountType, jo.feeLines);
        return total === 0 ? (
          <span className="text-ink-3">—</span>
        ) : (
          <span className="font-semibold">{formatMoney(total)}</span>
        );
      },
    },
    {
      key: 'actions', header: '', align: 'right', width: '150px',
      render: (jo) =>
        jo.isConverted ? (
          jo.convertedToSaleId ? (
            <button
              type="button"
              onClick={(e) => {
                e.stopPropagation();
                navigate(RoutePaths.saleDetail.replace(':id', jo.convertedToSaleId!));
              }}
              className="rounded-ctl border border-line px-2.5 py-1 text-ctl-sm font-medium text-ink-2 hover:bg-surface-2"
            >
              View sale
            </button>
          ) : null
        ) : (
          <span className="flex items-center justify-end gap-tk-sm">
            <button
              type="button"
              onClick={(e) => {
                e.stopPropagation();
                navigate(`${RoutePaths.jobOrders}/${jo.id}`);
              }}
              className="rounded-ctl border border-line px-2.5 py-1 text-ctl-sm font-medium text-ink-2 hover:bg-surface-2"
            >
              Edit
            </button>
            <button
              type="button"
              onClick={(e) => {
                e.stopPropagation();
                onResume(jo);
              }}
              className="rounded-ctl border border-accent-text px-2.5 py-1 text-ctl-sm font-semibold text-accent-text hover:bg-accent-soft"
            >
              Resume
            </button>
            <IconButton
              title="Delete Job Order"
              tone="danger"
              onClick={(e) => {
                e.stopPropagation();
                onDelete(jo);
              }}
            >
              <TrashIcon className="h-4 w-4" />
            </IconButton>
          </span>
        ),
    },
  ];

  if (error) return <ErrorView title="Could not load Job Orders" message={error.message} />;

  const firstRun = !isLoading && (jobOrders ?? []).length === 0;

  return (
    <div className="flex flex-col gap-3">
      {/* Band 1 — saved views + date range + primary action */}
      <div className="flex flex-wrap items-center gap-tk-sm">
        <div className="flex items-center gap-1.5">
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
                'flex items-center gap-1.5 whitespace-nowrap rounded-pill border px-3 py-[5px] text-ctl-sm font-medium transition-[color]',
                view === v.value
                  ? 'border-accent-text bg-accent-soft text-accent-text'
                  : 'border-line bg-surface text-ink-2 hover:text-ink',
              )}
            >
              {v.label}
              <span className="font-mono text-micro">{counts[v.value]}</span>
            </button>
          ))}
        </div>
        <div className="ml-auto flex items-center gap-tk-sm">
          <Segmented
            label="Date range"
            options={DATE_OPTIONS}
            value={preset}
            onChange={(p) => {
              setPreset(p);
              setPage(1);
            }}
          />
          <Button variant="primary" icon={<PlusIcon className="h-3.5 w-3.5" />} onClick={() => setNewOpen(true)}>
            New Job Order
          </Button>
        </div>
      </div>

      {/* Band 2 — filters */}
      <div className="flex flex-wrap items-center gap-tk-sm">
        <div className="w-[290px]">
          <SearchInput
            value={search}
            onChange={(v) => {
              setSearch(v);
              setPage(1);
            }}
            placeholder="Search JO no., motorcycle, mechanic"
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
        />
        {isFiltered ? (
          <button
            type="button"
            onClick={clearFilters}
            className="text-ctl-sm font-medium text-ink-2 hover:text-ink"
          >
            Clear filters
          </button>
        ) : null}
        <span className="ml-auto font-mono text-micro text-ink-3">
          {rows.length} {rows.length === 1 ? 'ticket' : 'tickets'}
        </span>
      </div>

      {openOutsideRange > 0 ? (
        <p className="text-ctl-sm text-ink-2">
          {openOutsideRange} open job order{openOutsideRange === 1 ? '' : 's'} outside this range —
          widen the dates above to see {openOutsideRange === 1 ? 'it' : 'them'}.
        </p>
      ) : null}

      {deleteJobOrder.error ? (
        <p className="rounded-ctl border border-neg bg-neg-soft px-tk-md py-tk-sm text-ctl-sm text-neg">
          Could not delete the Job Order: {deleteJobOrder.error.message}
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
          empty={
            firstRun ? (
              <div className="flex flex-col items-center gap-3 py-11 text-center">
                <span className="flex h-[52px] w-[52px] items-center justify-center rounded-card bg-accent-soft text-xl">
                  🎫
                </span>
                <p className="text-[14.5px] font-semibold text-ink">No job orders yet</p>
                <p className="max-w-[330px] text-ctl-sm text-ink-3 [text-wrap:pretty]">
                  Open a ticket when a unit comes in, add parts and labor as the work goes, and
                  bill it at the register.
                </p>
                <Button variant="primary" icon={<PlusIcon className="h-3.5 w-3.5" />} onClick={() => setNewOpen(true)}>
                  New Job Order
                </Button>
              </div>
            ) : (
              <div className="flex flex-col items-center gap-3 py-11 text-center">
                <p className="text-cell text-ink-3">No job orders match these filters</p>
                {isFiltered ? (
                  <button
                    type="button"
                    onClick={clearFilters}
                    className="rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-sm font-medium text-ink-2 hover:bg-surface-2"
                  >
                    Clear filters
                  </button>
                ) : null}
              </div>
            )
          }
        />
        {rows.length > 0 ? (
          <div className="border-t border-line bg-surface-2">
            <Pager
              total={rows.length}
              page={page}
              onPage={setPage}
              pageSize={pageSize}
              onPageSize={(n) => {
                setPageSize(n);
                setPage(1);
              }}
            />
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
