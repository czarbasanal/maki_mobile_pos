// Rebuild per design/maki-pos-expenses-redesign — fakes ExpenseRepository via
// DiProvider.override (same template as InventoryListPage.test.tsx). The
// list page's characteristic bug (guide §2, "twice broken"): the By-category
// card and the table foot must derive from the SAME scoped (date-ranged)
// array — a category filter narrows the table but must NOT shrink the card.
// Dates are relative to the real clock (JobOrdersPage.test.tsx's idiom) so
// the default `last7` range window doesn't need a fake clock, with enough
// margin around each preset boundary to stay clear of flakiness.
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ExpensesPage } from './ExpensesPage';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import { formatMoney } from '@/core/utils/money';
import type { Expense } from '@/domain/entities';

function signIn(role: UserRole = UserRole.admin) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role, isActive: true } as never,
    status: 'signedIn',
  });
}

const daysAgo = (n: number) => new Date(Date.now() - n * 86_400_000);

function makeExpense(overrides: Partial<Expense> = {}): Expense {
  return {
    id: 'e1',
    description: 'Fuel',
    amount: 500,
    category: 'Transportation',
    date: daysAgo(0),
    paidVia: 'cash',
    notes: null,
    receiptNumber: null,
    receiptImageUrl: null,
    createdAt: daysAgo(0),
    updatedAt: null,
    createdBy: 'u1',
    createdByName: 'Cashier',
    updatedBy: null,
    updatedByName: null,
    ...overrides,
  };
}

