// Job Orders list — per design/JO-Sale-Detail-Hand-off §A and its reference
// implementation (Job Orders & Sale Detail.dc.html). Three bands over the
// table card: saved status views + date range + primary action, then filters
// (search · mechanic dropdown · clear · count), then the DataTable with its
// pagination footer inside the card. Status is a saved-view strip with live
// counts; each row carries ONE action (View sale / Resume) and the whole row
// clicks the same way.
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
import { usePageClamp } from '@/presentation/hooks/usePageClamp';
import { usePageSize } from '@/presentation/hooks/usePageSize';
import { Badge } from '@/presentation/components/ui/Badge';
import { Button } from '@/presentation/components/ui/Button';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { FirstRunState, NoMatchesState } from '@/presentation/components/ui/TableEmptyStates';
import { ViewChips } from '@/presentation/components/ui/ViewChips';
import { IconButton } from '@/presentation/components/ui/IconButton';
import { SearchInput } from '@/presentation/components/ui/SearchInput';
import { DateRangeControl } from '@/presentation/components/ui/DateRangeControl';
import { SelectFilter } from '@/presentation/components/ui/SelectFilter';
import { TableFooter } from '@/presentation/components/ui/TableFooter';
import { statusTone } from '@/presentation/components/ui/statusTone';
import { formatInShopZone } from '@/domain/time/shopTime';
import { cn } from '@/core/utils/cn';
import type { JobOrder } from '@/domain/entities';
import { Dialog } from '@/presentation/components/common/Dialog';
import { NewJobOrderDialog } from './NewJobOrderDialog';
import { nextJobOrderNumber } from '@/domain/jobOrders/joNumber';
import { type RangePreset } from '@/domain/reports/dateRange';
import { useDateRangeControlState } from '@/presentation/hooks/useDateRangeControlState';

type StatusView = 'all' | 'open' | 'billed';
type DatePreset = Extract<RangePreset, 'today' | 'yesterday' | 'last7' | 'last30'> | 'custom';

