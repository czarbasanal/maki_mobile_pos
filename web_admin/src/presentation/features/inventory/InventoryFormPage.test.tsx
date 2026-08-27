// InventoryFormPage's create-mode auto-SKU wiring: selecting a coded product
// category peeks the category's next sequence and fills the SKU field
// (mirrors the mobile product form's category-onChanged peek — see
// lib/presentation/mobile/screens/inventory/product_form_screen.dart
// _applyCategoryForSku); unchecking auto-generate hands the field back to
// the user and a manual edit survives further category churn.
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { InventoryFormPage } from './InventoryFormPage';
import { defaultCostCode } from '@/domain/entities/CostCode';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { Category, Product } from '@/domain/entities';
import type { SellingOption } from '@/domain/entities/SellingOption';

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

// A third coded category so the duplicate-name tests can select a category
// distinct from the auto-SKU tests' "Brakes" without disturbing them.
const cvtCategory: Category = {
  id: 'c3',
  name: 'CVT',
  isActive: true,
  createdAt: new Date(),
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
  code: '0009',
};

/** Minimal active product, for duplicate-name-dialog tests. */
function product(overrides: Partial<Product> = {}): Product {
  return {
    id: 'existing-1',
    sku: '00090001',
    name: 'A PRODUCT',
    cost: 0,
    price: 0,
    quantity: 0,
    reorderLevel: 0,
    unit: 'pcs',
    category: null,
    supplierId: null,
    supplierName: null,
    barcodes: [],
    notes: null,
    costCode: 'AA',
    imageUrl: null,
    isActive: true,
    createdAt: new Date(),
    updatedAt: null,
    createdBy: null,
    updatedBy: null,
    createdByName: null,
    updatedByName: null,
    searchKeywords: [],
    baseSku: null,
    variationNumber: null,
    sellingOptions: [],
    ...overrides,
  } as Product;
}

