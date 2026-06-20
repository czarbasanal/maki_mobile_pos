import { useMutation } from '@tanstack/react-query';
import { useSaleRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Sale } from '@/domain/entities';
import { PaymentMethod } from '@/domain/enums/PaymentMethod';
import { SaleStatus } from '@/domain/enums/SaleStatus';
import type { DiscountType } from '@/domain/enums/DiscountType';
import { cartGrandTotal, cashTenders, type CartLine } from '@/domain/sales/cart';

export interface CheckoutInput {
  lines: CartLine[];
  discountType: DiscountType;
  amountReceived: number;
  changeGiven: number;
}

export function useCheckout() {
  const repo = useSaleRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<Sale, Error, CheckoutInput>({
    mutationFn: async ({ lines, discountType, amountReceived, changeGiven }) => {
      if (!actor) throw new Error('Not signed in');
      const grandTotal = cartGrandTotal(lines, discountType);
      const cashierName = actor.displayName.trim() || actor.email;
      const saleInput: Omit<Sale, 'id' | 'createdAt' | 'updatedAt'> = {
        saleNumber: '', // generated inside the repo transaction
        items: lines,
        laborLines: [],
        mechanicId: null,
        mechanicName: null,
        tenders: cashTenders(grandTotal),
        discountType,
        paymentMethod: PaymentMethod.cash,
        amountReceived,
        changeGiven,
        status: SaleStatus.completed,
        cashierId: actor.id,
        cashierName,
        draftId: null,
        notes: null,
        voidedAt: null,
        voidedBy: null,
        voidedByName: null,
        voidReason: null,
      };
      return repo.create(saleInput, actor.id);
    },
  });
}