function harness(all: Expense[]) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const expenseRepo: Partial<Container['expenseRepo']> = {
    // Mirrors FirestoreExpenseRepository.list's range filter — ExpensesPage
    // never passes `category` to this call (that filter is client-side, on
    // top of the ONE scoped array), so this fake doesn't need to honor it.
    list: vi.fn(async (filters?: { start?: Date; end?: Date }) =>
      all.filter(
        (e) => (!filters?.start || e.date >= filters.start) && (!filters?.end || e.date <= filters.end),
      ),
    ),
  };
  return render(
    <DiProvider override={{ expenseRepo: expenseRepo as Container['expenseRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/expenses']}>
          <Routes>
            <Route path="/expenses" element={<ExpensesPage />} />
            <Route path="/expenses/edit/:id" element={<div>EDIT EXPENSE</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('ExpensesPage — one scoped array feeds every card (guide §2)', () => {
  it('the By-category rows sum to the same total the table foot reports', async () => {
    signIn();
    harness([
      makeExpense({ id: 'e1', description: 'Fuel', amount: 500, category: 'Transportation', date: daysAgo(0) }),
      makeExpense({ id: 'e2', description: 'Electric bill', amount: 300, category: 'Utilities', date: daysAgo(2) }),
      makeExpense({ id: 'e3', description: 'Wages payout', amount: 1200, category: 'Wages', date: daysAgo(4) }),
      // Well outside the default last-7-days scope.
      makeExpense({ id: 'e4', description: 'Old rent', amount: 9999, category: 'Rent', date: daysAgo(40) }),
    ]);

    expect(await screen.findByText('Fuel')).toBeInTheDocument();
    expect(screen.queryByText('Old rent')).not.toBeInTheDocument();

    const byCategoryCard = within(screen.getByTestId('by-category-card'));
    expect(byCategoryCard.getByText('Transportation')).toBeInTheDocument();
    expect(byCategoryCard.getByText('Utilities')).toBeInTheDocument();
    expect(byCategoryCard.getByText('Wages')).toBeInTheDocument();
    expect(byCategoryCard.queryByText('Rent')).not.toBeInTheDocument();

    // 500 + 300 + 1200 — the table foot and the card must agree.
    expect(screen.getByText('Total shown')).toBeInTheDocument();
    expect(screen.getByTestId('total-shown')).toHaveTextContent(formatMoney(2000));

    // THE literal invariant (guide §2, "twice broken"): parse each rendered
    // By-category row amount and the Total-shown figure, and assert their
    // sums are equal — not just that both happen to render the same
    // formatted-money string somewhere on the page.
    const parseMoney = (text: string) => Number(text.replace(/[₱,]/g, ''));
    const rowAmounts = byCategoryCard.getAllByText(/^₱/).map((el) => parseMoney(el.textContent ?? ''));
    const rowSum = rowAmounts.reduce((a, b) => a + b, 0);
    const totalShown = parseMoney(screen.getByTestId('total-shown').textContent ?? '');
    expect(rowSum).toBe(2000);
    expect(rowSum).toBe(totalShown);
  });

  it('the By-category card stays fixed to the scoped range when a category filter narrows the table', async () => {
    signIn();
    harness([
      makeExpense({ id: 'e1', description: 'Fuel', amount: 500, category: 'Transportation', date: daysAgo(0) }),
      makeExpense({ id: 'e2', description: 'Electric bill', amount: 300, category: 'Utilities', date: daysAgo(1) }),
    ]);
    expect(await screen.findByText('Fuel')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: /Category/ }));
    await userEvent.click(screen.getByRole('option', { name: /Transportation/ }));
    expect(screen.queryByText('Electric bill')).not.toBeInTheDocument();

    // The card still shows BOTH categories at their full, un-narrowed amounts.
    const byCategoryCard = within(screen.getByTestId('by-category-card'));
    expect(byCategoryCard.getByText('Utilities')).toBeInTheDocument();
    expect(byCategoryCard.getByText(formatMoney(300))).toBeInTheDocument();
    expect(byCategoryCard.getByText(formatMoney(500))).toBeInTheDocument();
  });
});

describe('ExpensesPage — filters', () => {
  it('clicking a category row in the By-category card filters the table, and clicking again clears it', async () => {
    signIn();
    harness([
      makeExpense({ id: 'e1', description: 'Fuel', amount: 500, category: 'Transportation', date: daysAgo(0) }),
      makeExpense({ id: 'e2', description: 'Electric bill', amount: 300, category: 'Utilities', date: daysAgo(1) }),
    ]);
    expect(await screen.findByText('Fuel')).toBeInTheDocument();

    const categoryRow = within(screen.getByTestId('by-category-card')).getByRole('button', {
      name: /Transportation/,
    });
    await userEvent.click(categoryRow);
    expect(screen.getByText('Fuel')).toBeInTheDocument();
    expect(screen.queryByText('Electric bill')).not.toBeInTheDocument();

    await userEvent.click(categoryRow);
    expect(screen.getByText('Electric bill')).toBeInTheDocument();
  });

  it('search narrows by note, and Clear filters resets it', async () => {
    signIn();
    harness([
      makeExpense({ id: 'e1', description: 'Fuel', amount: 500, category: 'Transportation', date: daysAgo(0), notes: null }),
      makeExpense({
        id: 'e2', description: 'Electric bill', amount: 300, category: 'Utilities', date: daysAgo(1),
        notes: 'meralco',
      }),
    ]);
    expect(await screen.findByText('Fuel')).toBeInTheDocument();

    await userEvent.type(screen.getByPlaceholderText(/Search/i), 'meralco');
    await waitFor(() => expect(screen.queryByText('Fuel')).not.toBeInTheDocument());
    expect(screen.getByText('Electric bill')).toBeInTheDocument();

    await userEvent.click(screen.getByText('Clear filters'));
    expect(await screen.findByText('Fuel')).toBeInTheDocument();
  });
});

describe('ExpensesPage — Total shown', () => {
  it('sums the whole filtered set across pages, not just the visible slice', async () => {
    signIn();
    const many = Array.from({ length: 30 }, (_, i) =>
      makeExpense({ id: `e${i + 1}`, description: `Expense ${i + 1}`, amount: 10, category: 'Transportation', date: daysAgo(0) }),
    );
    harness(many);

    expect(await screen.findByText('Expense 1')).toBeInTheDocument();
    expect(screen.getByTestId('total-shown')).toHaveTextContent(formatMoney(300)); // 30 * 10

    await userEvent.click(screen.getByRole('button', { name: 'Next' }));
    expect(await screen.findByText('Expense 26')).toBeInTheDocument();
    // Unchanged on page 2 — it sums every filtered row, not the 5 shown here.
    expect(screen.getByTestId('total-shown')).toHaveTextContent(formatMoney(300));
  });
});

describe('ExpensesPage — empty states', () => {
  it('shows the first-run tile when there are no expenses at all in range', async () => {
    signIn();
    harness([]);
    expect(await screen.findByText('No expenses yet')).toBeInTheDocument();
  });

  it('shows the no-matches state with Clear filters when filters exclude every row', async () => {
    signIn();
    harness([makeExpense({ id: 'e1', description: 'Fuel', date: daysAgo(0) })]);
    expect(await screen.findByText('Fuel')).toBeInTheDocument();

    await userEvent.type(screen.getByPlaceholderText(/Search/i), 'no-such-thing-xyz');
    expect(await screen.findByText('No expenses match these filters')).toBeInTheDocument();
    // Two "Clear filters" controls exist while filtered — the filters-row
    // link and the empty state's own button.
    expect(screen.getAllByRole('button', { name: 'Clear filters' }).length).toBeGreaterThan(0);
  });
});

describe('ExpensesPage — row interactions', () => {
  it('a row click navigates to the edit route', async () => {
    signIn();
    harness([makeExpense({ id: 'e1', description: 'Fuel', date: daysAgo(0) })]);
    expect(await screen.findByText('Fuel')).toBeInTheDocument();

    await userEvent.click(screen.getByText('Fuel'));
    expect(screen.getByText('EDIT EXPENSE')).toBeInTheDocument();
  });

  it('shows a paperclip indicator only on rows with a receipt', async () => {
    signIn();
    harness([
      makeExpense({ id: 'e1', description: 'Fuel', date: daysAgo(0), receiptImageUrl: 'https://x/receipt.jpg' }),
      makeExpense({ id: 'e2', description: 'No receipt item', date: daysAgo(0), receiptImageUrl: null }),
    ]);
    expect(await screen.findByText('Fuel')).toBeInTheDocument();

    const withReceipt = screen.getByText('Fuel').closest('tr')!;
    expect(within(withReceipt).getByLabelText('Has receipt')).toBeInTheDocument();
    const withoutReceipt = screen.getByText('No receipt item').closest('tr')!;
    expect(within(withoutReceipt).queryByLabelText('Has receipt')).toBeNull();
  });
});
