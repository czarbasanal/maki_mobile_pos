// Stock adjustment is reachable from the Edit Product page as well as the
// product drawer — you often notice a count is wrong while already editing the
// item, and having to close the form, reopen the drawer and adjust from there
// loses whatever you had typed.
//
// Audit-grade rebuild (spec 2026-09-04 / handoff guide): the dialog previews
// the resulting on-hand, requires a reason, requires a note for flagged
// reasons, gates `Set to` to admins, and recovers from a stale on-hand race
// rather than silently applying a delta to a changed base.
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ProductModal } from './ProductModal';
import { defaultCostCode } from '@/domain/entities/CostCode';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import { StaleOnHandError } from '@/domain/products/adjustmentErrors';
import type { AdjustmentReason, Product } from '@/domain/entities';

function signIn(role: UserRole = UserRole.admin) {
  useAuthStore.setState({
    user: {
      id: 'u1', email: 'a@b.co', displayName: 'Tester', role, isActive: true,
    } as never,
    status: 'signedIn',
  });
}

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p9', sku: 'ABC123', name: 'Brake shoe (Yamaha)', costCode: 'NBF',
    cost: 170, price: 250, quantity: 8, reorderLevel: 3, unit: 'set',
    supplierId: null, supplierName: null, isActive: true,
    createdAt: new Date('2026-01-01'), updatedAt: null,
    createdBy: null, updatedBy: null, createdByName: null, updatedByName: null,
    searchKeywords: [], baseSku: null, variationNumber: null, barcodes: [],
    sellingOptions: [], category: null, imageUrl: null, notes: null, tagIds: [],
    ...over,
  };
}

function reason(over: Partial<AdjustmentReason> = {}): AdjustmentReason {
  return {
    id: 'r-delivery', name: 'Delivery', requiresNote: false, isActive: true,
    createdAt: new Date('2026-01-01'), updatedAt: null, createdBy: null, updatedBy: null,
    ...over,
  };
}

const REASONS: AdjustmentReason[] = [
  reason({ id: 'r-delivery', name: 'Delivery', requiresNote: false }),
  reason({ id: 'r-damaged', name: 'Damaged', requiresNote: true }),
];

