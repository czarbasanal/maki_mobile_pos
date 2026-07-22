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
