// One component, two modes, rendered over the list (per design/
// maki-pos-expenses-redesign §4) — mirrors ProductModal.test.tsx's harness
// shape. Category/paid-via are chips now, not <select>s, so these tests
// click buttons rather than selectOptions. Receipt storage is a plain
// module (not part of the DI container), so it's mocked directly — same
// coverage the old ExpenseFormPage.test.tsx carried for the upload-first
// pattern.
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ExpenseModal } from './ExpenseModal';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { Category, Expense } from '@/domain/entities';

vi.mock('@/data/expenseReceiptStorage', () => ({
  uploadExpenseReceipt: vi.fn(),
  deleteExpenseReceipt: vi.fn(),
}));
import { deleteExpenseReceipt, uploadExpenseReceipt } from '@/data/expenseReceiptStorage';

beforeEach(() => {
  vi.clearAllMocks();
  URL.createObjectURL = vi.fn(() => 'blob:mock-url');
  URL.revokeObjectURL = vi.fn();
});

function signIn(role: UserRole = UserRole.admin) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role, isActive: true } as never,
    status: 'signedIn',
  });
}

const expenseCategories: Category[] = [
  { id: 'c1', name: 'Transportation', isActive: true, createdAt: new Date(), updatedAt: null, createdBy: null, updatedBy: null },
  { id: 'c2', name: 'Utilities', isActive: true, createdAt: new Date(), updatedAt: null, createdBy: null, updatedBy: null },
];

function makeExpense(overrides: Partial<Expense> = {}): Expense {
  return {
    id: 'e1',
    description: 'Oil change',
    amount: 750,
    category: 'Transportation',
    date: new Date('2026-07-10T12:00:00.000Z'),
    paidVia: 'gcash',
    notes: 'note here',
    receiptNumber: null,
    receiptImageUrl: null,
    createdAt: new Date('2026-07-10T10:04:00.000Z'),
    updatedAt: null,
    createdBy: 'u1',
    createdByName: 'Cashier',
    updatedBy: null,
    updatedByName: null,
    ...overrides,
  };
}

