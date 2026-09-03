// Suppliers — per design/maki-pos-suppliers-redesign, assembled from the
// shared library. Status became the saved-view strip (only genuinely
// inactive rows carry a badge), the dead per-supplier inventory value became
// Parts + Spend 90d (what you actually buy), per-row actions are gone (rows
// open the supplier; deactivation lives there), and the summary band answers
// who am I buying from, on what terms, and whose details are missing.
//
// The card rows and the view chips derive from ONE inView predicate — the
// counts-disagree trap (guide §2) — and a clickable stat filters to exactly
// its own number.
import { useEffect, useMemo, useState } from 'react';
import { Outlet, useNavigate } from 'react-router-dom';
import { PlusIcon } from '@heroicons/react/24/outline';
import { useSuppliers } from '@/presentation/hooks/useSuppliers';
import { useProducts } from '@/presentation/hooks/useProducts';
import { useReceivings } from '@/presentation/hooks/useReceivings';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { RoutePaths } from '@/presentation/router/routePaths';
import { TransactionType, transactionTypeDisplayName } from '@/domain/enums';
import type { Supplier } from '@/domain/entities';
import { formatMoney } from '@/core/utils/money';
import { formatInShopZone } from '@/domain/time/shopTime';
import { resolvePreset } from '@/domain/reports/dateRange';
import { useAuthStore } from '@/presentation/stores/authStore';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { usePageClamp } from '@/presentation/hooks/usePageClamp';
import { usePageSize } from '@/presentation/hooks/usePageSize';
import { Badge, type Tone } from '@/presentation/components/ui/Badge';
import { BreakdownCard } from '@/presentation/components/ui/BreakdownCard';
import { Button } from '@/presentation/components/ui/Button';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { MoneyCard } from '@/presentation/components/ui/MoneyCard';
import { SearchInput } from '@/presentation/components/ui/SearchInput';
import { SelectFilter } from '@/presentation/components/ui/SelectFilter';
import { FirstRunState, NoMatchesState } from '@/presentation/components/ui/TableEmptyStates';
import { TableFooter } from '@/presentation/components/ui/TableFooter';
import { ViewChips } from '@/presentation/components/ui/ViewChips';

type View = 'active' | 'inactive' | 'never' | 'all';

// Terms change how you buy, so the chip is color-coded — one shared map.
const TERMS_TONE: Record<TransactionType, Tone> = {
  [TransactionType.cash]: 'positive',
  [TransactionType.terms30d]: 'info',
  [TransactionType.terms45d]: 'info',
  [TransactionType.terms60d]: 'warning',
  [TransactionType.terms90d]: 'warning',
  [TransactionType.notApplicable]: 'neutral',
};

// Decorative initials-mark palette, cycled by row index — never derive
// meaning from the color (guide §3).
const MARKS = [
  { bg: 'var(--accent-soft)', fg: 'var(--accent-text)' },
  { bg: 'var(--info-soft)', fg: 'var(--info)' },
  { bg: 'var(--pos-soft)', fg: 'var(--pos)' },
  { bg: 'var(--surface-3)', fg: 'var(--text-2)' },
];

