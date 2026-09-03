// The receiving modal's auto-SKU must be the category-driven kind — the old
// inline form called the retired name-based generator at form time. It also
// queues (not creates): the spec it hands back is what a pendingNewProduct
// line persists, so every field must survive into onAdd.
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import { NewProductDialog } from './NewProductDialog';
import type { NewProductSpec } from './useReceivingEntry';
import type { Category } from '@/domain/entities';

const codedCategory = {
  id: 'c1', name: 'Brakes', isActive: true, createdAt: new Date(), updatedAt: null,
  createdBy: null, updatedBy: null, code: '0007',
} as Category;
const uncodedCategory = {
  id: 'c2', name: 'Snacks', isActive: true, createdAt: new Date(), updatedAt: null,
  createdBy: null, updatedBy: null,
} as Category;
const unitCat = {
  id: 'u-pcs', name: 'pcs', isActive: true, createdAt: new Date(), updatedAt: null,
  createdBy: null, updatedBy: null,
} as Category;

function signIn(role: UserRole = UserRole.admin) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role, isActive: true } as never,
    status: 'signedIn',
  });
}

function harness(onAdd = vi.fn(), initial: NewProductSpec | null = null) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const categoryRepo: Partial<Container['categoryRepo']> = {
    watchAll: (kind, cb) => {
      cb(kind === 'product' ? [codedCategory, uncodedCategory] : [unitCat]);
      return () => {};
    },
    peekNextSequence: vi.fn(async () => 5),
  };
  render(
    <DiProvider override={{ categoryRepo: categoryRepo as Container['categoryRepo'] }}>
      <QueryClientProvider client={qc}>
        <NewProductDialog open onClose={() => {}} onAdd={onAdd} initial={initial} />
      </QueryClientProvider>
    </DiProvider>,
  );
  return onAdd;
}

describe('NewProductDialog auto-SKU', () => {
  it('shows no code for an auto-SKU row — the SKU is assigned on save', async () => {
    signIn();
    harness();

    await userEvent.selectOptions(screen.getByLabelText('Category'), 'Brakes');

    // Peeking the registry produced a number that looked authoritative and was
    // identical for every row added before saving, so three new products in a
    // category displayed one code. The field now states when it is assigned.
    await waitFor(() =>
      expect(screen.getByLabelText('SKU')).toHaveValue('Assigned when saved'),
    );
    expect(screen.getByLabelText('SKU')).not.toHaveValue(expect.stringMatching(/\d/));
    expect(screen.getByText(/assigned when the receiving is saved/i)).toBeInTheDocument();
  });

  it('an uncoded category leaves the SKU empty and says why — never name-based', async () => {
    signIn();
    harness();

    await userEvent.selectOptions(screen.getByLabelText('Category'), 'Snacks');

    expect(screen.getByLabelText('SKU')).toHaveValue('');
    expect(
      screen.getByText(/This category has no code/),
    ).toBeInTheDocument();
  });

  it('hands the category code to onAdd so the receive transaction can re-scan', async () => {
    signIn();
    const onAdd = harness();

    await userEvent.selectOptions(screen.getByLabelText('Category'), 'Brakes');
    await waitFor(() =>
      expect(screen.getByLabelText('SKU')).toHaveValue('Assigned when saved'),
    );
    await userEvent.type(screen.getByLabelText('Name'), 'Brake shoe');
    await userEvent.type(screen.getByLabelText('Cost'), '90');
    await userEvent.type(screen.getByLabelText('Price'), '130');
    await userEvent.type(screen.getByLabelText('Quantity received'), '3');
    await userEvent.click(screen.getByRole('button', { name: 'Add to receiving' }));

    expect(onAdd).toHaveBeenCalledTimes(1);
    const spec = onAdd.mock.calls[0][0];
    // The seed is sequence 1, and it is only a FLOOR: the receive transaction
    // scans from max(seed, registry.nextSequence). What matters is that it
    // still matches the category's pattern so the code reaches the allocator.
    expect(spec.sku).toBe('00070001');
    expect(spec.autoGenerateSku).toBe(true);
    expect(spec.autoSkuCategoryCode).toBe('0007');
  });
});

