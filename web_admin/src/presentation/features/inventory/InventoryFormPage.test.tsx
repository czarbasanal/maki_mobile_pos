// InventoryFormPage's create-mode auto-SKU wiring: selecting a coded product
// category peeks the category's next sequence and fills the SKU field
// (mirrors the mobile product form's category-onChanged peek — see
// lib/presentation/mobile/screens/inventory/product_form_screen.dart
// _applyCategoryForSku); unchecking auto-generate hands the field back to
// the user and a manual edit survives further category churn.
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { InventoryFormPage } from './InventoryFormPage';
import { defaultCostCode } from '@/domain/entities/CostCode';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { Category, Product } from '@/domain/entities';

function signIn() {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role: UserRole.admin, isActive: true } as never,
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

// No `code` — exercises the "category has no code" branch, distinct from
// no-category-selected and from a coded category whose peek fails.
const uncodedCategory: Category = {
  id: 'c2',
  name: 'Snacks',
  isActive: true,
  createdAt: new Date(),
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
};
const UNCODED_CATEGORY_NAME = uncodedCategory.name;

function harness(opts: {
  peekNextSequence?: ReturnType<typeof vi.fn>;
  create?: ReturnType<typeof vi.fn>;
} = {}) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const categoryRepo: Partial<Container['categoryRepo']> = {
    watchAll: (kind, cb) => {
      cb(kind === 'product' ? [codedCategory, uncodedCategory] : []);
      return () => {};
    },
    peekNextSequence: opts.peekNextSequence ?? vi.fn().mockResolvedValue(5),
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
  const productRepo: Partial<Container['productRepo']> = {
    create:
      opts.create ??
      vi.fn().mockResolvedValue({ id: 'new-product' } as Product),
  };
  const activityLogRepo = {
    log: vi.fn().mockResolvedValue(undefined),
  } as unknown as Container['activityLogRepo'];
  return render(
    <DiProvider
      override={{
        categoryRepo: categoryRepo as Container['categoryRepo'],
        supplierRepo: supplierRepo as Container['supplierRepo'],
        costCodeRepo: costCodeRepo as Container['costCodeRepo'],
        productRepo: productRepo as Container['productRepo'],
        activityLogRepo,
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/inventory/add']}>
          <InventoryFormPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

async function selectCategory(name: string) {
  await userEvent.selectOptions(screen.getByLabelText('Category'), name);
}

describe('InventoryFormPage — create-mode auto-SKU', () => {
  it('selecting a coded category peeks the next sequence and fills the SKU field', async () => {
    const peekNextSequence = vi.fn().mockResolvedValue(5);
    harness({ peekNextSequence });

    await userEvent.selectOptions(screen.getByLabelText('Category'), 'Brakes');

    expect(peekNextSequence).toHaveBeenCalledWith('0007');
    await waitFor(() => {
      expect(screen.getByLabelText('SKU')).toHaveValue('00070005');
    });
  });

  it('submits the peeked category code so the create transaction can claim it', async () => {
    signIn();
    const create = vi.fn().mockResolvedValue({ id: 'new-product' } as Product);
    harness({ create });

    await userEvent.selectOptions(screen.getByLabelText('Category'), 'Brakes');
    await waitFor(() => {
      expect(screen.getByLabelText('SKU')).toHaveValue('00070005');
    });
    await userEvent.type(screen.getByLabelText('Name'), 'Brake Pad');
    await userEvent.type(screen.getByLabelText('Cost'), '100');
    await userEvent.type(screen.getByLabelText('Price'), '150');
    await userEvent.type(screen.getByLabelText('Initial quantity'), '10');

    await userEvent.click(screen.getByRole('button', { name: 'Create product' }));

    await waitFor(() => expect(create).toHaveBeenCalled());
    const [input, , autoSkuCategoryCode] = create.mock.calls[0];
    expect(input.sku).toBe('00070005');
    expect(autoSkuCategoryCode).toBe('0007');
  });

  it('a manual override after unchecking auto-generate survives further category changes', async () => {
    harness();

    await userEvent.click(screen.getByLabelText('Auto-generate SKU from category'));
    const skuField = screen.getByLabelText('SKU');
    await userEvent.clear(skuField);
    await userEvent.type(skuField, 'MANUAL-1');

    // Changing the category no longer drives the field once auto-generate
    // is off — the peek must not fire and the typed value must survive.
    await userEvent.selectOptions(screen.getByLabelText('Category'), 'Brakes');

    expect(screen.getByLabelText('SKU')).toHaveValue('MANUAL-1');
  });

  it('opens with an empty SKU and the pick-a-category hint', async () => {
    harness();
    expect(screen.getByLabelText('SKU')).toHaveValue('');
    expect(
      await screen.findByText('Pick a category to generate the SKU.'),
    ).toBeInTheDocument();
  });

  it('typing a name generates nothing', async () => {
    harness();
    // Under the old name-based generator, blurring Name with this value
    // would have produced a visible non-empty SKU (e.g. 'MLKCHCLT-xxxxxx').
    // Blur is triggered via a real Tab key press, not a synthetic event, so
    // it exercises the same code path a user would.
    await userEvent.type(screen.getByLabelText('Name'), 'MILK CHOCOLATE');
    await userEvent.tab();
    expect(screen.getByLabelText('SKU')).toHaveValue('');
  });

  it('an uncoded category leaves the SKU empty and says why', async () => {
    harness();
    await selectCategory(UNCODED_CATEGORY_NAME);
    expect(screen.getByLabelText('SKU')).toHaveValue('');
    expect(
      screen.getByText(
        'This category has no code — pick another, or turn off auto-generate and type a SKU.',
      ),
    ).toBeInTheDocument();
    // Must not be confused with the "no category selected" hint.
    expect(
      screen.queryByText('Pick a category to generate the SKU.'),
    ).toBeNull();
  });

  it('a failed peek blames the server, not the category, and leaves the SKU empty', async () => {
    const peekNextSequence = vi.fn().mockRejectedValue(new Error('offline'));
    harness({ peekNextSequence });
    await selectCategory('Brakes');
    expect(
      await screen.findByText(
        "Couldn't reach the server — try again, or turn off auto-generate and type a SKU.",
      ),
    ).toBeInTheDocument();
    expect(screen.getByLabelText('SKU')).toHaveValue('');
    // Must not be confused with the "category has no code" hint — this
    // category DOES have a code; only the network call failed.
    expect(
      screen.queryByText(
        'This category has no code — pick another, or turn off auto-generate and type a SKU.',
      ),
    ).toBeNull();
  });

  it('no regenerate button while auto-generate is on', () => {
    harness();
    expect(screen.queryByRole('button', { name: /regenerate/i })).toBeNull();
  });

  it('submitting with an empty SKU raises the required error, not a generated one', async () => {
    const create = vi.fn();
    harness({ create });
    await userEvent.type(screen.getByLabelText('Name'), 'WIDGET');
    await userEvent.click(screen.getByRole('button', { name: /save|create/i }));
    expect(await screen.findByText('SKU is required')).toBeInTheDocument();
    expect(create).not.toHaveBeenCalled();
  });
});

describe('InventoryFormPage — edit-mode supplier mapping', () => {
  it('shows the saved supplier even while the suppliers list has not loaded', async () => {
    signIn();
    const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    const target = {
      id: 'p1', sku: 'SPRNG18', name: 'CENTER SPRING', cost: 10, price: 20,
      quantity: 5, reorderLevel: 1, unit: 'pcs', category: 'Brakes',
      supplierId: 'sup-1', supplierName: 'FUGO', barcodes: [], notes: null,
      costCode: 'AA', imageUrl: null, isActive: true,
      createdAt: new Date(), updatedAt: null,
    } as unknown as Product;
    const categoryRepo: Partial<Container['categoryRepo']> = {
      watchAll: (kind, cb) => { cb(kind === 'product' ? [codedCategory] : []); return () => {}; },
      peekNextSequence: vi.fn().mockResolvedValue(5),
    };
    // Suppliers never load — the saved supplier must still be selectable.
    const supplierRepo: Partial<Container['supplierRepo']> = {
      watchAll: () => () => {},
    };
    const costCodeRepo: Partial<Container['costCodeRepo']> = {
      watch: (cb) => { cb(defaultCostCode); return () => {}; },
    };
    const productRepo: Partial<Container['productRepo']> = {
      getById: vi.fn().mockResolvedValue(target),
    };
    render(
      <DiProvider
        override={{
          categoryRepo: categoryRepo as Container['categoryRepo'],
          supplierRepo: supplierRepo as Container['supplierRepo'],
          costCodeRepo: costCodeRepo as Container['costCodeRepo'],
          productRepo: productRepo as Container['productRepo'],
        }}
      >
        <QueryClientProvider client={qc}>
          <MemoryRouter initialEntries={['/inventory/edit/p1']}>
            <Routes>
              <Route path="/inventory/edit/:id" element={<InventoryFormPage />} />
            </Routes>
          </MemoryRouter>
        </QueryClientProvider>
      </DiProvider>,
    );
    const option = (await screen.findByRole('option', { name: 'FUGO' })) as HTMLOptionElement;
    expect(option.value).toBe('sup-1');
    expect(option.selected).toBe(true);
  });
});

describe('InventoryFormPage — uppercase inputs', () => {
  it('name and sku fields uppercase as you type', async () => {
    signIn();
    harness();
    const user = userEvent.setup();
    const name = screen.getByLabelText('Name') as HTMLInputElement;
    await user.type(name, 'brake pad');
    expect(name.value).toBe('BRAKE PAD');

    const autoToggle = screen.getByRole('checkbox', { name: /auto-generate/i });
    if ((autoToggle as HTMLInputElement).checked) await user.click(autoToggle);
    const sku = screen.getByLabelText('SKU') as HTMLInputElement;
    await user.clear(sku);
    await user.type(sku, 'abc123x');
    expect(sku.value).toBe('ABC123X');
  });
});
