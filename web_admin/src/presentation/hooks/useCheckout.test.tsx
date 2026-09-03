// Activity-log wiring for sale checkout (task-10 representative case: sale
// create -> type 'sale'). Also covers the JO bill-out path, which is the
// same write (repo.create converts the job order internally when jobOrderId is set).
import { describe, expect, it, vi } from 'vitest';
import { act, renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useCheckout, type CheckoutInput } from './useCheckout';
import { DiscountType } from '@/domain/enums/DiscountType';
import { PaymentMethod } from '@/domain/enums/PaymentMethod';
import type { Sale } from '@/domain/entities';
import type { ReactNode } from 'react';

function wrap(saleRepo: Partial<Container['saleRepo']>, activityLog: ReturnType<typeof vi.fn>) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const activityLogRepo = { log: activityLog } as unknown as Container['activityLogRepo'];
  return ({ children }: { children: ReactNode }) => (
    <DiProvider override={{ saleRepo: saleRepo as Container['saleRepo'], activityLogRepo }}>
      <QueryClientProvider client={qc}>{children}</QueryClientProvider>
    </DiProvider>
  );
}

const checkoutInput: CheckoutInput = {
  checkoutId: 'ticket-uuid-1',
  lines: [
    { id: 'i1', productId: 'p1', sku: 'A', name: 'Plug', unitPrice: 100, unitCost: 60, quantity: 2, discountValue: 0, unit: 'pcs', optionId: null, optionLabel: null, optionPieces: null, optionPrice: null },
  ],
  discountType: DiscountType.amount,
  paymentMethod: PaymentMethod.cash,
  tenders: { cash: 200 },
  amountReceived: 200,
  changeGiven: 0,
  laborLines: [],
  feeLines: [],
  mechanicId: null,
  mechanicName: null,
  motorcycleModel: null,
  jobOrderId: null,
  autoJobOrderName: null,
  notes: null,
};

function makeSale(overrides: Partial<Sale> = {}): Sale {
  return {
    id: 's1',
    saleNumber: 'S-00100',
    items: checkoutInput.lines,
    laborLines: [],
    feeLines: [],
    mechanicId: null,
    mechanicName: null,
    motorcycleModel: null,
    tenders: { cash: 200 },
    discountType: DiscountType.amount,
    paymentMethod: PaymentMethod.cash,
    amountReceived: 200,
    changeGiven: 0,
    status: 'completed' as Sale['status'],
    cashierId: 'u1',
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

describe('useCheckout activity logging', () => {
  it('logs type sale on a successful checkout', async () => {
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never,
      status: 'signedIn',
    });
    const log = vi.fn().mockResolvedValue(undefined);
    const created = makeSale();
    const create = vi.fn().mockResolvedValue(created);
    const { result } = renderHook(() => useCheckout(), { wrapper: wrap({ create }, log) });

    act(() => {
      result.current.mutate(checkoutInput);
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(log).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'sale',
        action: 'Completed sale S-00100',
        entityId: 's1',
        entityType: 'sale',
      }),
    );
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });
});
