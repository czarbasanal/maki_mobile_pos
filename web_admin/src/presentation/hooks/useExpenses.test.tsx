// useExpenses/useExpenseTotals/mutations — fakes the ExpenseRepository via
// DiProvider.override (same template as useDraft.test.tsx). The totals math
// test is the important one: it pins that {today, week, month} are three
// independent range sums over Expense.amount, with week/month using
// calendar (Monday-start week / 1st-of-month) boundaries, not rolling
// windows.
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

function wrap(expenseRepo: Partial<Container['expenseRepo']>) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return ({ children }: { children: ReactNode }) => (
    <DiProvider override={{ expenseRepo: expenseRepo as Container['expenseRepo'] }}>
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
    notes: null,
    receiptNumber: null,
    receiptImageUrl: null,
    createdAt: new Date('2026-07-10T00:00:00.000Z'),
    updatedAt: null,
    createdBy: 'actor-1',
    createdByName: 'Cashier',
    updatedBy: null,
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
  // 2026-07-15 is a Wednesday — Monday-start week is 2026-07-13..2026-07-19.
  const now = new Date('2026-07-15T12:00:00.000Z');

  it('sums today/week/month independently over Expense.amount', async () => {
    const todayExpense = makeExpense({ id: 'today', amount: 100, date: now });
    const earlierThisWeek = makeExpense({
      id: 'week',
      amount: 200,
      date: new Date('2026-07-13T08:00:00.000Z'), // Monday this week, not today
    });
    const earlierThisMonth = makeExpense({
      id: 'month',
      amount: 300,
      date: new Date('2026-07-02T08:00:00.000Z'), // this month, before this week
    });
    const lastMonth = makeExpense({
      id: 'lastmonth',
      amount: 9999,
      date: new Date('2026-06-20T08:00:00.000Z'),
    });

    // Fake repo mirrors a real range query: filter the full fixture set by
    // the [start,end] window the hook asks for.
    const all = [todayExpense, earlierThisWeek, earlierThisMonth, lastMonth];
    const list = vi.fn(
      async ({ start, end }: { start?: Date; end?: Date }) =>
        all.filter((e) => (!start || e.date >= start) && (!end || e.date <= end)),
    );

    const { result } = renderHook(() => useExpenseTotals(now), { wrapper: wrap({ list }) });
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    expect(result.current.totals).toEqual({
      today: 100,
      week: 300, // today (100) + earlierThisWeek (200)
      month: 600, // week (300) + earlierThisMonth (300)
    });
  });
});

describe('expense mutations', () => {
  it('useCreateExpense calls repo.create with the actor id + display name', async () => {
    useAuthStore.setState({
      user: { id: 'u1', displayName: 'Cashier One', email: 'c@x.com' } as never,
      status: 'signedIn',
    });
    const create = vi.fn().mockResolvedValue(makeExpense());
    const { result } = renderHook(() => useCreateExpense(), { wrapper: wrap({ create }) });

    act(() => {
      result.current.mutate({
        description: 'Fuel',
        amount: 100,
        category: 'Transportation',
        date: new Date(),
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
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it('useUpdateExpense calls repo.update with the actor id', async () => {
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
    expect(update).toHaveBeenCalledWith('e1', { amount: 500 }, 'u2');
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it('useDeleteExpense calls repo.delete', async () => {
    const del = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useDeleteExpense(), { wrapper: wrap({ delete: del }) });

    act(() => {
      result.current.mutate('e1');
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(del).toHaveBeenCalledWith('e1');
  });
});
