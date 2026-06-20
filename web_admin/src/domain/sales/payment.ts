// Pure helpers that turn cashier payment entry into a Sale's tender fields.
// Mirrors the mobile salmon/mixed contract: `paymentMethod` is the label,
// `tenders` is the actual money by method (always sums to grandTotal).
import { PaymentMethod } from '@/domain/enums/PaymentMethod';

export type PaymentMode = 'cash' | 'gcash' | 'maya' | 'mixed' | 'salmon';
export type DigitalMethod = 'gcash' | 'maya';
export type DpMethod = 'cash' | 'gcash' | 'maya';

export interface PaymentDraft {
  mode: PaymentMode;
  cashReceived: number; // mode 'cash' only — cash handed (drives change)
  digitalMethod: DigitalMethod; // mode 'mixed' — which digital half
  dpMethod: DpMethod; // mode 'salmon' — downpayment method
  splitAmount: number; // 'mixed' = digital amount; 'salmon' = downpayment
}

export const emptyPaymentDraft: PaymentDraft = {
  mode: 'cash',
  cashReceived: 0,
  digitalMethod: 'gcash',
  dpMethod: 'cash',
  splitAmount: 0,
};

function roundCents(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

export function paymentLabel(mode: PaymentMode): PaymentMethod {
  // mode values are a subset of PaymentMethod values.
  return mode as PaymentMethod;
}

export function buildTenders(
  draft: PaymentDraft,
  total: number,
): Partial<Record<PaymentMethod, number>> {
  switch (draft.mode) {
    // Single-method: the whole sale lands in one bucket. Use the RAW total (not
    // roundCents) so the tender equals grandTotal/netAmount exactly — the
    // reporting invariant Σ byPaymentMethod == netAmount must hold even when a
    // percentage discount leaves grandTotal with sub-cent fractions.
    case 'cash':
      return { [PaymentMethod.cash]: total };
    case 'gcash':
      return { [PaymentMethod.gcash]: total };
    case 'maya':
      return { [PaymentMethod.maya]: total };
    case 'mixed': {
      const digital = roundCents(draft.splitAmount);
      const tenders: Partial<Record<PaymentMethod, number>> = {
        [PaymentMethod.cash]: roundCents(total - digital),
      };
      tenders[draft.digitalMethod] = digital;
      return tenders;
    }
    case 'salmon': {
      const dp = roundCents(draft.splitAmount);
      const tenders: Partial<Record<PaymentMethod, number>> = {
        [PaymentMethod.salmon]: roundCents(total - dp),
      };
      tenders[draft.dpMethod] = dp;
      return tenders;
    }
  }
}

export function amountReceivedFor(draft: PaymentDraft, total: number): number {
  switch (draft.mode) {
    case 'cash':
      return draft.cashReceived;
    case 'salmon':
      return roundCents(draft.splitAmount);
    default:
      return total; // gcash / maya / mixed — paid in full (matches the tender)
  }
}

export function changeGivenFor(draft: PaymentDraft, total: number): number {
  if (draft.mode !== 'cash') return 0;
  return Math.max(0, roundCents(draft.cashReceived - total));
}

export function paymentError(draft: PaymentDraft, total: number): string | null {
  const t = roundCents(total);
  switch (draft.mode) {
    case 'cash':
      return roundCents(draft.cashReceived) < t
        ? 'Cash received is less than the total'
        : null;
    case 'gcash':
    case 'maya':
      return null;
    case 'mixed': {
      const s = roundCents(draft.splitAmount);
      return s > 0 && s < t ? null : 'Digital amount must be between ₱0 and the total';
    }
    case 'salmon': {
      const s = roundCents(draft.splitAmount);
      return s > 0 && s < t ? null : 'Downpayment must be between ₱0 and the total';
    }
  }
}
