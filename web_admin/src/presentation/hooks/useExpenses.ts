import { useMutation, useQuery, useQueryClient, type QueryClient } from '@tanstack/react-query';
import { endOfDay, startOfDay, startOfMonth, startOfWeek } from 'date-fns';
import { useExpenseRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Expense } from '@/domain/entities';
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
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<Expense, Error, CreateExpenseInput>({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      const actorName = actor.displayName.trim() || actor.email;
      return repo.create(
        { ...input, createdBy: actor.id, createdByName: actorName },
        actor.id,
        actorName,
      );
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
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, UpdateExpenseInput>({
    mutationFn: async ({ id, patch }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.update(id, patch, actor.id);
    },
    onSuccess: () => invalidateExpenses(qc),
  });
}

export function useDeleteExpense() {
  const repo = useExpenseRepo();
  const qc = useQueryClient();
  return useMutation<void, Error, string>({
    mutationFn: async (id) => {
      await repo.delete(id);
    },
    onSuccess: () => invalidateExpenses(qc),
  });
}
