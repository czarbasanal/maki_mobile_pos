import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { PaperClipIcon, PlusIcon, TrashIcon } from '@heroicons/react/24/outline';
import { useDeleteExpense, useExpenses, useExpenseTotals } from '@/presentation/hooks/useExpenses';
import { useActiveCategories } from '@/presentation/hooks/useCategories';
import { CategoryKind } from '@/domain/categories/categoryKind';
import { paymentMethodDisplayName } from '@/domain/enums';
import { resolvePreset, type DateRange } from '@/domain/reports/dateRange';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { useAuthStore } from '@/presentation/stores/authStore';
import { DateRangePicker } from '@/presentation/components/common/DateRangePicker';
import { SummaryCard } from '@/presentation/features/dashboard/SummaryCard';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { Pager } from '@/presentation/components/common/Pager';
import { Dialog } from '@/presentation/components/common/Dialog';
import { formatMoney } from '@/core/utils/money';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cn } from '@/core/utils/cn';
import type { Expense } from '@/domain/entities';

const PAGE_SIZE = 25;
const dateFmt = new Intl.DateTimeFormat('en-PH', { dateStyle: 'medium' });

export function ExpensesPage() {
  useEffect(() => {
    document.title = 'Expenses · MAKI POS Admin';
  }, []);
  const navigate = useNavigate();
  const user = useAuthStore((s) => s.user);
  const canDelete = !!user && hasPermission(user.role, Permission.deleteExpense);

  const [range, setRange] = useState<DateRange>(() => resolvePreset('last7'));
  const [category, setCategory] = useState('');
  const [page, setPage] = useState(1);

  const { totals } = useExpenseTotals();
  const { data: categories } = useActiveCategories(CategoryKind.expense);
  const { expenses, isLoading, error } = useExpenses({
    start: range.start,
    end: range.end,
    category: category || undefined,
  });
  const del = useDeleteExpense();
  const [deleting, setDeleting] = useState<Expense | null>(null);

  // Filters changed — a page number from the previous result set may now
  // point past the end (or simply be stale), so snap back to page 1.
  useEffect(() => {
    setPage(1);
  }, [range, category]);

  const paged = useMemo(
    () => expenses.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE),
    [expenses, page],
  );

  const confirmDelete = async () => {
    if (!deleting) return;
    try {
      await del.mutateAsync(deleting.id);
      setDeleting(null);
    } catch {
      // Surfaced via del.error below; confirm dialog stays open.
    }
  };

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Expenses</h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Shop expenses and receipts.
          </p>
        </div>
        <button
          type="button"
          onClick={() => navigate(RoutePaths.expenseAdd)}
          className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark"
        >
          <PlusIcon className="h-3.5 w-3.5" /> Add expense
        </button>
      </header>

      <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-3">
        <SummaryCard title="Today" value={formatMoney(totals.today)} />
        <SummaryCard title="This Week" value={formatMoney(totals.week)} />
        <SummaryCard title="This Month" value={formatMoney(totals.month)} />
      </div>

      <div className="flex flex-wrap items-center gap-tk-sm">
        <DateRangePicker onChange={setRange} />
        <select
          aria-label="Category"
          value={category}
          onChange={(e) => setCategory(e.target.value)}
          className="rounded-md border border-light-border bg-light-card px-tk-sm py-tk-sm text-bodySmall text-light-text"
        >
          <option value="">All categories</option>
          {(categories ?? []).map((c) => (
            <option key={c.id} value={c.name}>
              {c.name}
            </option>
          ))}
        </select>
      </div>

      {error ? (
        <ErrorView title="Could not load expenses" message={error.message} />
      ) : isLoading ? (
        <LoadingView label="Loading expenses…" />
      ) : expenses.length === 0 ? (
        <EmptyState
          title="No expenses found"
          description="Try a different date range or category."
        />
      ) : (
        <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <table className="w-full text-bodySmall">
            <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
              <tr>
                <Th>Description</Th>
                <Th>Category</Th>
                <Th>Paid via</Th>
                <Th>Date</Th>
                <Th className="text-right">Amount</Th>
                <Th className="text-right">&nbsp;</Th>
              </tr>
            </thead>
            <tbody className="divide-y divide-light-hairline">
              {paged.map((e) => (
                <tr
                  key={e.id}
                  onClick={() => navigate(`/expenses/edit/${e.id}`)}
                  className="cursor-pointer hover:bg-light-subtle"
                >
                  <Td className="font-medium text-light-text">
                    <span className="inline-flex items-center gap-tk-xs">
                      {e.receiptImageUrl ? (
                        <PaperClipIcon
                          className="h-3.5 w-3.5 shrink-0 text-light-text-hint"
                          aria-label="Has receipt"
                        />
                      ) : null}
                      {e.description}
                    </span>
                  </Td>
                  <Td className="text-light-text-secondary">{e.category}</Td>
                  <Td className="text-light-text-secondary">{paymentMethodDisplayName[e.paidVia]}</Td>
                  <Td className="text-light-text-secondary">{dateFmt.format(e.date)}</Td>
                  <Td className="text-right text-light-text">{formatMoney(e.amount)}</Td>
                  <Td className="text-right">
                    {canDelete ? (
                      <button
                        type="button"
                        onClick={(ev) => {
                          ev.stopPropagation();
                          setDeleting(e);
                        }}
                        className="inline-flex items-center gap-1 rounded-md px-tk-sm py-[4px] text-bodySmall text-error-dark hover:bg-error-light/40"
                      >
                        <TrashIcon className="h-3.5 w-3.5" /> Delete
                      </button>
                    ) : null}
                  </Td>
                </tr>
              ))}
            </tbody>
          </table>
          <Pager total={expenses.length} page={page} onPage={setPage} pageSize={PAGE_SIZE} />
        </div>
      )}

      <Dialog
        open={deleting !== null}
        onClose={() => {
          if (!del.isPending) setDeleting(null);
        }}
        title="Delete this expense?"
        description={
          deleting ? `"${deleting.description}" will be permanently deleted.` : undefined
        }
        dismissable={!del.isPending}
      >
        {del.error ? (
          <p className="mb-tk-md text-bodySmall text-error-dark">{del.error.message}</p>
        ) : null}
        <div className="flex justify-end gap-tk-sm">
          <button
            type="button"
            onClick={() => setDeleting(null)}
            disabled={del.isPending}
            className="rounded-md px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-60"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={confirmDelete}
            disabled={del.isPending}
            className="inline-flex items-center gap-tk-xs rounded-md bg-error px-tk-md py-tk-sm text-bodySmall font-semibold text-white hover:bg-error-dark disabled:opacity-60"
          >
            {del.isPending ? <Spinner className="h-3.5 w-3.5" /> : null} Delete
          </button>
        </div>
      </Dialog>
    </div>
  );
}

function Th({ children, className }: { children: ReactNode; className?: string }) {
  return <th className={cn('px-tk-md py-tk-sm text-left font-medium', className)}>{children}</th>;
}
function Td({ children, className }: { children: ReactNode; className?: string }) {
  return <td className={cn('px-tk-md py-tk-sm', className)}>{children}</td>;
}