function harness(opts: {
  path?: string;
  create?: ReturnType<typeof vi.fn>;
  update?: ReturnType<typeof vi.fn>;
  del?: ReturnType<typeof vi.fn>;
  getById?: ReturnType<typeof vi.fn>;
  newExpenseId?: ReturnType<typeof vi.fn>;
  categories?: Category[];
} = {}) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const expenseRepo: Partial<Container['expenseRepo']> = {
    newExpenseId: opts.newExpenseId ?? vi.fn().mockReturnValue('preset-1'),
    create: opts.create ?? vi.fn().mockResolvedValue({ id: 'preset-1' } as Expense),
    update: opts.update ?? vi.fn().mockResolvedValue(undefined),
    delete: opts.del ?? vi.fn().mockResolvedValue(undefined),
    getById: opts.getById,
  };
  const categoryRepo: Partial<Container['categoryRepo']> = {
    watchAll: (kind, cb) => {
      cb(kind === 'expense' ? (opts.categories ?? expenseCategories) : []);
      return () => {};
    },
  };
  const activityLogRepo = { log: vi.fn().mockResolvedValue(undefined) } as unknown as Container['activityLogRepo'];
  return render(
    <DiProvider
      override={{
        expenseRepo: expenseRepo as Container['expenseRepo'],
        categoryRepo: categoryRepo as Container['categoryRepo'],
        activityLogRepo,
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={[opts.path ?? '/expenses/add']}>
          <Routes>
            <Route path="/expenses" element={<div>EXPENSES LIST</div>} />
            <Route path="/expenses/add" element={<ExpenseModal />} />
            <Route path="/expenses/edit/:id" element={<ExpenseModal />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('ExpenseModal — add mode validity', () => {
  it('Save stays inert until Description is filled and Amount is above zero', async () => {
    signIn();
    harness();
    const save = screen.getByRole('button', { name: 'Add expense' });
    expect(save).toHaveAttribute('aria-disabled', 'true');

    await userEvent.type(screen.getByLabelText('Description'), 'Fuel');
    expect(save).toHaveAttribute('aria-disabled', 'true'); // amount still 0

    await userEvent.type(screen.getByLabelText('Amount'), '500');
    expect(save).not.toHaveAttribute('aria-disabled');
  });

  it('the date cannot be emptied — the calendar field always holds a valid day', async () => {
    signIn();
    harness();
    await userEvent.type(screen.getByLabelText('Description'), 'Fuel');
    await userEvent.type(screen.getByLabelText('Amount'), '500');
    const save = screen.getByRole('button', { name: 'Add expense' });
    // Category auto-defaults to the first option, date defaults to today —
    // both filled once description/amount are, so Save is live here.
    expect(save).not.toHaveAttribute('aria-disabled');

    // The shared DateField replaced the native input: it is a picker button,
    // not an editable field, so the empty-date invalid state the old test
    // covered is unreachable from the UI (the validity guard itself stays,
    // as a belt against future callers seeding an empty draft).
    expect(screen.getByRole('button', { name: 'Date' })).not.toHaveTextContent('Pick a date');
    expect(save).not.toHaveAttribute('aria-disabled');
  });

  it('Save stays inert with no category selected (an empty category list never auto-picks one)', async () => {
    signIn();
    harness({ categories: [] });
    await userEvent.type(screen.getByLabelText('Description'), 'Fuel');
    await userEvent.type(screen.getByLabelText('Amount'), '500');

    expect(screen.getByRole('button', { name: 'Add expense' })).toHaveAttribute('aria-disabled', 'true');
  });
});

describe('ExpenseModal — create', () => {
  it('creates with description/amount/category/paidVia/date/notes, then returns to the list', async () => {
    signIn();
    const create = vi.fn().mockResolvedValue({ id: 'preset-1' } as Expense);
    harness({ create });

    await userEvent.type(screen.getByLabelText('Description'), 'Fuel');
    await userEvent.type(screen.getByLabelText('Amount'), '500');
    await userEvent.click(screen.getByRole('button', { name: 'Transportation' }));
    await userEvent.click(screen.getByRole('button', { name: 'GCash' }));
    await userEvent.type(screen.getByLabelText(/Note/), 'ref 123');

    await userEvent.click(screen.getByRole('button', { name: 'Add expense' }));

    await waitFor(() => expect(create).toHaveBeenCalled());
    const [input] = create.mock.calls[0];
    expect(input.description).toBe('Fuel');
    expect(input.amount).toBe(500);
    expect(input.category).toBe('Transportation');
    expect(input.paidVia).toBe('gcash');
    expect(input.notes).toBe('ref 123');
    expect(input.date).toBeInstanceOf(Date);
    expect(await screen.findByText('EXPENSES LIST')).toBeInTheDocument();
  });

  it('uploads the receipt first, then creates with the preset id + URL', async () => {
    signIn();
    vi.mocked(uploadExpenseReceipt).mockResolvedValue('https://x/receipt.jpg');
    const create = vi.fn().mockResolvedValue({ id: 'preset-1' } as Expense);
    harness({ create });

    await userEvent.type(screen.getByLabelText('Description'), 'Fuel');
    await userEvent.type(screen.getByLabelText('Amount'), '500');

    const file = new File(['receipt-bytes'], 'receipt.jpg', { type: 'image/jpeg' });
    await userEvent.upload(screen.getByLabelText('Receipt'), file);

    await userEvent.click(screen.getByRole('button', { name: 'Add expense' }));

    await waitFor(() => expect(create).toHaveBeenCalled());
    expect(uploadExpenseReceipt).toHaveBeenCalledWith('preset-1', file);
    const [input] = create.mock.calls[0];
    expect(input.id).toBe('preset-1');
    expect(input.receiptImageUrl).toBe('https://x/receipt.jpg');
  });

  it('creates without a preset id when no receipt is picked', async () => {
    signIn();
    const create = vi.fn().mockResolvedValue({ id: 'auto-1' } as Expense);
    const newExpenseId = vi.fn().mockReturnValue('preset-1');
    harness({ create, newExpenseId });

    await userEvent.type(screen.getByLabelText('Description'), 'Fuel');
    await userEvent.type(screen.getByLabelText('Amount'), '250');

    await userEvent.click(screen.getByRole('button', { name: 'Add expense' }));

    await waitFor(() => expect(create).toHaveBeenCalled());
    expect(newExpenseId).not.toHaveBeenCalled();
    expect(uploadExpenseReceipt).not.toHaveBeenCalled();
    const [input] = create.mock.calls[0];
    expect(input.id).toBeUndefined();
    expect(input.receiptImageUrl).toBeNull();
  });
});

describe('ExpenseModal — edit prefill + update', () => {
  it('prefills fields including paidVia, and patches the update on save', async () => {
    signIn();
    const target = makeExpense();
    const getById = vi.fn().mockResolvedValue(target);
    const update = vi.fn().mockResolvedValue(undefined);
    harness({ path: '/expenses/edit/e1', getById, update });

    expect(await screen.findByDisplayValue('Oil change')).toBeInTheDocument();
    expect(screen.getByLabelText('Amount')).toHaveValue(750);
    expect(screen.getByRole('button', { name: 'Date' })).toHaveTextContent('Jul 10, 2026');
    expect(screen.getByDisplayValue('note here')).toBeInTheDocument();
    // The active category/paid-via chips reflect the target.
    expect(screen.getByRole('button', { name: 'Transportation' })).toHaveAttribute('aria-pressed', 'true');
    expect(screen.getByRole('button', { name: 'GCash' })).toHaveAttribute('aria-pressed', 'true');

    await userEvent.clear(screen.getByLabelText('Description'));
    await userEvent.type(screen.getByLabelText('Description'), 'Oil + filter');
    await userEvent.click(screen.getByRole('button', { name: 'Save changes' }));

    await waitFor(() => expect(update).toHaveBeenCalled());
    const [id, patch] = update.mock.calls[0];
    expect(id).toBe('e1');
    expect(patch.description).toBe('Oil + filter');
    expect(patch.amount).toBe(750);
    expect(await screen.findByText('EXPENSES LIST')).toBeInTheDocument();
  });

  it('edit-mode subtitle carries the category and the spentOn date, not an id', async () => {
    signIn();
    const getById = vi.fn().mockResolvedValue(makeExpense());
    harness({ path: '/expenses/edit/e1', getById });

    expect(await screen.findByText(/TRANSPORTATION/)).toBeInTheDocument();
  });
});

describe('ExpenseModal — Record history', () => {
  it('renders createdByName/createdAt and updatedByName/updatedAt in the shop zone', async () => {
    signIn();
    const target = makeExpense({
      createdByName: 'Bern',
      createdAt: new Date('2026-07-10T02:04:00.000Z'), // 10:04 AM Asia/Manila
      updatedByName: 'Czar',
      updatedAt: new Date('2026-07-10T09:00:00.000Z'), // 5:00 PM Asia/Manila
    });
    const getById = vi.fn().mockResolvedValue(target);
    harness({ path: '/expenses/edit/e1', getById });

    expect(await screen.findByText('Bern')).toBeInTheDocument();
    expect(screen.getByText('Czar')).toBeInTheDocument();
    expect(screen.getByText(/10:04 AM/)).toBeInTheDocument();
    expect(screen.getByText(/5:00 PM/)).toBeInTheDocument();
  });

  it('shows "—" and "Never edited" when the expense has never been updated', async () => {
    signIn();
    const target = makeExpense({ updatedByName: null, updatedAt: null });
    const getById = vi.fn().mockResolvedValue(target);
    harness({ path: '/expenses/edit/e1', getById });

    expect(await screen.findByText('Never edited')).toBeInTheDocument();
    const lastUpdated = screen.getByText('Last updated by').closest('div')!;
    expect(within(lastUpdated).getByText('—')).toBeInTheDocument();
  });

  it('a legacy doc (updatedAt set, updatedByName missing) shows "—" and the raw timestamp, not "Never edited"', async () => {
    signIn();
    const target = makeExpense({
      updatedByName: null,
      updatedAt: new Date('2026-07-12T09:00:00.000Z'),
    });
    const getById = vi.fn().mockResolvedValue(target);
    harness({ path: '/expenses/edit/e1', getById });

    const lastUpdated = await screen.findByText('Last updated by');
    const card = lastUpdated.closest('div')!;
    expect(within(card).getByText('—')).toBeInTheDocument();
    expect(within(card).queryByText('Never edited')).not.toBeInTheDocument();
    expect(within(card).getByText(/5:00 PM/)).toBeInTheDocument();
  });
});

describe('ExpenseModal — danger zone', () => {
  it('deletes the expense and cleans up its receipt when one exists', async () => {
    signIn();
    const target = makeExpense({ receiptImageUrl: 'https://x/receipt.jpg' });
    const getById = vi.fn().mockResolvedValue(target);
    const del = vi.fn().mockResolvedValue(undefined);
    harness({ path: '/expenses/edit/e1', getById, del });

    expect(await screen.findByText('Danger zone')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Delete expense' }));

    // The Modal shell is ALSO role="dialog" — name the confirm one specifically.
    const dialog = await screen.findByRole('dialog', { name: 'Delete this expense?' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'Delete' }));

    await waitFor(() => expect(del).toHaveBeenCalledWith('e1'));
    expect(deleteExpenseReceipt).toHaveBeenCalledWith('e1');
    expect(await screen.findByText('EXPENSES LIST')).toBeInTheDocument();
  });

  it('does not call deleteExpenseReceipt when the expense has no receipt', async () => {
    signIn();
    const target = makeExpense({ receiptImageUrl: null });
    const getById = vi.fn().mockResolvedValue(target);
    const del = vi.fn().mockResolvedValue(undefined);
    harness({ path: '/expenses/edit/e1', getById, del });

    await userEvent.click(await screen.findByRole('button', { name: 'Delete expense' }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete this expense?' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'Delete' }));

    await waitFor(() => expect(del).toHaveBeenCalledWith('e1'));
    expect(deleteExpenseReceipt).not.toHaveBeenCalled();
  });

  it('the danger zone is not shown in add mode', async () => {
    signIn();
    harness();
    expect(screen.queryByText('Danger zone')).not.toBeInTheDocument();
  });
});