function harness(opts: {
  peekNextSequence?: ReturnType<typeof vi.fn>;
  create?: ReturnType<typeof vi.fn>;
  findByNameKey?: ReturnType<typeof vi.fn>;
  createVariation?: ReturnType<typeof vi.fn>;
} = {}) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const categoryRepo: Partial<Container['categoryRepo']> = {
    watchAll: (kind, cb) => {
      cb(kind === 'product' ? [codedCategory, uncodedCategory, cvtCategory] : []);
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
    findByNameKey: opts.findByNameKey ?? vi.fn().mockResolvedValue(null),
    createVariation:
      opts.createVariation ??
      vi.fn().mockResolvedValue({ id: 'variation-1' } as Product),
    recordPriceChange: vi.fn().mockResolvedValue(undefined),
    barcodeExists: vi.fn().mockResolvedValue(false),
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

/** Fills name, category, cost and price by their field labels. */
async function fillForm(values: { name: string; category?: string; cost: string; price: string }) {
  await userEvent.type(screen.getByLabelText('Name'), values.name);
  if (values.category) {
    await selectCategory(values.category);
    // Category selection auto-peeks a SKU (create mode); wait for it so the
    // required-SKU validation doesn't block the submit this helper leads to.
    await waitFor(() => expect(screen.getByLabelText('SKU')).not.toHaveValue(''));
  }
  await userEvent.clear(screen.getByLabelText('Cost'));
  await userEvent.type(screen.getByLabelText('Cost'), values.cost);
  await userEvent.clear(screen.getByLabelText('Price'));
  await userEvent.type(screen.getByLabelText('Price'), values.price);
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
    // Positive control: prove the form actually rendered, so the absence
    // above means "no button", not "nothing rendered at all".
    expect(screen.getByLabelText('SKU')).toBeInTheDocument();
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
      createdAt: new Date(), updatedAt: null, sellingOptions: [],
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
          <MemoryRouter initialEntries={['/inventory/p1/edit']}>
            <Routes>
              <Route path="/inventory/:id/edit" element={<InventoryFormPage />} />
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

describe('InventoryFormPage — selling options', () => {
  const editableProduct = (o: Partial<Product> = {}): Product =>
    ({
      id: 'p1',
      sku: 'SPRNG18',
      name: 'CENTER SPRING',
      cost: 60,
      price: 100,
      quantity: 5,
      reorderLevel: 1,
      unit: 'pcs',
      category: null,
      supplierId: null,
      supplierName: null,
      barcodes: [],
      notes: null,
      costCode: 'AA',
      imageUrl: null,
      isActive: true,
      createdAt: new Date(),
      updatedAt: null,
      createdBy: null,
      updatedBy: null,
      createdByName: null,
      updatedByName: null,
      searchKeywords: [],
      baseSku: null,
      variationNumber: null,
      sellingOptions: [],
      ...o,
    }) as Product;

  function editHarness(
    opts: {
      role?: UserRole;
      target?: Product;
      update?: ReturnType<typeof vi.fn>;
    } = {},
  ) {
    useAuthStore.setState({
      user: {
        id: 'u1',
        email: 'a@b.co',
        displayName: 'Tester',
        role: opts.role ?? UserRole.admin,
        isActive: true,
      } as never,
      status: 'signedIn',
    });
    const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    const target = opts.target ?? editableProduct();
    const categoryRepo: Partial<Container['categoryRepo']> = {
      watchAll: (_kind, cb) => {
        cb([]);
        return () => {};
      },
      peekNextSequence: vi.fn().mockResolvedValue(1),
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
      getById: vi.fn().mockResolvedValue(target),
      update: opts.update ?? vi.fn().mockResolvedValue(undefined),
      skuExists: vi.fn().mockResolvedValue(false),
      barcodeExists: vi.fn().mockResolvedValue(false),
      recordPriceChange: vi.fn().mockResolvedValue(undefined),
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
          <MemoryRouter initialEntries={[`/inventory/${target.id}/edit`]}>
            <Routes>
              <Route path="/inventory/:id/edit" element={<InventoryFormPage />} />
            </Routes>
          </MemoryRouter>
        </QueryClientProvider>
      </DiProvider>,
    );
  }

  it('shows no options note on the Price field when the product has no selling options', async () => {
    editHarness({ role: UserRole.admin, target: editableProduct({ sellingOptions: [] }) });
    await screen.findByLabelText('Name');
    expect(screen.queryByText(/inventory value/)).toBeNull();
  });

  it('shows a note on the Price field once the product has a selling option', async () => {
    const by3: SellingOption = { id: 'o2', label: 'By 3', pieces: 3, price: 330 };
    editHarness({ role: UserRole.admin, target: editableProduct({ sellingOptions: [by3] }) });
    expect(await screen.findByText(/inventory value/)).toBeInTheDocument();
  });

  it('shows the Selling options section to an admin editing a product', async () => {
    editHarness({ role: UserRole.admin });
    expect(await screen.findByText('Selling options')).toBeInTheDocument();
  });

  it('hides the Selling options section from a staff user editing a product', async () => {
    editHarness({ role: UserRole.staff });
    // Wait for the async product load to resolve before asserting absence —
    // otherwise "not found" could just mean "still loading", not "hidden".
    await screen.findByLabelText('Name');
    expect(screen.queryByText('Selling options')).toBeNull();
  });

  it('hides the Selling options section from a cashier editing a product', async () => {
    editHarness({ role: UserRole.cashier });
    await screen.findByLabelText('Name');
    expect(screen.queryByText('Selling options')).toBeNull();
  });

  it('shows the Selling options section to an admin creating a new product', () => {
    signIn();
    harness();
    expect(screen.getByText('Selling options')).toBeInTheDocument();
  });

  it('hides the Selling options section from a staff user creating a new product', () => {
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role: UserRole.staff, isActive: true } as never,
      status: 'signedIn',
    });
    harness();
    expect(screen.queryByText('Selling options')).toBeNull();
  });

  it('hides the Selling options section from a cashier user creating a new product', () => {
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role: UserRole.cashier, isActive: true } as never,
      status: 'signedIn',
    });
    harness();
    expect(screen.queryByText('Selling options')).toBeNull();
  });

  it('creating a product with a selling option forwards it to the create mutation, as an empty-array-safe write', async () => {
    signIn();
    const create = vi.fn().mockResolvedValue({ id: 'new-product' } as Product);
    harness({ create });

    await userEvent.selectOptions(screen.getByLabelText('Category'), 'Brakes');
    await waitFor(() => expect(screen.getByLabelText('SKU')).toHaveValue('00070005'));
    await userEvent.type(screen.getByLabelText('Name'), 'Brake Pad');
    await userEvent.type(screen.getByLabelText('Cost'), '60');
    await userEvent.type(screen.getByLabelText('Price'), '100');
    await userEvent.type(screen.getByLabelText('Initial quantity'), '10');

    const heading = await screen.findByText('Selling options');
    const section = within(heading.closest('section') as HTMLElement);
    await userEvent.click(section.getByRole('button', { name: /add option/i }));
    await userEvent.type(section.getByLabelText('Label'), 'By 6');
    await userEvent.type(section.getByLabelText('Price'), '600');

    await userEvent.click(screen.getByRole('button', { name: 'Create product' }));

    await waitFor(() => expect(create).toHaveBeenCalled());
    const [input] = create.mock.calls[0];
    expect(input.sellingOptions).toEqual([
      expect.objectContaining({ label: 'By 6', pieces: 1, price: 600 }),
    ]);
  });

  it('blocks submit while an added selling option is invalid, and never calls the mutation', async () => {
    const update = vi.fn().mockResolvedValue(undefined);
    editHarness({ update });
    const heading = await screen.findByText('Selling options');
    // Scoped to the section: the top-level Pricing section also has a field
    // labelled "Price", so an unscoped query would be ambiguous.
    const section = within(heading.closest('section') as HTMLElement);

    await userEvent.click(section.getByRole('button', { name: /add option/i }));
    // Freshly-added row has an empty label — invalid per validateSellingOptions.
    await userEvent.click(screen.getByRole('button', { name: 'Save changes' }));

    expect(await screen.findByText(/label/i)).toBeInTheDocument();
    expect(update).not.toHaveBeenCalled();
  });

  it('allows submit once the selling option is valid, and forwards it to the write', async () => {
    const update = vi.fn().mockResolvedValue(undefined);
    editHarness({ update });
    const heading = await screen.findByText('Selling options');
    const section = within(heading.closest('section') as HTMLElement);

    await userEvent.click(section.getByRole('button', { name: /add option/i }));
    await userEvent.type(section.getByLabelText('Label'), 'By 6');
    await userEvent.type(section.getByLabelText('Price'), '600');

    await userEvent.click(screen.getByRole('button', { name: 'Save changes' }));

    await waitFor(() => expect(update).toHaveBeenCalled());
    const [, patch, , includeSellingOptions] = update.mock.calls[0];
    expect(includeSellingOptions).toBe(true);
    expect(patch.sellingOptions).toEqual([
      expect.objectContaining({ label: 'By 6', pieces: 1, price: 600 }),
    ]);
  });
});

