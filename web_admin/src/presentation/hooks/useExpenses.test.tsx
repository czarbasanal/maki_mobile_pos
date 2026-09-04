// useExpenses/useExpenseTotals/mutations — fakes the ExpenseRepository via
// DiProvider.override (same template as useJobOrder.test.tsx). The totals math
// test is the important one: it pins that {today, last7, last30} are three
// independent range sums over Expense.amount, each a ROLLING shop-day window
// ending today (resolvePreset('today'|'last7'|'last30')) — not calendar
// week/month boundaries (Expenses redesign guide §2's Spend-card exception).
import { describe, expect, it, vi } from 'vitest';
import { act, renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import {
  useCreateExpense,
  useDeleteExpense,
  useExpenses,
  useExpenseTotals,
  useUpdateExpense,
} from './useExpenses';
import type { Expense } from '@/domain/entities';
import type { ReactNode } from 'react';

function wrap(
  expenseRepo: Partial<Container['expenseRepo']>,
  activityLog: ReturnType<typeof vi.fn> = vi.fn().mockResolvedValue(undefined),
) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const activityLogRepo = { log: activityLog } as unknown as Container['activityLogRepo'];
  return ({ children }: { children: ReactNode }) => (
    <DiProvider override={{ expenseRepo: expenseRepo as Container['expenseRepo'], activityLogRepo }}>
      <QueryClientProvider client={qc}>{children}</QueryClientProvider>
    </DiProvider>
  );
}

function makeExpense(overrides: Partial<Expense> = {}): Expense {
  return {
    id: 'e1',
    description: 'Fuel',
    amount: 100,
    category: 'Transportation',
    date: new Date('2026-07-10T00:00:00.000Z'),
    paidVia: 'cash',
    notes: null,
    receiptNumber: null,
    receiptImageUrl: null,
    createdAt: new Date('2026-07-10T00:00:00.000Z'),
    updatedAt: null,
    createdBy: 'actor-1',
    createdByName: 'Cashier',
    updatedBy: null,
    updatedByName: null,
    ...overrides,
  };
}

describe('useExpenses', () => {
  it('lists expenses via repo.list(filters)', async () => {
    const list = vi.fn().mockResolvedValue([makeExpense()]);
    const { result } = renderHook(
      () => useExpenses({ start: new Date('2026-07-01'), end: new Date('2026-07-31') }),
      { wrapper: wrap({ list }) },
    );
    await waitFor(() => expect(result.current.isLoading).toBe(false));
    expect(result.current.expenses).toHaveLength(1);
    expect(list).toHaveBeenCalledWith({
      start: new Date('2026-07-01'),
      end: new Date('2026-07-31'),
    });
  });
});

describe('useExpenseTotals', () => {
  // Shop offset defaults to Asia/Manila (UTC+8) — noon UTC is still Jul 15
  // shop-side, so this stays clear of any day-boundary edge case.
  const now = new Date('2026-07-15T12:00:00.000Z');

  it('sums today/last7/last30 independently over Expense.amount, each a rolling window ending today', async () => {
    const todayExpense = makeExpense({ id: 'today', amount: 100, date: now });
    // 5 days back — inside last7 (and last30), outside today.
    const withinLast7 = makeExpense({
      id: 'w7',
      amount: 200,
      date: new Date('2026-07-10T00:00:00.000Z'),
    });
    // ~25 days back — outside last7's window (only reaches back 6 days), inside last30.
    const outside7within30 = makeExpense({
      id: 'w30',
      amount: 300,
      date: new Date('2026-06-20T00:00:00.000Z'),
    });
    // ~75 days back — outside every window.
    const outsideAll = makeExpense({
      id: 'old',
      amount: 9999,
      date: new Date('2026-05-01T00:00:00.000Z'),
    });

    // Fake repo mirrors a real range query: filter the full fixture set by
    // the [start,end] window the hook asks for.
    const all = [todayExpense, withinLast7, outside7within30, outsideAll];
    const list = vi.fn(
      async ({ start, end }: { start?: Date; end?: Date }) =>
        all.filter((e) => (!start || e.date >= start) && (!end || e.date <= end)),
    );

    const { result } = renderHook(() => useExpenseTotals(now), { wrapper: wrap({ list }) });
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    expect(result.current.totals).toEqual({
      today: 100,
      last7: 300, // todayExpense (100) + withinLast7 (200)
      last30: 600, // last7 (300) + outside7within30 (300)
    });
  });
});

describe('expense mutations', () => {
  it('useCreateExpense calls repo.create with the actor id + display name, and logs an expense activity (task-10 representative case)', async () => {
    useAuthStore.setState({
      user: { id: 'u1', displayName: 'Cashier One', email: 'c@x.com', role: 'cashier' } as never,
      status: 'signedIn',
    });
    const create = vi.fn().mockResolvedValue(makeExpense());
    const log = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useCreateExpense(), { wrapper: wrap({ create }, log) });

    act(() => {
      result.current.mutate({
        description: 'Fuel',
        amount: 100,
        category: 'Transportation',
        date: new Date(),
        paidVia: 'cash',
        notes: null,
        receiptNumber: null,
        receiptImageUrl: null,
      });
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(create).toHaveBeenCalledWith(
      expect.objectContaining({ description: 'Fuel' }),
      'u1',
      'Cashier One',
    );
    expect(log).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'expense',
        action: 'Created expense: Fuel',
        entityType: 'expense',
        userId: 'u1',
      }),
    );
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it('useUpdateExpense calls repo.update with the actor id and display name (Record history\'s updatedByName)', async () => {
    useAuthStore.setState({
      user: { id: 'u2', displayName: 'Staff', email: 's@x.com' } as never,
      status: 'signedIn',
    });
    const update = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useUpdateExpense(), { wrapper: wrap({ update }) });

    act(() => {
      result.current.mutate({ id: 'e1', patch: { amount: 500 } });
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(update).toHaveBeenCalledWith('e1', { amount: 500 }, 'u2', 'Staff');
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it("useUpdateExpense falls back to the actor's email when displayName is blank", async () => {
    useAuthStore.setState({
      user: { id: 'u3', displayName: '  ', email: 'blank@x.com' } as never,
      status: 'signedIn',
    });
    const update = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useUpdateExpense(), { wrapper: wrap({ update }) });

    act(() => {
      result.current.mutate({ id: 'e1', patch: { amount: 500 } });
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(update).toHaveBeenCalledWith('e1', { amount: 500 }, 'u3', 'blank@x.com');
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it('useUpdateExpense logs null metadata for a description-only patch (no undefined keys — addDoc rejects them)', async () => {
    useAuthStore.setState({
      user: { id: 'u2', displayName: 'Staff', email: 's@x.com' } as never,
      status: 'signedIn',
    });
    const update = vi.fn().mockResolvedValue(undefined);
    const log = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useUpdateExpense(), { wrapper: wrap({ update }, log) });

    act(() => {
      result.current.mutate({ id: 'e1', patch: { description: 'Renamed' } });
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(log).toHaveBeenCalledWith(expect.objectContaining({ metadata: null }));
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it('useDeleteExpense calls repo.delete with the id', async () => {
    const del = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useDeleteExpense(), { wrapper: wrap({ delete: del }) });

    act(() => {
      result.current.mutate({ id: 'e1', description: 'Fuel', category: 'Transportation', amount: 100 });
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(del).toHaveBeenCalledWith('e1');
  });
});
