// Create (upload-before-create pattern), edit-prefill (incl. paidVia), and
// validation — mirrors ProductModal.test.tsx's harness shape. Receipt
// storage is a plain module (not part of the DI container), so it's mocked
// directly.
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ExpenseFormPage } from './ExpenseFormPage';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { Category, Expense } from '@/domain/entities';

vi.mock('@/data/expenseReceiptStorage', () => ({
  uploadExpenseReceipt: vi.fn(),
  deleteExpenseReceipt: vi.fn(),
}));
import { uploadExpenseReceipt } from '@/data/expenseReceiptStorage';

// jsdom has no URL.createObjectURL/revokeObjectURL — the form calls both when
// a receipt file is picked (preview) and disposed.
beforeEach(() => {
  vi.clearAllMocks();
  URL.createObjectURL = vi.fn(() => 'blob:mock-url');
  URL.revokeObjectURL = vi.fn();
});

function signIn() {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role: UserRole.admin, isActive: true } as never,
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
];

function harness(opts: {
  path?: string;
  create?: ReturnType<typeof vi.fn>;
  update?: ReturnType<typeof vi.fn>;
  getById?: ReturnType<typeof vi.fn>;
  newExpenseId?: ReturnType<typeof vi.fn>;
} = {}) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const expenseRepo: Partial<Container['expenseRepo']> = {
    newExpenseId: opts.newExpenseId ?? vi.fn().mockReturnValue('preset-1'),
    create: opts.create ?? vi.fn().mockResolvedValue({ id: 'preset-1' } as Expense),
    update: opts.update ?? vi.fn().mockResolvedValue(undefined),
    getById: opts.getById,
    delete: vi.fn().mockResolvedValue(undefined),
  };
  const categoryRepo: Partial<Container['categoryRepo']> = {
    watchAll: (kind, cb) => {
      cb(kind === 'expense' ? expenseCategories : []);
      return () => {};
    },
  };
  const activityLogRepo = {
    log: vi.fn().mockResolvedValue(undefined),
  } as unknown as Container['activityLogRepo'];
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
            <Route path="/expenses" element={<div>Expenses list</div>} />
            <Route path="/expenses/add" element={<ExpenseFormPage />} />
            <Route path="/expenses/edit/:id" element={<ExpenseFormPage />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('ExpenseFormPage — create', () => {
  it('uploads the receipt first, then creates with the preset id + URL', async () => {
    signIn();
    vi.mocked(uploadExpenseReceipt).mockResolvedValue('https://x/receipt.jpg');
    const create = vi.fn().mockResolvedValue({ id: 'preset-1' } as Expense);
    harness({ create });

    await userEvent.type(screen.getByLabelText('Description'), 'Fuel');
    const amount = screen.getByLabelText('Amount');
    await userEvent.clear(amount);
    await userEvent.type(amount, '500');
    await userEvent.selectOptions(screen.getByLabelText('Category'), 'Transportation');
    await userEvent.selectOptions(screen.getByLabelText('Paid via'), 'gcash');

    const file = new File(['receipt-bytes'], 'receipt.jpg', { type: 'image/jpeg' });
    await userEvent.upload(screen.getByLabelText('Receipt'), file);

    await userEvent.click(screen.getByRole('button', { name: 'Add expense' }));

    await waitFor(() => expect(create).toHaveBeenCalled());
    expect(uploadExpenseReceipt).toHaveBeenCalledWith('preset-1', file);
    const [input] = create.mock.calls[0];
    expect(input.id).toBe('preset-1');
    expect(input.receiptImageUrl).toBe('https://x/receipt.jpg');
    expect(input.description).toBe('Fuel');
    expect(input.amount).toBe(500);
    expect(input.category).toBe('Transportation');
    expect(input.paidVia).toBe('gcash');
  });

  it('creates without a preset id when no receipt is picked', async () => {
    signIn();
    const create = vi.fn().mockResolvedValue({ id: 'auto-1' } as Expense);
    const newExpenseId = vi.fn().mockReturnValue('preset-1');
    harness({ create, newExpenseId });

    await userEvent.type(screen.getByLabelText('Description'), 'Fuel');
    const amount = screen.getByLabelText('Amount');
    await userEvent.clear(amount);
    await userEvent.type(amount, '250');
    await userEvent.selectOptions(screen.getByLabelText('Category'), 'Transportation');

    await userEvent.click(screen.getByRole('button', { name: 'Add expense' }));

    await waitFor(() => expect(create).toHaveBeenCalled());
    expect(newExpenseId).not.toHaveBeenCalled();
    expect(uploadExpenseReceipt).not.toHaveBeenCalled();
    const [input] = create.mock.calls[0];
    expect(input.id).toBeUndefined();
    expect(input.receiptImageUrl).toBeNull();
  });
});

describe('ExpenseFormPage — edit prefill', () => {
  it('prefills fields including paidVia', async () => {
    signIn();
    const target: Expense = {
      id: 'e1',
      description: 'Oil change',
      amount: 750,
      category: 'Transportation',
      date: new Date('2026-07-10T12:00:00.000Z'),
      paidVia: 'gcash',
      notes: 'note here',
      receiptNumber: null,
      receiptImageUrl: null,
      createdAt: new Date('2026-07-10T12:00:00.000Z'),
      updatedAt: null,
      createdBy: 'u1',
      createdByName: 'Cashier',
      updatedBy: null,
    };
    const getById = vi.fn().mockResolvedValue(target);
    harness({ path: '/expenses/edit/e1', getById });

    expect(await screen.findByDisplayValue('Oil change')).toBeInTheDocument();
    expect(screen.getByLabelText('Amount')).toHaveValue(750);
    expect(screen.getByLabelText('Category')).toHaveValue('Transportation');
    expect(screen.getByLabelText('Paid via')).toHaveValue('gcash');
    expect(screen.getByLabelText('Date')).toHaveValue('2026-07-10');
    expect(screen.getByDisplayValue('note here')).toBeInTheDocument();
  });
});

describe('ExpenseFormPage — validation', () => {
  it('blocks submit when description is empty and amount is zero', async () => {
    signIn();
    const create = vi.fn();
    harness({ create });

    await userEvent.click(screen.getByRole('button', { name: 'Add expense' }));

    expect(await screen.findByText('Description is required')).toBeInTheDocument();
    expect(screen.getByText('Must be greater than 0')).toBeInTheDocument();
    expect(create).not.toHaveBeenCalled();
  });
});
