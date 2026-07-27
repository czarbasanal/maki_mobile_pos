import { useMutation, useQuery, useQueryClient, type QueryClient } from '@tanstack/react-query';
import { endOfDay, startOfDay, startOfMonth, startOfWeek } from 'date-fns';
import { useActivityLogRepo, useExpenseRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivity } from '@/application/activityLogger';
import { ActivityType, type Expense } from '@/domain/entities';
import type { ExpenseCreateInput, ExpenseListFilters } from '@/domain/repositories/ExpenseRepository';

function invalidateExpenses(qc: QueryClient) {
  qc.invalidateQueries({ queryKey: ['expenses'] });
}

export interface ExpensesResult {
  expenses: Expense[];
  isLoading: boolean;
  error: Error | null;
}

/** One-shot read of a single expense by id — disabled until an id is supplied
 *  (mirrors useProduct). Backs the edit form's prefill. */
export function useExpense(id: string | undefined) {
  const repo = useExpenseRepo();
  return useQuery<Expense | null>({
    queryKey: ['expenses', 'byId', id],
    queryFn: () => repo.getById(id as string),
    enabled: !!id,
  });
}

/** List query — range + optional category filter, per ExpenseRepository.list. */
export function useExpenses(filters: ExpenseListFilters = {}): ExpensesResult {
  const repo = useExpenseRepo();
  const query = useQuery({
    queryKey: [
      'expenses',
      'list',
      filters.start?.getTime(),
      filters.end?.getTime(),
      filters.category,
    ],
    queryFn: () => repo.list(filters),
  });

  return {
    expenses: query.data ?? [],
    isLoading: query.isLoading,
    error: (query.error as Error) ?? null,
  };
}

export interface ExpenseTotals {
  today: number;
  week: number;
  month: number;
}

export interface ExpenseTotalsResult {
  totals: ExpenseTotals;
  isLoading: boolean;
  error: Error | null;
}

const ZERO_TOTALS: ExpenseTotals = { today: 0, week: 0, month: 0 };

function sumAmount(expenses: Expense[]): number {
  return expenses.reduce((total, e) => total + e.amount, 0);
}

/**
 * Today / this-(Monday-start)-week / this-calendar-month expense sums, each
 * an independent range query ending at `now` — mirrors the mobile
 * expenses_screen.dart's startOfWeek/startOfMonth extensions (calendar
 * boundaries, not rolling 7/30-day windows).
 */
export function useExpenseTotals(now: Date = new Date()): ExpenseTotalsResult {
  const repo = useExpenseRepo();
  const end = endOfDay(now);
  const query = useQuery({
    queryKey: ['expenses', 'totals', startOfDay(now).getTime()],
    queryFn: async () => {
      const [today, week, month] = await Promise.all([
        repo.list({ start: startOfDay(now), end }),
        repo.list({ start: startOfWeek(now, { weekStartsOn: 1 }), end }),
        repo.list({ start: startOfMonth(now), end }),
      ]);
      return {
        today: sumAmount(today),
        week: sumAmount(week),
        month: sumAmount(month),
      } satisfies ExpenseTotals;
    },
  });

  return {
    totals: query.data ?? ZERO_TOTALS,
    isLoading: query.isLoading,
    error: (query.error as Error) ?? null,
  };
}

/** What the create form actually supplies — createdBy/createdByName are
 *  filled in from the signed-in actor, not the caller. */
export type CreateExpenseInput = Omit<
  ExpenseCreateInput,
  'createdBy' | 'createdByName'
>;

export function useCreateExpense() {
  const repo = useExpenseRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<Expense, Error, CreateExpenseInput>({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      const actorName = actor.displayName.trim() || actor.email;
      const created = await repo.create(
        { ...input, createdBy: actor.id, createdByName: actorName },
        actor.id,
        actorName,
      );
      logActivity(activityLogRepo, () => ({
        type: ActivityType.expense,
        action: `Created expense: ${created.description}`,
        details: `${created.category} • ₱${created.amount.toFixed(2)}`,
        entityId: created.id,
        entityType: 'expense',
        metadata: { amount: created.amount, category: created.category },
      }));
      return created;
    },
    onSuccess: () => invalidateExpenses(qc),
  });
}

export interface UpdateExpenseInput {
  id: string;
  patch: Partial<Omit<Expense, 'id' | 'createdAt' | 'createdBy' | 'createdByName'>>;
}

export function useUpdateExpense() {
  const repo = useExpenseRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, UpdateExpenseInput>({
    mutationFn: async ({ id, patch }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.update(id, patch, actor.id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.expense,
        action: `Updated expense${patch.description ? `: ${patch.description}` : ` ${id}`}`,
        details:
          patch.category !== undefined || patch.amount !== undefined
            ? `${patch.category ?? ''}${patch.amount !== undefined ? ` • ₱${patch.amount.toFixed(2)}` : ''}`.trim()
            : null,
        entityId: id,
        entityType: 'expense',
        // Only defined keys — addDoc rejects undefined values, and the
        // rejection would be swallowed (entry silently dropped).
        metadata:
          patch.amount !== undefined || patch.category !== undefined
            ? {
                ...(patch.amount !== undefined ? { amount: patch.amount } : {}),
                ...(patch.category !== undefined ? { category: patch.category } : {}),
              }
            : null,
      }));
    },
    onSuccess: () => invalidateExpenses(qc),
  });
}

export interface DeleteExpenseInput {
  id: string;
  // Caller already has the full row loaded (list/detail view) — passed
  // through rather than re-fetched, so the log can carry the same
  // "Deleted expense: {description}" wording the mobile use case emits.
  description: string;
  category: string;
  amount: number;
}

export function useDeleteExpense() {
  const repo = useExpenseRepo();
  const activityLogRepo = useActivityLogRepo();
  const qc = useQueryClient();
  return useMutation<void, Error, DeleteExpenseInput>({
    mutationFn: async ({ id, description, category, amount }) => {
      await repo.delete(id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.expense,
        action: `Deleted expense: ${description}`,
        details: `${category} • ₱${amount.toFixed(2)}`,
        entityId: id,
        entityType: 'expense',
        metadata: { amount, category },
      }));
    },
    onSuccess: () => invalidateExpenses(qc),
  });
}
