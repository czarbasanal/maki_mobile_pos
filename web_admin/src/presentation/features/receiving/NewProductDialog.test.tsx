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

function harness(onAdd = vi.fn()) {
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
        <NewProductDialog open onClose={() => {}} onAdd={onAdd} />
      </QueryClientProvider>
    </DiProvider>,
  );
  return onAdd;
}

describe('NewProductDialog auto-SKU', () => {
  it('picking a coded category peeks and fills the SKU preview', async () => {
    signIn();
    harness();

    await userEvent.selectOptions(screen.getByLabelText('Category'), 'Brakes');

    await waitFor(() => expect(screen.getByLabelText('SKU')).toHaveValue('00070005'));
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
    await waitFor(() => expect(screen.getByLabelText('SKU')).toHaveValue('00070005'));
    await userEvent.type(screen.getByLabelText('Name'), 'Brake shoe');
    await userEvent.type(screen.getByLabelText('Cost'), '90');
    await userEvent.type(screen.getByLabelText('Price'), '130');
    await userEvent.type(screen.getByLabelText('Quantity received'), '3');
    await userEvent.click(screen.getByRole('button', { name: 'Add to receiving' }));

    expect(onAdd).toHaveBeenCalledTimes(1);
    const spec = onAdd.mock.calls[0][0];
    expect(spec.sku).toBe('00070005');
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
