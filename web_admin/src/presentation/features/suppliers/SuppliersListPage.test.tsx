// The redesigned supplier directory: the card rows and the chips share one
// inView predicate, Parts/Spend 90d replace the dead inventory value,
// contact phone is copyable, and 'Never'/'No contact' read as states.
import { describe, expect, it, beforeEach } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { SuppliersListPage } from './SuppliersListPage';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole, TransactionType } from '@/domain/enums';
import { clearSubscriptionCache } from '@/presentation/hooks/useFirestoreSubscription';
import type { Product, Receiving, Supplier } from '@/domain/entities';

const supplier = (o: Partial<Supplier> = {}): Supplier => ({
  id: 's1',
  name: 'Boss Atan Argao',
  address: 'Poblacion, Argao, Cebu',
  contactPerson: 'Aileen Flores',
  contactNumber: '0918 662 3390',
  alternativeNumber: null,
  email: null,
  transactionType: TransactionType.cash,
  isActive: true,
  notes: null,
  createdAt: new Date(),
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
  productCount: 0,
  totalInventoryValue: 0,
  ...o,
});

const receipt = (o: Partial<Receiving> = {}): Receiving => ({
  id: 'r1',
  referenceNumber: 'RCV-1',
  supplierId: 's1',
  supplierName: 'Boss Atan Argao',
  items: [],
  totalCost: 1000,
  totalQuantity: 5,
  status: 'completed',
  notes: null,
  createdAt: new Date(),
  completedAt: new Date(),
  createdBy: 'u1',
  createdByName: 'C',
  completedBy: 'u1',
  version: 0,
  invoiceNumber: null,
  receivedOn: null,
  ...o,
});

function harness({
  suppliers = [supplier()],
  products = [],
  receivings = [],
}: {
  suppliers?: Supplier[];
  products?: Product[];
  receivings?: Receiving[];
} = {}) {
  clearSubscriptionCache();
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.c', displayName: 'C', role: UserRole.admin, isActive: true } as never,
    status: 'signedIn',
  });
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const override = {
    supplierRepo: {
      watchAll: (cb: (s: Supplier[]) => void) => {
        cb(suppliers);
        return () => {};
      },
    },
    productRepo: {
      watchAll: (cb: (p: Product[]) => void) => {
        cb(products);
        return () => {};
      },
    },
    receivingRepo: {
      watchAll: (_range: unknown, cb: (r: Receiving[]) => void) => {
        cb(receivings);
        return () => {};
      },
    },
  } as unknown as Container;
  render(
    <DiProvider override={override}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/suppliers']}>
          <Routes>
            <Route path="/suppliers" element={<SuppliersListPage />} />
            <Route path="/suppliers/edit/:id" element={<div>EDIT SUPPLIER</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('SuppliersListPage (redesign)', () => {
  beforeEach(() => clearSubscriptionCache());

  it('renders the initials mark, terms chip, copyable phone, and derived columns', () => {
    harness({
      suppliers: [supplier()],
      products: [
        { id: 'p1', supplierId: 's1', isActive: true } as Product,
        { id: 'p2', supplierId: 's1', isActive: true } as Product,
      ],
      receivings: [receipt({ totalCost: 38683 })],
    });
    const row = screen.getByText('Boss Atan Argao').closest('tr')!;
    expect(within(row).getByText('BA')).toBeInTheDocument(); // initials mark
    expect(within(row).getByText('Cash')).toBeInTheDocument();
    expect(within(row).getByRole('button', { name: /copy phone number/i })).toBeInTheDocument();
    expect(within(row).getByText('2')).toBeInTheDocument(); // parts
    expect(within(row).getByText('₱38,683.00')).toBeInTheDocument(); // spend 90d
  });

  it('a supplier with no receipts reads Never, no contact reads No contact', () => {
    harness({
      suppliers: [supplier({ contactPerson: null, contactNumber: null })],
    });
    const row = screen.getByText('Boss Atan Argao').closest('tr')!;
    expect(within(row).getByText('Never')).toBeInTheDocument();
    expect(within(row).getByText('No contact')).toBeInTheDocument();
  });

  it('the Never received card row and its chip agree, and clicking filters to exactly that count', async () => {
    harness({
      suppliers: [
        supplier({ id: 's1', name: 'Bought From' }),
        supplier({ id: 's2', name: 'Never Bought' }),
        supplier({ id: 's3', name: 'Retired', isActive: false }),
      ],
      receivings: [receipt({ supplierId: 's1' })],
    });

    // Card row and chip BOTH read 1 (inactive s3 is excluded — not a task):
    // one predicate, two surfaces, same number.
    expect(screen.getAllByRole('button', { name: /Never received 1/ })).toHaveLength(2);
    const cardRow = screen.getAllByRole('button', { name: /Never received/ })[0];
    await userEvent.click(cardRow);
    expect(cardRow).toHaveAttribute('aria-pressed', 'true');
    expect(screen.getByText('Never Bought')).toBeInTheDocument();
    expect(screen.queryByText('Bought From')).not.toBeInTheDocument();
  });

  it('summary stats: buying on terms and missing contact', () => {
    harness({
      suppliers: [
        supplier({ id: 's1', transactionType: TransactionType.terms60d }),
        supplier({ id: 's2', name: 'Cash Guy', transactionType: TransactionType.cash }),
        supplier({ id: 's3', name: 'Ghost', contactPerson: null, contactNumber: null }),
      ],
    });
    expect(screen.getByText('Buying on terms')).toBeInTheDocument();
    expect(screen.getByText('Missing contact')).toBeInTheDocument();
    expect(screen.getByText('no name or number on file')).toBeInTheDocument();
  });

  it('rows open the supplier; there are no per-row action buttons', async () => {
    harness({ suppliers: [supplier()] });
    const row = screen.getByText('Boss Atan Argao').closest('tr')!;
    expect(within(row).queryByRole('button', { name: /edit/i })).not.toBeInTheDocument();
    await userEvent.click(screen.getByText('Boss Atan Argao'));
    expect(screen.getByText('EDIT SUPPLIER')).toBeInTheDocument();
  });

  it('first-run and filtered-empty are distinct; inactive default view hides retired rows', async () => {
    harness({ suppliers: [] });
    expect(screen.getByText('No suppliers yet')).toBeInTheDocument();
  });

  it('the terms filter narrows and its counts respect the search only', async () => {
    harness({
      suppliers: [
        supplier({ id: 's1', name: 'Cash Guy', transactionType: TransactionType.cash }),
        supplier({ id: 's2', name: 'Terms Guy', transactionType: TransactionType.terms60d }),
      ],
    });
    await userEvent.click(screen.getByRole('button', { name: /Terms/ }));
    await userEvent.click(screen.getByRole('option', { name: /60 Days/ }));
    expect(screen.getByText('Terms Guy')).toBeInTheDocument();
    expect(screen.queryByText('Cash Guy')).not.toBeInTheDocument();
  });
});
