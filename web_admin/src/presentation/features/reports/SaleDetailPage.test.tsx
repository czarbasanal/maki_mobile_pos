import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { SaleDetailPage } from './SaleDetailPage';
import { DiscountType, PaymentMethod, SaleStatus, UserRole } from '@/domain/enums';
import type { Category, Sale, User } from '@/domain/entities';
import { formatMoney } from '@/core/utils/money';
import {
  saleGrandTotal,
  saleLaborSubtotal,
  salePartsSubtotal,
  saleTotalDiscount,
} from '@/domain/entities';

function sale(overrides: Partial<Sale> = {}): Sale {
  return {
    id: 's1',
    saleNumber: 'OR-0001',
    items: [
      {
        id: 'i1',
        productId: 'p1',
        sku: 'SKU-1',
        name: 'Spark Plug',
        unitPrice: 100,
        unitCost: 60,
        quantity: 2,
        discountValue: 20,
        unit: 'pcs',
        optionId: null,
        optionLabel: null,
        optionPieces: null,
        optionPrice: null,
      },
    ],
    laborLines: [{ id: 'l1', description: 'Tune-up', fee: 450 }],
    feeLines: [],
    mechanicId: 'm1',
    mechanicName: 'Juan Dela Cruz',
    motorcycleModel: 'Yamaha Mio i 125',
    discountType: DiscountType.amount,
    paymentMethod: PaymentMethod.cash,
    tenders: {},
    amountReceived: 650,
    changeGiven: 0,
    status: SaleStatus.completed,
    cashierId: 'c1',
    cashierName: 'Cashier',
    createdAt: new Date('2026-05-13T10:00:00Z'),
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

function webUser(role: UserRole): User {
  return {
    id: `u-${role}`,
    email: `${role}@shop.test`,
    displayName: `${role[0].toUpperCase()}${role.slice(1)} User`,
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

interface HarnessOptions {
  user?: User;
  pending?: boolean;
  voidReasons?: string[];
  voidRequestRepo?: Partial<Container['voidRequestRepo']>;
  /** Router history, last entry being the page under test. */
  entries?: string[];
  activityLogRepo?: Partial<Container['activityLogRepo']>;
}

function harness(saleRepo: Partial<Container['saleRepo']>, opts: HarnessOptions = {}) {
  const user = opts.user ?? webUser(UserRole.admin);
  useAuthStore.setState({ status: 'signedIn', user });
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const categoryRepo: Partial<Container['categoryRepo']> = {
    watchAll: (_kind, cb: (categories: Category[]) => void) => {
      cb(
        (opts.voidReasons ?? []).map((name, i) => ({
          id: `vr${i}`,
          name,
          isActive: true,
          createdAt: new Date('2026-01-01'),
          updatedAt: null,
          createdBy: null,
          updatedBy: null,
        })),
      );
      return () => {};
    },
  };
  // The container falls back to REAL Firestore repos for anything not
  // overridden — the void-request repo must always be stubbed here.
  const voidRequestRepo: Partial<Container['voidRequestRepo']> = {
    hasPendingForSale: vi.fn().mockResolvedValue(opts.pending ?? false),
    createRequest: vi.fn().mockResolvedValue(undefined),
    ...(opts.voidRequestRepo ?? {}),
  };
  const activityLogRepo: Partial<Container['activityLogRepo']> = {
    log: vi.fn().mockResolvedValue(undefined),
    ...(opts.activityLogRepo ?? {}),
  };
  const view = render(
    <DiProvider
      override={{
        saleRepo: saleRepo as Container['saleRepo'],
        categoryRepo: categoryRepo as Container['categoryRepo'],
        voidRequestRepo: voidRequestRepo as Container['voidRequestRepo'],
        activityLogRepo: activityLogRepo as Container['activityLogRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter
          initialEntries={opts.entries ?? ['/reports/sales/s1']}
          initialIndex={(opts.entries?.length ?? 1) - 1}
        >
          <Routes>
            <Route path="/reports/sales/:id" element={<SaleDetailPage />} />
            <Route path="/sales/day" element={<div>day sales page</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { view, voidRequestRepo, activityLogRepo };
}

describe('SaleDetailPage', () => {
  it('names the motorcycle beside the mechanic when the sale came from a job order', async () => {
    harness({ getById: vi.fn().mockResolvedValue(sale()) });
    await waitFor(() => expect(screen.getByRole('heading', { name: 'OR-0001' })).toBeInTheDocument());
    expect(screen.getByText(/Yamaha Mio i 125/)).toBeInTheDocument();
  });

  it('omits the motorcycle line for a walk-in sale', async () => {
    harness({ getById: vi.fn().mockResolvedValue(sale({ motorcycleModel: null })) });
    await waitFor(() => expect(screen.getByRole('heading', { name: 'OR-0001' })).toBeInTheDocument());
    expect(screen.queryByText(/Motorcycle:/)).not.toBeInTheDocument();
  });

  it('does not show a Shop fees row when the sale has no fee lines', async () => {
    harness({ getById: vi.fn().mockResolvedValue(sale()) });
    await waitFor(() => expect(screen.getByRole('heading', { name: 'OR-0001' })).toBeInTheDocument());
    expect(screen.queryByText('Shop fees')).not.toBeInTheDocument();
  });

  it('shows fee rows in the item table and a Shop fees total when fees are present', async () => {
    const withFees = sale({
      feeLines: [{ id: 'f1', name: 'Convenience fee', amount: 50 }],
    });
    harness({ getById: vi.fn().mockResolvedValue(withFees) });
    await waitFor(() => expect(screen.getByRole('heading', { name: 'OR-0001' })).toBeInTheDocument());

    // Rendered twice: once in the on-screen table, once in the hidden print receipt.
    expect(screen.getAllByText(/Convenience fee/).length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('Shop fees').length).toBeGreaterThanOrEqual(1);
  });

  describe('selling option', () => {
    const optionItem = (quantity: number) => ({
      id: 'i1',
      productId: 'p1',
      sku: 'ABC-1',
      name: 'Pulley Ball',
      unitPrice: 110,
      unitCost: 60,
      quantity,
      discountValue: 0,
      unit: 'pcs',
      optionId: 'o2',
      optionLabel: 'By 3',
      optionPieces: 3,
      optionPrice: 330,
    });

    it('shows the option label beside the name for a single set', async () => {
      harness({ getById: vi.fn().mockResolvedValue(sale({ items: [optionItem(3)] })) });
      await waitFor(() => expect(screen.getByRole('heading', { name: 'OR-0001' })).toBeInTheDocument());

      expect(screen.getAllByText(/By 3/).length).toBeGreaterThanOrEqual(1);
      expect(screen.queryByText(/× 2/)).not.toBeInTheDocument();
    });

    it('shows the set count and total pieces for more than one set', async () => {
      harness({ getById: vi.fn().mockResolvedValue(sale({ items: [optionItem(6)] })) });
      await waitFor(() => expect(screen.getByRole('heading', { name: 'OR-0001' })).toBeInTheDocument());

      expect(screen.getAllByText(/By 3 × 2/).length).toBeGreaterThanOrEqual(1);
      expect(screen.getAllByText(/6 pcs/).length).toBeGreaterThanOrEqual(1);
    });

    it('a line with no option renders unchanged', async () => {
      harness({ getById: vi.fn().mockResolvedValue(sale()) });
      await waitFor(() => expect(screen.getByRole('heading', { name: 'OR-0001' })).toBeInTheDocument());

      expect(screen.queryByText(/By /)).not.toBeInTheDocument();
    });
  });

  it('reconciles: rendered Total equals parts − discount + labor + fees for a composite sale', async () => {
    const composite = sale({
      feeLines: [{ id: 'f1', name: 'Convenience fee', amount: 50 }],
    });
    harness({ getById: vi.fn().mockResolvedValue(composite) });
    await waitFor(() => expect(screen.getByRole('heading', { name: 'OR-0001' })).toBeInTheDocument());

    const expectedTotal =
      salePartsSubtotal(composite) -
      saleTotalDiscount(composite) +
      saleLaborSubtotal(composite) +
      50; // fees
    expect(expectedTotal).toBe(saleGrandTotal(composite));
    expect(screen.getAllByText(formatMoney(expectedTotal)).length).toBeGreaterThanOrEqual(1);
  });
});

describe('SaleDetailPage — void gating by role (cashier web access)', () => {
  it('admin gets the direct Void button, no Request void', async () => {
    harness({ getById: vi.fn().mockResolvedValue(sale()) });
    await screen.findByRole('heading', { name: 'OR-0001' });
    expect(screen.getByRole('button', { name: 'Void sale' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Request void' })).not.toBeInTheDocument();
  });

  it('cashier gets Request void, never the direct Void', async () => {
    harness(
      { getById: vi.fn().mockResolvedValue(sale()) },
      { user: webUser(UserRole.cashier) },
    );
    await screen.findByRole('heading', { name: 'OR-0001' });
    expect(screen.getByRole('button', { name: 'Request void' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Void sale' })).not.toBeInTheDocument();
  });

  it('a pending request replaces the cashier action with the banner', async () => {
    harness(
      { getById: vi.fn().mockResolvedValue(sale()) },
      { user: webUser(UserRole.cashier), pending: true },
    );
    await screen.findByText('Void pending approval');
    expect(screen.queryByRole('button', { name: 'Request void' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Void sale' })).not.toBeInTheDocument();
  });

  it('a pending request points the admin at the Void Requests queue', async () => {
    harness({ getById: vi.fn().mockResolvedValue(sale()) }, { pending: true });
    await screen.findByText('Void pending approval');
    expect(screen.getByText(/approve or reject it from Void Requests/i)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Void sale' })).not.toBeInTheDocument();
  });

  it('a voided sale offers neither action to anyone', async () => {
    harness(
      {
        getById: vi.fn().mockResolvedValue(
          sale({ status: SaleStatus.voided, voidedAt: new Date('2026-05-14') }),
        ),
      },
      { user: webUser(UserRole.cashier) },
    );
    await screen.findByRole('heading', { name: 'OR-0001' });
    expect(screen.queryByRole('button', { name: 'Request void' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Void sale' })).not.toBeInTheDocument();
  });

  describe('a voided sale reads as voided', () => {
    const voided = () =>
      sale({
        status: SaleStatus.voided,
        voidedAt: new Date('2026-05-14'),
        voidReason: 'Wrong item scanned',
      });

    it('replaces the action with a disabled Voided button', async () => {
      // Previously the button simply vanished, which reads the same as "you
      // are not allowed to void" — say what happened instead.
      harness({ getById: vi.fn().mockResolvedValue(voided()) });
      await screen.findByRole('heading', { name: 'OR-0001' });

      const btn = screen.getByRole('button', { name: 'Voided' });
      expect(btn).toBeDisabled();
    });

    it('strikes through the sale number and the total', async () => {
      harness({ getById: vi.fn().mockResolvedValue(voided()) });
      const heading = await screen.findByRole('heading', { name: 'OR-0001' });
      expect(heading).toHaveClass('line-through');

      const total = screen.getByTestId('sale-total');
      expect(total).toHaveClass('line-through');
    });

    it('names why it was voided', async () => {
      harness({ getById: vi.fn().mockResolvedValue(voided()) });
      await screen.findByRole('heading', { name: 'OR-0001' });
      // Specific: 'Wrong item scanned' is also one of the void-reason options
      // sitting in the (unopened) dialog markup.
      expect(screen.getByText(/^Voided: Wrong item scanned/)).toBeInTheDocument();
    });

    it('leaves a completed sale untouched', async () => {
      harness({ getById: vi.fn().mockResolvedValue(sale()) });
      const heading = await screen.findByRole('heading', { name: 'OR-0001' });
      expect(heading).not.toHaveClass('line-through');
      expect(screen.queryByRole('button', { name: 'Voided' })).not.toBeInTheDocument();
    });
  });

  it('the request writes the mobile-shaped doc and logs the mobile string', async () => {
    // Stateful stub: the pending flag flips once the request lands, so the
    // page's cache invalidation can surface the banner like production would.
    let pendingNow = false;
    const { voidRequestRepo, activityLogRepo } = harness(
      { getById: vi.fn().mockResolvedValue(sale()) },
      {
        user: webUser(UserRole.cashier),
        voidReasons: ['Wrong item', 'Customer changed mind'],
        voidRequestRepo: {
          hasPendingForSale: vi.fn().mockImplementation(() => Promise.resolve(pendingNow)),
          createRequest: vi.fn().mockImplementation(() => {
            pendingNow = true;
            return Promise.resolve();
          }),
        },
      },
    );
    await userEvent.click(await screen.findByRole('button', { name: 'Request void' }));
    await userEvent.selectOptions(screen.getByRole('combobox'), 'Wrong item');
    await userEvent.click(screen.getByRole('button', { name: 'Send request' }));

    await waitFor(() => expect(voidRequestRepo.createRequest).toHaveBeenCalledTimes(1));
    const expectedTotal = saleGrandTotal(sale());
    expect(voidRequestRepo.createRequest).toHaveBeenCalledWith({
      saleId: 's1',
      saleNumber: 'OR-0001',
      saleGrandTotal: expectedTotal,
      requestedBy: 'u-cashier',
      requestedByName: 'Cashier User',
      requestedByRole: 'cashier',
      reason: 'Wrong item',
      itemsSummary: '2× Spark Plug',
    });
    await waitFor(() =>
      expect(activityLogRepo.log).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'Requested void for sale OR-0001',
          details: `Reason: Wrong item, Amount: ₱${expectedTotal.toFixed(2)}`,
          entityId: 's1',
          entityType: 'sale',
        }),
      ),
    );
    // The pending banner takes over after the request lands.
    await screen.findByText('Void pending approval');
  });

  it("the 'Other' reason requires at least 5 characters of detail", async () => {
    const { voidRequestRepo } = harness(
      { getById: vi.fn().mockResolvedValue(sale()) },
      { user: webUser(UserRole.cashier), voidReasons: ['Wrong item'] },
    );
    await userEvent.click(await screen.findByRole('button', { name: 'Request void' }));
    await userEvent.selectOptions(screen.getByRole('combobox'), 'Other');
    const detail = screen.getByRole('textbox');
    await userEvent.type(detail, 'oops');
    expect(screen.getByRole('button', { name: 'Send request' })).toBeDisabled();
    await userEvent.type(detail, ' wrong price charged');
    await userEvent.click(screen.getByRole('button', { name: 'Send request' }));
    await waitFor(() =>
      expect(voidRequestRepo.createRequest).toHaveBeenCalledWith(
        expect.objectContaining({ reason: 'oops wrong price charged' }),
      ),
    );
  });
});

describe('SaleDetailPage — going back', () => {
  it('returns to where you came from, not to a fixed page', async () => {
    // Dashboard → View all → a sale. "Back to sales" was hardcoded to the
    // sales REPORT, so it dumped you somewhere you had never been.
    harness(
      { getById: vi.fn().mockResolvedValue(sale()) },
      { entries: ['/sales/day', '/reports/sales/s1'] },
    );
    await screen.findByRole('heading', { name: 'OR-0001' });

    await userEvent.click(screen.getByRole('button', { name: /back/i }));
    expect(await screen.findByText('day sales page')).toBeInTheDocument();
  });
});