describe('NewProductDialog full fields', () => {
  it('barcodes and notes ride the queued spec', async () => {
    signIn();
    const onAdd = harness();

    await userEvent.type(screen.getByLabelText('Name'), 'Brake shoe');
    await userEvent.click(screen.getByText('Auto-generate SKU from category'));
    await userEvent.type(screen.getByLabelText('SKU'), 'MANUAL-9');
    await userEvent.type(screen.getByLabelText('Cost'), '90');
    await userEvent.type(screen.getByLabelText('Price'), '130');
    await userEvent.type(screen.getByLabelText('Quantity received'), '3');
    await userEvent.type(screen.getByLabelText('Add barcode'), '4800111222333{Enter}');
    await userEvent.type(screen.getByLabelText('Notes'), 'left shelf');
    await userEvent.click(screen.getByRole('button', { name: 'Add to receiving' }));

    const spec = onAdd.mock.calls[0][0];
    expect(spec.sku).toBe('MANUAL-9');
    expect(spec.autoSkuCategoryCode).toBeNull();
    expect(spec.barcodes).toEqual(['4800111222333']);
    expect(spec.notes).toBe('left shelf');
  });

  it('refuses to queue without a quantity', async () => {
    signIn();
    const onAdd = harness();

    await userEvent.type(screen.getByLabelText('Name'), 'Brake shoe');
    await userEvent.click(screen.getByText('Auto-generate SKU from category'));
    await userEvent.type(screen.getByLabelText('SKU'), 'MANUAL-9');
    await userEvent.type(screen.getByLabelText('Cost'), '90');
    await userEvent.type(screen.getByLabelText('Price'), '130');
    await userEvent.click(screen.getByRole('button', { name: 'Add to receiving' }));

    expect(onAdd).not.toHaveBeenCalled();
    expect(screen.getByText(/Quantity must be more than 0/)).toBeInTheDocument();
  });

  it('hides the selling-options editor from non-admins', async () => {
    signIn(UserRole.staff);
    harness();

    expect(screen.queryByText('Selling options')).toBeNull();
  });
});

describe('NewProductDialog — edit mode', () => {
  const spec: NewProductSpec = {
    name: 'Squid', sku: 'SQ-9', autoGenerateSku: false, category: 'Snacks', unit: 'pcs',
    cost: 90, price: 130, quantity: 3, reorderLevel: 1, autoSkuCategoryCode: null,
    barcodes: ['4800111222333'], notes: 'fresh', sellingOptions: [],
  };

  it('prefills every field from the queued spec and retitles to Edit', async () => {
    signIn();
    harness(vi.fn(), spec);

    expect(await screen.findByText('Edit product')).toBeInTheDocument();
    expect(screen.getByDisplayValue('Squid')).toBeInTheDocument();
    expect(screen.getByLabelText('SKU')).toHaveValue('SQ-9');
    expect(screen.getByDisplayValue('90')).toBeInTheDocument();
    expect(screen.getByDisplayValue('130')).toBeInTheDocument();
    expect(screen.getByText('4800111222333')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Save changes' })).toBeInTheDocument();
  });

  it('hands the edited spec back through onAdd', async () => {
    signIn();
    const onAdd = harness(vi.fn(), spec);

    const name = await screen.findByDisplayValue('Squid');
    await userEvent.clear(name);
    await userEvent.type(name, 'Squid Large');
    await userEvent.click(screen.getByRole('button', { name: 'Save changes' }));

    expect(onAdd).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'Squid Large', sku: 'SQ-9', cost: 90, price: 130, quantity: 3 }),
    );
  });
});

describe('NewProductDialog — reorder level default', () => {
  async function fillRequired() {
    await userEvent.type(screen.getByLabelText(/name/i), 'Squid');
    await userEvent.selectOptions(screen.getByLabelText('Category'), 'Brakes');
    await userEvent.type(screen.getByLabelText(/cost/i), '90');
    await userEvent.type(screen.getByLabelText(/price/i), '130');
    await userEvent.type(screen.getByLabelText(/quantity/i), '3');
  }

  it('left unset it defaults to 1', async () => {
    signIn();
    const onAdd = harness();
    await fillRequired();
    await userEvent.click(screen.getByRole('button', { name: /add to receiving/i }));
    expect(onAdd).toHaveBeenCalledWith(expect.objectContaining({ reorderLevel: 1 }));
  });

  it('an explicit 0 is kept — never overridden', async () => {
    signIn();
    const onAdd = harness();
    await fillRequired();
    await userEvent.type(screen.getByLabelText('Reorder level'), '0');
    await userEvent.click(screen.getByRole('button', { name: /add to receiving/i }));
    expect(onAdd).toHaveBeenCalledWith(expect.objectContaining({ reorderLevel: 0 }));
  });
});
