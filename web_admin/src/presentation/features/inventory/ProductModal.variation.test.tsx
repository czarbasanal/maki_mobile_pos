// New Product form: a typed SKU that collides with an existing product at a
// DIFFERENT cost offers to spawn `<base>-N` instead of just rejecting the save.
// Same cost is still a plain duplicate. Mirrors the receiving flow's
// cost-mismatch behavior (domain/receiving/classifyReceivingRows.ts).
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ProductModal } from './ProductModal';
import { defaultCostCode } from '@/domain/entities/CostCode';
import { encodeCostCode } from '@/domain/entities';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { Category, Product } from '@/domain/entities';

function signIn() {
  useAuthStore.setState({
    user: {
      id: 'u1',
      email: 'a@b.co',
      displayName: 'Tester',
      role: UserRole.admin,
      isActive: true,
    } as never,
    status: 'signedIn',
  });
}

const codedCategory: Category = {
  id: 'c1',
  name: 'Brakes',
  isActive: true,
  createdAt: new Date(),
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
  code: '0007',
};

function existingProduct(over: Partial<Product> = {}): Product {
  return {
    id: 'p9',
    sku: 'ABC123',
    name: 'Brake shoe (Yamaha)',
    costCode: 'NBF',
    cost: 170,
    price: 250,
    quantity: 8,
    reorderLevel: 3,
    unit: 'set',
    supplierId: null,
    supplierName: null,
    isActive: true,
    createdAt: new Date('2026-01-01'),
    updatedAt: null,
    createdBy: null,
    updatedBy: null,
    createdByName: null,
    updatedByName: null,
    searchKeywords: [],
    baseSku: null,
    variationNumber: null,
    barcodes: [],
    sellingOptions: [],
    category: 'Brakes',
    imageUrl: null,
    notes: null,
    tagIds: [],
    ...over,
  };
}