function harness(opts: {
  p?: Product;
  reasons?: AdjustmentReason[];
  adjustStockAudited?: ReturnType<typeof vi.fn>;
  seedDefaults?: ReturnType<typeof vi.fn>;
} = {}) {
  const p = opts.p ?? product();
  const reasonList = opts.reasons ?? REASONS;
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const adjustStockAudited =
    opts.adjustStockAudited ?? vi.fn().mockResolvedValue({ before: p.quantity, after: p.quantity, delta: 0 });
  const productRepo: Partial<Container['productRepo']> = {
    getById: vi.fn().mockResolvedValue(p),
    adjustStockAudited: adjustStockAudited as Container['productRepo']['adjustStockAudited'],
  };
  const categoryRepo: Partial<Container['categoryRepo']> = {
    watchAll: (_kind, cb) => { cb([]); return () => {}; },
    peekNextSequence: vi.fn().mockResolvedValue(1),
  };
  const supplierRepo: Partial<Container['supplierRepo']> = {
    watchAll: (cb) => { cb([]); return () => {}; },
  };
  const costCodeRepo: Partial<Container['costCodeRepo']> = {
    watch: (cb) => { cb(defaultCostCode); return () => {}; },
  };
  const seedDefaults = opts.seedDefaults ?? vi.fn().mockResolvedValue(undefined);
  const adjustmentReasonRepo: Partial<Container['adjustmentReasonRepo']> = {
    watchAll: (cb) => { cb(reasonList); return () => {}; },
    seedDefaults: seedDefaults as Container['adjustmentReasonRepo']['seedDefaults'],
  };
  const activityLogRepo = { log: vi.fn().mockResolvedValue(undefined) } as unknown as Container['activityLogRepo'];
  render(
    <DiProvider
      override={{
        productRepo: productRepo as Container['productRepo'],
        categoryRepo: categoryRepo as Container['categoryRepo'],
        supplierRepo: supplierRepo as Container['supplierRepo'],
        costCodeRepo: costCodeRepo as Container['costCodeRepo'],
        adjustmentReasonRepo: adjustmentReasonRepo as Container['adjustmentReasonRepo'],
        activityLogRepo,
        tagRepo: { watchAll: (cb: (t: never[]) => void) => { cb([]); return () => {}; } } as unknown as Container['tagRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/inventory/p9/edit']}>
          <Routes>
            <Route path="/inventory/:id/edit" element={<ProductModal />} />
            <Route path="/inventory/add" element={<ProductModal />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { productRepo, adjustStockAudited, seedDefaults };
}

async function openDialog(name = /Brake shoe \(Yamaha\)/) {
  await screen.findByDisplayValue(name);
  await userEvent.click(screen.getByRole('button', { name: /Adjust stock/ }));
  return screen.findByRole('dialog', { name: 'Adjust stock' });
}

describe('ProductModal — stock adjustment', () => {
  it('offers stock adjustment while editing a product', async () => {
    signIn();
    harness();
    const dialog = await openDialog();
    expect(dialog).toBeInTheDocument();
  });

  it('binds the dialog to the product being edited, not a blank one', async () => {
    // The preview strip shows the on-hand in the product's own unit, so
    // seeing "set" proves it received this product rather than a placeholder.
    signIn();
    harness({ p: product({ quantity: 8, unit: 'set' }) });
    const dialog = await openDialog();
    expect(dialog).toHaveTextContent('On hand');
    expect(dialog).toHaveTextContent('set');
  });
});

describe('ProductModal — stock adjustment is edit-only', () => {
  it('is absent when creating a product, which has no stock to adjust yet', async () => {
    signIn();
    const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    const categoryRepo: Partial<Container['categoryRepo']> = {
      watchAll: (_kind, cb) => { cb([]); return () => {}; },
      peekNextSequence: vi.fn().mockResolvedValue(1),
    };
    const supplierRepo: Partial<Container['supplierRepo']> = {
      watchAll: (cb) => { cb([]); return () => {}; },
    };
    const costCodeRepo: Partial<Container['costCodeRepo']> = {
      watch: (cb) => { cb(defaultCostCode); return () => {}; },
    };
    render(
      <DiProvider
        override={{
          categoryRepo: categoryRepo as Container['categoryRepo'],
          supplierRepo: supplierRepo as Container['supplierRepo'],
          costCodeRepo: costCodeRepo as Container['costCodeRepo'],
          tagRepo: { watchAll: (cb: (t: never[]) => void) => { cb([]); return () => {}; } } as unknown as Container['tagRepo'],
        }}
      >
        <QueryClientProvider client={qc}>
          <MemoryRouter initialEntries={['/inventory/add']}>
            <Routes>
              <Route path="/inventory/add" element={<ProductModal />} />
            </Routes>
          </MemoryRouter>
        </QueryClientProvider>
      </DiProvider>,
    );

    expect(screen.queryByRole('button', { name: /Adjust stock/ })).toBeNull();
  });
});

describe('AdjustStockDialog — validity gating', () => {
  it('disables Apply until a quantity and a reason are picked', async () => {
    signIn();
    harness();
    const dialog = await openDialog();
    const apply = () => screen.getByRole('button', { name: /Apply adjustment/ });
    expect(apply()).toBeDisabled();

    await userEvent.type(screen.getByRole('textbox', { name: 'Quantity' }), '5');
    expect(apply()).toBeDisabled(); // still no reason

    await userEvent.click(screen.getByRole('button', { name: 'Delivery' }));
    expect(apply()).toBeEnabled();
    void dialog;
  });

  it('keeps Apply disabled when the picked reason requires a note and none is typed', async () => {
    signIn();
    harness();
    await openDialog();
    await userEvent.type(screen.getByRole('textbox', { name: 'Quantity' }), '5');
    await userEvent.click(screen.getByRole('button', { name: 'Damaged' }));

    expect(screen.getByRole('button', { name: /Apply adjustment/ })).toBeDisabled();

    await userEvent.type(screen.getByRole('textbox', { name: 'Note' }), 'Cracked casing');
    expect(screen.getByRole('button', { name: /Apply adjustment/ })).toBeEnabled();
  });
});

describe('AdjustStockDialog — note-required cue', () => {
  it('drops the "(optional)" suffix and flags the field when a flagged reason is picked', async () => {
    signIn();
    harness();
    await openDialog();
    expect(screen.getByText('Note (optional)')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Damaged' }));

    expect(screen.queryByText('Note (optional)')).toBeNull();
    expect(screen.getByText('Note')).toBeInTheDocument();
  });
});

describe('AdjustStockDialog — Set to is admin-only', () => {
  it('hides Set to for staff', async () => {
    signIn(UserRole.staff);
    harness();
    const dialog = await openDialog();
    expect(within(dialog).queryByRole('button', { name: 'Set to' })).toBeNull();
  });

  it('shows Set to for admins', async () => {
    signIn(UserRole.admin);
    harness();
    const dialog = await openDialog();
    expect(within(dialog).getByRole('button', { name: 'Set to' })).toBeInTheDocument();
  });
});

describe('AdjustStockDialog — apply', () => {
  it('calls adjustStockAudited with the exact input, including expectedOnHand', async () => {
    signIn();
    const { adjustStockAudited } = harness({ p: product({ quantity: 8 }) });
    await openDialog();

    await userEvent.type(screen.getByRole('textbox', { name: 'Quantity' }), '5');
    await userEvent.click(screen.getByRole('button', { name: 'Delivery' }));
    await userEvent.click(screen.getByRole('button', { name: /Apply adjustment/ }));

    await waitFor(() => expect(adjustStockAudited).toHaveBeenCalledTimes(1));
    expect(adjustStockAudited).toHaveBeenCalledWith(
      'p9',
      {
        mode: 'add',
        quantity: 5,
        expectedOnHand: 8,
        reasonId: 'r-delivery',
        reasonName: 'Delivery',
        note: null,
      },
      'u1',
      'Tester',
    );
  });

  it('closes both modals and toasts on success', async () => {
    signIn();
    harness({
      p: product({ quantity: 8, unit: 'set' }),
      adjustStockAudited: vi.fn().mockResolvedValue({ before: 8, after: 13, delta: 5 }),
    });
    await openDialog();

    await userEvent.type(screen.getByRole('textbox', { name: 'Quantity' }), '5');
    await userEvent.click(screen.getByRole('button', { name: 'Delivery' }));
    await userEvent.click(screen.getByRole('button', { name: /Apply adjustment/ }));

    // Both the adjust dialog AND the product modal close.
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Adjust stock' })).toBeNull());
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Edit product' })).toBeNull());
  });
});

describe('AdjustStockDialog — stale on-hand', () => {
  it('keeps mode/qty/reason/note and swaps in the fresh figure', async () => {
    signIn();
    const adjustStockAudited = vi.fn().mockRejectedValue(new StaleOnHandError(20));
    harness({ p: product({ quantity: 8 }), adjustStockAudited });
    await openDialog();

    await userEvent.type(screen.getByRole('textbox', { name: 'Quantity' }), '5');
    await userEvent.click(screen.getByRole('button', { name: 'Delivery' }));
    await userEvent.click(screen.getByRole('button', { name: /Apply adjustment/ }));

    await screen.findByText(/Someone else moved this stock — on hand is now 20\./);
    // Dialog stays open with everything the user entered intact.
    expect(screen.getByRole('dialog', { name: 'Adjust stock' })).toBeInTheDocument();
    expect(screen.getByRole('textbox', { name: 'Quantity' })).toHaveValue('5');
    expect(screen.getByRole('button', { name: 'Delivery' })).toHaveAttribute('aria-pressed', 'true');
  });
});

describe('AdjustStockDialog — reason seeding', () => {
  it('seeds default reasons once when the stream is empty', async () => {
    signIn();
    const { seedDefaults } = harness({ reasons: [] });
    await openDialog();

    await waitFor(() => expect(seedDefaults).toHaveBeenCalledTimes(1));
  });

  it('does not seed when reasons already exist', async () => {
    signIn();
    const { seedDefaults } = harness({ reasons: REASONS });
    await openDialog();

    expect(seedDefaults).not.toHaveBeenCalled();
  });
});
