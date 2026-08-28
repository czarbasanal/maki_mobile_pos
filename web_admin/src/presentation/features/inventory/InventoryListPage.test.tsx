import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { InventoryListPage } from './InventoryListPage';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import { formatMoney } from '@/core/utils/money';
import type { Product } from '@/domain/entities';

// Numbers are chosen so no two figures (row cells, unfiltered totals, filtered
// totals) collide as formatted money strings — collisions would make
// getByText ambiguous.
const widget = (o: Partial<Product> = {}): Product =>
  ({
    id: 'p1',
    sku: 'A1',
    name: 'Widget',
    category: 'Widgets',
    cost: 110,
    price: 230,
    quantity: 3,
    reorderLevel: 1,
    unit: 'pcs',
    isActive: true,
    ...o,
  }) as Product;

const gadget = (o: Partial<Product> = {}): Product =>
  ({
    id: 'p2',
    sku: 'B1',
    name: 'Gadget',
    category: 'Gadgets',
    cost: 185,
    price: 305,
    quantity: 2,
    reorderLevel: 1,
    unit: 'pcs',
    isActive: true,
    ...o,
  }) as Product;

const products: Product[] = [widget(), gadget()];

function harness(list: Product[] = products) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const productRepo: Partial<Container['productRepo']> = {
    watchAll: (cb: (products: Product[]) => void) => {
      cb(list);
      return () => {};
    },
  };
  return render(
    <DiProvider override={{ productRepo: productRepo as Container['productRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/inventory']}>
          <InventoryListPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

function signIn(role: UserRole) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role, isActive: true } as never,
  });
}

describe('InventoryListPage totals strip', () => {
  it('shows the three figures computed from the visible list to an admin', () => {
    signIn(UserRole.admin);
    harness();
    expect(screen.getByText('Stock Cost')).toBeInTheDocument();
    expect(screen.getByText(formatMoney(700))).toBeInTheDocument();
    expect(screen.getByText('Retail Value')).toBeInTheDocument();
    expect(screen.getByText(formatMoney(1300))).toBeInTheDocument();
    expect(screen.getByText('Expected Profit')).toBeInTheDocument();
    expect(screen.getByText(formatMoney(600))).toBeInTheDocument();
  });

  it('hides the totals strip from non-admin roles', () => {
    signIn(UserRole.staff);
    harness();
    expect(screen.queryByText('Stock Cost')).not.toBeInTheDocument();
    expect(screen.queryByText('Retail Value')).not.toBeInTheDocument();
    expect(screen.queryByText('Expected Profit')).not.toBeInTheDocument();
  });

  it('recomputes totals for the filtered subset when a category is applied', async () => {
    signIn(UserRole.admin);
    harness();
    await userEvent.selectOptions(screen.getByRole('combobox'), 'Widgets');
    expect(screen.getByText(formatMoney(330))).toBeInTheDocument(); // cost: 110 * 3
    expect(screen.getByText(formatMoney(690))).toBeInTheDocument(); // retail: 230 * 3
    expect(screen.getByText(formatMoney(360))).toBeInTheDocument(); // profit: 690 - 330
  });
});

describe('InventoryListPage pagination', () => {
  const many: Product[] = Array.from({ length: 30 }, (_, i) =>
    widget({ id: `p${i + 1}`, sku: `SKU-${i + 1}`, name: `Product ${i + 1}` }),
  );

  it('shows only 25 rows and the pager for 30 products, revealing the rest on page 2', async () => {
    signIn(UserRole.staff);
    harness(many);

    expect(screen.getByText('Product 1')).toBeInTheDocument();
    expect(screen.getByText('1–25 of 30')).toBeInTheDocument();
    expect(screen.queryByText('Product 26')).not.toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Next' }));

    expect(screen.getByText('Product 26')).toBeInTheDocument();
    expect(screen.getByText('Product 30')).toBeInTheDocument();
    expect(screen.queryByText('Product 1')).not.toBeInTheDocument();
  });

  it('hides the pager entirely when the filtered set is at or under 25', () => {
    signIn(UserRole.staff);
    harness(many.slice(0, 25));

    expect(screen.queryByRole('button', { name: 'Next' })).not.toBeInTheDocument();
  });
});

describe('InventoryListPage SKU cell', () => {
  it('displays the SKU verbatim in a mono cell', () => {
    signIn(UserRole.admin);
    harness([widget({ sku: '00070153' })]);
    const cell = screen.getByText('00070153');
    expect(cell).toBeInTheDocument();
    expect(cell).toHaveClass('font-mono');
  });

  it('passes a non-coded SKU through unchanged', () => {
    signIn(UserRole.admin);
    harness([widget()]);
    expect(screen.getByText('A1')).toBeInTheDocument();
  });
});

describe('InventoryListPage thumbnails', () => {
  it('shows each product’s photo in its row', () => {
    harness([widget({ imageUrl: 'https://example.test/widget.jpg' })]);

    expect(screen.getByRole('img', { name: 'Widget' })).toHaveAttribute(
      'src',
      'https://example.test/widget.jpg',
    );
  });

  it('shows a placeholder for a product with no photo yet', () => {
    // Most of the catalogue was bulk imported without images, so this is the
    // common row, not the exception — it must not look like a load error.
    harness([widget({ imageUrl: null })]);

    expect(screen.getByLabelText('No image')).toBeInTheDocument();
  });
});

describe('InventoryListPage cost visibility', () => {
  // viewProductCost is admin-only (and password-gated on mobile); the web list
  // showed the Cost column to every role that could view inventory.
  it('hides the Cost column from staff', () => {
    signIn(UserRole.staff);
    harness([widget()]);

    expect(screen.queryByText('Cost')).toBeNull();
    expect(screen.queryByText(formatMoney(110))).toBeNull();
  });

  it('shows the Cost column to admins', () => {
    signIn(UserRole.admin);
    harness([widget()]);

    expect(screen.getByText('Cost')).toBeInTheDocument();
    expect(screen.getByText(formatMoney(110))).toBeInTheDocument();
  });
});


describe('InventoryListPage — Add product gating (cashier web access)', () => {
  it('hides Add product from a cashier', () => {
    signIn(UserRole.cashier);
    harness();
    expect(screen.queryByRole('button', { name: /add product/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /add product/i })).not.toBeInTheDocument();
  });

  it('keeps Add product for staff (addProduct holders)', () => {
    signIn(UserRole.staff);
    harness();
    expect(
      screen.queryByRole('button', { name: /add product/i }) ??
        screen.queryByRole('link', { name: /add product/i }),
    ).toBeInTheDocument();
  });
});
