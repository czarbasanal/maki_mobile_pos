import { describe, expect, it, vi } from 'vitest';
import { render, screen, within } from '@testing-library/react';
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

describe('InventoryListPage money cards', () => {
  it('shows the three whole-catalog figures to an admin, with their bases', () => {
    signIn(UserRole.admin);
    harness();
    expect(screen.getByText('Stock cost')).toBeInTheDocument();
    expect(screen.getByText(formatMoney(700))).toBeInTheDocument();
    expect(screen.getByText('Retail value')).toBeInTheDocument();
    expect(screen.getByText(formatMoney(1300))).toBeInTheDocument();
    expect(screen.getByText('Expected profit')).toBeInTheDocument();
    expect(screen.getByText(formatMoney(600))).toBeInTheDocument();
    // Notes carry the basis so the numbers aren't ambiguous (guide §2).
    expect(screen.getByText('at latest cost')).toBeInTheDocument();
    expect(screen.getByText(/blended margin/)).toBeInTheDocument();
  });

  it('hides the money cards from non-admin roles', () => {
    signIn(UserRole.staff);
    harness();
    expect(screen.queryByText('Stock cost')).not.toBeInTheDocument();
    expect(screen.queryByText('Retail value')).not.toBeInTheDocument();
    expect(screen.queryByText('Expected profit')).not.toBeInTheDocument();
  });

  it('summary stays whole-catalog when a category filter is applied (reference reading)', async () => {
    signIn(UserRole.admin);
    harness();
    await userEvent.click(screen.getByRole('button', { name: /Category/ }));
    await userEvent.click(screen.getByRole('option', { name: /Widgets/ }));
    // Rows narrow to Widgets, the cards do not move.
    expect(screen.queryByText('Gadget')).not.toBeInTheDocument();
    expect(screen.getByText(formatMoney(700))).toBeInTheDocument();
    expect(screen.getByText(formatMoney(1300))).toBeInTheDocument();
  });
});

