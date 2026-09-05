// Expenses — per design/maki-pos-expenses-redesign and its reference
// (Expenses.dc.html). Summary row (Spend · By category · Entries · Largest
// single), then the action row (date range · Add expense · Export), then the
// filters row (search · Category · clear · count), then the table card with
// its "Total shown" foot and pagination. Row click opens the edit modal
// (rendered via the child route's Outlet, exactly like InventoryListPage).
//
// The guide's invariant (§2), broken twice in the original: ONE scoped array
// (the date-ranged fetch) feeds the table, the By-category card, the Entries
// count and the Largest-single card. Only the table narrows further by
// category/search — the cards never do. The Spend card is the deliberate
// exception: its three rows are FIXED windows (today/last7/last30) from
// useExpenseTotals, independent of the range control.
import { useEffect, useMemo, useState } from 'react';
import { useNavigate, Outlet } from 'react-router-dom';
import { ArrowDownTrayIcon, PaperClipIcon, PlusIcon } from '@heroicons/react/24/outline';
import { useExpenses, useExpenseTotals } from '@/presentation/hooks/useExpenses';
import { paymentMethodDisplayName } from '@/domain/enums';
import { PRESET_LABELS, type RangePreset } from '@/domain/reports/dateRange';
import { formatInShopZone } from '@/domain/time/shopTime';
import { useDateRangeControlState } from '@/presentation/hooks/useDateRangeControlState';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { useAuthStore } from '@/presentation/stores/authStore';
import { RoutePaths } from '@/presentation/router/routePaths';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { usePageClamp } from '@/presentation/hooks/usePageClamp';
import { usePageSize } from '@/presentation/hooks/usePageSize';
import { Button } from '@/presentation/components/ui/Button';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { MoneyCard } from '@/presentation/components/ui/MoneyCard';
import { FirstRunState, NoMatchesState } from '@/presentation/components/ui/TableEmptyStates';
import { SearchInput } from '@/presentation/components/ui/SearchInput';
import { SelectFilter } from '@/presentation/components/ui/SelectFilter';
import { DateRangeControl } from '@/presentation/components/ui/DateRangeControl';
import { TableFooter } from '@/presentation/components/ui/TableFooter';
import { toast } from '@/presentation/components/ui/toast';
import { toCsv, downloadCsv } from '@/core/utils/csv';
import { formatMoney } from '@/core/utils/money';
import { BreakdownCard } from '@/presentation/components/ui/BreakdownCard';
import type { Expense } from '@/domain/entities';

type DatePreset = Extract<RangePreset, 'today' | 'last7' | 'thisMonth'> | 'custom';

const DATE_OPTIONS: Array<{ value: DatePreset; label: string }> = [
  { value: 'today', label: 'Today' },
  { value: 'last7', label: '7 days' },
  { value: 'thisMonth', label: 'This month' },
  { value: 'custom', label: 'Custom' },
];

const dateFmt = (d: Date) => formatInShopZone(d, { month: 'short', day: 'numeric', year: 'numeric' });

// A small, fixed swatch of the app's own tokens — every category gets a
// STABLE color (hashed by name) so it never shifts as totals re-sort the
// rows, and it never needs a palette of its own.
const CATEGORY_SWATCH = [
  'var(--accent)',
  'var(--pos)',
  'var(--info)',
  'var(--accent-line)',
  'var(--neg)',
  'var(--text-3)',
];
function colorForCategory(name: string): string {
  let hash = 0;
  for (let i = 0; i < name.length; i += 1) hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  return CATEGORY_SWATCH[hash % CATEGORY_SWATCH.length];
}