describe('duplicate name detection', () => {
  beforeEach(() => {
    signIn();
  });

  it('stops the save and offers a choice when name+category already exist', async () => {
    const findByNameKey = vi.fn(async () =>
      product({ name: 'BELT BANDO', category: 'CVT', sku: '00020152', cost: 120, price: 250 }),
    );
    const create = vi.fn();
    harness({ findByNameKey, create });

    await fillForm({ name: 'BANDO BELT', category: 'CVT', cost: '130', price: '300' });
    await userEvent.click(screen.getByRole('button', { name: 'Create product' }));

    expect(await screen.findByText(/already exists/i)).toBeInTheDocument();
    expect(create).not.toHaveBeenCalled();
  });

  it('makes a variation carrying the typed cost and price', async () => {
    const existing = product({ name: 'BELT BANDO', category: 'CVT', sku: '00020152', cost: 120, price: 250 });
    const findByNameKey = vi.fn(async () => existing);
    const createVariation = vi.fn(async (_existing: Product, _opts: unknown) => existing);
    harness({ findByNameKey, createVariation });

    await fillForm({ name: 'BANDO BELT', category: 'CVT', cost: '130', price: '300' });
    await userEvent.click(screen.getByRole('button', { name: 'Create product' }));
    await userEvent.click(await screen.findByRole('button', { name: /make it a variation/i }));

    await waitFor(() => expect(createVariation).toHaveBeenCalledTimes(1));
    expect(createVariation.mock.calls[0][1]).toMatchObject({ cost: 130, price: 300 });
  });

  it('saves a separate product when the operator says they are different', async () => {
    const findByNameKey = vi.fn(async () => product({ name: 'BELT BANDO', category: 'CVT' }));
    const create = vi.fn(async () => product({}));
    harness({ findByNameKey, create });

    await fillForm({ name: 'BANDO BELT', category: 'CVT', cost: '130', price: '300' });
    await userEvent.click(screen.getByRole('button', { name: 'Create product' }));
    await userEvent.click(await screen.findByRole('button', { name: /separate product/i }));

    await waitFor(() => expect(create).toHaveBeenCalledTimes(1));
  });

  it('writes nothing when the operator cancels', async () => {
    const findByNameKey = vi.fn(async () => product({ name: 'BELT BANDO', category: 'CVT' }));
    const create = vi.fn();
    const createVariation = vi.fn();
    harness({ findByNameKey, create, createVariation });

    await fillForm({ name: 'BANDO BELT', category: 'CVT', cost: '130', price: '300' });
    await userEvent.click(screen.getByRole('button', { name: 'Create product' }));
    await userEvent.click(await screen.findByRole('button', { name: /cancel/i }));

    expect(create).not.toHaveBeenCalled();
    expect(createVariation).not.toHaveBeenCalled();
  });

  it('saves straight through when no duplicate exists', async () => {
    const findByNameKey = vi.fn(async () => null);
    const create = vi.fn(async () => product({}));
    harness({ findByNameKey, create });

    await fillForm({ name: 'BRAND NEW PART', category: 'CVT', cost: '130', price: '300' });
    await userEvent.click(screen.getByRole('button', { name: 'Create product' }));

    await waitFor(() => expect(create).toHaveBeenCalledTimes(1));
    expect(screen.queryByText(/already exists/i)).not.toBeInTheDocument();
  });
});