const DATE_OPTIONS: Array<{ value: DatePreset; label: string }> = [
  { value: 'today', label: 'Today' },
  { value: 'yesterday', label: 'Yesterday' },
  { value: 'last7', label: '7 days' },
  { value: 'last30', label: '30 days' },
  { value: 'custom', label: 'Custom' },
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

  // Today by default: the list is opened to work the day's tickets. Custom
  // range: DateRangeControl's popover with the browser's own date inputs;
  // picked dates are SHOP calendar days.
  const { preset, setPreset, customStart, setCustomStart, customEnd, setCustomEnd, range } =
    useDateRangeControlState<DatePreset>('today');
  const [view, setView] = useState<StatusView>('all');
  const [search, setSearch] = useState('');
  const [mechanicId, setMechanicId] = useState('');
  // Escape hatch past the 30-day preset cap: a bike can sit for months, and
  // an open ticket the date range hides would otherwise be unreachable from
  // this list (the guide's custom range picker isn't built yet).
  const [showOutsideOpen, setShowOutsideOpen] = useState(false);
  const [newOpen, setNewOpen] = useState(false);
  // Tickets a skinned confirm dialog is asking about; null = closed.
  const [deleting, setDeleting] = useState<JobOrder | null>(null);
  const [resuming, setResuming] = useState<JobOrder | null>(null);

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

  const resume = (jobOrder: JobOrder) => {
    loadJobOrder(jobOrder);
    navigate(RoutePaths.pos);
  };
  const onResume = (jobOrder: JobOrder) => {
    // A non-empty register cart would be silently replaced — confirm first.
    if (lines.length > 0) setResuming(jobOrder);
    else resume(jobOrder);
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
      // When the ticket was billed out; open tickets show — (still on the bench).
      key: 'closed', header: 'Closed', mono: true,
      render: (jo) =>
        jo.convertedAt ? (
          <span className="text-micro text-ink-2">{openedFmt(jo.convertedAt)}</span>
        ) : (
          <span className="text-ink-3">—</span>
        ),
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
      // The row's action (reference): View sale on billed, Resume on open —
      // the whole row does the same thing. An OPEN ticket also gets a delete
      // beside Resume; a billed one is a financial record and can't be
      // deleted (void the sale instead).
      key: 'action', header: '', align: 'right', width: '140px',
      render: (jo) => {
        if (jo.isConverted && !jo.convertedToSaleId) return null;
        const billed = jo.isConverted;
        return (
          <span className="flex items-center justify-end gap-1.5">
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
            {!billed ? (
              <IconButton
                title="Delete Job Order"
                tone="danger"
                onClick={(e) => {
                  e.stopPropagation();
                  deleteJobOrder.reset();
                  setDeleting(jo);
                }}
              >
                <TrashIcon className="h-4 w-4" />
              </IconButton>
            ) : null}
          </span>
        );
      },
    },
  ];

  if (error) return <ErrorView title="Could not load Job Orders" message={error.message} />;

  const firstRun = !isLoading && (jobOrders ?? []).length === 0;

  return (
    <div className="flex flex-col gap-3">
      {/* Band 1 — saved views + date range + primary action */}
      <div className="flex flex-wrap items-center gap-2">
        <ViewChips
          options={[
            { value: 'all', label: 'All', count: counts.all },
            { value: 'open', label: 'Open', count: counts.open },
            { value: 'billed', label: 'Billed', count: counts.billed },
          ]}
          value={view}
          onChange={(v) => {
            setView(v);
            setPage(1);
          }}
        />
        <div className="ml-auto flex items-center gap-2.5">
          <DateRangeControl
            options={DATE_OPTIONS}
            value={preset}
            onChange={(p) => {
              setPreset(p);
              setShowOutsideOpen(false);
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
      {deleteJobOrder.error ? (
        <p className="rounded-ctl border border-neg bg-neg-soft px-tk-md py-tk-sm text-ctl-sm text-neg">
          Could not delete the Job Order: {deleteJobOrder.error.message}
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
          minWidth="930px"
          empty={
            firstRun ? (
              <FirstRunState
                icon={
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--accent-text)" strokeWidth="1.6">
                    <rect x="4.5" y="3.5" width="15" height="17" rx="2.6" />
                    <line x1="8.4" y1="8.6" x2="15.6" y2="8.6" />
                    <line x1="8.4" y1="12.4" x2="15.6" y2="12.4" />
                    <line x1="8.4" y1="16.2" x2="12.6" y2="16.2" />
                  </svg>
                }
                title="No job orders yet"
                description="Open a ticket when a unit comes in for service. Add parts and labor as the work goes, then bill it at the register."
              >
                <Button variant="primary" icon={<PlusIcon className="h-3.5 w-3.5" />} onClick={() => setNewOpen(true)}>
                  New Job Order
                </Button>
              </FirstRunState>
            ) : (
              <NoMatchesState
                title="No job orders match these filters"
                hint="Try another date range, mechanic, or clear the search."
                onClear={isFiltered ? clearFilters : undefined}
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

      <NewJobOrderDialog
        open={newOpen}
        jobOrderNumber={newJobOrderNumber}
        onClose={() => setNewOpen(false)}
      />

      <Dialog
        open={resuming !== null}
        onClose={() => setResuming(null)}
        title="Replace the current cart?"
      >
        <p className="text-cell text-ink-2">
          Resuming <span className="font-mono font-medium text-ink">{resuming?.name}</span> loads
          its items into the register and clears what’s in the cart now.
        </p>
        <div className="mt-tk-md flex justify-end gap-tk-sm">
          <button
            type="button"
            onClick={() => setResuming(null)}
            className="rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-md text-ink-2 hover:bg-surface-2"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={() => {
              if (resuming) resume(resuming);
              setResuming(null);
            }}
            className="rounded-ctl bg-neg-soft px-tk-md py-tk-sm text-ctl-md font-medium text-neg hover:brightness-95"
          >
            Replace cart
          </button>
        </div>
      </Dialog>

      <Dialog
        open={deleting !== null}
        onClose={() => {
          if (!deleteJobOrder.isPending) setDeleting(null);
        }}
        title="Delete Job Order?"
        dismissable={!deleteJobOrder.isPending}
      >
        <p className="text-cell text-ink-2">
          <span className="font-mono font-medium text-ink">{deleting?.name}</span> and everything
          on it will be removed. This can’t be undone.
        </p>
        <div className="mt-tk-md flex justify-end gap-tk-sm">
          <button
            type="button"
            onClick={() => setDeleting(null)}
            disabled={deleteJobOrder.isPending}
            className="rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-md text-ink-2 hover:bg-surface-2"
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={deleteJobOrder.isPending}
            onClick={async () => {
              if (!deleting) return;
              try {
                await deleteJobOrder.mutateAsync({ id: deleting.id, name: deleting.name });
                setDeleting(null);
              } catch {
                // surfaced via the banner above the table
                setDeleting(null);
              }
            }}
            className="rounded-ctl bg-neg-soft px-tk-md py-tk-sm text-ctl-md font-medium text-neg hover:brightness-95 disabled:opacity-60"
          >
            {deleteJobOrder.isPending ? 'Deleting…' : 'Delete'}
          </button>
        </div>
      </Dialog>
    </div>
  );
}