function initialsOf(name: string): string {
  const parts = name.split(/\s+/).filter((w) => /[A-Za-z]/.test(w));
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

const DAY_MS = 24 * 60 * 60 * 1000;

export function SuppliersListPage() {
  const navigate = useNavigate();
  const { data: suppliers, isLoading, error } = useSuppliers();
  const { data: products } = useProducts();
  // One all-time receipts subscription feeds BOTH derived columns: "never
  // received" must mean never EVER (a 90-day fetch would misclassify a
  // supplier last seen 100 days ago), and Spend 90d filters the same set.
  const receiptsRange = useMemo(
    () => ({ start: new Date(2020, 0, 1), end: resolvePreset('today').end }),
    [],
  );
  const { data: receivings } = useReceivings(receiptsRange);

  const [view, setView] = useState<View>('active');
  const [search, setSearch] = useState('');
  const [terms, setTerms] = useState('');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = usePageSize('suppliers');

  useEffect(() => {
    document.title = 'Suppliers · MAKI POS Admin';
  }, []);
  useEffect(() => {
    setPage(1);
  }, [view, search, terms]);

  const partCountById = useMemo(() => {
    const m = new Map<string, number>();
    for (const p of products ?? []) {
      if (p.supplierId && p.isActive) m.set(p.supplierId, (m.get(p.supplierId) ?? 0) + 1);
    }
    return m;
  }, [products]);

  const { lastReceivedById, spend90dById } = useMemo(() => {
    const last = new Map<string, Date>();
    const spend = new Map<string, number>();
    const cutoff = Date.now() - 90 * DAY_MS;
    for (const r of receivings ?? []) {
      if (r.status !== 'completed' || !r.supplierId) continue;
      const when = r.completedAt ?? r.createdAt;
      const prev = last.get(r.supplierId);
      if (!prev || when > prev) last.set(r.supplierId, when);
      if (when.getTime() >= cutoff) {
        spend.set(r.supplierId, (spend.get(r.supplierId) ?? 0) + r.totalCost);
      }
    }
    return { lastReceivedById: last, spend90dById: spend };
  }, [receivings]);

  // ONE predicate drives the card rows, the chips, and the table.
  const inView = (s: Supplier, v: View): boolean => {
    switch (v) {
      case 'active':
        return s.isActive;
      case 'inactive':
        return !s.isActive;
      case 'never':
        // An active supplier you have never actually bought from — a task.
        // Inactive ones are deliberately excluded: they are not a task.
        return s.isActive && !lastReceivedById.has(s.id);
      case 'all':
        return true;
    }
  };

  const all = useMemo(() => suppliers ?? [], [suppliers]);

  const matchesSearch = (s: Supplier, q: string) =>
    !q ||
    s.name.toLowerCase().includes(q) ||
    (s.contactPerson?.toLowerCase().includes(q) ?? false) ||
    (s.email?.toLowerCase().includes(q) ?? false) ||
    (s.contactNumber?.includes(q) ?? false);

  const q = search.trim().toLowerCase();
  // Counts respect search (and the OTHER filter) but never the one they drive.
  const statusScope = useMemo(
    () =>
      all.filter((s) => matchesSearch(s, q) && (!terms || s.transactionType === terms)),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [all, q, terms],
  );
  const viewCounts = useMemo(
    () => ({
      active: statusScope.filter((s) => inView(s, 'active')).length,
      inactive: statusScope.filter((s) => inView(s, 'inactive')).length,
      never: statusScope.filter((s) => inView(s, 'never')).length,
      all: statusScope.length,
    }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [statusScope, lastReceivedById],
  );

  const termsOptions = useMemo(() => {
    const base = all.filter((s) => matchesSearch(s, q));
    const byType = new Map<string, number>();
    for (const s of base) byType.set(s.transactionType, (byType.get(s.transactionType) ?? 0) + 1);
    return Object.values(TransactionType)
      .filter((t) => byType.has(t))
      .map((t) => ({ value: t, label: transactionTypeDisplayName[t], count: byType.get(t)! }));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [all, q]);

  const rows = useMemo(
    () => statusScope.filter((s) => inView(s, view)),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [statusScope, view, lastReceivedById],
  );
  usePageClamp(page, setPage, rows.length, pageSize);
  const paged = useMemo(
    () => rows.slice((page - 1) * pageSize, page * pageSize),
    [rows, page, pageSize],
  );
  const markIndexById = useMemo(
    () => new Map(paged.map((s, i) => [s.id, i % MARKS.length])),
    [paged],
  );

  // Summary band — whole directory, never moved by the filters below it.
  const active = useMemo(() => all.filter((s) => s.isActive), [all]);
  const spend90Total = [...spend90dById.values()].reduce((n, v) => n + v, 0);
  const onTerms = active.filter(
    (s) =>
      s.transactionType !== TransactionType.cash &&
      s.transactionType !== TransactionType.notApplicable,
  ).length;
  const missingContact = active.filter((s) => !s.contactPerson && !s.contactNumber).length;

  const user = useAuthStore((s) => s.user);
  const canAdd = !!user && hasPermission(user.role, Permission.addSupplier);

  const isFiltered = view !== 'active' || terms !== '' || search.trim() !== '';
  const clearFilters = () => {
    setView('active');
    setTerms('');
    setSearch('');
    setPage(1);
  };

  const pickView = (v: View) => {
    setView((cur) => (cur === v ? 'all' : v));
    setPage(1);
  };

  const columns: Array<Column<Supplier>> = [
    {
      key: 'supplier', header: 'Supplier',
      render: (s) => {
        const mark = MARKS[markIndexById.get(s.id) ?? 0];
        return (
          <div className="flex min-w-0 items-center gap-3">
            <div
              aria-hidden
              className="flex h-8 w-8 shrink-0 items-center justify-center rounded-[9px] font-mono text-[11.5px] font-semibold"
              style={
                s.isActive
                  ? { background: mark.bg, color: mark.fg }
                  : { background: 'var(--surface-3)', color: 'var(--text-3)' }
              }
            >
              {initialsOf(s.name)}
            </div>
            <div className="flex min-w-0 flex-col gap-[2px]">
              <span className="flex items-center gap-1.5 text-ctl-sm font-medium text-ink">
                {s.name}
                {!s.isActive ? <Badge tone="neutral">Inactive</Badge> : null}
              </span>
              {s.address ? (
                <span className="text-[10.5px] text-ink-3">{s.address}</span>
              ) : null}
            </div>
          </div>
        );
      },
    },
    {
      key: 'contact', header: 'Contact',
      render: (s) =>
        s.contactPerson || s.contactNumber ? (
          <span className="flex flex-col gap-[2px]">
            <span className="text-ctl-sm text-ink">{s.contactPerson ?? '—'}</span>
            {s.contactNumber ? (
              <span className="flex items-center gap-1 font-mono text-[10.5px] text-ink-2">
                {s.contactNumber}
                <CopyButton value={s.contactNumber} label="phone number" />
              </span>
            ) : null}
          </span>
        ) : (
          // A state someone can act on, not missing data.
          <span className="text-ink-3">No contact</span>
        ),
    },
    {
      key: 'terms', header: 'Terms',
      render: (s) => (
        <Badge tone={TERMS_TONE[s.transactionType]} shape="tag">
          {transactionTypeDisplayName[s.transactionType]}
        </Badge>
      ),
    },
    {
      key: 'parts', header: 'Parts', align: 'right', width: '78px', mono: true,
      render: (s) => {
        const n = partCountById.get(s.id) ?? 0;
        return n > 0 ? (
          <span className="text-ctl-sm font-semibold">{n}</span>
        ) : (
          <span className="text-ink-3">—</span>
        );
      },
    },
    {
      key: 'last', header: 'Last received', width: '112px', mono: true,
      render: (s) => {
        const when = lastReceivedById.get(s.id);
        return when ? (
          <span className="text-micro text-ink-2">
            {formatInShopZone(when, { month: 'short', day: 'numeric', year: 'numeric' })}
          </span>
        ) : (
          <span className="text-ink-3">Never</span>
        );
      },
    },
    {
      key: 'spend', header: 'Spend 90d', align: 'right', width: '118px', mono: true,
      render: (s) => {
        const v = spend90dById.get(s.id) ?? 0;
        return v > 0 ? (
          <span className="text-[13px] font-semibold tracking-[-0.3px]">{formatMoney(v)}</span>
        ) : (
          <span className="text-ink-3">—</span>
        );
      },
    },
  ];

  if (error) return <ErrorView title="Could not load suppliers" message={error.message} />;

  const firstRun = !isLoading && all.length === 0;

  return (
    <div className="flex flex-col gap-3">
      {/* Summary row — Directory card + stat cards */}
      <div className="grid grid-cols-[repeat(auto-fit,minmax(236px,1fr))] gap-3">
        <BreakdownCard
          label="Directory"
          total={`${all.length} ${all.length === 1 ? 'supplier' : 'suppliers'}`}
          rows={[
            {
              key: 'active', label: 'Active', color: 'var(--pos)',
              count: viewCounts.active, active: view === 'active',
              onClick: () => pickView('active'),
            },
            {
              key: 'inactive', label: 'Inactive', color: 'var(--text-3)',
              count: viewCounts.inactive, active: view === 'inactive',
              onClick: () => pickView('inactive'),
            },
            {
              key: 'never', label: 'Never received', color: 'var(--accent)',
              count: viewCounts.never, active: view === 'never',
              onClick: () => pickView('never'),
            },
          ]}
        />
        <MoneyCard
          label="Spend, last 90 days"
          value={formatMoney(spend90Total)}
          note="completed supplier receipts only"
        />
        <MoneyCard
          label="Buying on terms"
          value={String(onTerms)}
          note={`of ${active.length} active ${active.length === 1 ? 'supplier' : 'suppliers'}`}
        />
        <MoneyCard
          label="Missing contact"
          value={String(missingContact)}
          note="no name or number on file"
        />
      </div>

      {/* Views row */}
      <div className="flex flex-wrap items-center gap-2">
        <ViewChips
          options={[
            { value: 'active' as const, label: 'Active', count: viewCounts.active },
            { value: 'inactive' as const, label: 'Inactive', count: viewCounts.inactive },
            { value: 'never' as const, label: 'Never received', count: viewCounts.never },
            { value: 'all' as const, label: 'All', count: viewCounts.all },
          ]}
          value={view}
          onChange={(v) => {
            setView(v);
            setPage(1);
          }}
        />
        {canAdd ? (
          <div className="ml-auto">
            <Button
              variant="primary"
              icon={<PlusIcon className="h-3.5 w-3.5" />}
              onClick={() => navigate(RoutePaths.supplierAdd)}
            >
              Add supplier
            </Button>
          </div>
        ) : null}
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
            placeholder="Search name, contact, or phone"
          />
        </div>
        <SelectFilter
          label="Terms"
          value={terms}
          options={termsOptions}
          onChange={(v) => {
            setTerms(v);
            setPage(1);
          }}
          allLabel="All terms"
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
          {rows.length} {rows.length === 1 ? 'supplier' : 'suppliers'}
        </span>
      </div>

      {/* Table card */}
      <section className="overflow-hidden rounded-card border border-line bg-surface shadow-card">
        <DataTable
          columns={columns}
          rows={paged}
          rowKey={(s) => s.id}
          onRowClick={(s) => navigate(RoutePaths.supplierEdit.replace(':id', s.id))}
          loading={isLoading}
          minWidth="940px"
          rowClassName={(s) => (s.isActive ? undefined : 'opacity-60')}
          empty={
            firstRun ? (
              <FirstRunState
                icon={
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--accent-text)" strokeWidth="1.6">
                    <path d="M4 9.5 5.4 4h13.2L20 9.5" />
                    <path d="M4.8 9.5h14.4v10h-14.4z" />
                    <path d="M9.4 19.5v-5.4h5.2v5.4" />
                  </svg>
                }
                title="No suppliers yet"
                description="Once a supplier exists you can tag it on a purchase order line and on every receipt."
              >
                {canAdd ? (
                  <Button
                    variant="primary"
                    icon={<PlusIcon className="h-3.5 w-3.5" />}
                    onClick={() => navigate(RoutePaths.supplierAdd)}
                  >
                    Add supplier
                  </Button>
                ) : null}
              </FirstRunState>
            ) : (
              <NoMatchesState
                title="No suppliers match these filters"
                hint="Try another view or terms, or clear the search."
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

      {/* The add/edit supplier modal (/suppliers/add, /suppliers/edit/:id)
          renders here, over the directory. */}
      <Outlet />
    </div>
  );
}
