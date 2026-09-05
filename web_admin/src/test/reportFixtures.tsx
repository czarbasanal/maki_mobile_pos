// Fixtures + harness for the reports page tests. One line-level `sale()`
// builder so every page test derives its expectations from the same shape
// the domain derives its figures from.
import type { ReactNode } from 'react';
import { render } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { vi } from 'vitest';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { DiscountType, PaymentMethod, SaleStatus, UserRole } from '@/domain/enums';
import type { Product, Sale, SaleItem, User } from '@/domain/entities';

export function webUser(role: UserRole): User {
  return {
    id: `u-${role}`,
    email: `${role}@shop.test`,
    displayName: `${role} user`,
    role,
    isActive: true,
    phoneNumber: null,
    photoUrl: null,
    createdAt: new Date('2026-01-01'),
    updatedAt: null,
    createdBy: null,
    updatedBy: null,
    lastLoginAt: null,
  };
}

export function item(
  o: Partial<SaleItem> & { productId: string; unitPrice: number; unitCost: number; quantity: number },
): SaleItem {
  return {
    id: `i-${o.productId}`,
    sku: `SKU-${o.productId}`,
    name: `Product ${o.productId}`,
    discountValue: 0,
    unit: 'pcs',
    optionId: null,
    optionLabel: null,
    optionPieces: null,
    optionPrice: null,
    ...o,
  };
}

export function sale(overrides: Partial<Sale> = {}): Sale {
  return {
    id: 's1',
    saleNumber: 'OR-0001',
    items: [item({ productId: 'p1', name: 'Spark Plug', sku: 'SKU-1', unitPrice: 100, unitCost: 60, quantity: 2 })],
    laborLines: [{ id: 'l1', description: 'Tune-up', fee: 450 }],
    feeLines: [],
    mechanicId: 'm1',
    mechanicName: 'Juan Dela Cruz',
    motorcycleModel: null,
    discountType: DiscountType.amount,
    paymentMethod: PaymentMethod.cash,
    tenders: {},
    amountReceived: 650,
    changeGiven: 0,
    status: SaleStatus.completed,
    cashierId: 'c1',
    cashierName: 'Cashier',
    createdAt: new Date(),
    updatedAt: null,
    jobOrderId: null,
    notes: null,
    voidedAt: null,
    voidedBy: null,
    voidedByName: null,
    voidReason: null,
    ...overrides,
  };
}

export const DAY_MS = 24 * 60 * 60 * 1000;

type PriceChanges = Awaited<ReturnType<Container['productRepo']['listPriceChangesInRange']>>;

export interface ReportHarness {
  saleRepo: Partial<Container['saleRepo']>;
  productRepo: Partial<Container['productRepo']>;
}

/**
 * Renders a reports page with a mocked sale repo. `sales` may be a function
 * of the queried range so a test can prove figures move with the range.
 */
export function renderReport(
  ui: ReactNode,
  {
    sales = [],
    priceChanges = [],
    products = [],
    role = UserRole.admin,
    path = '/reports',
  }: {
    sales?: Sale[] | ((range: { start: Date; end: Date }) => Sale[]);
    priceChanges?: PriceChanges | ((range: { start: Date; end: Date }) => PriceChanges) | Error;
    products?: Product[];
    role?: UserRole;
    path?: string;
  } = {},
): ReportHarness {
  useAuthStore.setState({ status: 'signedIn', user: webUser(role) });
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const saleRepo: Partial<Container['saleRepo']> = {
    list: vi.fn().mockImplementation((range: { start: Date; end: Date }) =>
      Promise.resolve(typeof sales === 'function' ? sales(range) : sales),
    ),
  };
  const productRepo: Partial<Container['productRepo']> = {
    listPriceChangesInRange: vi.fn().mockImplementation((start: Date, end: Date) =>
      priceChanges instanceof Error
        ? Promise.reject(priceChanges)
        : Promise.resolve(typeof priceChanges === 'function' ? priceChanges({ start, end }) : priceChanges),
    ),
    watchAll: (cb: (p: Product[]) => void) => {
      cb(products);
      return () => {};
    },
  };
  render(
    <DiProvider
      override={{
        saleRepo: saleRepo as Container['saleRepo'],
        productRepo: productRepo as Container['productRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={[path]}>{ui}</MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { saleRepo, productRepo };
}