export function ExpensesPage() {
  useEffect(() => {
    document.title = 'Expenses · MAKI POS Admin';
  }, []);
  const navigate = useNavigate();
  const user = useAuthStore((s) => s.user);
  const canAdd = !!user && hasPermission(user.role, Permission.addExpense);

  // Default last7 — matches the page's previous default.
  const { preset, setPreset, customStart, setCustomStart, customEnd, setCustomEnd, range } =
    useDateRangeControlState<DatePreset>('last7');
  const rangeLabel =
    preset === 'custom' && customStart && customEnd
      ? `${dateFmt(new Date(`${customStart}T00:00:00`))} – ${dateFmt(new Date(`${customEnd}T00:00:00`))}`
      : PRESET_LABELS[preset].toLowerCase();

  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = usePageSize('expenses');

  const { totals } = useExpenseTotals();
  // THE scoped array — every card and the table derive from this one fetch.
  // Category is applied on top, client-side, for the table only.
  const { expenses: scoped, isLoading, error } = useExpenses({ start: range.start, end: range.end });

  const byCategory = useMemo(() => {
    const totalsByName = new Map<string, number>();
    for (const e of scoped) totalsByName.set(e.category, (totalsByName.get(e.category) ?? 0) + e.amount);
    const grand = scoped.reduce((n, e) => n + e.amount, 0);
    return [...totalsByName.entries()]
      .sort(([, a], [, b]) => b - a)
      .map(([name, amount]) => ({
        name,
        amount,
        pct: grand > 0 ? (amount / grand) * 100 : 0,
        color: colorForCategory(name),
      }));
  }, [scoped]);

  const recorderCount = useMemo(() => new Set(scoped.map((e) => e.createdBy)).size, [scoped]);
  const largest = useMemo(
    () => (scoped.length === 0 ? null : scoped.reduce((a, b) => (b.amount > a.amount ? b : a))),
    [scoped],
  );

  const categoryOptions = useMemo(() => {
    const byName = new Map<string, number>();
    for (const e of scoped) byName.set(e.category, (byName.get(e.category) ?? 0) + 1);
    return [...byName.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([name, count]) => ({ value: name, label: name, count }));
  }, [scoped]);

  // Category dropped out of the option set (e.g. it only existed outside the
  // current range) reads as unset — a render-derived fallback, not a
  // setState reset. An effect-based reset would fire (and permanently wipe
  // the stored selection) during the loading gap between an old scoped array
  // and a new one, even when the new range still contains the category;
  // this heals back on its own the moment a scoped array that contains it
  // renders, with no transient "wiped" flash and no lost selection.
  const effectiveCategory = categoryOptions.some((c) => c.value === category) ? category : '';

  useEffect(() => {
    setPage(1);
  }, [range, effectiveCategory, search]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return scoped.filter((e) => {
      if (effectiveCategory && e.category !== effectiveCategory) return false;
      if (!q) return true;
      const haystack = [e.description, e.notes ?? '', e.category, paymentMethodDisplayName[e.paidVia]]
        .join(' ')
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [scoped, effectiveCategory, search]);

  usePageClamp(page, setPage, filtered.length, pageSize);
  const paged = useMemo(
    () => filtered.slice((page - 1) * pageSize, page * pageSize),
    [filtered, page, pageSize],
  );
  const totalShown = useMemo(() => filtered.reduce((n, e) => n + e.amount, 0), [filtered]);

  const isFiltered = effectiveCategory !== '' || search.trim() !== '';
  const clearFilters = () => {
    setCategory('');
    setSearch('');
    setPage(1);
  };

  const exportCsv = () => {
    const headers = ['Description', 'Note', 'Category', 'Paid via', 'Date', 'Amount', 'Recorded by'];
    const rows = filtered.map((e) => [
      e.description,
      e.notes ?? '',
      e.category,
      paymentMethodDisplayName[e.paidVia],
      dateFmt(e.date),
      e.amount,
      e.createdByName,
    ]);
    downloadCsv('expenses.csv', toCsv(headers, rows));
    toast.success('Export ready', `${filtered.length} rows`);
  };

  const columns: Array<Column<Expense>> = [
    {
      key: 'description', header: 'Description',
      render: (e) => (
        <div className="flex min-w-0 flex-col gap-0.5">
          <span className="flex items-center gap-1.5 text-ctl-sm font-medium tracking-[-0.1px] text-ink">
            {e.receiptImageUrl ? (
              <PaperClipIcon className="h-3 w-3 shrink-0 text-ink-3" aria-label="Has receipt" />
            ) : null}
            {e.description}
          </span>
          {e.notes ? <span className="text-[10.5px] text-ink-3">{e.notes}</span> : null}
        </div>
      ),
    },
    {
      key: 'category', header: 'Category', width: '124px',
      render: (e) => (
        <span className="whitespace-nowrap rounded-[6px] bg-surface-3 px-2 py-[3px] text-[11px] font-medium text-ink-2">
          {e.category}
        </span>
      ),
    },
    {
      key: 'paidVia', header: 'Paid via', width: '104px',
      render: (e) => <span className="text-ctl-sm text-ink-2">{paymentMethodDisplayName[e.paidVia]}</span>,
    },
    {
      key: 'date', header: 'Date', width: '150px', mono: true,
      render: (e) => (
        <div className="flex flex-col gap-0.5">
          <span className="font-mono text-[12px] text-ink-2">{dateFmt(e.date)}</span>
          <span className="text-[10.5px] text-ink-3">by {e.createdByName || '—'}</span>
        </div>
      ),
    },
    {
      key: 'amount', header: 'Amount', align: 'right', width: '132px', mono: true,
      render: (e) => <span className="text-[13px] font-semibold">{formatMoney(e.amount)}</span>,
    },
  ];

  if (error) return <ErrorView title="Could not load expenses" message={error.message} />;

  const firstRun = !isLoading && scoped.length === 0 && !isFiltered;

  return (
    <div className="flex flex-col gap-3">
      {/* Summary row — Spend · By category · Entries · Largest single */}
      <div className="grid grid-cols-[repeat(auto-fit,minmax(236px,1fr))] gap-3">
        <div className="flex flex-col gap-[11px] rounded-card border border-line bg-surface px-[17px] py-[15px] shadow-card">
          <div className="flex items-baseline gap-[9px]">
            <span className="text-[11.5px] font-medium text-ink-2">Spend</span>
          </div>
          <div className="flex flex-col gap-[7px]">
            <SpendRow label="Today" value={formatMoney(totals.today)} size="13px" />
            <SpendRow label="Last 7 days" value={formatMoney(totals.last7)} size="17px" />
            <SpendRow label="Last 30 days" value={formatMoney(totals.last30)} size="13px" />
          </div>
        </div>

        <BreakdownCard
          testId="by-category-card"
          label="By category"
          total={rangeLabel}
          bar={byCategory.map((c) => ({ key: c.name, color: c.color, pct: c.pct }))}
          emptyText="Nothing in range"
          rows={byCategory.map((c) => ({
            key: c.name,
            label: c.name,
            color: c.color,
            active: effectiveCategory === c.name,
            onClick: () => {
              setCategory(effectiveCategory === c.name ? '' : c.name);
              setPage(1);
            },
            value: (
              <>
                <span className="font-mono text-[10.5px] text-ink-3">{c.pct.toFixed(0)}%</span>
                <span className="font-mono text-[12.5px] font-semibold text-ink">{formatMoney(c.amount)}</span>
              </>
            ),
          }))}
        />

        <MoneyCard
          label="Entries"
          value={scoped.length.toLocaleString('en-PH')}
          note={`${recorderCount} ${recorderCount === 1 ? 'person' : 'people'} recording`}
        />
        <MoneyCard
          label="Largest single"
          value={largest ? formatMoney(largest.amount) : '—'}
          note={largest ? `${largest.description} · ${dateFmt(largest.date)}` : 'Nothing in range'}
        />
      </div>

      {/* Action row — date range · Add expense · Export */}
      <div className="flex flex-wrap items-center gap-2">
        <div className="ml-auto flex items-center gap-2.5">
          <DateRangeControl
            options={DATE_OPTIONS}
            value={preset}
            onChange={(p) => {
              setPreset(p);
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
          {canAdd ? (
            <Button variant="primary" icon={<PlusIcon className="h-3.5 w-3.5" />} onClick={() => navigate(RoutePaths.expenseAdd)}>
              Add expense
            </Button>
          ) : null}
          <Button
            variant="secondary"
            title="Export CSV"
            icon={<ArrowDownTrayIcon className="h-3.5 w-3.5" />}
            onClick={exportCsv}
          >
            Export CSV
          </Button>
        </div>
      </div>

      {/* Filters row */}
      <div className="flex flex-wrap items-center gap-2.5">
        <div className="w-[290px]">
          <SearchInput
            variant="bar"
            value={search}
            onChange={setSearch}
            placeholder="Search description, note, category, or paid via"
          />
        </div>
        <SelectFilter
          label="Category"
          value={effectiveCategory}
          options={categoryOptions}
          onChange={setCategory}
          allLabel="All categories"
          allTriggerLabel="All"
        />
        {isFiltered ? (
          <button type="button" onClick={clearFilters} className="border-b border-line text-[11.5px] text-ink-3 hover:text-neg">
            Clear filters
          </button>
        ) : null}
        <span className="ml-auto font-mono text-[12px] text-ink-3">
          {filtered.length.toLocaleString('en-PH')} {filtered.length === 1 ? 'entry' : 'entries'}
        </span>
      </div>

      {/* Table card */}
      <section className="overflow-hidden rounded-card border border-line bg-surface shadow-card">
        <DataTable
          columns={columns}
          rows={paged}
          rowKey={(e) => e.id}
          onRowClick={(e) => navigate(`/expenses/edit/${e.id}`)}
          loading={isLoading}
          minWidth="860px"
          foot={
            <tr className="border-t border-line bg-surface-2">
              <td colSpan={4} className="px-5 py-3 text-[12px] font-semibold text-ink-2">Total shown</td>
              <td data-testid="total-shown" className="px-5 py-3 text-right font-mono text-[15px] font-semibold text-ink">
                {formatMoney(totalShown)}
              </td>
            </tr>
          }
          empty={
            firstRun ? (
              <FirstRunState
                icon={
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--accent-text)" strokeWidth="1.6">
                    <path d="M4.5 5.5h15v13h-15z" />
                    <line x1="8" y1="10" x2="16" y2="10" />
                    <line x1="8" y1="14" x2="13" y2="14" />
                  </svg>
                }
                title="No expenses yet"
                description="Record what the shop spends — supplies, fuel, wages, rent. Anything logged here comes off the profit the register reports."
              >
                {canAdd ? (
                  <Button variant="primary" icon={<PlusIcon className="h-3.5 w-3.5" />} onClick={() => navigate(RoutePaths.expenseAdd)}>
                    Add expense
                  </Button>
                ) : null}
              </FirstRunState>
            ) : (
              <NoMatchesState
                title="No expenses match these filters"
                hint="Try another category or date range, or clear the search."
                onClear={isFiltered ? clearFilters : undefined}
              />
            )
          }
        />
        {filtered.length > 0 ? (
          <TableFooter
            total={filtered.length}
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

      {/* The add/edit modal (/expenses/add, /expenses/edit/:id) renders here, over this list. */}
      <Outlet />
    </div>
  );
}

function SpendRow({ label, value, size }: { label: string; value: string; size: '13px' | '17px' }) {
  return (
    <div className="flex items-baseline gap-2">
      <span className="text-[12px] text-ink-2">{label}</span>
      <span
        className="ml-auto font-mono font-semibold tracking-[-0.4px] text-ink"
        style={{ fontSize: size }}
      >
        {value}
      </span>
    </div>
  );
}