function harness(opts: {
  existing?: Product | null;
  createVariation?: ReturnType<typeof vi.fn>;
  create?: ReturnType<typeof vi.fn>;
  nextVariationNumber?: ReturnType<typeof vi.fn>;
} = {}) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const existing = opts.existing === undefined ? existingProduct() : opts.existing;
  const productRepo: Partial<Container['productRepo']> = {
    // A claimed SKU is exactly what makes the create hook reject the save.
    skuExists: vi.fn().mockResolvedValue(!!existing),
    barcodeExists: vi.fn().mockResolvedValue(false),
    findBySkuClaim: vi.fn().mockResolvedValue(existing),
    // Deliberately NOT 1: the dialog's fallback preview is `<base>-1`, so a
    // harness omitting this method would let the preview assertion pass
    // through the fallback and prove nothing.
    nextVariationNumber: opts.nextVariationNumber ?? vi.fn().mockResolvedValue(3),
    createVariation:
      opts.createVariation ??
      vi.fn().mockResolvedValue({ ...existingProduct(), id: 'v1', sku: 'ABC123-1' }),
    create: opts.create ?? vi.fn().mockResolvedValue({ id: 'new-product' } as Product),
    recordPriceChange: vi.fn().mockResolvedValue(undefined),
  };
  const categoryRepo: Partial<Container['categoryRepo']> = {
    watchAll: (kind, cb) => {
      cb(kind === 'product' ? [codedCategory] : []);
      return () => {};
    },
    peekNextSequence: vi.fn().mockResolvedValue(5),
  };
  const supplierRepo: Partial<Container['supplierRepo']> = {
    watchAll: (cb) => {
      cb([]);
      return () => {};
    },
  };
  const costCodeRepo: Partial<Container['costCodeRepo']> = {
    watch: (cb) => {
      cb(defaultCostCode);
      return () => {};
    },
  };
  const activityLogRepo = {
    log: vi.fn().mockResolvedValue(undefined),
  } as unknown as Container['activityLogRepo'];
  render(
    <DiProvider
      override={{
        categoryRepo: categoryRepo as Container['categoryRepo'],
        supplierRepo: supplierRepo as Container['supplierRepo'],
        costCodeRepo: costCodeRepo as Container['costCodeRepo'],
        productRepo: productRepo as Container['productRepo'],
        activityLogRepo,
        tagRepo: { watchAll: (cb: (t: never[]) => void) => { cb([]); return () => {}; } } as unknown as Container['tagRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/inventory/add']}>
          <ProductModal />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return productRepo;
}

/** Fills the form with a manually-typed SKU (auto-generate off) and submits. */
async function submitManual(sku: string, cost: string) {
  await userEvent.click(screen.getByLabelText('Auto'));
  await userEvent.type(screen.getByLabelText('SKU'), sku);
  await userEvent.type(screen.getByLabelText('Name'), 'Brake shoe (Yamaha)');
  await userEvent.type(screen.getByLabelText('Cost'), cost);
  await userEvent.type(screen.getByLabelText('Price'), '250');
  await userEvent.type(screen.getByLabelText('Initial quantity'), '12');
  await userEvent.click(screen.getByRole('button', { name: 'Create product' }));
}


/** SelectFilter replaced the native category select — open it, pick a row. */
async function pickCategory(user: ReturnType<typeof userEvent.setup> | typeof userEvent, name: string) {
  await user.click(screen.getByRole('button', { name: /^Category/ }));
  await user.click(await screen.findByRole('option', { name }));
}

describe('ProductModal — cost variation on create', () => {
  it('offers a variation when the SKU is taken at a different cost', async () => {
    signIn();
    harness();

    await submitManual('ABC123', '185');

    expect(await screen.findByText('SKU already exists')).toBeInTheDocument();
    // Names the product they'd be varying and both costs, so the decision is
    // informed rather than blind.
    expect(screen.getByText(/Brake shoe \(Yamaha\)/)).toBeInTheDocument();
    expect(screen.getByText(/170\.00/)).toBeInTheDocument();
    expect(screen.getByText(/185\.00/)).toBeInTheDocument();
    // The allocated number comes from the repo, not the `-1` fallback.
    expect(screen.getByText(/ABC123-3/)).toBeInTheDocument();
  });

  it('names every typed field the variation will not keep, barcodes included', async () => {
    signIn();
    harness();

    await submitManual('ABC123', '185');

    expect(await screen.findByText('SKU already exists')).toBeInTheDocument();
    // Barcodes are dropped too (the manufacturer code stays with the base
    // item) — a scanned code vanishing unannounced would be the worst
    // surprise of the three, so the warning must say so.
    expect(
      screen.getByText(/name, price, quantity and barcodes you typed will not be saved/i),
    ).toBeInTheDocument();
  });

  it('spawns the variation at the entered cost when confirmed', async () => {
    signIn();
    const createVariation = vi
      .fn()
      .mockResolvedValue({ ...existingProduct(), id: 'v1', sku: 'ABC123-1' });
    harness({ createVariation });

    await submitManual('ABC123', '185');
    await screen.findByText('SKU already exists');
    await userEvent.click(screen.getByRole('button', { name: 'Create variation' }));

    await waitFor(() => expect(createVariation).toHaveBeenCalled());
    const [existing, opts] = createVariation.mock.calls[0];
    expect(existing.id).toBe('p9');
    expect(opts.cost).toBe(185);
    expect(opts.costCode).toBe(encodeCostCode(defaultCostCode, 185));
    expect(opts.actorId).toBe('u1');
  });

  it('keeps the plain duplicate error when the cost matches', async () => {
    signIn();
    const createVariation = vi.fn();
    harness({ createVariation });

    await submitManual('ABC123', '170');

    expect(await screen.findByText(/A product with this SKU already exists/)).toBeInTheDocument();
    expect(screen.queryByText('SKU already exists')).toBeNull();
    expect(createVariation).not.toHaveBeenCalled();
  });

  it('does not contradict itself with a duplicate banner behind the offer', async () => {
    signIn();
    harness();

    await submitManual('ABC123', '185');
    await screen.findByText('SKU already exists');

    // The page-level mutation banner would otherwise still read "A product
    // with this SKU already exists" while the dialog offers a way forward.
    expect(screen.queryByText(/A product with this SKU already exists/)).toBeNull();
  });

  it('restores the duplicate-SKU error after the offer is declined', async () => {
    signIn();
    harness();

    await submitManual('ABC123', '185');
    await screen.findByText('SKU already exists');
    await userEvent.click(
      within(screen.getByRole('dialog', { name: 'SKU already exists' })).getByRole('button', {
        name: 'Cancel',
      }),
    );

    // Declining must leave the user knowing why the save didn't go through.
    expect(
      await screen.findByText(/A product with this SKU already exists/),
    ).toBeInTheDocument();
  });

  it('backs out without writing anything when cancelled', async () => {
    signIn();
    const createVariation = vi.fn();
    harness({ createVariation });

    await submitManual('ABC123', '185');
    await screen.findByText('SKU already exists');
    await userEvent.click(
      within(screen.getByRole('dialog', { name: 'SKU already exists' })).getByRole('button', {
        name: 'Cancel',
      }),
    );

    await waitFor(() => expect(screen.queryByText('SKU already exists')).toBeNull());
    expect(createVariation).not.toHaveBeenCalled();
  });

  it('never offers a variation on the auto-SKU path — a generated SKU cannot collide', async () => {
    signIn();
    const createVariation = vi.fn();
    const create = vi.fn().mockResolvedValue({ id: 'new-product' } as Product);
    harness({ createVariation, create });

    await pickCategory(userEvent, 'Brakes');
    await waitFor(() => expect(screen.getByLabelText('SKU')).toHaveValue('00070005'));
    await userEvent.type(screen.getByLabelText('Name'), 'Brake shoe (Yamaha)');
    await userEvent.type(screen.getByLabelText('Cost'), '185');
    await userEvent.type(screen.getByLabelText('Price'), '250');
    await userEvent.type(screen.getByLabelText('Initial quantity'), '12');
    await userEvent.click(screen.getByRole('button', { name: 'Create product' }));

    await waitFor(() => expect(create).toHaveBeenCalled());
    expect(createVariation).not.toHaveBeenCalled();
    expect(screen.queryByText('SKU already exists')).toBeNull();
  });
});
