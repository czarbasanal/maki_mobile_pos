// Fakes ExpenseRepository + CategoryRepository via DiProvider.override (same
// template as InventoryListPage.test.tsx). The fake `list` ignores date
// range (useExpenseTotals's three window queries + the main list query all
// go through it) but DOES respect `category`, so the category-filter test can
// pin real narrowing without a real Firestore range query.
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ExpensesPage } from './ExpensesPage';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import { formatMoney } from '@/core/utils/money';
import type { Category, Expense } from '@/domain/entities';

vi.mock('@/data/expenseReceiptStorage', () => ({
  deleteExpenseReceipt: vi.fn(),
}));
import { deleteExpenseReceipt } from '@/data/expenseReceiptStorage';

beforeEach(() => {
  vi.clearAllMocks();
});

function signIn(role: UserRole) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role, isActive: true } as never,
    status: 'signedIn',
  });
}

const expenseCategories: Category[] = [
  {
    id: 'c1',
    name: 'Transportation',
    isActive: true,
    createdAt: new Date(),
    updatedAt: null,
    createdBy: null,
    updatedBy: null,
  },
  {
    id: 'c2',
    name: 'Utilities',
    isActive: true,
    createdAt: new Date(),
    updatedAt: null,
    createdBy: null,
    updatedBy: null,
  },
];

function makeExpense(overrides: Partial<Expense> = {}): Expense {
  return {
    id: 'e1',
    description: 'Fuel',
    amount: 500,
    category: 'Transportation',
    date: new Date('2026-07-20T12:00:00.000Z'),
    paidVia: 'cash',
    notes: null,
    receiptNumber: null,
    receiptImageUrl: null,
    createdAt: new Date('2026-07-20T12:00:00.000Z'),
    updatedAt: null,
    createdBy: 'u1',
    createdByName: 'Cashier',
    updatedBy: null,
    ...overrides,
  };
}

function harness(
  list: Expense[],
  opts: { delete?: ReturnType<typeof vi.fn> } = {},
) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const expenseRepo: Partial<Container['expenseRepo']> = {
    list: vi.fn(async (filters?: { category?: string }) =>
      filters?.category ? list.filter((e) => e.category === filters.category) : list,
    ),
    delete: opts.delete ?? vi.fn().mockResolvedValue(undefined),
  };
  const categoryRepo: Partial<Container['categoryRepo']> = {
    watchAll: (kind, cb) => {
      cb(kind === 'expense' ? expenseCategories : []);
      return () => {};
    },
  };
  return render(
    <DiProvider
      override={{
        expenseRepo: expenseRepo as Container['expenseRepo'],
        categoryRepo: categoryRepo as Container['categoryRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/expenses']}>
          <ExpensesPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('ExpensesPage — totals + list', () => {
  it('renders the three totals cards and the expense list', async () => {
    signIn(UserRole.admin);
    harness([
      makeExpense({ id: 'e1', description: 'Fuel', amount: 500, category: 'Transportation' }),
      makeExpense({ id: 'e2', description: 'Electric bill', amount: 300, category: 'Utilities' }),
    ]);

    expect(await screen.findByText('Fuel')).toBeInTheDocument();
    expect(screen.getByText('Electric bill')).toBeInTheDocument();

    // 'Today' collides with a DateRangePicker preset option, so only pin the
    // two summary-card titles that are unique in the document.
    expect(screen.getByText('This Week')).toBeInTheDocument();
    expect(screen.getByText('This Month')).toBeInTheDocument();
    // The fake list() ignores the date window, so all three totals equal the
    // full unfiltered sum (500 + 300).
    expect(screen.getAllByText(formatMoney(800))).toHaveLength(3);
  });

  it('shows an empty state when there are no expenses', async () => {
    signIn(UserRole.admin);
    harness([]);
    expect(await screen.findByText('No expenses found')).toBeInTheDocument();
  });
});

describe('ExpensesPage — pagination', () => {
  const many: Expense[] = Array.from({ length: 26 }, (_, i) =>
    makeExpense({ id: `e${i + 1}`, description: `Expense ${i + 1}` }),
  );

  it('shows only 25 rows and the pager for 26 expenses, revealing the rest on page 2', async () => {
    signIn(UserRole.staff);
    harness(many);

    expect(await screen.findByText('Expense 1')).toBeInTheDocument();
    expect(screen.getByText('1–25 of 26')).toBeInTheDocument();
    expect(screen.queryByText('Expense 26')).not.toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Next' }));

    expect(await screen.findByText('Expense 26')).toBeInTheDocument();
    expect(screen.queryByText('Expense 1')).not.toBeInTheDocument();
  });
});

describe('ExpensesPage — category filter', () => {
  it('narrows the list and resets to page 1', async () => {
    signIn(UserRole.staff);
    const transportation = Array.from({ length: 30 }, (_, i) =>
      makeExpense({ id: `t${i + 1}`, description: `T${i + 1}`, category: 'Transportation' }),
    );
    const utilities = Array.from({ length: 5 }, (_, i) =>
      makeExpense({ id: `u${i + 1}`, description: `U${i + 1}`, category: 'Utilities' }),
    );
    harness([...transportation, ...utilities]);

    expect(await screen.findByText('T1')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Next' }));
    expect(await screen.findByText('U1')).toBeInTheDocument();

    await userEvent.selectOptions(screen.getByLabelText('Category'), 'Transportation');

    // Page reset to 1 — T1 is visible again, and Utilities are filtered out
    // entirely (so U1 must not appear on any page).
    expect(await screen.findByText('T1')).toBeInTheDocument();
    expect(screen.queryByText('U1')).not.toBeInTheDocument();
  });
});

describe('ExpensesPage — delete', () => {
  it('staff can now delete expenses (shop policy 2026-07-04)', async () => {
    signIn(UserRole.staff);
    const del = vi.fn().mockResolvedValue(undefined);
    harness([makeExpense({ id: 'e1', description: 'Fuel' })], { delete: del });

    expect(await screen.findByText('Fuel')).toBeInTheDocument();
    const deleteBtn = screen.getByRole('button', { name: /Delete/ });
    expect(deleteBtn).toBeInTheDocument();
  });

  it('admin can delete an expense via the confirm dialog', async () => {
    signIn(UserRole.admin);
    const del = vi.fn().mockResolvedValue(undefined);
    harness([makeExpense({ id: 'e1', description: 'Fuel' })], { delete: del });

    expect(await screen.findByText('Fuel')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /Delete/ }));

    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByText(/Fuel/)).toBeInTheDocument();

    await userEvent.click(within(dialog).getByRole('button', { name: 'Delete' }));

    expect(del).toHaveBeenCalledWith('e1');
  });

  it('deletes receipt storage when expense has receiptImageUrl', async () => {
    signIn(UserRole.admin);
    const del = vi.fn().mockResolvedValue(undefined);
    harness([makeExpense({ id: 'e1', description: 'Fuel', receiptImageUrl: 'https://x/receipt.jpg' })], { delete: del });

    expect(await screen.findByText('Fuel')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /Delete/ }));

    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Delete' }));

    expect(deleteExpenseReceipt).toHaveBeenCalledWith('e1');
  });

  it('does not call deleteExpenseReceipt when expense has no receipt', async () => {
    signIn(UserRole.admin);
    const del = vi.fn().mockResolvedValue(undefined);
    harness([makeExpense({ id: 'e1', description: 'Fuel', receiptImageUrl: null })], { delete: del });

    expect(await screen.findByText('Fuel')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /Delete/ }));

    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Delete' }));

    expect(deleteExpenseReceipt).not.toHaveBeenCalled();
  });
});