describe('InventoryListPage stock health card', () => {
  it('counts the three buckets and filters the table when a row is clicked', async () => {
    signIn(UserRole.staff);
    harness([
      widget({ id: 'a', sku: 'IN-1', name: 'Healthy', quantity: 30, reorderLevel: 2 }),
      widget({ id: 'b', sku: 'OUT-1', name: 'Gone', quantity: 0, reorderLevel: 2 }),
    ]);

    expect(screen.getByText('2 SKUs')).toBeInTheDocument();
    // The health rows and the view chips both label the buckets — pick the
    // card's row (it has the color square, the chip has a count).
    await userEvent.click(screen.getAllByRole('button', { name: /Out of stock/ })[0]);
    expect(screen.getByText('Gone')).toBeInTheDocument();
    expect(screen.queryByText('Healthy')).not.toBeInTheDocument();
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

  it('keeps the footer visible under one page, with Next disabled', () => {
    // Reference behavior: the footer is part of the card whenever rows
    // render; it hides only on the empty states.
    signIn(UserRole.staff);
    harness(many.slice(0, 25));

    expect(screen.getByText('1–25 of 25')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Next' })).toBeDisabled();
  });
});

describe('InventoryListPage SKU cell', () => {
  it('displays the SKU verbatim in a mono cell', () => {
    signIn(UserRole.admin);
    harness([widget({ sku: '00070153' })]);
    const cell = screen.getByText('00070153');
    expect(cell).toBeInTheDocument();
    // Its own dedicated column now — mono comes from the td.
    expect(cell.closest('td')).toHaveClass('font-mono');
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

describe('InventoryListPage status filter', () => {
  it('hides archived products by default and has no show-inactive toggle', () => {
    signIn(UserRole.admin);
    harness([
      widget({ id: 'a', sku: 'LIVE-1', name: 'Live Part', isActive: true }),
      widget({ id: 'b', sku: 'DEAD-1', name: 'Retired Part', isActive: false }),
    ]);
    // Assert on the SKU cell — the name cell carries an "(inactive)" badge
    // that splits its text node.
    expect(screen.getByText('LIVE-1')).toBeInTheDocument();
    expect(screen.queryByText('DEAD-1')).not.toBeInTheDocument();
    // The toggle was replaced by a Status filter.
    expect(screen.queryByRole('button', { name: /inactive/i })).not.toBeInTheDocument();
  });

  it('shows only archived products when the state segmented is set to Inactive', async () => {
    signIn(UserRole.admin);
    harness([
      widget({ id: 'a', sku: 'LIVE-1', name: 'Live Part', isActive: true }),
      widget({ id: 'b', sku: 'DEAD-1', name: 'Retired Part', isActive: false }),
    ]);
    await userEvent.click(screen.getByRole('radio', { name: 'Inactive' }));
    expect(screen.getByText('DEAD-1')).toBeInTheDocument();
    expect(screen.queryByText('LIVE-1')).not.toBeInTheDocument();
  });
});

describe('InventoryListPage — redesign specifics', () => {
  it('Margin and Cost columns render only for cost-holders, colored by threshold', () => {
    signIn(UserRole.admin);
    harness([
      widget({ id: 'a', sku: 'FAT-1', name: 'Fat', cost: 10, price: 100 }), // 90%
      widget({ id: 'b', sku: 'THIN-1', name: 'Thin', cost: 90, price: 100 }), // 10%
    ]);
    expect(screen.getByText('Margin')).toBeInTheDocument();
    expect(screen.getByText('90%')).toHaveClass('text-pos');
    expect(screen.getByText('10%')).toHaveClass('text-neg');
  });

  it('staff see neither Cost nor Margin', () => {
    signIn(UserRole.staff);
    harness();
    expect(screen.queryByText('Margin')).not.toBeInTheDocument();
    expect(screen.queryByText('Cost')).not.toBeInTheDocument();
  });

  it('margin shows — when the price is zero', () => {
    signIn(UserRole.admin);
    harness([widget({ id: 'a', sku: 'FREE-1', name: 'Free', cost: 10, price: 0 })]);
    const row = screen.getByText('FREE-1').closest('tr')!;
    expect(within(row).getAllByText('—').length).toBeGreaterThanOrEqual(1);
  });

  it('the stock cell reads none / N on hand by bucket', () => {
    signIn(UserRole.staff);
    harness([
      widget({ id: 'a', sku: 'OUT-1', name: 'Gone', quantity: 0, reorderLevel: 2 }),
      widget({ id: 'b', sku: 'IN-1', name: 'Healthy', quantity: 30, reorderLevel: 2 }),
    ]);
    expect(screen.getByText('none')).toHaveClass('text-neg');
    expect(screen.getByText('30 on hand')).toHaveClass('text-ink-2');
  });

  it('export downloads the FILTERED rows and toasts the count', async () => {
    signIn(UserRole.admin);
    // jsdom ships no createObjectURL — stub the pair downloadCsv uses.
    const urlSpy = vi.fn(() => 'blob:x');
    const revokeSpy = vi.fn();
    Object.assign(URL, { createObjectURL: urlSpy, revokeObjectURL: revokeSpy });
    harness();

    await userEvent.click(screen.getByRole('button', { name: /Category/ }));
    await userEvent.click(screen.getByRole('option', { name: /Widgets/ }));
    await userEvent.click(screen.getByRole('button', { name: 'Export CSV' }));

    // The Toaster isn't mounted in this harness — the download itself is the
    // observable: a blob URL was minted (and the CSV held the filtered row).
    expect(urlSpy).toHaveBeenCalledTimes(1);
  });

  it('first-run and filtered-empty states are distinct', async () => {
    signIn(UserRole.admin);
    const view = harness([]);
    expect(screen.getByText('No products yet')).toBeInTheDocument();
    view.unmount();

    signIn(UserRole.admin);
    harness();
    await userEvent.type(screen.getByPlaceholderText('Search by name or SKU'), 'zzz');
    expect(await screen.findByText('No products match these filters')).toBeInTheDocument();
    expect(screen.queryByText('No products yet')).not.toBeInTheDocument();
  });
});
